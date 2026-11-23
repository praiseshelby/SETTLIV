import os
import time
from playwright.sync_api import sync_playwright

ARTIFACT_DIR = r"C:\Users\shelb\.gemini\antigravity\brain\7659ce50-0cf1-403f-8370-388e0ace120b"
EDGE_PATH = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch(
            executable_path=EDGE_PATH,
            headless=True
        )

        # 1. Loading screen frames (load index.html directly or intercept flutter_bootstrap to capture pure loader)
        context_loader = browser.new_context(
            viewport={"width": 1440, "height": 900},
            color_scheme="light"
        )
        page_loader = context_loader.new_page()
        # Route abort for flutter_bootstrap.js to keep loading screen frozen
        page_loader.route("**/flutter_bootstrap.js", lambda route: route.abort())
        page_loader.goto("http://localhost:3000/")
        time.sleep(0.5)
        page_loader.screenshot(path=os.path.join(ARTIFACT_DIR, "x2_loading_frame1.png"))
        print("Captured x2_loading_frame1.png")
        time.sleep(1.0)
        page_loader.screenshot(path=os.path.join(ARTIFACT_DIR, "x2_loading_frame2.png"))
        print("Captured x2_loading_frame2.png")
        context_loader.close()

        # 2. Light Theme: Dashboard 1440x900
        context_light = browser.new_context(
            viewport={"width": 1440, "height": 900},
            color_scheme="light",
            device_scale_factor=1.0,
        )
        page_light = context_light.new_page()
        page_light.goto("http://localhost:3000/#/")
        time.sleep(2)
        page_light.evaluate("""() => {
            localStorage.setItem('flutter.settliv_theme_mode', '"light"');
            localStorage.setItem('settliv_has_visited_compatibility', 'true');
        }""")
        page_light.reload()
        time.sleep(3.5)
        page_light.screenshot(path=os.path.join(ARTIFACT_DIR, "x2_desktop_dashboard_light.png"))
        print("Captured x2_desktop_dashboard_light.png")

        # 3. Add Expense Dialog 1440x900
        page_light.goto("http://localhost:3000/#/add")
        time.sleep(3.0)
        page_light.screenshot(path=os.path.join(ARTIFACT_DIR, "x2_desktop_add_dialog.png"))
        print("Captured x2_desktop_add_dialog.png")

        # 4. Settings > Experience 1440x900
        page_light.goto("http://localhost:3000/#/settings")
        time.sleep(3.0)
        page_light.screenshot(path=os.path.join(ARTIFACT_DIR, "x2_desktop_settings_experience.png"))
        print("Captured x2_desktop_settings_experience.png")
        context_light.close()

        # 5. Dark Theme: Dashboard 1440x900
        context_dark = browser.new_context(
            viewport={"width": 1440, "height": 900},
            color_scheme="dark",
            device_scale_factor=1.0,
        )
        page_dark = context_dark.new_page()
        page_dark.goto("http://localhost:3000/#/")
        time.sleep(2)
        page_dark.evaluate("""() => {
            localStorage.setItem('flutter.settliv_theme_mode', '"dark"');
            localStorage.setItem('settliv_has_visited_compatibility', 'true');
        }""")
        page_dark.reload()
        time.sleep(3.5)
        page_dark.screenshot(path=os.path.join(ARTIFACT_DIR, "x2_desktop_dashboard_dark.png"))
        print("Captured x2_desktop_dashboard_dark.png")
        context_dark.close()

        browser.close()
        print("ALL SCREENSHOTS CAPTURED SUCCESSFULLY")

if __name__ == "__main__":
    run()
