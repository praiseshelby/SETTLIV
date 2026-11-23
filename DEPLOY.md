# Settliv — Deployment Guide

## 1. Build

```bash
flutter build web --release --no-web-resources-cdn
```

Output is in `build/web/`.

## 2. Deploy to Vercel

```bash
cp vercel.json build/web/
cd build/web
npx vercel --prod --yes
```

> The `vercel.json` configures SPA routing (all paths → `index.html`) with correct MIME types for Flutter web assets.

## 3. Local Preview

```bash
# After building:
python3 -m http.server 8080 --directory build/web
# Open http://localhost:8080
```

> **Screen lock (WebAuthn)** requires HTTPS or `localhost`. It is **not available** on plain HTTP deployments.

## 4. Environment Notes

| Requirement | Value |
|---|---|
| Flutter SDK | stable (3.x+) |
| Dart | 3.x |
| Renderer | HTML (default for web) |
| Packages | No native plugins; all packages work on web |

## 5. What Gets Deployed

- Full Flutter web bundle (JS + assets)
- Branded loading screen in `index.html`
- Favicon + manifest from `web/`
- No server-side logic; fully client-side

## 6. Routing

All routes are client-side via GoRouter. The `vercel.json` rewrites all requests to `index.html`. Deep links like `/settings?section=experience` and `/insights/budgets` work correctly on both initial load and navigation.

## 7. Known Deployment Considerations

- **WebAuthn / Screen Lock**: Works on `localhost` and HTTPS only. Disabled automatically on HTTP origins.
- **SharedPreferences**: Browser `localStorage` on web. Cleared when the user clears site data.
- **Feedback email**: Uses `mailto:` — requires the user's default mail client. No SMTP server.
