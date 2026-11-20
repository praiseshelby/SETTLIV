import os
import time
from playwright.sync_api import sync_playwright

VIEWPORTS = [
    {"name": "390x844", "width": 390, "height": 844},
    {"name": "360x640", "width": 360, "height": 640},
]

THEMES = ["light", "dark"]

ROUTES = [
    {"name": "home", "path": "/#/"},
    {"name": "records", "path": "/#/records"},
    {"name": "insights", "path": "/#/insights"},
    {"name": "plan", "path": "/#/plan"},
    {"name": "balances", "path": "/#/balances"},
    {"name": "groups", "path": "/#/groups"},
    {"name": "gallery", "path": "/#/gallery"},
    {"name": "add", "path": "/#/add"},
]

OUTPUT_DIR = r"C:\Users\shelb\Downloads\SETTLIV-X\screenshots"
os.makedirs(OUTPUT_DIR, exist_ok=True)

EDGE_PATH = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch(
            executable_path=EDGE_PATH,
            headless=True
        )

        for vp in VIEWPORTS:
            for theme in THEMES:
                context = browser.new_context(
                    viewport={"width": vp["width"], "height": vp["height"]},
                    color_scheme=theme,
                    device_scale_factor=1.0,
                )
                page = context.new_page()

                # Prime local storage theme if needed
                page.goto(f"http://localhost:3000/#/")
                time.sleep(2)
                page.evaluate(f"""() => {{
                    localStorage.setItem('flutter.settliv_theme_mode', '"{theme}"');
                }}""")
                page.reload()
                time.sleep(2.5)

                for route in ROUTES:
                    url = f"http://localhost:3000{route['path']}"
                    page.goto(url)
                    # wait for flutter rendering & animations to settle
                    time.sleep(1.8)

                    filename = f"{route['name']}_{vp['name']}_{theme}.png"
                    filepath = os.path.join(OUTPUT_DIR, filename)
                    page.screenshot(path=filepath)
                    print(f"Captured: {filename}")

                context.close()

        browser.close()

if __name__ == "__main__":
    run()
