declare -A REPO_MAP
declare REPO_NAME

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'
NL='\n'
BOLD='\033[1m'
BG_BLUE_WHITE='\033[44;97m'   # Fons blau, text blanc
RESET='\033[0m'

source ~/publish/print_banner.sh

read_repo_map() {
    local FILE_PATH="$HOME/publish/repo_map.txt"

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
    echo "$(declare -p REPO_MAP)"
}

select_repo() {
    local selected_repo="$1"
    eval "$(read_repo_map)"

    if [[ -n $selected_repo ]]; then
        REPO_NAME="$selected_repo"
    fi

    if [[ -z $REPO_NAME ]]; then
        echo -e "${NL}${GREEN}Selecciona el repositori:${NC}"
        select REPO_NAME in "${!REPO_MAP[@]}"; do
            if [[ -n $REPO_NAME ]]; then
                break
            else
                echo -e "${RED}Opció no vàlida!${NC}"
            fi
        done
    fi

    if [[ -n ${REPO_MAP[$REPO_NAME]} ]]; then
        IFS=';' read -r -a REPO_INFO <<< "${REPO_MAP[$REPO_NAME]}"
        for info in "${REPO_INFO[@]}"; do
            IFS='=' read -r key value <<< "$info"
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            case $key in
                url) REPO=$value ;;
                build_dir) BUILD_DIR=$value ;;
                doker_file) DOKER_FILE=$value ;;
                nexus_url) NEXUS_URL=$value ;;
                ktl) KTL=$value ;;
                kns) KNS=$value ;;
                url_list) REPO_LIST=$value ;;
                name) DEPLOY_NAME=$value ;;
                deploy_dir) DEPLOY_DIR=$value ;;
            esac
        done
    else
        echo -e "${RED}Error: El repositori '$REPO_NAME' no existeix!${NC}"
        exit 1
    fi

    if [[ -z $BUILD_DIR ]]; then
        echo -e "${RED}Error: BUILD_DIR no està definit!${NC}"
        exit 1
    fi

    print_banner_title "$REPO_NAME"
}
