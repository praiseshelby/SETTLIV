# Settliv — Calm, India-First Expense Splitting Prototype

A production-grade Flutter Web prototype for flatmates and trips with instant UPI settlement simulation.
- **Run locally**: `flutter run -d chrome` or serve release: `python3 -m http.server 3000 --directory build/web`
- **Run tests**: `flutter test` | **Analyze**: `flutter analyze`
- **Architecture**:
  - `lib/core/`: Design tokens (navy, emerald, coral, saffron), Manrope typography, custom widgets (`PhoneFrame`, `MoneyText`, `GroupCoverArt`).
  - `lib/data/`: Pure `BalanceEngine`, integer-paise math, immutable models, seed data (+₹1,240 Flatmates, -₹380 Goa Trip).
  - `lib/features/`: `home/` (summary card, groups, activity), `add_expense/` (rule-based NLP parser + manual), `group_detail/` (charts, simulated UPI settle sheet, expense detail).
  - `lib/routes/`: Declarative GoRouter routing (`/`, `/add`, `/group/:id`, `/gallery`).
