# accio_web.py

Fa login en una web, clica l'enllaç cap a una segona pàgina (encara que tardi a carregar)
i hi prem un botó. Tot amb "tocs humans":

- el ratolí es mou en corba fins a l'element i clica en un punt aleatori, no al centre exacte
- s'escriu tecla a tecla, amb velocitat variable i alguna pausa més llarga
- hi ha petites pauses entre passos
- abans de prémer l'acció s'espera un temps aleatori entre 0 i 3 s (`jitter_max_s`)

## Instal·lació

    pip install playwright
    playwright install chromium

## Configuració

    cp config.example.json config.json

Edita `config.json` amb la URL de login i els selectors CSS dels elements:

| clau              | què és                                                  |
|-------------------|---------------------------------------------------------|
| `usuari`          | camp de l'usuari                                        |
| `contrasenya`     | camp de la contrasenya                                  |
| `boto_login`      | botó d'entrar                                           |
| `enllac_pagina2`  | enllaç que porta a la segona pàgina                     |
| `boto_accio`      | botó que s'ha de prémer a la segona pàgina              |
| `confirmacio`     | (opcional) element que surt quan l'acció ha anat bé     |

`timeout_pagina2_s` és el màxim que s'esperarà la segona pàgina (per defecte 90 s).
El script espera fins que el botó de l'acció és visible **i** habilitat.

Per trobar un selector: clic dret a l'element → Inspecciona → mira l'`id`, el `name`
o el text del botó (p. ex. `button:has-text('Confirmar')`).

## Execució

    export WEB_USER="el_meu_usuari"
    export WEB_PASS="la_meva_contrasenya"
    ./accio_web.py                 # ocult
    ./accio_web.py --visible       # veient el navegador (per provar)
    ./accio_web.py --jitter 5      # fins a 5 s d'aleatorietat

Si hi ha un error es desa una captura `error_AAAAMMDD_HHMMSS.png`.
El codi de sortida és 0 si ha anat bé i 1 si ha fallat (útil per a cron).

Per fer servir un Chrome ja instal·lat: `export CHROMIUM_PATH=/ruta/a/chrome`.
