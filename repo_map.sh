#!/bin/bash

read_repo_map() {
    declare -A REPO_MAP
    local REPO_NAME=""
    local FILE_PATH="./publish/repo_map.txt"

    if [ ! -f "$FILE_PATH" ]; then
        echo -e "${NL}${RED}Error: El fitxer $FILE_PATH no existeix!${NC}"
        exit 1
    fi

    while IFS='=' read -r key value; do
        if [[ $key =~ ^\[.*\]$ ]]; then
            REPO_NAME=$(echo $key | tr -d '[]')
        elif [[ -n $key && -n $value ]]; then
            REPO_MAP[$REPO_NAME]+="$key=$value;"
        fi
    done < "$FILE_PATH"
    echo $(declare -p REPO_MAP)
}

select_repo() {
    eval "$(read_repo_map)"  # Crida a read_repo_map() per llegir el mapa de repositoris
    echo -e "${NL}${GREEN}Selecciona el repositori:${NC}"
    select REPO_NAME in "${!REPO_MAP[@]}"; do
        if [[ -n $REPO_NAME ]]; then
            IFS=';' read -r -a REPO_INFO <<< "${REPO_MAP[$REPO_NAME]}"
            for info in "${REPO_INFO[@]}"; do
                IFS='=' read -r key value <<< "$info"
                key=$(echo $key | xargs)  # Trim spaces
                value=$(echo $value | xargs)  # Trim spaces
                if [[ $key == "url" ]]; then
                    REPO=$value
                elif [[ $key == "build_dir" ]]; then
                    BUILD_DIR=$value
                elif [[ $key == "nexus_url" ]]; then
                    NEXUS_URL=$value
                elif [[ $key == "ktl" ]]; then
                    KTL=$value
                elif [[ $key == "kns" ]]; then
                    KNS=$value
                elif [[ $key == "url_list" ]]; then
                    REPO_LIST=$value
                elif [[ $key == "name" ]]; then
                    DEPLOY_NAME=$value
                fi
            done
            break
        else
            echo -e "${NL}${RED}Opció no vàlida!${NC}"
        fi
    done
    # echo -e "${NL}${GREEN}Repositori seleccionat: ${BLUE}$REPO${NC}"
    # echo -e "${GREEN}Repositori llista: ${BLUE}$REPO_LIST${NC}"
    # echo -e "${GREEN}Directori de construcció: ${BLUE}$BUILD_DIR${NC}"
    # echo -e "${GREEN}URL de Nexus: ${BLUE}$NEXUS_URL${NC}"
    # echo -e "${GREEN}Kubernetes land: ${BLUE}$KTL${NC}"
    # echo -e "${GREEN}Kubernetes namespace: ${BLUE}$KNS${NC}"
    # echo -e "${GREEN}Kubernetes deploy name: ${BLUE}$KNS${NC}${NL}"
}