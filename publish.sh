#!/bin/bash

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
NL='\n'

trap 'echo -e "${NL}${RED}Procés parat!${NC}"; exit' SIGINT ERR

# Incloure funcions
source ~/publish/get_package_version.sh
source ~/publish/repo_map.sh
#source ~/publish/build.sh
source ~/publish/tag_manager.sh


# Seleccionar repositori (amb suport per argument)
select_repo "$1"


# Verificar que $BUILD_DIR està definit
if [ -z "$BUILD_DIR" ]; then
    echo -e "${NL}${RED}Error: BUILD_DIR no està definit!${NC}"
    exit 1
fi

# Verificar que package.json existeix
if [ ! -f "$BUILD_DIR/package.json" ]; then
    echo -e "${NL}${RED}Error: El fitxer package.json no existeix al directori de construcció!${NC}"
    exit 1
fi

# Obtenir la versió

if [ -n "$DOKER_FILE" ]; then
    VERSION=$(get_version "$BUILD_DIR/$(dirname "$DOKER_FILE")")
else
    VERSION=$(get_version "$BUILD_DIR")
fi

if [ $? -ne 0 ]; then
    echo -e "${NL}${RED}Error obtenint la versió!${NC}"
    exit 1
fi
echo -e "${NL}${GREEN}Versió obtinguda: ${RED}$VERSION${NC}"

# Obtenir la llista de tags del registre
TAGS=$(curl -s "$REPO_LIST" | jq -r '.tags[]')

# Comprovar si la versió hi és
if echo "$TAGS" | grep -q "^$VERSION$"; then
    echo -e "${NL}${RED}La versió $VERSION ja existeix al registre Nexus.${NC}"
    read -p "Vols sobreescriure-la? (s/n): " OVERWRITE
    if [ "$OVERWRITE" != "s" ]; then
        echo -e "${NL}${RED}Publicació cancel·lada.${NC}"
        exit 1
    fi
fi


# Construcció del projecte
echo -e "${NL}${GREEN}Iniciant la construcció del projecte...${NC}"
#build_project "$BUILD_DIR"
 cd $BUILD_DIR
if [ $? -ne 0 ]; then
    echo -e "${NL}${RED}Error en la construcció del projecte!${NC}"
    exit 1
fi

# Construcció de la imatge Docker
echo -e "${NL}${GREEN}Construint la imatge Docker amb la versió ${RED}$VERSION${GREEN}...${NC}"

if [ -n "$DOKER_FILE" ]; then
    docker build --platform linux/amd64 -f "$DOKER_FILE" -t "$REPO:$VERSION" .
else
    docker build --platform linux/amd64 -t "$REPO:$VERSION" .
fi
if [ $? -ne 0 ]; then
    echo -e "${NL}${RED}Error construint la imatge Docker!${NC}"
    exit 1
fi


# Confirmació abans de publicar
NEXUS_URL="${NEXUS_URL}%2F${VERSION}"
if [ -n "$EXISTING_IMAGE" ]; then
    echo -e "${NL}${GREEN}Abans de publicar, elimina la versió anterior si cal.${NC}"
    echo -e "${NL}${GREEN}URL per eliminar: ${BLUE}$NEXUS_URL${NC}${NL}"
else
    echo -e "${NL}${GREEN}No hi ha cap versió anterior al Nexus.${NC}"
fi
read -p "Prem Enter per continuar..."

# Publicació
echo -e "${NL}${GREEN}Pujant la imatge a Nexus...${NC}"
docker push "$REPO:$VERSION"
if [ $? -ne 0 ]; then
    echo -e "${NL}${RED}Error pujant la imatge a Nexus!${NC}"
    exit 1
fi

echo -e "${NL}${GREEN}Imatge pujada correctament!${NC}"

# Desplegament
read -p "Vols fer el desplegament? (s/n): " DEPLOY
if [ "$DEPLOY" == "s" ]; then
    echo -e "${NL}${GREEN}Iniciant el desplegament: ${RED}$REPO_NAME${NC}"
    bash ~/publish/deploy.sh "$REPO_NAME"
    if [ $? -ne 0 ]; then
        echo -e "${NL}${RED}Error en el desplegament!${NC}"
        exit 1
    fi
    echo -e "${NL}${GREEN}Desplegament completat correctament!${NC}"
else
    echo -e "${NL}${GREEN}Desplegament cancel·lat.${NC}"
fi

# Etiqueta
read -p "Vols publicar una etiqueta? (s/n): " TAG
if [ "$TAG" == "s" ]; then
    manage_tag "$BUILD_DIR" "$VERSION"
else
    echo -e "${NL}${GREEN}Publicació de l'etiqueta cancel·lada.${NC}"
fi

# Actualització repository deploy
read -p "Vols actualitzar el repositori deploy? (s/n): " DEPLOY
if [ "$DEPLOY" == "s" ]; then
    echo -e "${NL}${GREEN}Iniciant actualització: ${RED}$REPO_NAME${NC}"
    bash ~/publish/deploy_repo_change.sh "$REPO_NAME" "$VERSION"
    if [ $? -ne 0 ]; then
        echo -e "${NL}${RED}Error en el desplegament!${NC}"
        exit 1
    fi
    echo -e "${NL}${GREEN}Actualització completat correctament!${NC}"
else
    echo -e "${NL}${GREEN}ACtualització cancel·lada.${NC}"
fi
