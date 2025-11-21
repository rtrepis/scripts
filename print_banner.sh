
print_banner_title() {
    # Banner centrat amb quadre i colors (UTF-8)
    local title="$1"
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)

    # Amplada del banner: com a mínim el text + marges, sense passar-se de l’ample terminal
    local pad=6
    local width=$(( ${#title} + pad * 2 + 2 ))   # +2 per a les vores
    (( width > cols )) && width=$cols

    # Càlcul de farcits
    local inner=$(( width - 2 ))
    local left=$(( (inner - ${#title}) / 2 ))
    local right=$(( inner - ${#title} - left ))

    # Línies superior/inferior
    local line
    line=$(printf '═%.0s' $(seq 1 $inner))

    printf "\n${BG_BLUE_WHITE}╔%s╗${RESET}\n" "$line"
    printf "${BG_BLUE_WHITE}║%*s%s%*s║${RESET}\n" "$left" "" "$title" "$right" ""
    printf "${BG_BLUE_WHITE}╚%s╝${RESET}\n\n" "$line"
}
