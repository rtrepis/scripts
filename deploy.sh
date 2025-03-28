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
source ./publish/repo_map.sh
source ./.bash_aliases

# Funció per comprovar si estàs loguejat al servidor correcte
is_logged_in_ktl() {
    local current_context=$(kubectl config current-context)
    if [[ "$current_context" == "$KTL" ]]; then
        echo -e "${NL}${GREEN}Estàs loguejat al servidor correcte: ${RED}$current_context${NC}"
        return 0
    else
        echo -e "${NL}${RED}No estàs loguejat al servidor correcte! Context actual: ${RED}$current_context${NC}"
        return 1
    fi
}

# Funció per fer login a KTL
login_ktl() {
    if is_logged_in_ktl; then
        echo -e "${NL}${GREEN}No cal fer login a Kubernetes.${NC}"
    else
        echo -e "${NL}${GREEN}Fent login a Kubernetes: ${RED}${KTL}${NC}"
        ktl $KTL || { echo -e "${NL}${RED}Error en el login a Kubernetes!${NC}"; exit 1; }
    fi
}

# Funció per fer login a KNS
login_kns() {
    echo -e "${NL}${GREEN}Entrant al namespace de: ${RED}${KNS}${NC}"
    kns $KNS || { echo -e "${NL}${RED}Error en entrar al namespace!${NC}"; exit 1; }
}

# Funció per obtenir les 5 últimes versions del Nexus
get_latest_images() {
    local num_images=5
    local response=$(curl -s "${REPO_LIST}") || { echo -e "${NL}${RED}Error en obtenir les versions del Nexus!${NC}"; exit 1; }
    echo $response | jq -r '.tags[]' | sort -r | head -n $num_images || { echo -e "${NL}${RED}Error en processar les versions del Nexus!${NC}"; exit 1; }
}

# Funció per obtenir la imatge actual del deployment
get_current_image() {
    kubectl get deployment "${DEPLOY_NAME}" -o json | jq -r '.spec.template.spec.containers[].image' || { echo -e "${NL}${RED}Error en obtenir la imatge actual del deployment!${NC}"; exit 1; }
}

# Funció per actualitzar el deployment amb la nova versió
update_deployment() {
    kubectl set image deployment/"${DEPLOY_NAME}" *="${REPO}:${VERSION}" || { echo -e "${NL}${RED}Error en actualitzar el deployment!${NC}"; exit 1; }
    kubectl rollout restart deployment/"${DEPLOY_NAME}" || { echo -e "${NL}${RED}Error en reiniciar el deployment!${NC}"; exit 1; }
}

# Inici del deployment
echo -e "${NL}${GREEN}Iniciant el desplegament...${NC}"

# Seleccionar el repositori
select_repo

# Fer login a KTL
login_ktl

# Fer login a KNS
login_kns

# Obtenir les 5 últimes versions del Nexus
latest_images=$(get_latest_images)

# Preguntar quina versió vols
echo -e "${NL}${GREEN}Selecciona la versió que vols:${NC}"
select VERSION in $latest_images; do
    if [[ -n $VERSION ]]; then
        echo -e "${NL}${GREEN}Versió seleccionada: ${RED}$VERSION${NC}"
        break
    else
        echo -e "${NL}${RED}Opció no vàlida!${NC}"
    fi
done

# Obtenir la imatge actual del deployment
current_image=$(get_current_image)

# Comprovar si la versió seleccionada coincideix amb la versió actual
if [[ "${current_image}" == "${REPO}:${VERSION}" ]]; then
    read -p "Prem Enter per continuar..."
    echo -e "${NL}${GREEN}La versió seleccionada ja està desplegada. Fent redeploy...${NC}"
    kubectl rollout restart deployment/"${DEPLOY_NAME}" || { echo -e "${NL}${RED}Error en reiniciar el deployment!${NC}"; exit 1; }
else
    echo -e "${NL}${GREEN}Versió actual: ${RED}${current_image}${NC}"
    echo -e "${NL}${GREEN}Nova versió: ${RED}${REPO}:${VERSION}${NC}"
    read -p "Prem Enter per continuar..."
    echo -e "${NL}${GREEN}Actualitzant el deployment amb la nova versió...${NC}"
    update_deployment
fi

echo -e "${NL}${GREEN}Desplegament completat${RED}!!${NC}"