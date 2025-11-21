#!/bin/bash

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
NL='\n'

trap 'echo -e "${NL}${RED}Procés parat!${NC}"; exit' SIGINT ERR

# Incloure funcions i mapes
source ~/publish/repo_map.sh

# Seleccionar repositori
select_repo
if [ -z "$BUILD_DIR" ] || [ -z "$REPO_LIST" ]; then
    echo -e "${RED}BUILD_DIR o REPO_LIST no definits!${NC}"
    exit 1
fi

# Consultar la darrera versió publicada al Nexus
echo -e "${GREEN}Consultant la darrera versió publicada al Nexus...${NC}"
LATEST_VERSION=$(curl -s "$REPO_LIST" | jq -r '.tags[]' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)

if [ -n "$LATEST_VERSION" ]; then
    echo -e "${GREEN}Última versió publicada: ${RED}$LATEST_VERSION${NC}${NL}"
else
    echo -e "${RED}No s'ha pogut obtenir la darrera versió del Nexus.${NC}"
fi

# Crear branca release
cd "$BUILD_DIR"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" =~ ^release/([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    VERSION="${BASH_REMATCH[1]}"
    echo -e "${GREEN}Ja estàs a la branca ${RED}$CURRENT_BRANCH.${NL}${GREEN}S'utilitzarà la versió $VERSION.${NC}${NL}"
else
    read -p "Introdueix la nova versió (ex: 1.2.3): " VERSION
    if [ -z "$VERSION" ]; then
        echo -e "${RED}Versió no vàlida!${NC}${NL}"
        exit 1
    fi
    git checkout -b "release/$VERSION"
fi

# Actualitzar versió a package.json
jq --arg v "$VERSION" '.version = $v' package.json > tmp.$$.json && mv tmp.$$.json package.json

# Funció per actualitzar la versió dins d’un fitxer deployment.yaml
actualitza_versio_deployment() {
    local file="$1"
    if [ -f "$file" ]; then
        echo -e "${GREEN}Actualitzant versió a $file...${NC}${NL}"
        sed -i -E "s|(image: .*/contactes-federation:)[0-9]+\.[0-9]+\.[0-9]+|\1$VERSION|" "$file"
        git add "$file"
    else
        echo -e "${RED}Fitxer no trobat: $file${NC}"
    fi
}

# Fitxers devel i prod RELATIUS al BUILD_DIR
for env in devel prod; do
    for ext in yaml yml; do
        actualitza_versio_deployment "./_deploy/tanzu/$env/deployment.$ext"
    done
done

# Afegir package.json
git add package.json

# Comprovar si hi ha canvis abans de fer commit
if git diff --cached --quiet; then
    echo -e "${RED}No hi ha canvis per commitejar.${NC}${NL}"
else
    git commit -m "Update version $VERSION"
fi

# Preguntar si es vol publicar
read -p "Vols publicar ara? (s/n): " PUBLICAR
if [ "$PUBLICAR" != "s" ]; then
    echo -e "${GREEN}Publicació cancel·lada per l'usuari.${NC}"
    exit 0
fi

echo -e "${GREEN}Executant publicació...${NC}"
bash ~/publish/publish.sh "$REPO_NAME"

# Preguntar si es vol fer merge a develop
read -p "Vols fer merge a develop? (s/n): " MERGE
if [ "$MERGE" == "s" ]; then
    git checkout develop
    git merge --no--ff "release/$VERSION" -m "Merge release/$VERSION into current branch"
    echo -e "${GREEN}Merge completat a develop.${NC}"

    read -p "Vols fer push a origin/develop? (s/n): " PUSH_DEVELOP
    if [ "$PUSH_DEVELOP" == "s" ]; then
        git push origin develop
        echo -e "${GREEN}Push a origin/develop completat.${NC}"
    else
        read -p "Vols fer push a origin/release/$VERSION? (s/n): " PUSH_RELEASE
        if [ "$PUSH_RELEASE" == "s" ]; then
            git push origin "release/$VERSION"
            echo -e "${GREEN}Push a origin/release/$VERSION completat.${NC}"
        else
            echo -e "${GREEN}Cap push realitzat.${NC}"
        fi
    fi
else
    echo -e "${GREEN}Merge a develop cancel·lat.${NC}"
fi
