#!/bin/bash

# Definir colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # Sense color
NL='\n' # Salts de línia

# Funció per gestionar les etiquetes
manage_tag() {
    local BUILD_DIR=$1
    local VERSION=$2
    local TAG="v$VERSION"

    # Canviar al directori de construcció
    cd "$BUILD_DIR"

    # Verificar si l'etiqueta ja existeix
    TAG_EXISTS=$(git tag -l "$TAG")
    if [ -n "$TAG_EXISTS" ]; then
        # Eliminar l'etiqueta existent
        git tag -d "$TAG"
        git push origin ":refs/tags/$TAG"
        if [ $? -ne 0 ]; then
            echo -e "${NL}${RED}Error eliminant l'etiqueta!${NC}"
            exit 1
        fi
        echo -e "${NL}${GREEN}Etiqueta eliminada correctament!${NC}"
    fi

    # Publicar la nova etiqueta
    echo -e "${NL}${GREEN}Publicant etiqueta...${NC}"
    git tag -a "$TAG" -m "Publicació de la versió $VERSION"
    git push origin "$TAG"
    if [ $? -ne 0 ]; then
        echo -e "${NL}${RED}Error publicant l'etiqueta!${NC}"
        exit 1
    fi
    echo -e "${NL}${GREEN}Etiqueta publicada correctament!${NC}"
}
