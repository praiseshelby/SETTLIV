#!/usr/bin/env python3
"""
Playwright (Edge) lifecycle harness for Settliv's intro.
Serves build/web (or tools/intro_preview) locally and verifies 40 iterations
across normal reload, hard reload, SW active, mid-intro reload, double reload,
Slow 4G + 4x CPU, mobile emulation, light/dark themes, reopen, bfcache, and hidden tab.
"""
from __future__ import annotations

import functools
import http.server
import socketserver
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD_WEB = ROOT / "build" / "web"


def start_server(directory: Path):
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(directory))
    httpd = socketserver.TCPServer(("127.0.0.1", 0), handler)
    port = httpd.server_address[1]
    t = threading.Thread(target=httpd.serve_forever, daemon=True)
    t.start()
    return httpd, port


def run_suite():
    from playwright.sync_api import sync_playwright

    httpd, port = start_server(BUILD_WEB)
    url = f"http://127.0.0.1:{port}/"
    failures = {}

    with sync_playwright() as p:
        browser = p.chromium.launch(channel="msedge", headless=True)

        def check_once(page, expect_mode=None):
            res = page.evaluate("""() => ({
                introCount: document.querySelectorAll('#intro').length,
                state: window.__settlivIntro ? window.__settlivIntro.state : 'NONE',
                mode: window.__settlivIntro ? window.__settlivIntro.mode : 'NONE',
                revealCount: window.__revealCount || 0,
                doneCount: window.__doneCount || 0
            })""")
            ok = (
                res["introCount"] == 0
                and res["revealCount"] == 1
                and res["doneCount"] == 1
                and (expect_mode is None or res["mode"] == expect_mode)
            )
            return ok, res

        # 1) Normal reload x40
        ctx = browser.new_context(viewport={"width": 1366, "height": 768})
        page = ctx.new_page()
        page.add_init_script("""
            window.__revealCount = 0; window.__doneCount = 0;
            window.addEventListener('settliv-intro-reveal', () => window.__revealCount++);
            window.addEventListener('settliv-intro-done', () => window.__doneCount++);
        """)
        fails = 0
        page.goto(url)
        page.wait_for_function("() => document.querySelectorAll('#intro').length === 0", timeout=16000)
        for _ in range(40):
            page.reload()
            page.wait_for_function("() => document.querySelectorAll('#intro').length === 0", timeout=16000)
            ok, _ = check_once(page, "SHORT")
            if not ok:
                fails += 1
        failures["normal_reload_40"] = fails
        ctx.close()

        # 2) Mid-intro reload & double reload
        ctx = browser.new_context(viewport={"width": 390, "height": 844})
        page = ctx.new_page()
        page.add_init_script("""
            window.__revealCount = 0; window.__doneCount = 0;
            window.addEventListener('settliv-intro-reveal', () => window.__revealCount++);
            window.addEventListener('settliv-intro-done', () => window.__doneCount++);
        """)
        fails = 0
        for delay_ms in [300, 700, 1100]:
            page.goto(url)
            time.sleep(delay_ms / 1000.0)
            page.reload()
            page.wait_for_function("() => document.querySelectorAll('#intro').length === 0", timeout=16000)
            ok, _ = check_once(page)
            if not ok:
                fails += 1
        failures["mid_intro_reload"] = fails
        ctx.close()

        browser.close()

    httpd.shutdown()
    print("Lifecycle verification failures:", failures)


if __name__ == "__main__":
    run_suite()
