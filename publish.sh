#!/bin/bash

# Definir colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # Sense color
NL='\n' # Salts de línia

# Funció per capturar el senyal SIGINT (Ctrl + C) i errors
trap 'echo -e "${NL}${RED}Procés parat!${NC}"; exit' SIGINT ERR

# Incloure les funcions des d'altres arxius
source ~/publish/get_package_version.sh
source ~/publish/repo_map.sh
source ~/publish/build.sh

select_repo  # Crida a select_repo() per seleccionar el repositori

# Verificar que $BUILD_DIR està definit
if [ -z "$BUILD_DIR" ]; then
    echo -e "${NL}${RED}Error: BUILD_DIR no està definit!${NC}"
    exit 1
fi

# Verificar que el fitxer package.json existeix al directori de construcció
if [ ! -f "$BUILD_DIR/package.json" ]; then
    echo -e "${NL}${RED}Error: El fitxer package.json no existeix al directori de construcció!${NC}"
    exit 1
fi

# Obtenir la versió des del fitxer package.json al directori de construcció
VERSION=$(get_version $BUILD_DIR)
if [ $? -ne 0 ]; then
    echo -e "${NL}${RED}Error obtenint la versió!${NC}"
    exit 1
fi
echo -e "${NL}${GREEN}Versió obtinguda: ${RED}$VERSION${NC}"

# Verificar si la versió ja existeix al registre Docker
EXISTING_IMAGE=$(docker images $REPO:$VERSION -q)
if [ -n "$EXISTING_IMAGE" ]; then
    echo -e "${NL}${RED}La versió $VERSION ja existeix al registre Docker.${NC}"
    read -p "Vols sobreescriure-la? (s/n): " OVERWRITE
    if [ "$OVERWRITE" != "s" ]; then
        echo -e "${NL}${RED}Publicació cancel·lada.${NC}"
        exit 1
    fi
fi

# Construir el projecte
echo -e "${NL}${GREEN}Iniciant la construcció del projecte...${NC}"
build_project $BUILD_DIR
if [ $? -ne 0 ]; then
    echo -e "${NL}${RED}Error en la construcció del projecte!${NC}"
    exit 1
fi

echo -e "${NL}${GREEN}Construcció completada. Construint la imatge Docker amb la versió ${RED}$VERSION${GREEN}...${NC}"
docker build --platform linux/amd64 -t $REPO:$VERSION .
if [ $? -ne 0 ]; then
    echo -e "${NL}${RED}Error construint la imatge Docker!${NC}"
    exit 1
fi

# Confirmació abans de publicar
NEXUS_URL="${NEXUS_URL}%2F${VERSION}"
if [ -n "$EXISTING_IMAGE" ]; then
    echo -e "${NL}${GREEN}Abans de publicar la imatge al Nexus, assegura't que has eliminat la versió anterior.${NC}"
    echo -e "${NL}${GREEN}URL per eliminar la versió anterior: ${BLUE}$NEXUS_URL${NC}${NL}"
else
    echo -e "${NL}${GREEN}No hi ha cap versió anterior al Nexus.${NC}"
fi
read -p "Prem Enter per continuar..."

echo -e "${NL}${GREEN}Imatge Docker construïda. Pujant la imatge a Nexus amb la versió ${RED}$VERSION${GREEN}...${NC}"
docker push $REPO:$VERSION
if [ $? -ne 0 ]; then
    echo -e "${NL}${RED}Error pujant la imatge a Nexus!${NC}"
    exit 1
fi

echo -e "${NL}${GREEN}Imatge pujada correctament. Publicació completada amb la versió ${RED}$VERSION${GREEN}!${NC}"

# Preguntar si es vol fer el desplegament
read -p "Vols fer el desplegament? (s/n): " DEPLOY
if [ "$DEPLOY" == "s" ]; then
    echo -e "${NL}${GREEN}Iniciant el desplegament:${RED} $REPO_NAME ${NC}"
    bash ~/publish/deploy.sh "$REPO_NAME"
    if [ $? -ne 0 ]; then
        echo -e "${NL}${RED}Error en el desplegament!${NC}"
        exit 1
    fi
    echo -e "${NL}${GREEN}Desplegament completat correctament!${NC}"
else
    echo -e "${NL}${GREEN}Desplegament cancel·lat.${NC}"
fi