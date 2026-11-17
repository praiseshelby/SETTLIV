# Settliv Deployment Guide

### Option 1: Local Preview (Zero Setup)
Serve the pre-built Flutter Web production bundle:
```bash
python3 -m http.server 3000 --directory build/web --bind 0.0.0.0
```
Open [http://localhost:3000](http://localhost:3000) in any modern browser.

### Option 2: Replit Instant Host
1. Create a new Replit and select the **Python** or **Blank** template.
2. Upload this repository (or just `build/web/` and `.replit`).
3. Click **Run**.
4. Replit starts Python's web server on port 3000 and provides a public HTTPS URL.
*(Note: Built with `--base-href /` for standard root URL hosting).*

### Option 3: Rebuilding from Source
```bash
flutter build web --release --base-href /
```
Output artifacts are saved in `build/web/`.
