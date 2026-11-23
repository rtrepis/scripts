#!/usr/bin/env python3
"""
Automatització web amb comportament "humà":

  1. Obre la pàgina de login i hi entra amb usuari i contrasenya.
  2. Clica l'enllaç que porta a la segona pàgina (que tarda a carregar).
  3. Espera que la segona pàgina estigui llesta.
  4. Espera un temps aleatori (per defecte entre 0 i 3 segons).
  5. Prem el botó de l'acció.

Tots els moviments imiten una persona: el ratolí es desplaça en corba fins
a l'element, s'escriu tecla a tecla amb velocitat variable i hi ha petites
pauses entre passos.

Ús ràpid:
    export WEB_USER="usuari"
    export WEB_PASS="contrasenya"
    python3 accio_web.py --config config.json

Requisits:
    pip install playwright
    playwright install chromium
"""

import argparse
import json
import math
import os
import random
import sys
import time
from datetime import datetime

from playwright.sync_api import TimeoutError as PWTimeout
from playwright.sync_api import sync_playwright


# --------------------------------------------------------------------------- #
# Utilitats
# --------------------------------------------------------------------------- #
def log(msg):
    print(f"[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] {msg}", flush=True)


def pausa(min_s=0.3, max_s=1.2):
    """Pausa curta i aleatòria, com qui llegeix o pensa."""
    time.sleep(random.uniform(min_s, max_s))


# --------------------------------------------------------------------------- #
# Ratolí i teclat humans
# --------------------------------------------------------------------------- #
class Huma:
    def __init__(self, page):
        self.page = page
        vp = page.viewport_size or {"width": 1280, "height": 800}
        # Posició inicial del ratolí: un punt qualsevol de la pantalla
        self.x = random.uniform(100, vp["width"] - 100)
        self.y = random.uniform(100, vp["height"] - 100)
        page.mouse.move(self.x, self.y)

    def _moure(self, tx, ty):
        """Mou el ratolí seguint una corba de Bézier amb velocitat variable."""
        sx, sy = self.x, self.y
        dist = math.hypot(tx - sx, ty - sy)
        passos = max(12, int(dist / random.uniform(8, 15)))
        # Punts de control desplaçats per fer una trajectòria corbada
        desv = dist * random.uniform(0.1, 0.3)
        c1 = (sx + (tx - sx) * 0.3 + random.uniform(-desv, desv),
              sy + (ty - sy) * 0.3 + random.uniform(-desv, desv))
        c2 = (sx + (tx - sx) * 0.7 + random.uniform(-desv, desv),
              sy + (ty - sy) * 0.7 + random.uniform(-desv, desv))
        for i in range(1, passos + 1):
            t = i / passos
            # ease-in-out: comença i acaba més lent
            t = t * t * (3 - 2 * t)
            u = 1 - t
            x = u**3 * sx + 3 * u**2 * t * c1[0] + 3 * u * t**2 * c2[0] + t**3 * tx
            y = u**3 * sy + 3 * u**2 * t * c1[1] + 3 * u * t**2 * c2[1] + t**3 * ty
            self.page.mouse.move(x, y)
            time.sleep(random.uniform(0.004, 0.018))
        self.x, self.y = tx, ty

    def _punt_dins(self, locator):
        locator.scroll_into_view_if_needed()
        box = locator.bounding_box()
        if not box:
            raise RuntimeError("L'element no és visible a la pàgina")
        # Un punt aleatori cap al centre (no exactament al mig)
        x = box["x"] + box["width"] * random.uniform(0.3, 0.7)
        y = box["y"] + box["height"] * random.uniform(0.3, 0.7)
        return x, y

    def clicar(self, locator):
        x, y = self._punt_dins(locator)
        self._moure(x, y)
        pausa(0.08, 0.25)  # petita vacil·lació abans de clicar
        self.page.mouse.down()
        time.sleep(random.uniform(0.05, 0.14))  # durada real d'un clic
        self.page.mouse.up()

    def escriure(self, locator, text):
        self.clicar(locator)
        pausa(0.2, 0.5)
        locator.fill("")  # buida el camp per si hi havia res
        for c in text:
            self.page.keyboard.type(c)
            pausa_tecla = random.uniform(0.05, 0.18)
            if random.random() < 0.07:  # de tant en tant, una pausa més llarga
                pausa_tecla += random.uniform(0.2, 0.5)
            time.sleep(pausa_tecla)


# --------------------------------------------------------------------------- #
# Flux principal
# --------------------------------------------------------------------------- #
def executar(cfg, usuari, contrasenya, headless, jitter_max):
    t0 = time.monotonic()
    sel = cfg["selectors"]
    timeout_pag2 = int(cfg.get("timeout_pagina2_s", 90)) * 1000

    with sync_playwright() as p:
        # CHROMIUM_PATH opcional: per fer servir un Chrome/Chromium ja instal·lat
        navegador = p.chromium.launch(
            headless=headless,
            executable_path=os.environ.get("CHROMIUM_PATH") or None,
        )
        context = navegador.new_context(
            viewport={"width": 1366, "height": 768},
            locale=cfg.get("locale", "ca-ES"),
            timezone_id=cfg.get("timezone", "Europe/Madrid"),
        )
        page = context.new_page()
        page.set_default_timeout(30_000)

        try:
            # 1) Login ------------------------------------------------------
            log(f"Obrint {cfg['login_url']}")
            page.goto(cfg["login_url"], wait_until="domcontentloaded")
            huma = Huma(page)
            pausa(0.8, 1.8)  # "mirar" la pàgina

            log("Escrivint usuari")
            huma.escriure(page.locator(sel["usuari"]), usuari)
            pausa(0.3, 0.8)
            log("Escrivint contrasenya")
            huma.escriure(page.locator(sel["contrasenya"]), contrasenya)
            pausa(0.4, 1.0)

            log("Enviant login")
            huma.clicar(page.locator(sel["boto_login"]))

            # Confirmem que el login ha anat bé: ha d'aparèixer l'enllaç
            enllac = page.locator(sel["enllac_pagina2"]).first
            enllac.wait_for(state="visible", timeout=30_000)
            log("Login correcte")
            pausa(0.6, 1.5)

            # 2) Anar a la segona pàgina -----------------------------------
            log("Clicant l'enllaç a la segona pàgina")
            huma.clicar(enllac)

            # 3) Esperar que la pàgina 2 acabi de carregar (pot ser lenta)
            log(f"Esperant la segona pàgina (màx. {timeout_pag2 // 1000}s)")
            boto = page.locator(sel["boto_accio"]).first
            boto.wait_for(state="visible", timeout=timeout_pag2)
            try:
                page.wait_for_load_state("networkidle", timeout=15_000)
            except PWTimeout:
                pass  # algunes webs mai arriben a "idle"; el botó ja hi és
            # Espera que el botó estigui realment habilitat
            page.wait_for_function(
                "el => !el.disabled && el.getAttribute('aria-disabled') !== 'true'",
                arg=boto.element_handle(),
                timeout=timeout_pag2,
            )
            log("Segona pàgina carregada")

            # 4) Aleatorietat ----------------------------------------------
            espera = random.uniform(0, jitter_max)
            log(f"Espera aleatòria: {espera:.2f}s")
            time.sleep(espera)

            # 5) Acció -----------------------------------------------------
            log("Prement el botó de l'acció")
            huma.clicar(boto)

            if sel.get("confirmacio"):
                page.locator(sel["confirmacio"]).first.wait_for(
                    state="visible", timeout=30_000
                )
                log("Confirmació rebuda")

            log(f"FET en {time.monotonic() - t0:.2f}s")
            pausa(1.0, 2.0)
            return 0

        except Exception as e:  # noqa: BLE001
            nom = f"error_{datetime.now():%Y%m%d_%H%M%S}.png"
            try:
                page.screenshot(path=nom, full_page=True)
                log(f"Captura de l'error desada a {nom}")
            except Exception:  # noqa: BLE001
                pass
            log(f"ERROR: {e}")
            return 1
        finally:
            context.close()
            navegador.close()


def main():
    ap = argparse.ArgumentParser(description="Login + navegació + acció amb tocs humans")
    ap.add_argument("--config", default=os.path.join(os.path.dirname(__file__), "config.json"))
    ap.add_argument("--jitter", type=float, default=None,
                    help="Segons màxims d'espera aleatòria abans de l'acció (per defecte 3)")
    ap.add_argument("--visible", action="store_true",
                    help="Mostra el navegador (per defecte va ocult)")
    args = ap.parse_args()

    with open(args.config, encoding="utf-8") as f:
        cfg = json.load(f)

    usuari = os.environ.get("WEB_USER") or cfg.get("usuari")
    contrasenya = os.environ.get("WEB_PASS") or cfg.get("contrasenya")
    if not usuari or not contrasenya:
        sys.exit("Falten credencials: defineix WEB_USER i WEB_PASS")

    jitter = args.jitter if args.jitter is not None else float(cfg.get("jitter_max_s", 3))
    headless = not args.visible and cfg.get("headless", True)
    sys.exit(executar(cfg, usuari, contrasenya, headless, jitter))


if __name__ == "__main__":
    main()
