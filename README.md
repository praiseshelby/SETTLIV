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

## Supabase Setup

1. **Create project**: Create a project on the Supabase Free plan in the **South Asia (Mumbai)** region.
2. **Keys**: Copy the **Project URL** and **Publishable Key** from **Project Settings → API** into `lib/supabase_config.dart`. Never put the `service_role` secret key in Flutter.
3. **Google OAuth**: Enable Google under **Authentication → Providers → Google**, and add your local/production origins (e.g. `http://localhost:3000/`) to **Authentication → URL Configuration → Redirect URLs**.
4. **Email confirmation & SMTP**: Email accounts retain Supabase confirmation. Note that Supabase's default email sender is restricted to project-team emails; handle `email_address_not_authorized` or configure custom SMTP later if needed.
5. **SQL Migration & RLS**: Run `supabase/migrations/202611260001_profiles.sql` and `supabase/migrations/202611260002_ledger_schema.sql` in the **Supabase SQL Editor**. Every table enforces owner-only Row Level Security (`auth.uid() = user_id`).
6. **Edge Function (deploy later)**: Set `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` in Edge Function secrets, then deploy `supabase/functions/account-actions`. Self-service account deletion and username registration require this Edge Function to be deployed.
7. **Dashboard Inspection**: View users in **Authentication → Users**, ledger rows in **Table Editor**, and Edge Function logs in **Edge Functions → Logs**.
