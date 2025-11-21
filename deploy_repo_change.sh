#!/bin/bash
set -Eeuo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
NL='\n'

# Ctrl+C i errors
trap 'echo -e "${NL}${RED}Procés parat!${NC}"; exit 1' SIGINT ERR

# Funcions externes
source ~/publish/repo_map.sh
source ~/.bash_aliases

echo -e "${NL}${GREEN}Iniciant l'actualització repository develop...${NC}"

# Seleccionar repo
if [ -n "${1-}" ]; then
  REPO_NAME="$1"
  select_repo "$REPO_NAME"
else
  select_repo
fi

# ---------- Utilitats ----------
# 5 darreres versions del Nexus
get_latest_images() {
  local num_images=5
  local response
  if ! response=$(curl -s "${REPO_LIST}"); then
    echo -e "${NL}${RED}Error en obtenir les versions del Nexus!${NC}"
    exit 1
  fi
  echo "$response" | jq -r '.tags[]' | sort -Vr | head -n "$num_images" || {
    echo -e "${NL}${RED}Error en processar les versions del Nexus!${NC}"
    exit 1
  }
}

# Versió actual del deployment.yaml (agafa el TAG de la línia image:)
get_current_image_tag() {
  # Busca línia 'image:' robustament (ignora comentaris), i extreu el que hi ha després de l'últim ':'
  local line
  line=$(grep -E '^[[:space:]]*image:[[:space:]]*[^#]+' "$DEPLOY_DIR/deployment.yaml" | head -n1 || true)
  if [ -z "$line" ]; then
    echo ""
    return 0
  fi
  # Extreu el TAG (text després de l'últim ':')
  echo "$line" | awk -F':' '{print $NF}' | xargs
}

# Substitueix només el TAG de la imatge a la línia 'image:'
set_image_tag_in_yaml() {
  local new_tag="$1"
  local file="$DEPLOY_DIR/deployment.yaml"
  if [[ ! -f "$file" ]]; then
    echo -e "${RED}Error: No s'ha trobat $file${NC}"
    exit 1
  fi
  # Sed: manté tot fins a l'últim ':' i substitueix només el que ve després pel TAG
  # Exemple: image: registry:5000/path/name:OLD -> image: registry:5000/path/name:NEW
  sed -i -E 's|^([[:space:]]*image:[[:space:]]*.+:).*|\1'"${new_tag}"'|g' "$file"
}

# ---------- Flux ----------
# Mostrar versió actual
current_tag=$(get_current_image_tag)
echo -e "${BLUE}Versió actual al deployment.yaml: ${current_tag:-<cap>} ${NC}"

# Obtenir versions del Nexus
latest_images=$(get_latest_images)

# Seleccionar versió
if [ -n "${2-}" ]; then
  VERSION="$2"
  echo -e "${NL}${GREEN}Versió proporcionada com a argument: ${RED}$VERSION${NC}"
else
  echo -e "${NL}${GREEN}Selecciona la versió que vols:${NC}"
  select VERSION in $latest_images; do
    if [[ -n ${VERSION-} ]]; then
      echo -e "${NL}${GREEN}Versió seleccionada: ${RED}$VERSION${NC}"
      break
    else
      echo -e "${NL}${RED}Opció no vàlida!${NC}"
    fi
  done
fi

# NO TOQUEM ENCARA EL YAML —> primer validem i preparem el repo Git

# Directori del repo (pare de DEPLOY_DIR)
REPO_DIR_LOCAL="$(dirname "$(dirname "$DEPLOY_DIR")")"

echo -e "${BLUE}📁 Entrant al directori del repositori: $REPO_DIR_LOCAL${NC}"
cd "$REPO_DIR_LOCAL"

# Validacions Git bàsiques
if [ ! -d ".git" ]; then
  echo -e "${RED}❌ Error: el directori actual no és un repositori Git.${NC}"
  exit 1
fi

# Detecció branca per defecte del remot
DEFAULT_BRANCH=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | awk -F'/' '{print $NF}')
[ -z "${DEFAULT_BRANCH}" ] && DEFAULT_BRANCH="master"
echo -e "${BLUE}🌿 Branca per defecte detectada: ${DEFAULT_BRANCH}${NC}"

# Assegurar que no hi ha canvis locals abans de res
git update-index -q --refresh
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo -e "${NL}${RED}❌ Hi ha canvis locals sense commitejar o en staging.${NC}"
  echo -e "${RED}   Fes commit o guarda en stash abans de continuar.${NC}"
  exit 1
fi

# Sync amb el remot
echo -e "${BLUE}🔄 Actualitzant referències remotes...${NC}"
git fetch --all --prune

echo -e "${BLUE}🔁 Canviant a ${DEFAULT_BRANCH}...${NC}"
git checkout "${DEFAULT_BRANCH}"

echo -e "${BLUE}⬇️ Fent pull de ${DEFAULT_BRANCH} (ff-only)...${NC}"
git pull --ff-only origin "${DEFAULT_BRANCH}"

# Crear branca de release
RELEASE_BRANCH="release/v${VERSION}"
echo -e "${BLUE}🔧 Creant nova branca de release: ${RELEASE_BRANCH}${NC}"
git checkout -b "${RELEASE_BRANCH}"

# ARA sí: aplicar el canvi al YAML
if [[ -f "$DEPLOY_DIR/deployment.yaml" ]]; then
  before_tag=$(get_current_image_tag || true)
  set_image_tag_in_yaml "${VERSION}"
  after_tag=$(get_current_image_tag || true)

  if [[ "${before_tag}" == "${after_tag}" ]]; then
    echo -e "${BLUE}ℹ️ El deployment.yaml ja tenia la versió ${after_tag}; no hi ha cap canvi a commitejar.${NC}"
  else
    echo -e "${GREEN}Actualitzat deployment.yaml a la versió: ${VERSION}${NC}"
  fi
else
  echo -e "${RED}Error: No s'ha trobat el fitxer deployment.yaml a ${DEPLOY_DIR}${NC}"
  exit 1
fi

# Afegir i commitejar només si hi ha canvis
if ! git diff --quiet; then
  echo -e "${BLUE}📦 Afegint canvis al deployment.yaml...${NC}"
  git add "$DEPLOY_DIR/deployment.yaml"

  echo -e "${BLUE}📝 Fent commit amb el missatge: 'rel: ui-module devel version $VERSION'${NC}"
  git commit -m "rel: ui-module devel version ${VERSION}"
else
  echo -e "${BLUE}ℹ️ No s'han detectat canvis després del set de versió; saltant commit.${NC}"
fi

# Merge cap a la branca per defecte
echo -e "${BLUE}🔀 Canviant a ${DEFAULT_BRANCH} per fer el merge...${NC}"
git checkout "${DEFAULT_BRANCH}"

echo -e "${BLUE}📬 Fent merge de ${RELEASE_BRANCH} a ${DEFAULT_BRANCH}...${NC}"
git merge --no-ff "${RELEASE_BRANCH}" -m "Merge branch ${RELEASE_BRANCH}" || {
  echo -e "${RED}❌ Error durant el merge. Revisa conflictes i resol-los manualment.${NC}"
  exit 1
}

# Push a la branca per defecte
echo -e "${BLUE}🚀 Pujant els canvis a ${DEFAULT_BRANCH} al remot...${NC}"
git push origin "${DEFAULT_BRANCH}"

# Neteja branca local de release (la remota no s’ha creat)
echo -e "${BLUE}🧹 Esborrant la branca de release local: ${RELEASE_BRANCH}${NC}"
git branch -d "${RELEASE_BRANCH}"

echo -e "${GREEN}🎉 Release ${VERSION} creada, mergejada i pujada a ${DEFAULT_BRANCH} amb èxit!${NC}"
