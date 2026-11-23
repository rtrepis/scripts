#!/usr/bin/env node
/**
 * Automatització web amb comportament "humà":
 *
 *   1. Obre la pàgina de login i hi entra amb usuari i contrasenya.
 *   2. Clica l'enllaç que porta a la segona pàgina (que tarda a carregar).
 *   3. Espera que la segona pàgina estigui llesta.
 *   4. Espera un temps aleatori (per defecte entre 0 i 3 segons).
 *   5. Prem el botó de l'acció.
 *
 * El ratolí es desplaça en corba fins a l'element, s'escriu tecla a tecla
 * amb velocitat variable i hi ha petites pauses entre passos.
 *
 * Ús:
 *   export WEB_USER="usuari"
 *   export WEB_PASS="contrasenya"
 *   node accio_web.js [--config config.json] [--jitter 3] [--visible]
 */

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

// ------------------------------------------------------------------------- //
// Utilitats
// ------------------------------------------------------------------------- //
const rand = (min, max) => min + Math.random() * (max - min);
const sleep = (s) => new Promise((r) => setTimeout(r, s * 1000));
const pausa = (min = 0.3, max = 1.2) => sleep(rand(min, max));

function log(msg) {
  const t = new Date().toTimeString().slice(0, 8);
  const ms = String(new Date().getMilliseconds()).padStart(3, '0');
  console.log(`[${t}.${ms}] ${msg}`);
}

function args() {
  const a = process.argv.slice(2);
  const opt = { config: path.join(__dirname, 'config.json'), jitter: null, visible: false };
  for (let i = 0; i < a.length; i++) {
    if (a[i] === '--config') opt.config = a[++i];
    else if (a[i] === '--jitter') opt.jitter = parseFloat(a[++i]);
    else if (a[i] === '--visible') opt.visible = true;
    else if (a[i] === '-h' || a[i] === '--help') {
      console.log('Ús: node accio_web.js [--config fitxer.json] [--jitter segons] [--visible]');
      process.exit(0);
    }
  }
  return opt;
}

// ------------------------------------------------------------------------- //
// Ratolí i teclat humans
// ------------------------------------------------------------------------- //
class Huma {
  constructor(page) {
    this.page = page;
    const vp = page.viewportSize() || { width: 1280, height: 800 };
    this.x = rand(100, vp.width - 100);
    this.y = rand(100, vp.height - 100);
  }

  async inici() {
    await this.page.mouse.move(this.x, this.y);
  }

  /** Mou el ratolí seguint una corba de Bézier, més lent a l'inici i al final. */
  async moure(tx, ty) {
    const sx = this.x, sy = this.y;
    const dist = Math.hypot(tx - sx, ty - sy);
    const passos = Math.max(12, Math.floor(dist / rand(8, 15)));
    const desv = dist * rand(0.1, 0.3);
    const c1 = [sx + (tx - sx) * 0.3 + rand(-desv, desv), sy + (ty - sy) * 0.3 + rand(-desv, desv)];
    const c2 = [sx + (tx - sx) * 0.7 + rand(-desv, desv), sy + (ty - sy) * 0.7 + rand(-desv, desv)];
    for (let i = 1; i <= passos; i++) {
      let t = i / passos;
      t = t * t * (3 - 2 * t); // ease-in-out
      const u = 1 - t;
      const x = u ** 3 * sx + 3 * u ** 2 * t * c1[0] + 3 * u * t ** 2 * c2[0] + t ** 3 * tx;
      const y = u ** 3 * sy + 3 * u ** 2 * t * c1[1] + 3 * u * t ** 2 * c2[1] + t ** 3 * ty;
      await this.page.mouse.move(x, y);
      await sleep(rand(0.004, 0.018));
    }
    this.x = tx;
    this.y = ty;
  }

  async puntDins(locator) {
    await locator.scrollIntoViewIfNeeded();
    const box = await locator.boundingBox();
    if (!box) throw new Error("L'element no és visible a la pàgina");
    // Un punt aleatori cap al centre (no exactament al mig)
    return [box.x + box.width * rand(0.3, 0.7), box.y + box.height * rand(0.3, 0.7)];
  }

  async clicar(locator) {
    const [x, y] = await this.puntDins(locator);
    await this.moure(x, y);
    await pausa(0.08, 0.25); // petita vacil·lació
    await this.page.mouse.down();
    await sleep(rand(0.05, 0.14)); // durada real d'un clic
    await this.page.mouse.up();
  }

  async escriure(locator, text) {
    await this.clicar(locator);
    await pausa(0.2, 0.5);
    await locator.fill(''); // buida el camp per si hi havia res
    for (const c of text) {
      await this.page.keyboard.type(c);
      let p = rand(0.05, 0.18);
      if (Math.random() < 0.07) p += rand(0.2, 0.5); // de tant en tant, més llarga
      await sleep(p);
    }
  }
}

// ------------------------------------------------------------------------- //
// Flux principal
// ------------------------------------------------------------------------- //
async function executar(cfg, usuari, contrasenya, headless, jitterMax) {
  const t0 = Date.now();
  const sel = cfg.selectors;
  const timeoutPag2 = (cfg.timeout_pagina2_s ?? 90) * 1000;

  const navegador = await chromium.launch({
    headless,
    // CHROMIUM_PATH opcional: per fer servir un Chrome/Chromium ja instal·lat
    executablePath: process.env.CHROMIUM_PATH || undefined,
  });
  const context = await navegador.newContext({
    viewport: { width: 1366, height: 768 },
    locale: cfg.locale || 'ca-ES',
    timezoneId: cfg.timezone || 'Europe/Madrid',
  });
  const page = await context.newPage();
  page.setDefaultTimeout(30_000);

  try {
    // 1) Login ------------------------------------------------------------
    log(`Obrint ${cfg.login_url}`);
    await page.goto(cfg.login_url, { waitUntil: 'domcontentloaded' });
    const huma = new Huma(page);
    await huma.inici();
    await pausa(0.8, 1.8); // "mirar" la pàgina

    log('Escrivint usuari');
    await huma.escriure(page.locator(sel.usuari), usuari);
    await pausa(0.3, 0.8);
    log('Escrivint contrasenya');
    await huma.escriure(page.locator(sel.contrasenya), contrasenya);
    await pausa(0.4, 1.0);

    log('Enviant login');
    await huma.clicar(page.locator(sel.boto_login));

    // Confirmem que el login ha anat bé: ha d'aparèixer l'enllaç
    const enllac = page.locator(sel.enllac_pagina2).first();
    await enllac.waitFor({ state: 'visible', timeout: 30_000 }).catch(() => {
      throw new Error(
        "Login fallit: no apareix l'enllaç a la segona pàgina (credencials o selector incorrectes?)",
      );
    });
    log('Login correcte');
    await pausa(0.6, 1.5);

    // 2) Anar a la segona pàgina -----------------------------------------
    log("Clicant l'enllaç a la segona pàgina");
    await huma.clicar(enllac);

    // 3) Esperar que la pàgina 2 acabi de carregar (pot ser lenta) -------
    log(`Esperant la segona pàgina (màx. ${timeoutPag2 / 1000}s)`);
    const boto = page.locator(sel.boto_accio).first();
    await boto.waitFor({ state: 'visible', timeout: timeoutPag2 });
    await page.waitForLoadState('networkidle', { timeout: 15_000 }).catch(() => {
      // algunes webs mai arriben a "idle"; el botó ja hi és
    });
    // Espera que el botó estigui realment habilitat
    await page.waitForFunction(
      (el) => !el.disabled && el.getAttribute('aria-disabled') !== 'true',
      await boto.elementHandle(),
      { timeout: timeoutPag2 },
    );
    log('Segona pàgina carregada');

    // 4) Aleatorietat ----------------------------------------------------
    const espera = rand(0, jitterMax);
    log(`Espera aleatòria: ${espera.toFixed(2)}s`);
    await sleep(espera);

    // 5) Acció -----------------------------------------------------------
    log("Prement el botó de l'acció");
    await huma.clicar(boto);

    if (sel.confirmacio) {
      await page.locator(sel.confirmacio).first().waitFor({ state: 'visible', timeout: 30_000 });
      log('Confirmació rebuda');
    }

    log(`FET en ${((Date.now() - t0) / 1000).toFixed(2)}s`);
    await pausa(1.0, 2.0);
    return 0;
  } catch (e) {
    const d = new Date();
    const p2 = (n) => String(n).padStart(2, '0');
    const nom = `error_${d.getFullYear()}${p2(d.getMonth() + 1)}${p2(d.getDate())}_${p2(d.getHours())}${p2(d.getMinutes())}${p2(d.getSeconds())}.png`;
    try {
      await page.screenshot({ path: nom, fullPage: true });
      log(`Captura de l'error desada a ${nom}`);
    } catch {}
    log(`ERROR: ${e.message}`);
    return 1;
  } finally {
    await context.close();
    await navegador.close();
  }
}

async function main() {
  const opt = args();
  const cfg = JSON.parse(fs.readFileSync(opt.config, 'utf8'));

  const usuari = process.env.WEB_USER || cfg.usuari;
  const contrasenya = process.env.WEB_PASS || cfg.contrasenya;
  if (!usuari || !contrasenya) {
    console.error('Falten credencials: defineix WEB_USER i WEB_PASS');
    process.exit(2);
  }

  const jitter = opt.jitter ?? cfg.jitter_max_s ?? 3;
  const headless = !opt.visible && cfg.headless !== false;
  process.exit(await executar(cfg, usuari, contrasenya, headless, jitter));
}

main();
