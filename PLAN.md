# Settliv Build Plan

## Architecture & Directory Structure
```
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_typography.dart
│   │   ├── app_theme.dart
│   │   └── theme_provider.dart
│   ├── utils/
│   │   ├── currency_formatter.dart
│   │   └── date_formatter.dart
│   └── widgets/
│       ├── phone_frame.dart
│       ├── coming_soon_sheet.dart
│       ├── coming_soon_tag.dart
│       ├── money_text.dart
│       ├── primary_button.dart
│       ├── secondary_button.dart
│       ├── text_action_button.dart
│       ├── balance_hero_card.dart
│       ├── balance_pill.dart
│       ├── person_avatar.dart
│       ├── avatar_stack.dart
│       ├── group_cover_art.dart
│       ├── group_card.dart
│       ├── expense_tile.dart
│       ├── category_badge.dart
│       ├── member_chip.dart
│       ├── segmented_tabs.dart
│       ├── section_header.dart
│       ├── sheet_scaffold.dart
│       ├── empty_state.dart
│       ├── undo_snackbar.dart
│       └── floating_add_button.dart
├── data/
│   ├── models/
│   │   ├── person.dart
│   │   ├── group.dart
│   │   ├── expense.dart
│   │   ├── settlement.dart
│   │   └── split_breakdown.dart
│   ├── engine/
│   │   └── balance_engine.dart
│   ├── seed/
│   │   └── seed_data.dart
│   └── repositories/
│       ├── app_repository.dart
│       └── in_memory_app_repository.dart
├── features/
│   ├── home/
│   │   └── presentation/
│   │       ├── home_screen.dart
│   │       └── widgets/
│   │           ├── quick_add_bar.dart
│   │           └── user_profile_sheet.dart
│   ├── add_expense/
│   │   ├── logic/
│   │   │   └── quick_expense_parser.dart
│   │   └── presentation/
│   │       ├── add_expense_screen.dart
│   │       ├── quick_add_tab.dart
│   │       └── manual_add_tab.dart
│   ├── group_detail/
│   │   └── presentation/
│   │       ├── group_detail_screen.dart
│   │       ├── widgets/
│   │       │   ├── group_expenses_tab.dart
│   │       │   ├── group_balances_tab.dart
│   │       │   ├── balance_bars_chart.dart
│   │       │   └── category_donut_chart.dart
│   │       └── sheets/
│   │           ├── settle_sheet.dart
│   │           └── expense_detail_sheet.dart
│   └── gallery/
│       └── component_gallery_screen.dart
├── routes/
│   └── app_router.dart
└── main.dart
```

---

## Part 1: Foundation + Design System + Data
- [x] 1. Project setup: clean pubspec.yaml with only `flutter_riverpod`, `go_router`, `intl`.
- [x] 2. Core tokens: `AppColors` (light & dark palettes, tints, gradients), `AppTypography` (Indian money formatting, weights), `AppTheme` (theme data, radiuses, shadows).
- [x] 3. Responsive `PhoneFrame`: 390x844 centered on desktop (>600px) with bezel, radial wash background, Settliv wordmark; full screen on mobile.
- [x] 4. Immutable data models: `Person`, `Group`, `Expense`, `Settlement`, `SplitMode`, `Category`.
- [x] 5. Pure `BalanceEngine`: calculates net balances per group, total balance for user, and debt-simplification matrix ("who pays whom"). All in integer paise.
- [x] 6. Indian realistic seed data: Arjun, Flatmates ("You are owed ₹1,240"), Goa Trip ("You owe ₹380"), 25 realistic expenses.
- [x] 7. Unit tests for `BalanceEngine` & seed: proving exact balance amounts and zero-sum per group.
- [x] 8. Core Component Library:
  - `MoneyText` (tabular, Indian grouping, sign, color roles)
  - `BalanceHeroCard` (navy mesh, count-up, emerald/coral chips)
  - `BalancePill` (owed, owe, settled)
  - `PersonAvatar` & `AvatarStack` (8 deterministic duotone gradients, initials)
  - `GroupCoverArt` (CustomPainter for Flatmates and Goa Trip)
  - `GroupCard` (cover art, name, members, pill)
  - `ExpenseTile` (CategoryBadge, title, payer, share)
  - `CategoryBadge` (8 categories with tints and icons)
  - `MemberChip`, `SegmentedTabs`, `PrimaryButton`, `SecondaryButton`, `TextActionButton`
  - `SheetScaffold`, `EmptyState`, `ComingSoonTag`, `SectionHeader`, `UndoSnackbar`, `FloatingAddButton`
- [x] 9. Hidden `/gallery` screen demonstrating all components in Light and Dark modes.
- [x] 10. `GoRouter` setup with routes `/`, `/add`, `/group/:id`, and `/gallery`.
- [x] 11. Run `flutter analyze` & `flutter test` with zero issues; verified release build.

---

## Part 2: Screen 1 (Home) + Screen 2 (Add Expense) + Sheets
- [x] 1. Rule-based `QuickExpenseParser` (pure Dart, amount, people, category, group inference) with unit tests for 11 phrases.
- [x] 2. Screen 1: Home (`/`)
  - Time-based greeting ("Good morning/evening, Arjun") + quiet avatar profile trigger.
  - Profile sheet with live Light/Dark/System theme switcher & Coming Soon tag.
  - `BalanceHeroCard` with animated balance count-up & net stats.
  - Quick-add bar with placeholder & suggestion chips navigating to `/add`.
  - "Your groups" section with `GroupCard`s linking to `/group/:id`.
  - "Recent activity" section grouped by day labels (Today, Yesterday, Date), latest 8 expenses.
  - Staggered entry animation & floating Add button.
- [x] 3. Screen 2: Add Expense (`/add` full-screen modal slide up)
  - SegmentedTabs: Quick | Manual.
  - Quick tab: multiline input, live `DraftCard`, one-tap confirm, "Edit details" prefill button.
  - Manual tab: Giant `AmountField` (₹ prefix, 44/800, live Indian grouping), description, category chip row, group selector, date picker sheet, paid-by sheet, dynamic member split chips, Equal / Exact / Percent split modes with live remainder validation.
  - Morphing emerald save button, automatic Home hero count-up, highlight animation, `UndoSnackbar`.
- [x] 4. Expense Detail Sheet:
  - Triggered from any `ExpenseTile`.
  - Shows breakdown of shares, payer, category, and date.
  - Soft Delete action with `UndoSnackbar`, and Edit action reopening `/add`.
- [x] 5. Run `flutter analyze` & `flutter test` with zero issues; verified in phone frame.

---

## Part 3: Screen 3 (Group Detail) + Simulated UPI Settle + Polish & Deploy
- [x] 1. Screen 3: Group Detail (`/group/:id`)
  - Collapsing header with `GroupCoverArt` hero transition, group name, member `AvatarStack`, and type pill.
  - User balance pill for this group.
  - Trip progress bar ("Day 3 of 5 · Goa Trip" with saffron-to-coral indicator).
  - SegmentedTabs: Expenses / Balances.
  - Sticky "Settle up" button + Floating Add button.
  - Expenses tab: day-grouped `ExpenseTile`s with empty state.
  - Balances tab: "Who pays whom" simplified rows with Settle/Nudge actions, animated custom horizontal balance bars, and custom Spend by Category donut chart with legend.
- [x] 2. Simulated UPI Settle Sheet:
  - Step 1: Amount & payee, suggested settlement amount, UPI / Cash option.
  - Step 2: Monogram UPI app picker (GPay, PhonePe, Paytm, BHIM, Other), note preview, Copy UPI ID.
  - Step 3: Simulation step (~900ms progress ring).
  - Step 4: Confirmation, "Mark paid", emerald check ring + confetti celebration (<1.2s), balance updates, `UndoSnackbar`.
- [x] 3. Global Polish:
  - Responsive audit at 360, 390, 430px widths & desktop.
  - Contrast, tap targets >= 48px, Semantics labels, Indian currency formatting.
  - Zero overflow, zero console warnings.
- [x] 4. Deployment Files:
  - Ready-to-serve release build in `build/web`.
  - `.replit`, `DEPLOY.md`, `README.md`.
- [x] 5. Final verification: `flutter analyze` 0 issues, all tests pass, build succeeds.
