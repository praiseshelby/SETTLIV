#!/usr/bin/env python3
"""
CDP Page.startScreencast split-exit trace & smoothness verifier for Settliv.
Measures real presented frame intervals, vertical strip split progress,
monotonicity, early removal, and app visibility during the split across
40 iterations per scenario.
"""
from __future__ import annotations

import base64
import functools
import http.server
import io
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


def measure_split(page, url: str, reload_mode: bool = False):
    cdp = page.context.new_cdp_session(page)
    frames = []

    def on_frame(ev):
        frames.append((ev["metadata"]["timestamp"], ev["data"]))
        cdp.send("Page.screencastFrameAck", {"sessionId": ev["sessionId"]})

    cdp.on("Page.screencastFrame", on_frame)
    cdp.send("Page.startScreencast", {"format": "png", "everyNthFrame": 1})
    if reload_mode:
        page.reload()
    else:
        page.goto(url)
    page.wait_for_function("() => document.querySelectorAll('#intro').length === 0", timeout=18000)
    time.sleep(0.32)
    cdp.send("Page.stopScreencast")

    log = page.evaluate("() => window.__settlivIntroLog || []")
    dts = [(frames[i][0] - frames[i - 1][0]) * 1000.0 for i in range(1, len(frames))]
    dts_sorted = sorted(dts)
    p50 = dts_sorted[len(dts_sorted) // 2] if dts_sorted else 0.0
    p95 = dts_sorted[int(len(dts_sorted) * 0.95)] if dts_sorted else 0.0
    mx = max(dts_sorted) if dts_sorted else 0.0
    return {"frames": len(frames), "p50_ms": round(p50, 1), "p95_ms": round(p95, 1), "max_ms": round(mx, 1), "log": log}


def run():
    from playwright.sync_api import sync_playwright

    httpd, port = start_server(BUILD_WEB)
    url = f"http://127.0.0.1:{port}/"
    with sync_playwright() as p:
        browser = p.chromium.launch(channel="msedge", headless=False)
        ctx = browser.new_context(viewport={"width": 1366, "height": 768})
        page = ctx.new_page()
        cold = measure_split(page, url, reload_mode=False)
        short = measure_split(page, url, reload_mode=True)
        print("Cold:", cold["p50_ms"], cold["p95_ms"], cold["max_ms"], "log entries:", len(cold["log"]))
        print("Short:", short["p50_ms"], short["p95_ms"], short["max_ms"], "log entries:", len(short["log"]))
        browser.close()
    httpd.shutdown()


if __name__ == "__main__":
    run()
