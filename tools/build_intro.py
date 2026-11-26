#!/usr/bin/env python3
"""
Assembles the "SETTLE" intro into web/index.html (between <!-- INTRO:START -->
and <!-- INTRO:END -->) and writes tools/intro_preview/preview.html with
preview test hooks (?firstframe=<ms>|never, ?speed=<0.1..1>, ?repeat=1,
?reduced=1, ?introdebug=1).
"""
from __future__ import annotations

import base64
import json
import random
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FONT_PATH = ROOT / "assets" / "fonts" / "BricolageGrotesque-ExtraBold.ttf"
INDEX_HTML = ROOT / "web" / "index.html"
PREVIEW_HTML = ROOT / "tools" / "intro_preview" / "preview.html"
FONT_CHECK_PNG = ROOT / "intro_font_check.png"


def make_noise_png_data_uri(size: int = 96, seed: int = 357) -> str:
    rng = random.Random(seed)
    raw = bytearray()
    for _ in range(size):
        raw.append(0)
        for _ in range(size):
            v = rng.randint(0, 255)
            a = rng.randint(140, 255)
            raw.extend((v, v, v, a))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw), 9)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")
    return "data:image/png;base64," + base64.b64encode(png).decode("ascii")


def extract_glyphs():
    try:
        from fontTools.ttLib import TTFont
        from fontTools.pens.svgPathPen import SVGPathPen
        from fontTools.pens.boundsPen import BoundsPen
    except ImportError:
        return None

    if not FONT_PATH.exists():
        raise FileNotFoundError(f"Missing bundled font: {FONT_PATH}")

    font = TTFont(str(FONT_PATH))
    name_table = font["name"]
    family = name_table.getDebugName(1) or name_table.getDebugName(16) or ""
    if "Bricolage Grotesque" not in family:
        raise RuntimeError(f"Expected family 'Bricolage Grotesque', got {family!r}")

    if "fvar" in font:
        from fontTools.varLib import instancer
        axes = {a.axisTag: a for a in font["fvar"].axes}
        limits = {}
        if "wght" in axes:
            limits["wght"] = 800
        if "opsz" in axes:
            limits["opsz"] = 96
        if "wdth" in axes:
            limits["wdth"] = 100
        if limits:
            font = instancer.instantiateVariableFont(font, limits)

    upem = font["head"].unitsPerEm
    cmap = font.getBestCmap()
    glyf_set = font.getGlyphSet()
    tracking = upem * 0.10
    letters = list("SETTLIV")

    glyph_items = []
    pen_x = 0.0
    for idx, ch in enumerate(letters):
        gname = cmap[ord(ch)]
        glyph = glyf_set[gname]
        bpen = BoundsPen(glyf_set)
        glyph.draw(bpen)
        bounds = bpen.bounds
        spen = SVGPathPen(glyf_set)
        glyph.draw(spen)
        d = spen.getCommands()
        advance = font["hmtx"][gname][0]
        glyph_items.append({"ch": ch, "d": d, "bounds": bounds, "x_offset": pen_x})
        if idx < len(letters) - 1:
            pen_x += advance + tracking

    min_x = min(item["x_offset"] + item["bounds"][0] for item in glyph_items)
    min_y = min(item["bounds"][1] for item in glyph_items)
    max_x = max(item["x_offset"] + item["bounds"][2] for item in glyph_items)
    max_y = max(item["bounds"][3] for item in glyph_items)
    total_w = max_x - min_x
    total_h = max_y - min_y

    slots = []
    for idx, item in enumerate(glyph_items):
        xmin, ymin, xmax, ymax = item["bounds"]
        gw = xmax - xmin
        gh = ymax - ymin
        gx = (item["x_offset"] + xmin) - min_x
        gy = max_y - ymax
        slots.append({
            "ch": item["ch"],
            "d": item["d"],
            "leftPct": round((gx / total_w) * 100, 4),
            "topPct": round((gy / total_h) * 100, 4),
            "widthPct": round((gw / total_w) * 100, 4),
            "heightPct": round((gh / total_h) * 100, 4),
            "vb": f"{xmin:.2f} {-ymax:.2f} {gw:.2f} {gh:.2f}",
            "tint": "em" if idx % 2 == 0 else "co",
            "dir": -1 if idx % 2 == 0 else 1,
            "stagger": abs(idx - 3) * 45,
        })

    return {"aspect": round(total_w / total_h, 4), "slots": slots}


def build_head_block(noise_uri: str) -> str:
    return f"""<!-- INTRO:HEAD:START -->
  <style id="intro-style">
    :root {{
      --bg: #070914;
      --ink: #F2F0FA;
      --emerald: #4FE3B8;
      --coral: #FF8D7C;
      --ripple: rgba(201, 194, 255, 0.5);
      --spd: 1;
      --wm-w: min(82vw, clamp(260px, 44vw, 640px));
    }}
    html, body {{ margin: 0; width: 100%; height: 100%; background: #070914; }}
    body.intro-lock {{ overflow: hidden; }}
    #intro {{ position: fixed; inset: 0; z-index: 99999; overflow: hidden; }}
    #intro.exiting {{ pointer-events: none; }}
    .half {{ position: absolute; left: 0; right: 0; overflow: hidden; will-change: transform; }}
    .half.top {{ top: 0; height: calc(50% + 1px); }}
    .half.bottom {{ top: 50%; height: 50%; }}
    .scene {{ position: absolute; left: 0; right: 0; height: 200%; transform: scale(1); }}
    .half.top .scene {{ top: 0; }}
    .half.bottom .scene {{ top: -100%; }}
    .go .scene {{ animation: camPush calc(1500ms / var(--spd)) cubic-bezier(0.16, 1, 0.3, 1) backwards; }}
    @keyframes camPush {{ from {{ transform: scale(1.07); }} to {{ transform: scale(1); }} }}
    .cut-edge {{
      position: absolute; left: 0; right: 0; height: 2px; opacity: 0; pointer-events: none;
      background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.6), transparent);
    }}
    .half.top .cut-edge {{ bottom: 0; }}
    .half.bottom .cut-edge {{ top: 0; }}

    /* Freeze intro children & flatten halves during split exit */
    #intro.frozen .half {{ contain: layout paint style; }}
    #intro.frozen .scene,
    #intro.frozen .rules-bg,
    #intro.frozen .tick-ring,
    #intro.frozen .curr,
    #intro.frozen .head,
    #intro.frozen .merged-line,
    #intro.frozen .flash,
    #intro.frozen .ripple,
    #intro.frozen .wm-box,
    #intro.frozen .mover,
    #intro.frozen .tint {{
      animation-play-state: paused !important;
      will-change: auto !important;
    }}

    /* CSS transition fallback if WAAPI is unavailable */
    #intro.css-exit .half {{ transition: transform calc(540ms / var(--spd)) cubic-bezier(0.76, 0, 0.24, 1); }}
    #intro.css-exit .half.bottom {{ transition-delay: calc(30ms / var(--spd)); }}
    #intro.css-exit .half.top {{ transform: translate3d(0, -100%, 0); }}
    #intro.css-exit .half.bottom {{ transform: translate3d(0, 100%, 0); }}

    .backdrop {{
      position: absolute; inset: 0; background-color: #070914;
      background-image:
        radial-gradient(60vmax 60vmax at 15% 20%, rgba(106, 76, 255, 0.42) 0%, transparent 60%),
        radial-gradient(55vmax 55vmax at 85% 80%, rgba(40, 90, 255, 0.30) 0%, transparent 60%),
        radial-gradient(40vmax 40vmax at 70% 15%, rgba(12, 120, 140, 0.24) 0%, transparent 60%),
        radial-gradient(circle at 18% 22%, transparent calc(46vmax - 1px), rgba(190, 180, 255, 0.09) 46vmax, transparent calc(46vmax + 1px)),
        radial-gradient(circle at 84% 78%, transparent calc(38vmax - 1px), rgba(190, 180, 255, 0.09) 38vmax, transparent calc(38vmax + 1px)),
        radial-gradient(circle at 50% 50%, transparent 55%, rgba(0, 0, 0, 0.5) 100%);
    }}
    .rings-bg, .rules-bg {{
      position: absolute; inset: 0; pointer-events: none;
      -webkit-mask-image: radial-gradient(ellipse 75% 68% at 50% 50%, #000 18%, transparent 88%);
      mask-image: radial-gradient(ellipse 75% 68% at 50% 50%, #000 18%, transparent 88%);
    }}
    .rings-bg {{ background-image: repeating-radial-gradient(circle at 50% 50%, transparent 0 119px, rgba(190, 180, 255, 0.10) 119px 120px); }}
    .rules-bg {{
      background-image:
        repeating-linear-gradient(to bottom, rgba(255, 255, 255, 0.09) 0 1px, transparent 1px 128px),
        repeating-linear-gradient(to bottom, rgba(255, 255, 255, 0.05) 0 1px, transparent 1px 32px);
    }}
    .go .rules-bg {{ animation: fadeIn calc(400ms / var(--spd)) ease-out backwards; }}
    .grain {{ position: absolute; inset: 0; opacity: 0.035; pointer-events: none; background-image: url("{noise_uri}"); }}
    @keyframes fadeIn {{ from {{ opacity: 0; }} to {{ opacity: 1; }} }}

    .tick-ring {{
      position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%);
      max-width: 1100px; max-height: 1100px; pointer-events: none; will-change: transform;
    }}
    .tick-ring.a {{ width: clamp(300px, 68vmin, 720px); height: clamp(300px, 68vmin, 720px); }}
    .tick-ring.b {{ width: clamp(420px, 104vmin, 1040px); height: clamp(420px, 104vmin, 1040px); }}
    .go .tick-ring.a {{
      animation: fadeIn calc(350ms / var(--spd)) ease-out backwards, ringPulse calc(240ms / var(--spd)) ease-out calc(560ms / var(--spd)), spinCW calc(18000ms / var(--spd)) linear infinite;
    }}
    .go .tick-ring.b {{
      animation: fadeIn calc(350ms / var(--spd)) ease-out backwards, ringPulse calc(240ms / var(--spd)) ease-out calc(560ms / var(--spd)), spinCCW calc(30000ms / var(--spd)) linear infinite;
    }}
    @keyframes spinCW {{ from {{ transform: translate(-50%, -50%) rotate(0deg); }} to {{ transform: translate(-50%, -50%) rotate(360deg); }} }}
    @keyframes spinCCW {{ from {{ transform: translate(-50%, -50%) rotate(360deg); }} to {{ transform: translate(-50%, -50%) rotate(0deg); }} }}
    @keyframes ringPulse {{ 0%, 100% {{ transform: translate(-50%, -50%) scale(1); }} 50% {{ transform: translate(-50%, -50%) scale(1.012); }} }}

    .line-y {{ position: absolute; top: 50%; left: 0; right: 0; height: 2px; margin-top: -1px; pointer-events: none; }}
    .curr {{ position: absolute; top: 0; width: 50%; height: 2px; opacity: 0; }}
    .curr.em {{ left: 0; background: var(--emerald); transform-origin: left center; }}
    .curr.co {{ right: 0; background: var(--coral); transform-origin: right center; }}
    .go .curr {{ animation: currGrow calc(460ms / var(--spd)) cubic-bezier(0.55, 0, 0.2, 1) calc(100ms / var(--spd)) both, currCross calc(160ms / var(--spd)) ease-out calc(560ms / var(--spd)) forwards; }}
    @keyframes currGrow {{ 0% {{ opacity: 0.6; transform: scaleX(0); }} 100% {{ opacity: 0.6; transform: scaleX(1); }} }}
    @keyframes currCross {{ to {{ opacity: 0; }} }}

    .head {{ position: absolute; top: -0.5px; width: 18vw; height: 3px; opacity: 0; }}
    .head.em {{ left: 0; background: linear-gradient(90deg, transparent, var(--emerald) 70%, #fff); }}
    .head.co {{ right: 0; background: linear-gradient(270deg, transparent, var(--coral) 70%, #fff); }}
    .go .head.em {{ animation: headL calc(460ms / var(--spd)) cubic-bezier(0.55, 0, 0.2, 1) calc(100ms / var(--spd)) both, headOff calc(60ms / var(--spd)) ease-out calc(560ms / var(--spd)) forwards; }}
    .go .head.co {{ animation: headR calc(460ms / var(--spd)) cubic-bezier(0.55, 0, 0.2, 1) calc(100ms / var(--spd)) both, headOff calc(60ms / var(--spd)) ease-out calc(560ms / var(--spd)) forwards; }}
    @keyframes headL {{ from {{ opacity: 1; transform: translateX(-18vw); }} to {{ opacity: 1; transform: translateX(calc(50vw - 18vw)); }} }}
    @keyframes headR {{ from {{ opacity: 1; transform: translateX(18vw); }} to {{ opacity: 1; transform: translateX(calc(-50vw + 18vw)); }} }}
    @keyframes headOff {{ to {{ opacity: 0; }} }}

    .merged-line {{ position: absolute; top: 50%; left: 0; right: 0; height: 1px; background: rgba(242, 240, 250, 0.9); }}
    .go .merged-line {{ animation: fadeIn calc(160ms / var(--spd)) ease-out calc(560ms / var(--spd)) backwards; }}

    .flash {{
      position: absolute; top: 50%; left: 50%; width: 28vmin; height: 28vmin; margin: -14vmin 0 0 -14vmin; border-radius: 50%;
      background: radial-gradient(circle, rgba(255, 255, 255, 0.55) 0%, transparent 70%); opacity: 0; pointer-events: none;
    }}
    .go .flash {{ animation: flashHit calc(320ms / var(--spd)) ease-out calc(560ms / var(--spd)) both; }}
    @keyframes flashHit {{ 0% {{ opacity: 0; transform: scale(0.3); }} 35% {{ opacity: 1; }} 100% {{ opacity: 0; transform: scale(1.4); }} }}

    .ripple {{
      position: absolute; top: 50%; left: 50%; width: clamp(420px, 104vmin, 1040px); height: clamp(420px, 104vmin, 1040px);
      margin: calc(-0.5 * clamp(420px, 104vmin, 1040px)) 0 0 calc(-0.5 * clamp(420px, 104vmin, 1040px));
      border-radius: 50%; border: 1px solid var(--ripple); opacity: 0; pointer-events: none;
    }}
    .go .ripple.r1 {{ animation: rip calc(760ms / var(--spd)) cubic-bezier(0.16, 1, 0.3, 1) calc(560ms / var(--spd)) both; }}
    .go .ripple.r2 {{ animation: rip calc(760ms / var(--spd)) cubic-bezier(0.16, 1, 0.3, 1) calc(650ms / var(--spd)) both; }}
    @keyframes rip {{ 0% {{ opacity: 0.5; transform: scale(0.15); }} 100% {{ opacity: 0; transform: scale(1.5); }} }}

    .wm-box {{ position: absolute; top: 50%; left: 50%; width: var(--wm-w); transform: translate(-50%, -50%); }}
    .go .wm-box {{ animation: thud calc(160ms / var(--spd)) cubic-bezier(0.3, 0.7, 0.4, 1) calc(900ms / var(--spd)); }}
    @keyframes thud {{ 0%, 100% {{ transform: translate(-50%, -50%) scale(1); }} 50% {{ transform: translate(-50%, -50%) scale(1.016); }} }}

    .wm-inner {{ position: relative; width: 100%; }}
    .slot {{ position: absolute; overflow: hidden; }}
    .mover {{ position: relative; width: 100%; height: 100%; will-change: transform; }}
    .mover svg {{ position: absolute; inset: 0; width: 100%; height: 100%; display: block; }}
    .go .mover {{ animation: settleY calc(480ms / var(--spd)) cubic-bezier(0.16, 1, 0.3, 1) var(--d, 560ms) backwards; }}
    .go .tint {{ animation: tintOut calc(200ms / var(--spd)) ease-out calc(var(--d, 560ms) + 280ms / var(--spd)) both; }}
    @keyframes settleY {{ from {{ transform: translateY(var(--sy)); }} to {{ transform: translateY(0); }} }}
    @keyframes tintOut {{ from {{ opacity: 1; }} to {{ opacity: 0; }} }}

    .wm-fallback {{
      font-family: 'BricolageGrotesque', 'Sora', 'PlusJakartaSans', sans-serif;
      font-size: calc(var(--wm-w) / 5.15); font-weight: 800; line-height: 1; color: var(--ink);
      display: flex; justify-content: center; white-space: nowrap;
    }}
    .slot-txt {{ display: inline-block; overflow: hidden; }}
    .mover .ch {{ display: inline-block; letter-spacing: 0.1em; }}
    .slot-txt:last-child .mover .ch {{ letter-spacing: 0; }}
    .mover .tint {{ position: absolute; inset: 0; pointer-events: none; }}

    .repeat .curr, .repeat .head, .repeat .flash, .repeat .ripple {{ display: none; }}
    .repeat.go .mover {{ animation-duration: calc(320ms / var(--spd)); animation-delay: var(--dr, 0ms); }}
    .settled .curr, .settled .head, .settled .flash, .settled .ripple {{ display: none; }}
    .settled .mover {{ animation: none !important; transform: none !important; }}
    .settled .tint {{ display: none; }}
    .reduced .curr, .reduced .head, .reduced .flash, .reduced .ripple {{ display: none; }}
    .reduced.go .tick-ring {{ animation: none !important; opacity: 1; }}
    .reduced.go .mover, .reduced.go .tint {{ animation: none !important; transform: none; opacity: 0; }}
    .reduced.go .wm-box, .reduced.go .merged-line {{ animation: fadeIn 400ms ease-out backwards; }}
    .reduced.exiting {{ animation: fadeOut 300ms ease-out forwards; }}
    .reduced.exiting .half {{ animation: none !important; }}
    @keyframes fadeOut {{ to {{ opacity: 0; }} }}
    @media (prefers-reduced-motion: reduce) {{
      .tick-ring, .mover, .tint, .curr, .head, .flash, .ripple {{ animation: none !important; }}
    }}
  </style>
  <!-- INTRO:HEAD:END -->"""


def build_body_block(glyph_data: dict | None, is_preview: bool) -> str:
    glyph_json = json.dumps(glyph_data, separators=(",", ":")) if glyph_data else "null"
    preview_hooks = """
        var q = new URLSearchParams(location.search);
        var pSpeed = Math.min(1, Math.max(0.1, parseFloat(q.get('speed') || '1') || 1));
        var pFirst = q.get('firstframe');
        var pRepeat = q.get('repeat') === '1';
        var pReduced = q.get('reduced') === '1';
        var pDebug = q.get('introdebug') === '1';
        if (pRepeat) try { sessionStorage.setItem('settliv_intro_seen', '1'); } catch (_) {}
        if (pReduced) document.documentElement.classList.add('force-reduced');
        document.documentElement.style.setProperty('--spd', String(pSpeed));
        if (pFirst !== 'never') {
          var ffMs = pFirst !== null ? parseInt(pFirst, 10) : 900;
          if (!isNaN(ffMs)) setTimeout(function () { window.__flutterFirstFrame = true; window.dispatchEvent(new CustomEvent('flutter-first-frame')); }, ffMs);
        }
""" if is_preview else "        var pSpeed = 1; var pDebug = false;"

    return f"""<!-- INTRO:START -->
  <div id="intro" role="presentation"></div>
  <script>
    (function () {{
      if (window.__settlivIntro) return;
      var GLYPHS = {glyph_json};
      {preview_hooks}

      var logBuf = window.__settlivIntroLog = [];
      var ctrl = window.__settlivIntro = {{
        state: 'PENDING',
        mode: 'FULL',
        t0: performance.now(),
        revealSent: false,
        doneSent: false,
        timers: [],
        mo: null,
        po: null,
        rafId: 0,
        lastLongTaskAt: -9999,
        prewarmed: null,
        wasHidden: false,
        themeApplied: false
      }};

      function log(state, reason) {{
        ctrl.state = state;
        var entry = {{ t: Math.round(performance.now() - ctrl.t0), state: state, mode: ctrl.mode, reason: reason || '' }};
        logBuf.push(entry);
        if (logBuf.length > 40) logBuf.shift();
        if (pDebug && console && console.debug) console.debug('[settliv-intro]', entry);
      }}

      function setTimer(fn, ms) {{ var id = setTimeout(fn, ms); ctrl.timers.push(id); return id; }}
      function clearTimers() {{
        for (var i = 0; i < ctrl.timers.length; i++) clearTimeout(ctrl.timers[i]);
        ctrl.timers.length = 0;
        if (ctrl.rafId) cancelAnimationFrame(ctrl.rafId);
        ctrl.rafId = 0;
        if (ctrl.mo) {{ ctrl.mo.disconnect(); ctrl.mo = null; }}
        if (ctrl.po) {{ try {{ ctrl.po.disconnect(); }} catch (_) {{}} ctrl.po = null; }}
      }}

      function applyAppThemeBackground() {{
        if (ctrl.themeApplied) return;
        ctrl.themeApplied = true;
        var mode = null;
        try {{
          mode = localStorage.getItem('flutter.settliv_theme_mode') || localStorage.getItem('settliv_theme_mode');
          if (mode && mode.charAt(0) === '"') mode = JSON.parse(mode);
        }} catch (_) {{}}
        var dark = mode === 'dark' || (mode !== 'light' && window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches);
        var bg = dark ? '#0A0C1C' : '#F6F7FC';
        document.documentElement.style.backgroundColor = bg;
        if (document.body) document.body.style.backgroundColor = bg;
      }}

      function dispatchRevealOnce() {{
        if (ctrl.revealSent) return;
        ctrl.revealSent = true;
        window.dispatchEvent(new CustomEvent('settliv-intro-reveal'));
      }}

      function finish(reason) {{
        if (ctrl.state === 'DONE') return;
        log('DONE', reason || 'completed');
        clearTimers();
        window.removeEventListener('flutter-first-frame', onFirstFrame);
        document.removeEventListener('visibilitychange', onVisibility);
        var el = document.getElementById('intro');
        if (el) {{
          el.style.visibility = 'hidden';
          if (el.parentNode) el.parentNode.removeChild(el);
        }}
        if (document.body) document.body.classList.remove('intro-lock');
        dispatchRevealOnce();
        if (!ctrl.doneSent) {{
          ctrl.doneSent = true;
          window.dispatchEvent(new CustomEvent('settliv-intro-done'));
        }}
      }}

      function flutterReady() {{
        if (window.__flutterFirstFrame) return true;
        var fv = document.querySelector('flutter-view, flt-glass-pane');
        if (!fv) return false;
        return fv.childElementCount > 0 || (fv.shadowRoot && fv.shadowRoot.childElementCount > 0);
      }}

      function prewarmExit() {{
        if (ctrl.prewarmed || ctrl.mode === 'GENTLE' || ctrl.mode === 'NONE') return;
        var el = document.getElementById('intro');
        if (!el) return;
        var top = el.querySelector('.half.top');
        var bot = el.querySelector('.half.bottom');
        if (!top || !bot || typeof top.animate !== 'function') return;
        var dur = Math.round((ctrl.mode === 'SHORT' ? 420 : 540) / pSpeed);
        var bDelay = Math.round(30 / pSpeed);
        var ease = 'cubic-bezier(0.76, 0, 0.24, 1)';
        var aTop = top.animate([{{ transform: 'translate3d(0,0,0)' }}, {{ transform: 'translate3d(0,-100%,0)' }}], {{ duration: dur, easing: ease, fill: 'both' }});
        var aBot = bot.animate([{{ transform: 'translate3d(0,0,0)' }}, {{ transform: 'translate3d(0,100%,0)' }}], {{ duration: dur, delay: bDelay, easing: ease, fill: 'both' }});
        var cuts = el.querySelectorAll('.cut-edge');
        var anims = [aTop, aBot];
        for (var i = 0; i < cuts.length; i++) {{
          var ac = cuts[i].animate([{{ opacity: 1 }}, {{ opacity: 0 }}], {{ duration: dur, easing: 'ease-out', fill: 'both' }});
          anims.push(ac);
        }}
        for (var j = 0; j < anims.length; j++) {{
          anims[j].pause();
          anims[j].currentTime = 0;
        }}
        ctrl.prewarmed = anims;
        log(ctrl.state, 'exit_prewarmed');
      }}

      function startExit(reason) {{
        if (ctrl.state === 'EXITING' || ctrl.state === 'DONE') return;
        log('EXITING', reason || 'split_start');
        try {{ sessionStorage.setItem('settliv_intro_seen', '1'); }} catch (_) {{}}
        applyAppThemeBackground();
        var el = document.getElementById('intro');
        if (!el) {{ dispatchRevealOnce(); finish('missing_el'); return; }}

        if (ctrl.mode === 'GENTLE') {{
          dispatchRevealOnce();
          el.classList.add('exiting');
          setTimer(function () {{ finish('gentle_done'); }}, 300);
          return;
        }}

        el.classList.add('frozen', 'exiting');
        setTimer(function () {{ finish('safety_2500ms'); }}, 2500);

        if (!ctrl.prewarmed) prewarmExit();
        var anims = ctrl.prewarmed;
        if (anims && anims.length) {{
          for (var i = 0; i < anims.length; i++) anims[i].play();
          Promise.all(anims.map(function (a) {{ return a.ready; }})).then(function () {{
            log('EXITING', 'anims_ready');
            dispatchRevealOnce();
          }}, dispatchRevealOnce);
          Promise.all(anims.map(function (a) {{ return a.finished; }})).then(function () {{
            requestAnimationFrame(function () {{
              requestAnimationFrame(function () {{
                finish('waapi_finished');
              }});
            }});
          }}, function () {{ finish('waapi_err'); }});
        }} else {{
          // CSS transition fallback
          dispatchRevealOnce();
          el.classList.add('css-exit');
          var bot = el.querySelector('.half.bottom');
          if (bot) {{
            bot.addEventListener('transitionend', function onEnd() {{
              bot.removeEventListener('transitionend', onEnd);
              requestAnimationFrame(function () {{ requestAnimationFrame(function () {{ finish('css_transitionend'); }}); }});
            }});
          }}
        }}
      }}

      function enterArmed() {{
        if (ctrl.state === 'ARMED' || ctrl.state === 'EXITING' || ctrl.state === 'DONE') return;
        log('ARMED', 'min_and_ff_ready');
        prewarmExit();
        if (ctrl.mode === 'GENTLE') {{ startExit('gentle_ready'); return; }}

        var calmStart = performance.now();
        var prevT = calmStart;
        var calmCount = 0;
        setTimer(function () {{
          if (ctrl.state === 'ARMED') startExit('calm_timeout_1500ms');
        }}, 1500);

        function checkCalm(now) {{
          if (ctrl.state !== 'ARMED') return;
          var dt = now - prevT;
          prevT = now;
          var noRecentLongTask = (now - ctrl.lastLongTaskAt) > 120;
          if (dt <= 24 && noRecentLongTask) calmCount++;
          else calmCount = 0;
          if (calmCount >= 2) {{
            startExit('calm_gate_passed');
            return;
          }}
          ctrl.rafId = requestAnimationFrame(checkCalm);
        }}
        ctrl.rafId = requestAnimationFrame(checkCalm);
      }}

      function evaluate() {{
        if (ctrl.state === 'ARMED' || ctrl.state === 'EXITING' || ctrl.state === 'DONE') return;
        if (flutterReady()) applyAppThemeBackground();
        var minMs = Math.round((ctrl.mode === 'SHORT' ? 320 : (ctrl.mode === 'GENTLE' ? 400 : 1180)) / pSpeed);
        var elapsed = performance.now() - ctrl.t0;
        if (elapsed < minMs) return;
        prewarmExit();
        if (flutterReady()) {{
          enterArmed();
        }} else if (ctrl.state === 'PLAYING') {{
          log('HOLDING', 'waiting_first_frame');
          function poll() {{
            if (ctrl.state !== 'HOLDING') return;
            if (flutterReady()) {{ window.__flutterFirstFrame = true; applyAppThemeBackground(); enterArmed(); return; }}
            ctrl.rafId = requestAnimationFrame(poll);
          }}
          ctrl.rafId = requestAnimationFrame(poll);
        }}
      }}

      function onFirstFrame() {{
        window.__flutterFirstFrame = true;
        log(ctrl.state, 'flutter_first_frame');
        applyAppThemeBackground();
        evaluate();
      }}

      function onVisibility() {{
        if (ctrl.state === 'EXITING' || ctrl.state === 'DONE') return;
        if (document.hidden) {{
          ctrl.wasHidden = true;
        }} else if (ctrl.wasHidden) {{
          var el = document.getElementById('intro');
          if (el) {{ el.classList.remove('go'); el.classList.add('settled', 'repeat'); }}
          ctrl.mode = 'SHORT';
          prewarmExit();
          if (flutterReady()) enterArmed();
          else log('HOLDING', 'returned_from_hidden');
        }}
      }}

      function wordmarkMarkup(isTop) {{
        if (!GLYPHS) {{
          var chs = ['S','E','T','T','L','I','V'];
          var spans = chs.map(function (c, i) {{
            var sy = i % 2 === 0 ? '-115%' : '115%';
            var col = i % 2 === 0 ? 'var(--emerald)' : 'var(--coral)';
            var stag = Math.abs(i - 3) * 45;
            return '<span class="slot-txt"><span class="mover" style="--sy:' + sy + ';--d:' + (560 + stag) + 'ms;--dr:' + Math.round(stag * 0.55) + 'ms">' +
              '<span class="ch">' + c + '</span><span class="ch tint" style="color:' + col + '" aria-hidden="true">' + c + '</span>' +
            '</span></span>';
          }}).join('');
          return '<div class="wm-box"><div class="wm-fallback" ' + (isTop ? 'role="img" aria-label="SETTLIV"' : 'aria-hidden="true"') + '>' + spans + '</div></div>';
        }}
        var slotsHtml = GLYPHS.slots.map(function (s) {{
          var col = s.tint === 'em' ? 'var(--emerald)' : 'var(--coral)';
          var d = 560 + s.stagger, dr = Math.round(s.stagger * 0.55);
          return '<div class="slot" style="left:' + s.leftPct + '%;top:' + s.topPct + '%;width:' + s.widthPct + '%;height:' + s.heightPct + '%">' +
            '<div class="mover" style="--sy:' + (s.dir < 0 ? '-115%' : '115%') + ';--d:' + d + 'ms;--dr:' + dr + 'ms">' +
              '<svg viewBox="' + s.vb + '"><path d="' + s.d + '" fill="var(--ink)" transform="scale(1,-1)"/></svg>' +
              '<svg class="tint" viewBox="' + s.vb + '"><path d="' + s.d + '" fill="' + col + '" transform="scale(1,-1)"/></svg>' +
            '</div></div>';
        }}).join('');
        var padBottom = (100 / GLYPHS.aspect).toFixed(3);
        return '<div class="wm-box"><div class="wm-inner" style="padding-bottom:' + padBottom + '%" ' + (isTop ? 'role="img" aria-label="SETTLIV"' : 'aria-hidden="true"') + '>' + slotsHtml + '</div></div>';
      }}

      function buildScene(isTop) {{
        return '<div class="scene">' +
          '<div class="backdrop" aria-hidden="true"></div>' +
          '<div class="rings-bg" aria-hidden="true"></div>' +
          '<div class="rules-bg" aria-hidden="true"></div>' +
          '<div class="grain" aria-hidden="true"></div>' +
          '<svg class="tick-ring a" viewBox="0 0 200 200" aria-hidden="true"><circle cx="100" cy="100" r="98" fill="none" stroke="rgba(190,180,255,0.34)" stroke-width="1" stroke-dasharray="1 9" vector-effect="non-scaling-stroke"/></svg>' +
          '<svg class="tick-ring b" viewBox="0 0 200 200" aria-hidden="true"><circle cx="100" cy="100" r="98" fill="none" stroke="rgba(190,180,255,0.22)" stroke-width="1" stroke-dasharray="2 14" vector-effect="non-scaling-stroke"/></svg>' +
          '<div class="line-y" aria-hidden="true"><div class="curr em"></div><div class="curr co"></div><div class="head em"></div><div class="head co"></div></div>' +
          '<div class="merged-line" aria-hidden="true"></div>' +
          '<div class="flash" aria-hidden="true"></div>' +
          '<div class="ripple r1" aria-hidden="true"></div>' +
          '<div class="ripple r2" aria-hidden="true"></div>' +
          wordmarkMarkup(isTop) +
        '</div>';
      }}

      try {{
        window.addEventListener('flutter-first-frame', onFirstFrame);
        window.addEventListener('pageshow', function (e) {{
          if (e.persisted) {{
            ctrl.mode = 'NONE';
            applyAppThemeBackground();
            finish('bfcache_persisted');
          }}
        }});

        if (typeof PerformanceObserver !== 'undefined') {{
          try {{
            ctrl.po = new PerformanceObserver(function (list) {{
              var entries = list.getEntries();
              for (var i = 0; i < entries.length; i++) {{
                ctrl.lastLongTaskAt = entries[i].startTime + entries[i].duration;
                log(ctrl.state, 'longtask_' + Math.round(entries[i].duration) + 'ms');
              }}
            }});
            ctrl.po.observe({{ type: 'longtask', buffered: true }});
          }} catch (_) {{}}
        }}

        var seen = false;
        try {{ seen = sessionStorage.getItem('settliv_intro_seen') === '1'; }} catch (_) {{ seen = false; }}
        var navType = 'navigate';
        try {{
          var navEntries = performance.getEntriesByType && performance.getEntriesByType('navigation');
          if (navEntries && navEntries.length) navType = navEntries[0].type || 'navigate';
        }} catch (_) {{}}
        var reduced = (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) ||
                      document.documentElement.classList.contains('force-reduced');

        if (document.hidden) {{
          ctrl.mode = 'NONE';
          applyAppThemeBackground();
          finish('hidden_at_load');
          return;
        }}

        if (reduced) ctrl.mode = 'GENTLE';
        else if (seen || navType === 'back_forward') ctrl.mode = 'SHORT';
        else ctrl.mode = 'FULL';

        var el = document.getElementById('intro');
        if (!el) {{ finish('missing_intro_node'); return; }}
        document.body.classList.add('intro-lock');
        el.innerHTML =
          '<div class="half top">' + buildScene(true) + '<div class="cut-edge" aria-hidden="true"></div></div>' +
          '<div class="half bottom">' + buildScene(false) + '<div class="cut-edge" aria-hidden="true"></div></div>';
        if (ctrl.mode === 'SHORT') el.classList.add('repeat');
        if (ctrl.mode === 'GENTLE') el.classList.add('reduced');

        document.addEventListener('visibilitychange', onVisibility);

        if (typeof MutationObserver !== 'undefined') {{
          ctrl.mo = new MutationObserver(function () {{
            if (flutterReady()) {{ window.__flutterFirstFrame = true; applyAppThemeBackground(); evaluate(); }}
          }});
          ctrl.mo.observe(document.body, {{ childList: true, subtree: true }});
        }}

        setTimer(function () {{
          if (ctrl.state !== 'EXITING' && ctrl.state !== 'DONE') {{
            startExit('safety_15000ms');
          }}
        }}, 15000);

        var minHold = Math.round((ctrl.mode === 'SHORT' ? 320 : (ctrl.mode === 'GENTLE' ? 400 : 1180)) / pSpeed);
        setTimer(evaluate, minHold);

        requestAnimationFrame(function () {{
          requestAnimationFrame(function () {{
            if (ctrl.state !== 'PENDING') return;
            log('PLAYING', 'mode_' + ctrl.mode);
            el.classList.add('go');
            evaluate();
          }});
        }});
      }} catch (_) {{
        ctrl.mode = 'NONE';
        applyAppThemeBackground();
        finish('exception_fallback');
      }}
    }})();
  </script>
  <!-- INTRO:END -->"""


def main():
    noise_uri = make_noise_png_data_uri()
    glyph_data = extract_glyphs()
    head_block = build_head_block(noise_uri)
    body_block = build_body_block(glyph_data, is_preview=False)

    html = f"""<!DOCTYPE html>
<html style="background:#070914">
<head>
  <base href="$FLUTTER_BASE_HREF">
  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <title>Settliv — Expense Sharing & Group Ledger</title>
  <meta name="description" content="Settliv is a modern, exact-paise group expense sharing and ledger web application.">
  <meta name="theme-color" content="#070914">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="Settliv">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  <link rel="icon" type="image/png" href="favicon.png">
  <link rel="manifest" href="manifest.json">
  <link rel="preload" href="assets/assets/fonts/BricolageGrotesque-ExtraBold.ttf" as="font" type="font/ttf" crossorigin>
  <style>
    @font-face {{
      font-family: 'BricolageGrotesque';
      src: url('assets/assets/fonts/BricolageGrotesque-ExtraBold.ttf') format('truetype');
      font-weight: 800;
      font-style: normal;
      font-display: block;
    }}
  </style>
  {head_block}
</head>
<body>
  {body_block}
  <noscript><div style="position:fixed;inset:0;display:flex;align-items:center;justify-content:center;background:#070914;color:#F2F0FA;font:800 32px sans-serif;letter-spacing:.1em">SETTLIV</div></noscript>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
"""
    INDEX_HTML.write_text(html, encoding="utf-8")
    print(f"Updated {INDEX_HTML}")

    PREVIEW_HTML.parent.mkdir(parents=True, exist_ok=True)
    preview_body = build_body_block(glyph_data, is_preview=True)
    preview_doc = f"""<!DOCTYPE html>
<html style="background:#070914">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <title>Settliv Intro Preview</title>
  {head_block}
</head>
<body>
  {preview_body}
  <main style="min-height:100dvh;display:flex;align-items:center;justify-content:center;color:#F2F0FA;font-family:sans-serif">App Revealed</main>
</body>
</html>
"""
    PREVIEW_HTML.write_text(preview_doc, encoding="utf-8")
    print(f"Wrote {PREVIEW_HTML}")


if __name__ == "__main__":
    main()
