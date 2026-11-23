#!/usr/bin/env node
/**
 * Disparador remot per a accio_web.js
 *
 * S'executa de forma permanent a l'ordinador on ha de córrer l'automatització
 * i permet llançar-la des del mòbil de dues maneres (es poden activar les dues):
 *
 *  A) Bot de Telegram  (no cal obrir ports: l'ordinador pregunta a Telegram)
 *       TELEGRAM_TOKEN=123:ABC   token que dona @BotFather
 *       TELEGRAM_CHAT_ID=987654  el teu chat id (només tu podràs donar ordres)
 *     Ordres: /executar  /estat  /ajuda
 *
 *  B) Pàgina web amb un botó (per fer servir amb Tailscale o dins la mateixa xarxa)
 *       HTTP_PORT=8080
 *       HTTP_CLAU=una-clau-llarga-i-secreta
 *     Des del mòbil: http://<ip-de-l-ordinador>:8080/?clau=una-clau-llarga-i-secreta
 *
 * Les credencials de la web (WEB_USER / WEB_PASS) s'han de definir també,
 * perquè es passen tal qual a accio_web.js.
 */

const { spawn } = require('child_process');
const fs = require('fs');
const http = require('http');
const path = require('path');
const crypto = require('crypto');

const DIR = __dirname;
const SCRIPT = path.join(DIR, 'accio_web.js');
const TG_API = process.env.TELEGRAM_API || 'https://api.telegram.org';

const log = (m) => console.log(`[${new Date().toLocaleString('ca-ES')}] ${m}`);

// ------------------------------------------------------------------------- //
// Execució de l'automatització (una sola alhora)
// ------------------------------------------------------------------------- //
let enMarxa = null; // { inici: Date }
let ultim = null;   // { inici, fi, codi, sortida, captura }

function executarAccio() {
  return new Promise((resolve) => {
    if (enMarxa) {
      resolve({ ocupat: true });
      return;
    }
    const inici = new Date();
    enMarxa = { inici };
    log('Llançant accio_web.js');

    const abans = new Set(fs.readdirSync(DIR).filter((f) => f.startsWith('error_')));
    const fill = spawn(process.execPath, [SCRIPT, ...(process.env.ACCIO_ARGS || '').split(' ').filter(Boolean)], {
      cwd: DIR,
      env: process.env,
    });
    let sortida = '';
    fill.stdout.on('data', (d) => { sortida += d; process.stdout.write(d); });
    fill.stderr.on('data', (d) => { sortida += d; process.stderr.write(d); });
    fill.on('close', (codi) => {
      const noves = fs.readdirSync(DIR).filter((f) => f.startsWith('error_') && !abans.has(f));
      ultim = {
        inici,
        fi: new Date(),
        codi,
        sortida,
        captura: noves.length ? path.join(DIR, noves.sort().pop()) : null,
      };
      enMarxa = null;
      log(`accio_web.js ha acabat amb codi ${codi}`);
      resolve(ultim);
    });
  });
}

function resum(r) {
  if (r.ocupat) return "⏳ Ja s'està executant, espera que acabi.";
  const linies = r.sortida.trim().split('\n').slice(-6).join('\n');
  const durada = ((r.fi - r.inici) / 1000).toFixed(1);
  return `${r.codi === 0 ? '✅ FET' : '❌ ERROR'} (${durada}s)\n\n${linies}`;
}

function estat() {
  if (enMarxa) return `⏳ En marxa des de ${enMarxa.inici.toLocaleTimeString('ca-ES')}`;
  if (!ultim) return '💤 Esperant ordres. Encara no s\'ha executat cap vegada.';
  return `💤 Esperant ordres.\nÚltima execució: ${ultim.inici.toLocaleString('ca-ES')} → ${ultim.codi === 0 ? 'OK' : 'ERROR'}`;
}

// ------------------------------------------------------------------------- //
// A) Telegram (long polling: només connexions de sortida)
// ------------------------------------------------------------------------- //
async function tg(token, metode, cos) {
  const opts = cos instanceof FormData
    ? { method: 'POST', body: cos }
    : { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(cos || {}) };
  const r = await fetch(`${TG_API}/bot${token}/${metode}`, opts);
  return r.json();
}

async function telegram(token, chatId) {
  const enviar = (text) => tg(token, 'sendMessage', { chat_id: chatId, text });
  const enviarFoto = async (fitxer, text) => {
    const fd = new FormData();
    fd.append('chat_id', chatId);
    fd.append('caption', text.slice(0, 1000));
    fd.append('photo', new Blob([fs.readFileSync(fitxer)]), path.basename(fitxer));
    return tg(token, 'sendPhoto', fd);
  };

  log('Telegram actiu. Escriu /executar al bot.');
  await enviar('🟢 Disparador en marxa. Ordres: /executar /estat').catch(() => {});

  let offset = 0;
  for (;;) {
    try {
      const r = await tg(token, 'getUpdates', { offset, timeout: 50, allowed_updates: ['message'] });
      for (const u of r.result || []) {
        offset = u.update_id + 1;
        const m = u.message;
        if (!m || !m.text) continue;
        if (String(m.chat.id) !== String(chatId)) {
          log(`Ignorat missatge d'un xat no autoritzat (${m.chat.id})`);
          continue;
        }
        const ordre = m.text.trim().split(/[\s@]/)[0].toLowerCase();
        if (ordre === '/executar') {
          await enviar('🚀 Començant...');
          // No bloquegem el bucle: així /estat continua responent
          executarAccio().then(async (res) => {
            try {
              if (res.captura) await enviarFoto(res.captura, resum(res));
              else await enviar(resum(res));
            } catch (e) { log(`No s'ha pogut enviar el resultat: ${e.message}`); }
          });
        } else if (ordre === '/estat') {
          await enviar(estat());
        } else {
          await enviar('Ordres: /executar · /estat');
        }
      }
    } catch (e) {
      log(`Telegram: ${e.message}. Ho torno a provar en 10 s`);
      await new Promise((res) => setTimeout(res, 10_000));
    }
  }
}

// ------------------------------------------------------------------------- //
// B) Pàgina web amb botó
// ------------------------------------------------------------------------- //
function igualSegur(a, b) {
  const x = Buffer.from(String(a));
  const y = Buffer.from(String(b));
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

function pagina(clau, missatge = '') {
  return `<!doctype html><html lang="ca"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Disparador</title>
<style>body{font-family:system-ui,sans-serif;max-width:480px;margin:40px auto;padding:0 16px;background:#f5f5f5;color:#222}
button{width:100%;padding:28px;font-size:1.5rem;border:0;border-radius:14px;background:#1a7f37;color:#fff}
button:active{background:#145c29}pre{white-space:pre-wrap;background:#fff;padding:12px;border-radius:8px}
@media(prefers-color-scheme:dark){body{background:#111;color:#eee}pre{background:#222}}</style></head><body>
<h2>Disparador</h2><p>${esc(estat())}</p>
<form method="post" action="/executar?clau=${encodeURIComponent(clau)}"
 onsubmit="this.querySelector('button').disabled=true;this.querySelector('button').textContent='Executant…'">
<button>Executar</button></form>
${missatge ? `<pre>${esc(missatge)}</pre>` : ''}
<p><a href="/?clau=${encodeURIComponent(clau)}">Actualitzar estat</a></p></body></html>`;
}

function servidorWeb(port, clauSecreta) {
  http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://x');
    const clau = url.searchParams.get('clau') || '';
    if (!igualSegur(clau, clauSecreta)) {
      res.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('Accés denegat');
      return;
    }
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    if (req.method === 'POST' && url.pathname === '/executar') {
      const r = await executarAccio();
      res.end(pagina(clau, resum(r)));
    } else {
      res.end(pagina(clau));
    }
  }).listen(port, () => log(`Pàgina web activa al port ${port}`));
}

// ------------------------------------------------------------------------- //
const { TELEGRAM_TOKEN, TELEGRAM_CHAT_ID, HTTP_PORT, HTTP_CLAU } = process.env;
let algun = false;

if (TELEGRAM_TOKEN && TELEGRAM_CHAT_ID) {
  algun = true;
  telegram(TELEGRAM_TOKEN, TELEGRAM_CHAT_ID);
}
if (HTTP_PORT) {
  if (!HTTP_CLAU || HTTP_CLAU.length < 16) {
    console.error('HTTP_CLAU ha de tenir com a mínim 16 caràcters');
    process.exit(2);
  }
  algun = true;
  servidorWeb(Number(HTTP_PORT), HTTP_CLAU);
}
if (!algun) {
  console.error('Configura TELEGRAM_TOKEN + TELEGRAM_CHAT_ID i/o HTTP_PORT + HTTP_CLAU');
  process.exit(2);
}
