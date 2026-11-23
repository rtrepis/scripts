# Automatització web + disparador des del mòbil

- **`accio_web.js`**: fa login en una web, clica l'enllaç cap a una segona pàgina (encara que
  tardi a carregar) i hi prem un botó, amb "tocs humans" i una espera aleatòria de 0 a 3 s
  abans de l'acció. Fa servir el **Microsoft Edge** instal·lat a l'ordinador.
- **`disparador.js`**: es queda engegat a l'ordinador i permet llançar `accio_web.js` des del
  mòbil, per **Telegram** o per una **pàgina web amb un botó**.

```
 Mòbil ──(Telegram o Tailscale)──▶ Ordinador (disparador.js) ──▶ Edge ──▶ la web
```

El mòbil no es connecta directament a l'ordinador (el router de l'oficina no ho deixa):

- **Telegram**: l'ordinador pregunta a Telegram cada pocs segons si hi ha ordres noves.
  Només fa connexions de sortida, així que no cal obrir ports ni tocar el router.
- **Tailscale**: crea una xarxa privada entre el mòbil i l'ordinador. El mòbil obre una
  pàgina de l'ordinador com si fossin a la mateixa xarxa.

> Si és un ordinador de l'empresa, demana permís a informàtica abans d'instal·lar-hi
> Node, Tailscale o un bot.

---

## 1. Preparar l'ordinador (Windows)

1. Instal·la **Node.js 20 LTS o més nou**: <https://nodejs.org>
2. Copia la carpeta `web_automation` a l'ordinador, per exemple a `C:\automatitzacio`.
3. Obre una consola en aquesta carpeta i executa:

       npm install

   Microsoft Edge ja ve amb Windows, no cal baixar cap altre navegador.
4. Copia `config.example.json` com a `config.json` i omple la URL i els selectors (secció 4).
5. Copia `disparador.env.example` com a `disparador.env` i omple usuari i contrasenya de la web.
6. Prova que funciona veient el navegador:

       set WEB_USER=el_meu_usuari
       set WEB_PASS=la_meva_contrasenya
       node accio_web.js --visible

## 2a. Disparador per Telegram (recomanat)

1. Al Telegram del mòbil, parla amb **@BotFather** → `/newbot` → posa-li un nom.
   Et donarà un **token** (`123456:ABC...`).
2. Obre el teu bot nou i envia-li qualsevol missatge.
3. Al navegador obre `https://api.telegram.org/bot<TOKEN>/getUpdates` i busca
   `"chat":{"id":NNNNN`. Aquest número és el teu **chat id**.
4. Posa'ls a `disparador.env`:

       TELEGRAM_TOKEN=123456:ABC...
       TELEGRAM_CHAT_ID=NNNNN

5. Fes doble clic a **`iniciar_disparador.bat`**.

Ordres al bot:

| ordre       | què fa                                                       |
|-------------|--------------------------------------------------------------|
| `/executar` | llança l'automatització i et respon amb el resultat          |
| `/estat`    | diu si està en marxa i com va anar l'última vegada           |

Si falla, el bot t'envia la captura de pantalla de l'error. Només respon al teu chat id:
els missatges d'altres persones s'ignoren.

## 2b. Disparador per pàgina web + Tailscale

1. Instal·la **Tailscale** (<https://tailscale.com>) a l'ordinador i al mòbil, amb el mateix compte.
2. A `disparador.env`:

       HTTP_PORT=8080
       HTTP_CLAU=una-clau-llarga-i-aleatoria-de-com-a-minim-16-caracters

3. Engega `iniciar_disparador.bat`.
4. Al mòbil obre `http://<ip-tailscale-de-l-ordinador>:8080/?clau=<la-teva-clau>`
   i desa-ho a la pantalla d'inici. Hi trobaràs un botó gran **Executar**.

Es poden fer servir les dues opcions alhora. Si ja hi ha una execució en marxa, una segona
ordre no en llança una altra.

## 3. Que s'engegui sol

- Prem `Win + R`, escriu `shell:startup` i hi poses un accés directe a `iniciar_disparador.bat`.
- L'ordinador ha d'estar **encès i sense suspendre's**: Configuració → Sistema →
  Energia → Suspensió: *Mai*. Pot estar amb la sessió bloquejada.

## 4. `config.json`

| clau                | què és                                                  |
|---------------------|---------------------------------------------------------|
| `login_url`         | adreça de la pàgina de login                            |
| `navegador`         | `msedge` (per defecte), `chrome` o `chromium`           |
| `selectors.usuari`  | camp de l'usuari                                        |
| `selectors.contrasenya` | camp de la contrasenya                              |
| `selectors.boto_login`  | botó d'entrar                                       |
| `selectors.enllac_pagina2` | enllaç que porta a la segona pàgina              |
| `selectors.boto_accio`  | botó que s'ha de prémer a la segona pàgina          |
| `selectors.confirmacio` | (opcional) element que surt quan l'acció ha anat bé |
| `jitter_max_s`      | segons màxims d'espera aleatòria abans de l'acció (3)   |
| `timeout_pagina2_s` | màxim que s'esperarà la segona pàgina (90)              |
| `headless`          | `true` = navegador ocult                                |

Per trobar un selector, fes clic dret a l'element → **Inspecciona** → mira l'`id`, el `name`
o el text del botó (p. ex. `button:has-text('Confirmar')`).

## Opcions de `accio_web.js`

    node accio_web.js --visible       # veient el navegador
    node accio_web.js --jitter 5      # fins a 5 s d'aleatorietat

Si hi ha un error es desa una captura `error_AAAAMMDD_HHMMSS.png`. El codi de sortida és 0
si ha anat bé i 1 si ha fallat.
