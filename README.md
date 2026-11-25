# Settliv — Calm, India-First Expense Splitting Prototype

A production-grade Flutter Web prototype for flatmates and trips with instant UPI settlement simulation.

## Features

- **Expense splitting** with exact-paise math and balance engine
- **Group ledger** (Flatmates, trips, personal)
- **Insights** — spending calendar, category donut, month recap, savings goals, upcoming recurring
- **Compatibility preview** — experience Web (PC / mobile) or App layout from one link
- **Screen lock** — WebAuthn device authentication (requires HTTPS or localhost)
- **Help & Feedback** — local report queue, email via mailto
- **Dark mode** — full token-driven theme (Manrope, Plus Jakarta Sans, Sora & Bricolage typography)
- **Settle Orbit splash & layout transition** — viewport-scaled CSS + Flutter handoff splash and choreographed App ↔ Web preview transition

## Running Locally

```bash
flutter run -d chrome
```

Or serve the release build:

```bash
flutter build web --release --no-web-resources-cdn --pwa-strategy=none
python3 -m http.server 3000 --directory build/web
# Open http://localhost:3000
```

> **Note:** Screen lock (WebAuthn) requires a secure context. Use `localhost` or HTTPS.

## Running Tests

```bash
flutter test          # all tests
flutter analyze       # static analysis (must be 0 issues)
```

## Building & Deploying

```bash
flutter build web --release --no-web-resources-cdn --pwa-strategy=none
cp vercel.json build/web/
cd build/web
npx vercel --prod --yes
```

## Architecture

- `lib/core/` — Design tokens, Manrope/Bricolage typography, `PhoneFrame`, `AnimatedSection`, `SettlivLogomark`, `AdaptivePresenter`, `DeviceAuth`
- `lib/data/` — `BalanceEngine`, integer-paise math, immutable models, `SavingsGoal`, `FeedbackReport`, seed data
- `lib/features/` — `home/`, `add_expense/`, `group_detail/`, `insights/`, `plan/`, `settings/`, `records/`, `split_calculator/`
- `lib/routes/` — Declarative GoRouter; deep links: `/settings?section=experience`, `/insights/budgets`

## Compatibility Preview

Settliv includes a **Compatibility Preview** mode (Settings → Experience). It lets you view the PC website, mobile web, and mobile app layouts from one link. In the shipped product each device type gets only its native layout — this switch is for demonstration only.

Entry points:
- Sidebar footer card (expanded Web desktop)
- Icon-only tooltip on medium icon rail
- Compact Web menu drawer
- Phone-frame hint text (App on PC)
- First-visit card ("View layouts")
- Settings → Experience section

## Known Limitations

See [NOTES.md](NOTES.md) for the full QA findings and known limitations.
