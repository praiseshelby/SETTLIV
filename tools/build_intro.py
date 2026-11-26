#!/usr/bin/env python3
"""
Assembles the "SETTLE" intro into web/index.html (between <!-- INTRO:START -->
and <!-- INTRO:END -->) and writes tools/intro_preview/preview.html with
preview test hooks (?firstframe=<ms>|never, ?speed=<0.1..1>, ?repeat=1, ?reduced=1).

When fontTools is installed, extracts exact Bricolage Grotesque ExtraBold SVG
glyph outlines for S, E, T, T, L, I, V with 0.10em tracking and exact ink
bounding box, and optionally generates intro_font_check.png with Pillow.
"""
from __future__ import annotations

import base64
import io
import json
import math
import os
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
        raw.append(0)  # filter type 0
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
    """Extract inline SVG paths for S E T T L I V from the bundled TTF."""
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
    subfamily = name_table.getDebugName(2) or name_table.getDebugName(17) or ""
    version = name_table.getDebugName(5) or ""
    print(f"Font name table: family={family!r}, subfamily={subfamily!r}, version={version!r}")

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
    cap_height = float(font["OS/2"].sCapHeight if "OS/2" in font and hasattr(font["OS/2"], "sCapHeight") else upem * 0.72)

    for idx, ch in enumerate(letters):
        gname = cmap[ord(ch)]
        glyph = glyf_set[gname]
        bpen = BoundsPen(glyf_set)
        glyph.draw(bpen)
        bounds = bpen.bounds  # (xmin, ymin, xmax, ymax)
        spen = SVGPathPen(glyf_set)
        glyph.draw(spen)
        d = spen.getCommands()
        advance = font["hmtx"][gname][0]
        glyph_items.append({
            "ch": ch,
            "d": d,
            "bounds": bounds,
            "x_offset": pen_x,
            "advance": advance,
        })
        if idx < len(letters) - 1:
            pen_x += advance + tracking

    # Compute exact ink bounding box of whole run
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
        gy = max_y - ymax  # flipped Y in SVG
        # SVG path in font coords needs scale(1, -1) & translate(-xmin, -ymax)
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

    # Optional specimen check with Pillow
    try:
        from PIL import Image, ImageDraw, ImageFont
        img = Image.new("RGB", (1400, 440), (7, 9, 20))
        draw = ImageDraw.Draw(img)
        pil_font = ImageFont.truetype(str(FONT_PATH), 200)
        draw.text((60, 110), "SETTLIV", font=pil_font, fill=(242, 240, 250))
        img.save(FONT_CHECK_PNG)
        print(f"Saved font specimen: {FONT_CHECK_PNG}")
    except Exception:
        pass

    return {
        "aspect": round(total_w / total_h, 4),
        "slots": slots,
    }


def build_intro_block(noise_uri: str, glyph_data: dict | None, is_preview: bool) -> str:
    glyph_json = json.dumps(glyph_data, separators=(",", ":")) if glyph_data else "null"
    preview_hooks = """
    var q = new URLSearchParams(location.search);
    var pSpeed = Math.min(1, Math.max(0.1, parseFloat(q.get('speed') || '1') || 1));
    var pFirst = q.get('firstframe');
    var pRepeat = q.get('repeat') === '1';
    var pReduced = q.get('reduced') === '1';
    if (pRepeat) try { sessionStorage.setItem('settliv_intro_seen', '1'); } catch (_) {}
    if (pReduced) document.documentElement.classList.add('force-reduced');
    document.documentElement.style.setProperty('--spd', String(pSpeed));
    if (pFirst !== 'never') {
      var ffMs = pFirst !== null ? parseInt(pFirst, 10) : 900;
      if (!isNaN(ffMs)) setTimeout(function () { window.dispatchEvent(new CustomEvent('flutter-first-frame')); }, ffMs);
    }
""" if is_preview else ""

    return f"""<!-- INTRO:START -->
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
    #intro {{
      position: fixed; inset: 0; height: 100dvh; z-index: 99999; overflow: hidden;
    }}
    #intro.exiting {{ pointer-events: none; }}
    .half {{
      position: absolute; left: 0; right: 0; overflow: hidden; will-change: transform;
    }}
    .half.top {{ top: 0; height: calc(50% + 1px); }}
    .half.bottom {{ top: 50%; height: 50%; }}
    .scene {{
      position: absolute; left: 0; right: 0; height: 100dvh; transform: scale(1);
    }}
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
    #intro.exiting .cut-edge {{ animation: edgeFade calc(540ms / var(--spd)) ease-out forwards; }}
    @keyframes edgeFade {{ from {{ opacity: 1; }} to {{ opacity: 0; }} }}
    #intro.exiting .half.top {{ animation: splitUp calc(540ms / var(--spd)) cubic-bezier(0.76, 0, 0.24, 1) forwards; }}
    #intro.exiting .half.bottom {{ animation: splitDown calc(540ms / var(--spd)) cubic-bezier(0.76, 0, 0.24, 1) calc(30ms / var(--spd)) forwards; }}
    @keyframes splitUp {{ to {{ transform: translate3d(0, -100%, 0); }} }}
    @keyframes splitDown {{ to {{ transform: translate3d(0, 100%, 0); }} }}

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
    .rings-bg {{
      background-image: repeating-radial-gradient(circle at 50% 50%, transparent 0 119px, rgba(190, 180, 255, 0.10) 119px 120px);
    }}
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
    @keyframes ringPulse {{
      0%, 100% {{ transform: translate(-50%, -50%) scale(1); }}
      50% {{ transform: translate(-50%, -50%) scale(1.012); }}
    }}

    /* Currents & Comet Heads */
    .line-y {{ position: absolute; top: 50%; left: 0; right: 0; height: 2px; margin-top: -1px; pointer-events: none; }}
    .curr {{ position: absolute; top: 0; width: 50%; height: 2px; opacity: 0; }}
    .curr.em {{ left: 0; background: var(--emerald); transform-origin: left center; }}
    .curr.co {{ right: 0; background: var(--coral); transform-origin: right center; }}
    .go .curr {{
      animation: currGrow calc(460ms / var(--spd)) cubic-bezier(0.55, 0, 0.2, 1) calc(100ms / var(--spd)) both, currCross calc(160ms / var(--spd)) ease-out calc(560ms / var(--spd)) forwards;
    }}
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

    .merged-line {{
      position: absolute; top: 50%; left: 0; right: 0; height: 1px; background: rgba(242, 240, 250, 0.9);
    }}
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

    /* Wordmark & Letters */
    .wm-box {{
      position: absolute; top: 50%; left: 50%; width: var(--wm-w); transform: translate(-50%, -50%);
    }}
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

    /* Counter-translated Sheen */
    .sheen-win {{
      position: absolute; inset: 0; overflow: hidden; pointer-events: none; opacity: 0;
    }}
    .sheen-band {{
      position: relative; width: 100%; height: 100%;
    }}
    .go .sheen-win {{ animation: swMove calc(280ms / var(--spd)) ease-out calc(880ms / var(--spd)) both; }}
    .go .sheen-band {{ animation: sbMove calc(280ms / var(--spd)) ease-out calc(880ms / var(--spd)) both; }}
    .hold .sheen-win {{ animation: swMove calc(280ms / var(--spd)) ease-out infinite; animation-delay: 2400ms; }}
    @keyframes swMove {{ 0% {{ opacity: 1; transform: translateX(-14%); }} 100% {{ opacity: 0; transform: translateX(100%); }} }}
    @keyframes sbMove {{ 0% {{ transform: translateX(14%); }} 100% {{ transform: translateX(-100%); }} }}

    /* Fallback text wordmark if build_intro.py hasn't injected outlines yet */
    .wm-fallback {{
      font-family: 'BricolageGrotesque', 'Sora', 'PlusJakartaSans', sans-serif;
      font-size: calc(var(--wm-w) / 5.15); font-weight: 800; line-height: 1; color: var(--ink);
      display: flex; justify-content: center; white-space: nowrap;
    }}
    .wm-fallback span {{ letter-spacing: 0.1em; }}
    .wm-fallback span:last-child {{ letter-spacing: 0; }}

    /* Repeat short & Reduced motion */
    .repeat .curr, .repeat .head, .repeat .flash, .repeat .ripple {{ display: none; }}
    .repeat.go .mover {{ animation-duration: calc(320ms / var(--spd)); animation-delay: var(--dr, 0ms); }}
    .reduced .curr, .reduced .head, .reduced .flash, .reduced .ripple, .reduced .sheen-win {{ display: none; }}
    .reduced.go .tick-ring {{ animation: none !important; opacity: 1; }}
    .reduced.go .mover, .reduced.go .tint {{ animation: none !important; transform: none; opacity: 0; }}
    .reduced.go .wm-box, .reduced.go .merged-line {{ animation: fadeIn 400ms ease-out backwards; }}
    .reduced.exiting {{ animation: fadeOut 300ms ease-out forwards; }}
    .reduced.exiting .half {{ animation: none !important; }}
    @keyframes fadeOut {{ to {{ opacity: 0; }} }}
    @media (prefers-reduced-motion: reduce) {{
      .tick-ring, .mover, .tint, .curr, .head, .flash, .ripple, .sheen-win {{ animation: none !important; }}
    }}
  </style>

  <script>
    (function () {{
      if (window.__settlivSettleInit) return;
      window.__settlivSettleInit = true;
      try {{
        if ('serviceWorker' in navigator) {{
          navigator.serviceWorker.getRegistrations().then(function (r) {{
            for (var i = 0; i < r.length; i++) r[i].unregister();
          }});
        }}
        {preview_hooks}
        var GLYPHS = {glyph_json};
        var t0 = performance.now(), ff = false, done = false;
        var seen = false;
        try {{ seen = sessionStorage.getItem('settliv_intro_seen') === '1'; }} catch (_) {{}}
        var reduced = (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) ||
                      document.documentElement.classList.contains('force-reduced');

        function wordmarkMarkup(isTop) {{
          if (!GLYPHS) {{
            var chs = ['S','E','T','T','L','I','V'];
            var spans = chs.map(function (c, i) {{
              return '<span class="mover" style="--sy:' + (i%2===0?'-115%':'115%') + ';--d:' + (560+Math.abs(i-3)*45) + 'ms;--dr:' + (Math.abs(i-3)*25) + 'ms">' + c + '</span>';
            }}).join('');
            return '<div class="wm-box"><div class="wm-fallback" ' + (isTop ? 'role="img" aria-label="SETTLIV"' : 'aria-hidden="true"') + '>' + spans + '</div></div>';
          }}
          var slotsHtml = GLYPHS.slots.map(function (s, i) {{
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

        function removeNow() {{
          if (done) return;
          done = true;
          var el = document.getElementById('intro');
          if (el && el.parentNode) el.parentNode.removeChild(el);
          if (document.body) document.body.classList.remove('intro-lock');
          try {{ sessionStorage.setItem('settliv_intro_seen', '1'); }} catch (_) {{}}
          window.dispatchEvent(new CustomEvent('settliv-intro-reveal'));
          window.dispatchEvent(new CustomEvent('settliv-intro-done'));
        }}

        function startExit(ms) {{
          if (done) return;
          done = true;
          var el = document.getElementById('intro');
          if (!el) {{ removeNow(); return; }}
          window.dispatchEvent(new CustomEvent('settliv-intro-reveal'));
          el.classList.add('exiting');
          try {{ sessionStorage.setItem('settliv_intro_seen', '1'); }} catch (_) {{}}
          setTimeout(function () {{
            if (el.parentNode) el.parentNode.removeChild(el);
            if (document.body) document.body.classList.remove('intro-lock');
            window.dispatchEvent(new CustomEvent('settliv-intro-done'));
          }}, ms);
        }}

        function tryExit() {{
          if (!ff || done) return;
          var elapsed = performance.now() - t0;
          if (reduced) {{ startExit(300); return; }}
          if (seen) {{
            if (elapsed <= 250) {{ removeNow(); return; }}
            setTimeout(function () {{ startExit(420); }}, Math.max(0, 320 - elapsed));
            return;
          }}
          setTimeout(function () {{ startExit(570); }}, Math.max(0, 1180 - elapsed));
        }}

        window.addEventListener('pageshow', function (e) {{ if (e.persisted) removeNow(); }});

        window.addEventListener('DOMContentLoaded', function () {{
          if (document.hidden) {{ removeNow(); return; }}
          var el = document.getElementById('intro');
          if (!el) return;
          document.body.classList.add('intro-lock');
          el.innerHTML =
            '<div class="half top">' + buildScene(true) + '<div class="cut-edge" aria-hidden="true"></div></div>' +
            '<div class="half bottom">' + buildScene(false) + '<div class="cut-edge" aria-hidden="true"></div></div>';
          if (seen) el.classList.add('repeat');
          if (reduced) el.classList.add('reduced');
          requestAnimationFrame(function () {{
            el.classList.add('go');
            tryExit();
          }});
          if (MutationObserver) {{
            var mo = new MutationObserver(function () {{
              if (document.querySelector('flt-glass-pane, flutter-view')) {{
                mo.disconnect();
                ff = true;
                tryExit();
              }}
            }});
            mo.observe(document.body, {{ childList: true, subtree: true }});
          }}
        }});

        window.addEventListener('flutter-first-frame', function () {{ ff = true; tryExit(); }});
        setTimeout(function () {{ if (!done) startExit(570); }}, 15000);
      }} catch (_) {{
        var el = document.getElementById('intro');
        if (el && el.parentNode) el.parentNode.removeChild(el);
        if (document.body) document.body.classList.remove('intro-lock');
        window.dispatchEvent(new CustomEvent('settliv-intro-reveal'));
        window.dispatchEvent(new CustomEvent('settliv-intro-done'));
      }}
    }})();
  </script>
  <!-- INTRO:END -->"""


def main():
    noise_uri = make_noise_png_data_uri()
    glyph_data = extract_glyphs()
    block = build_intro_block(noise_uri, glyph_data, is_preview=False)

    html = INDEX_HTML.read_text(encoding="utf-8")
    start_marker = "<!-- INTRO:START -->"
    end_marker = "<!-- INTRO:END -->"
    if start_marker in html and end_marker in html:
        pre = html[: html.index(start_marker)]
        post = html[html.index(end_marker) + len(end_marker) :]
        INDEX_HTML.write_text(pre + block + post, encoding="utf-8")
        print(f"Updated {INDEX_HTML}")
    else:
        print("Markers not found in web/index.html")

    PREVIEW_HTML.parent.mkdir(parents=True, exist_ok=True)
    preview_block = build_intro_block(noise_uri, glyph_data, is_preview=True)
    preview_doc = f"""<!DOCTYPE html>
<html style="background:#070914">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <title>Settliv Intro Preview</title>
  {preview_block}
</head>
<body>
  <div id="intro" role="presentation"></div>
  <main style="min-height:100dvh;display:flex;align-items:center;justify-content:center;color:#F2F0FA;font-family:sans-serif">App Revealed</main>
</body>
</html>
"""
    PREVIEW_HTML.write_text(preview_doc, encoding="utf-8")
    print(f"Wrote {PREVIEW_HTML}")


if __name__ == "__main__":
    main()
