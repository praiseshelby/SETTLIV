# Settliv v0 - Functional Correctness Plan & Progress

## Part 1: Foundation and Audit
- [x] **1a. Integer Paise & Single-Source-of-Truth Ledger**:
  - Implemented `SplitCalculator` with exact integer paise distribution.
  - Leftover paise distributed deterministically to payer first (if participating), then in member order.
  - Balances derived dynamically from active expenses and settlement records.
  - Settlements are separate ledger records, ensuring expense undo/delete operations never corrupt balances.
  - Verified home totals invariant: `netBalance == totalOwedToUser - totalUserOwes`.
- [x] **1b. Seed Data Audit & Fix**:
  - Investigated Goa Trip "Mopa airport cab ₹4,000" showing "You lent ₹3,100": found `exp_goa_11` had `splitMode: exact` with uneven shares (Arjun ₹900, Nisha ₹1000, Rohan ₹1050, Tara ₹1050).
  - Fixed `exp_goa_11` to `splitMode: equal` with ₹1,000 per person (4-way split), so Arjun lent ₹3,000.
  - Balanced `exp_goa_7` ("Beach shack brunch") from ₹1,880 to ₹1,480 (equal split ₹370 each) so Arjun's net balance remains exactly -₹380, Flatmates remains +₹1,240, and overall net remains +₹860.
  - Verified all 25 seeded expenses' shares sum exactly to their respective totals.
- [x] **1c. AvatarStack & PersonAvatar**:
  - Centered initials inside `FittedBox` with comfortable padding so initials never clip.
  - Default size set to 28px with a 2px surface-colour ring (`theme.surface`) and 8px overlap.
  - Added "+N" chip at the end with surface border for remaining members.
- [x] **1d. Rules 7 & 8 App-Wide**:
  - Rule 7: Implemented `SettlivScrollBehavior` on `MaterialApp.router` returning unadorned child for scrollbars (hides on mobile, web, desktop) and no overscroll glow, while preserving mouse drag, trackpad, wheel, and touch scrolling.
  - Rule 8: Performance optimizations: max 2 `BackdropFilter` instances on screen, none in list items or scrolling rows; static `GroupCoverArt` wrapped in `RepaintBoundary` with `shouldRepaint=false`; `AuroraBackground` respects `disableAnimations`.
- [x] **1e. Group Detail Header Cleanup**:
  - Removed "· Goa Trip" from the "Day 3 of 5" line.
  - Removed the duplicate member count text next to the balance pill.
  - Replaced dotted capsule chips with a clean row of two text+icon actions: "Nudge" (functional, opens `NudgeSheet` and copies reminder message to clipboard) and "Settle up" (functional, opens `SettleSheet`).
  - Added `showGroupName: false` in `ExpenseTile` within the group's own expense list to eliminate duplicate group labels.
- [x] **1f. Comprehensive Unit Tests**:
  - `test/foundation_test.dart` added covering:
    - Currency formatting (Indian grouping, hiding `.00`, negative signs, number-to-words for lakhs and crores).
    - Amount parsing (`k`, `lakh`/`lac`/`L`, `cr`/`crore`, commas, decimals, error cases).
    - Split distribution (3-way split of ₹100 giving 3334 to payer and 3333 to others; remainder order; 4-way cab split; percent split with remainder).
    - Group balance derivation and invariants (sum of group balances == 0, home total invariant).
    - Settlement transactions updating balances and undoing correctly.
    - Soft-delete and undo restoring exact ledger state.
  - Verification: `flutter analyze` passed with 0 issues; all 39 tests passed.

---

## Part 2: Add Expense, Fully Correct
- [x] **2a. Quick Tab Overhaul**:
  - Removed static placeholder, "Try one of these" heading/chips, yellow hint box, and info box.
  - Added cycling placeholder with 5 realistic examples ("dinner 800 with Meera and Kabir", "cab 240 with Kabir", "groceries 1,250", "rent 18,000", "movie 600 split 4") with smooth fade+slide every 3.5s; pauses on focus, typing, and `MediaQuery.disableAnimations`.
  - Added "Use this" button on the composer card to fill the active example.
  - Live parse preview under the field with clean small text rows (amount, people, category, group); hides unrecognised parts.
  - Primary button is neutral/disabled until input is valid (no red idle text).
  - Draft card with "Confirm" and "Edit details in Manual" tab.
- [x] **2b. Suggestion Threshold Logic**:
  - Created `RepeatSuggestionEngine`: "Repeat" row appears on Quick tab ONLY for descriptions logged 3+ times in the same group (normalized description).
  - Seed data verified to have 0 repeated titles meeting the threshold (unit tested).
  - Tapping repeat suggestion prefills composer and group.
  - Removed Home screen static chips entirely.
- [x] **2c. Manual Tab Validation**:
  - Amount rules applied: digits and 1 decimal only, max 2 decimals, live Indian grouping, numeric keyboard, rejecting zero/negative.
  - Hard block above ₹10,00,00,000 with clear message.
  - Large amount confirmation dialog for amounts >= ₹1,00,000 showing amount in digits and words ("₹10,00,000 · Ten lakh") with "Edit amount" and "Yes, add it".
  - Description required (trimmed, max 60 chars), category default Other, at least one participant, payer required, date not in future.
  - Exact split validates sum matches total paise; percent split compares in basis points (10,000 bp = 100.00%) with live remaining/over indicators.
  - Save disabled until valid with neutral helper text.
- [x] **2d. Duplicate Guard**:
  - Checks if an expense with same title, amount, and group was logged within 2 minutes.
  - Shows confirmation dialog: "Looks like a duplicate. Add anyway?".
- [x] **2e. Expense Detail Sheet**:
  - Correct shares breakdown; Edit reopens prefilled into Manual tab; soft Delete with 5-second Undo snackbar restoring exact ledger balances.
- [x] **2f. Vertical Balance & Keyboard Handling**:
  - Comfortable composer card height; primary button sits above keyboard; `PopScope` guard asks "Discard changes?" before leaving with unsaved work.
- [x] **2g. Tests for Part 2**:
  - Added `test/add_expense_part2_test.dart` (parser edge cases: k, lakh, cr, commas, decimals, ambiguous, cap, unknown people, manual split validation, duplicate guard, repeat threshold).
  - Verified: `flutter analyze` 0 issues, all 53 tests passed.

---

## Part 3: Floating Bar, New Screens, Settle Flow, Final QA
- [x] **3a. Floating Bottom Bar**:
  - Implemented pill-shaped floating bar (~64px tall, 16px side margins, frosted glass with hairline border, inside phone frame on desktop).
  - Slots: Home, Groups, [+], Activity, You.
  - Active item shows icon + short label with a soft pill; center 52px Sapphire-gradient circle sits proud, scales to 0.94 on press, and opens Add Expense.
  - "You" slot opens existing profile sheet without changing selected tab.
  - Bar hides on `/add`, `/group/:id`, and when the keyboard is open.
  - All scrollable views padded by 120px at bottom so no content is obscured.
- [x] **3b. Home Screen Polish**:
  - Removed "Add an expense" card and example chips.
  - Final section order: greeting -> (32px) -> hero balance -> (32px) -> groups -> (32px) -> recent activity.
  - Handled empty/one-group/zero-balance states ("All settled up").
- [x] **3c. Groups Screen & In-Memory New Group**:
  - Displays list of groups with cover art, member avatars (`AvatarStack`), and balance indicators.
  - Dynamic in-memory "New group" creation with unique name validation, trip/home/other type selector, min 2 members, and duplicate member name detection.
- [x] **3d. Activity Screen**:
  - Chronological list of all expenses across groups grouped by date header.
  - Live search by description or payer name, with "All groups" and per-group filter chips.
  - Reuses `ExpenseTile` and `ExpenseDetailSheet` with full edit and 5-second soft delete with Undo.
- [x] **3e. Settle Flow Polish**:
  - Amount validated: cannot be ₹0, cannot exceed amount owed, partial settle allowed (min ₹1, paise handled).
  - Prominent "Simulated in prototype" badge on UPI picker.
  - "Did you pay ₹X to NAME?" confirmation step with double-tap guard (`_isSubmitting`).
  - "Mark as cash" records settlement; Undo restores exact balances; instant ledger and donut chart reactivity.
- [x] **3f. Nudge Sheet**:
  - Functional reminder copying to clipboard with debtor name and formatted amount.
- [x] **3g. Final QA Pass**:
  - Responsive verification across 320x568, 360x640, 390x844, and desktop frame with text scale 1.3 in light and dark modes.
  - Tested edge cases: 0, 0.5, 1e18, pasted junk, 3-way ₹100 splits, rapid double taps, back button during sheets.
  - Fixed `GroupCard` and `FloatingNavBar` layout constraints for small screens.
  - Comprehensive report and honest list of known limitations documented in `NOTES.md`.
  - Rebuilt release web build and verified all 67 tests passing.

---

## Task 2: Design System, Core Rebuild & Ledger Features

### Part 1: Theme, Shell, Data Layer, Settings (COMPLETED)
- [x] **A) Theme Rebuild & Design System Tokens**:
  - Implemented quiet, premium fintech design system (Linear / Revolut / Cash App).
  - Defined unified `SettlivThemeExtension` with strict Light and Dark tokens:
    - Light: canvas `#F5F3EE`, surface `#FFFFFF`, hairline `#E7E3DA`, ink `#121826`, muted ink AA-safe (`#5B6272`), anchor Navy `#0E1A3A`, Emerald `#0FA37F`, Coral `#EF5B48`, text-safe semantic shades (`#0A6E55` and `#BD3222`).
    - Dark: canvas `#0B1020`, surface `#131A2E`, raised `#1A2340`, hairline `#26304D`, text `#ECEAE4`, muted `#A3A9BA`, primary button off-white with Navy text, lighter mesh and contrast-safe semantic text tokens.
  - Type tokens in `AppTypography`: Manrope, tabular figures for all money texts, screen titles 22/700, body 15/500, captions 12/600.
  - Zero raw `Color(0x...)` or `Colors.*` outside `lib/core/theme/` (enforced and verified by unit test `test/theme_token_scan_test.dart`).
  - Unit test `test/wcag_contrast_test.dart` verifies all text/surface pairs achieve WCAG AA contrast (>= 4.5:1 body, >= 3:1 large).
  - All custom painters (cover art, charts, hero mesh, split bar) take colors via constructor and compare dynamically in `shouldRepaint`.
  - Dynamic live OS brightness detection and ThemeMode persistence (Light / Dark / System).
  - Updated `/gallery` component gallery displaying side-by-side components in both themes.
  - Updated prototype note text: "v0 prototype with local demo data. More screens and online features come in the full app."

- [x] **B) Navigation Shell**:
  - Implemented `DockedNavBar` via `StatefulShellRoute` with 4 main tabs: Home, Groups, Records, Insights.
  - DOCKED full-width bar with 28px top corners, top hairline, blur BackdropFilter layer, upward diffused shadow, safe-area aware, hidden when keyboard is open.
  - 5 equal slots: Home, Groups, [+], Records, Insights with active 3x18 sliding indicator line and bold label.
  - Center + button: 52x52 rounded square (radius 18), Navy in light / off-white in dark, raised 14px above the bar with 4px canvas ring, crisp icon, 0.94 scale press animation, opens Add Expense.
  - All pushed routes (`/add`, `/group/:id`, `/settings`, `/gallery`, modal sheets) use root navigator so the docked bar never overlays or is overlaid.
  - Verified by `test/shell_routing_test.dart`.

- [x] **C) Profile & Settings Screen**:
  - Full-screen route (`/settings`) opened by Home avatar with back button and no docked nav bar.
  - Profile card with editable name, own UPI ID with validation (`name@handle`), showing "UPI ID saved" (removed "verified" claims).
  - Appearance selector: System / Light / Dark with live cross-fade switching and persistence.
  - Privacy & Data: plain-language data explanations, "Delete all my data" with typed confirmation, "Start fresh" (empty app), and "Reset demo data".
  - Clean empty states across all screens for empty app scenarios.

- [x] **D) Full Domain Models & Persistence**:
  - Implemented full domain models: `Person`, `Group` (with personal space excluded from shared balances), `Expense` (with split parameters and revisions list), `Settlement`, `RecurringTemplate`.
  - Repository interface `AppRepository` backed by `PersistentAppRepository` using `shared_preferences` with debounced JSON serialization, versioning (`settliv_ledger_v1`), corrupt data recovery, and invariant validation.
  - Extended seed data to ~6 months of history with past months fully settled by matching settlements, keeping headline numbers exact: Flatmates +₹1,240, Goa Trip -₹380, net +₹860.
  - Verified by `test/persistence_test.dart` and `test/seed_test.dart`.

- [x] **E) Defect Fixes & Visual QA**:
  - Avatar initials measured and positioned to avoid overlap intersections.
  - Group badges and money texts never truncated or ellipsized.
  - Docked bar does not overlay content or sheets.
  - All 88 automated tests passing, 0 analyzer issues.
  - Visual QA verified across 390x844 and 360x640 in Light and Dark modes.

---

## Task 3: Visual Direction, Shell, Home, Balances, Insights, Plan

### Set 1: Revamp, Shell, Home, Balances, Insights, Plan (COMPLETED)
- [x] **1A. Data Regression Investigation & Seed Versioning**:
  - Stale persisted data key `settliv_ledger_v1` cleared and upgraded to `settliv_ledger_v2` with `schemaVersion = 2` and `seedVersion = 2`.
  - Added schema/seed version migration logic in `PersistentAppRepository` to safely upgrade or reseed without user data corruption.
  - Added integration test `test/seed_integration_test.dart` asserting fresh storage boot gives exact hero numbers: Flatmates +₹1,240, Goa Trip -₹380, net +₹860 across groups.
- [x] **1B. Theme, Tokens & Bundled Fonts ("Pearl Glass" & "Midnight Glass")**:
  - Removed beige/warm theme. Implemented modern cool-white "Pearl Glass" (#F6F7FC canvas, radial aurora #E9E5FF at 50% top-left, #E4EEFF at 40% bottom-right, 80% white surface with 1px hairline #E3E5F1, 1px white inner top highlight, ink #12132B, muted #5A5F7A, anchor Deep Indigo-Navy #16193F, accent #5B4BDB).
  - Implemented "Midnight Glass" dark theme (#0A0C1C canvas, violet wash #1A1640 at 45%, surface #12142A at 80%, raised #191C3A, hairline #272B4A, text #ECEBF5, muted #A5A8C0, off-white primary button with ink text).
  - Bundled official Google Fonts TTF assets (Sora for money, titles, numbers; Plus Jakarta Sans for body, labels, inputs) with all required weights declared in `pubspec.yaml`.
  - Verified ₹ glyph renders in both font families with tabular figures (`FontFeature.tabularFigures()`).
  - Added font specimen to `/gallery` showing money, titles, body, and ₹ symbol in both themes.
  - Verified static cached `AuroraBackground` inside `RepaintBoundary` repainting only on theme changes.
  - Built unified `ScreenScaffold` and `SectionCard` with 8pt grid, 20px screen padding, 28px top radii for sheets, 24px cards, 16px controls.
  - Verified token scanner (`test/theme_token_scan_test.dart`) and WCAG AA contrast (`test/wcag_contrast_test.dart`).
- [x] **1C. Navigation Shell & Docked Nav Bar**:
  - `StatefulShellRoute` with 4 tabs + center action: Home, Records, [+], Insights, Plan (NO Groups tab).
  - Docked full-width bar (top corners 28, top hairline, blur BackdropFilter layer at 88% surface, upward diffused shadow, hidden when keyboard is open, safe-area aware).
  - Active indicator: 3x20 sliding line centered over active tab (200ms ease-out).
  - Center + button: 52x52 rounded square (radius 18), deep indigo-navy in light / off-white in dark, raised 12px, soft shadow + hairline, NO colored ring, press scale 0.94, opens `/add`.
  - All pushed routes (`/add`, `/balances`, `/groups`, `/group/:id`, `/settings`, `/gallery`) sit above shell with no docked bar.
  - Content bottom padding equals bar height + safe area + 16px.
- [x] **1D. Home Screen & Balance Hero**:
  - Time-aware greeting, date line ("Saturday, 21 November"), 44px avatar button navigating to `/settings`.
  - Balance Hero Card: deep indigo-navy mesh with faint violet glow and 1px inner highlight; eyebrow "NET ACROSS GROUPS"; headline sentence ("You're owed" / "You owe" / "All settled up"); white Sora 40-44/800 amount with count-up, NO minus sign, on-dark status marker; thin diverging bar; two distinct columns for "Owed to you" and "You owe"; footer row with counterparty avatars and "View breakdown ›" opening `/balances`.
  - "This month" compact card: YOUR share this month vs last month with arrow and percentage change, month-to-date line, tapping opens `/insights`.
  - "Needs attention" card: displays ONLY when actionable items exist (debtor owing for 7+ days, due recurring bills, over budget).
  - Recent activity: pure function `RecentActivityEngine` (unit tested in `test/recent_activity_engine_test.dart`), single grouped container with hairline dividers, compact rows with category icon tiles, payer/settlement subtitles, amount sentences ("You lent ₹3,000", "You owe ₹1,160", "Not involved"), tapping opens detail sheet.
  - Recent groups: max 2 by last activity with cover strip, member avatars, full balance sentence, and "All groups ›" opening `/groups`.
- [x] **1E. Balances Page (/balances)**:
  - Header with net sentence ("You're owed ₹860 overall across groups").
  - Rectangular segmented control (radius 16) "Owed to you (N)" / "You owe (N)".
  - Per-person net summary rows with breakdown line ("Flatmates ₹1,240 · Goa Trip ₹640"), expandable per-group lines with individual Nudge/Settle actions.
  - "Settle all" with simulated UPI flow and cash option; undo snackbar restoring exact ledger state.
  - Pure function engine `PersonBalanceEngine` unit-tested in `test/person_balance_engine_test.dart`.
- [x] **1F. Insights Screen (/insights)**:
  - Period selector: This month, Last month, 3M, 6M, Year.
  - Debts & settlements card (settled in period vs net still owed).
  - "Your spending" hero (YOUR share only, never group totals) with percentage vs previous period.
  - Category breakdown donut chart via CustomPainter with slice percentages and list.
  - Breakdown by group and personal space.
  - Spending habits insights.
- [x] **1G. Plan Screen (/plan)**:
  - Monthly budget overview with your share spent so far.
  - 3-state progress bar (Emerald <=80%, Saffron 80-100%, Coral >100%).
  - Month-end pace projection ("Projected: ₹X at current pace ~₹Y/day").
  - Category spending limits with edit sheet, persisted in SharedPreferences.
- [x] **1H. Quality Assurance & Defect Fixes**:
  - Fixed 24px overflow on Home at 360x640 with text scale factor 1.3 in "This month" card.
  - Fixed hero card column money truncation ("Owed to you ₹1,2...") at 360px width by giving amount its own prominent tabular figure line.
  - Fixed `summary.breakdownText` in `PersonBalanceEngine` to use `CurrencyFormatter.formatPaise()` with proper Indian grouping commas.
  - Removed unused imports and cleaned up test prints.
  - Captured 32 responsive screenshots across 390x844 and 360x640 in both Light and Dark modes.
  - Full test suite: 98/98 tests passing.
  - `flutter analyze`: 0 issues found.

---

### Set 2: Records Personal Filter & Add Expense Personal Space (COMPLETED)
- [x] **2A. Records Screen (/records / /activity)**:
  - Added "Personal" filter chip alongside "All groups" and shared groups.
  - Tapping "Personal" filters expense list exclusively to personal space transactions.
  - Subtitle updated to reflect personal expenses across groups.
- [x] **2B. Add Expense Personal Space**:
  - Group selector displays "Personal (just me)" for the personal group.
  - Selecting "Personal (just me)" hides the "SPLIT WITH" and "SPLIT MODE" sections (no split, 100% share for current user).
  - Save button dynamically adapts to display "Save ₹X · personal".
  - Quick tab automatically focuses input field on navigating to `/add`.
- [x] **2C. Expense Tile Subtitle**:
  - When an expense belongs to the personal group, subtitle renders "Personal · Paid by you".
  - Fixed row constraints to prevent horizontal overflow on narrow viewports with enlarged text scale factors.
- [x] **2D. Set 2 Verification Tests**:
  - Added `test/set2_verification_test.dart` testing filter chip presence, personal expense filtering, Personal (just me) option, hiding split-with section, and personal subtitle rendering.

---

### Set 3: Group Detail, Theme Cross-Fade, Font Cleanup, Verification (COMPLETED)
- [x] **3A. Groups & Group Detail Screen**:
  - Theme-adaptive "New group" button on Groups screen using `theme.primaryButtonBg` and `theme.primaryButtonText`.
  - Group Detail collapsing header with frosted back button and trip progress indicator for trip groups.
  - Interactive tabs: Expenses list (grouped by day, clean hairline dividers) and Balances ("Who pays whom", `BalanceBarsChart`, `CategoryDonutChart`).
  - SettleSheet and NudgeSheet functional flows accessible from header and bottom bar.
- [x] **3B. Typography & Font Cleanup**:
  - Eradicated all 31 hardcoded `'Manrope'` string literals across `lib/` in favor of `AppTypography.fontBody` (`PlusJakartaSans`) and `AppTypography.fontDisplay` (`Sora`).
- [x] **3C. Theme Cross-Fade & Contrast**:
  - Verified `SettlivThemeExtension.lerp` for smooth transitions between Light and Dark modes.
  - Verified WCAG AA contrast compliance across all text and surface tokens.
- [x] **3D. Web App Cache Bypass**:
  - Unregistered stale PWA service workers in `web/index.html` and configured `Cache-Control: no-store, no-cache, must-revalidate` in local server to guarantee fresh updates on browser refresh.
- [x] **3E. Comprehensive Set 3 Test Suite**:
  - Added `test/set3_verification_test.dart` testing Groups list, Group Detail tab switching, Settle/Nudge sheets, and live Theme switching.
  - Verified full test suite: 108/108 tests passing, 0 analyze issues.

---

### Extended Features: Group Edit, Recurring Engine, Export/Import & Live UPI (COMPLETED)
- [x] **Extended 1. Active Group Management (Edit Group)**:
  - Added `EditGroupSheet` (`lib/features/group_detail/sheets/edit_group_sheet.dart`) launched from action button in `GroupDetailScreen` SliverAppBar.
  - Edit group name with validation.
  - Switch group type (Home, Trip, Other).
  - 6 Cover Theme Selector swatches with live gradient previews (`GroupCoverArt`).
  - Member management: view existing members, remove members (except current user), and add new members from contacts or create a new person inline.
  - Calls `updateGroup` and `addPerson` via `appStateProvider.notifier`.
- [x] **Extended 2. Recurring Expenses Engine**:
  - Implemented `processDueRecurringExpenses` in `PersistentAppRepository` and `AppStateNotifier` to compute due dates based on frequency (daily, weekly, monthly, yearly), generate exact paise shares with `SplitCalculator`, advance `lastGeneratedDate`, and persist new `Expense` records.
  - Created `RecurringExpensesScreen` (`lib/features/settings/presentation/recurring_expenses_screen.dart`) with active status banner, manual "Check due" trigger, rule cards with pause/resume toggle, delete confirmation, and modal sheet to add new recurring rules.
  - Added route `/settings/recurring` and linked from Settings screen.
- [x] **Extended 3. Data Export & Import (JSON & CSV)**:
  - Implemented `exportLedgerJson()` serializing full ledger matching v2 schema.
  - Implemented `exportExpensesCsv()` with RFC-compliant escaping, date, title, category, group, amount, payer, split mode, and personal flag.
  - Implemented `restoreFromJson()` validating invariants (current user exists, group members, computed shares sum matching total paise) before applying to ledger and saving.
  - Integrated in `SettingsScreen` under "BACKUP & EXPORT": Export JSON Backup (dialog + clipboard copy), Export Expenses CSV (clipboard copy), and Restore from JSON Backup (text input modal with validation).
- [x] **Extended 4. Live Device UPI Deep-Linking**:
  - In `SettleSheet`, constructed standard Indian UPI intent URLs (`upi://pay?pa=...&pn=...&am=...&cu=INR&tn=...`).
  - Tested `canLaunchUrl(universalUri)` with `launchUrl(..., mode: LaunchMode.externalApplication)`.
  - Added automated fallback to clipboard copy and confirmation step for web/desktop environments.
- [x] **Extended 5. Test Suite & Verification**:
  - Added `test/extended_features_test.dart` testing group editing, recurring template creation & due processing, JSON/CSV exports, valid/invalid restore invariants, and UPI URI generation.
  - Verified: `flutter analyze` (**0 issues found**).
  - Verified: `flutter test` (**118/118 tests passed**).





---

## Task 4: Final Front-End Polish (In Progress)

### Set 1: Shell, Home Revamp & Foundation Fixes (COMPLETED)
- [x] **A. Foundation Fixes (Bugs 1-7 foundations)**:
  - **ScreenScaffold & ScreenHeader**: Shared single `CustomScrollView` with header scrolling away (no pinned headers, no blank gaps), top padding = safe area + 12, bottom padding inside scroll content = bar height + safe area + 16. Applied across Home, Groups, Records, Insights, Balances, Settings, Plan, and Add Expense.
  - **Brand Fonts & Typography**: Installed Bricolage Grotesque (Bold 700 & ExtraBold 800 TTFs) for screen titles (30/800 tight tracking -0.8), section titles (17/700 sentence case), and SETTLIV wordmark. Money and big numbers preserved in Sora tabular figures. Body/labels in Plus Jakarta Sans. Eyebrow 11/700 +0.6 tracking (the only all-caps).
  - **Component Gallery Removal**: Deleted `/gallery` route, screen, navigation references, and settings tile.
  - **Pressed States & No Layout Shift**: Replaced animated scale on list rows with bounded background tint; scale 0.97 reserved exclusively for standalone buttons/cards.
  - **Category Palette per Theme**: Assigned separate light and dark colors for all 8 categories (Rent uses periwinkle/indigo `#4338CA` light / `#818CF8` dark, eliminating dark mode navy-on-navy invisibility). Added contrast tests in `test/wcag_contrast_test.dart` (icon vs tile >= 3:1, slice vs surface >= 3:1) - all 12 pass.
  - **Name Normalisation & "Paid by you"**: All member names normalized on input (trimmed, collapsed whitespace, title case). Current user consistently displays as "you" / "Paid by you" across all cards, rows, and sheets.
  - **Seed Data Audit**: Fixed "House party brew ₹2,820" in 3-person Flatmates so Arjun lent ₹1,880 (equal split ₹940 each). Verified all 25 seed expenses sum to exact totals, participants are group members, and lent/owe amounts match splits.
- [x] **B. Navigation Shell**:
  - 4 tabs + centre action: Home (`/`), Groups (`/groups`), `[+]` (`/add`), Records (`/records`), Insights (`/insights`).
  - Groups is now a `StatefulShellBranch` tab.
  - `/plan` redirects to `/insights/budgets`.
  - `DockedNavBar`: 5 slots with filled active icon, 3x20 active indicator line, 11/600 labels always visible, raised 52x52 rounded-square `+` button. Hidden on pushed routes (`/balances`, `/settings`, `/add`) and when keyboard is visible.
- [x] **C. Home Screen Revamp**:
  - **1. Header**: Time-aware greeting (`Good morning` / `Good afternoon` / `Good evening` / `Good night`) in Bricolage Grotesque. Subline: weekday + date + live status (`Saturday, 21 Nov · All settled`). Left: 44px drawn day-period tile (`DayPeriodTile` sunrise/sun/sunset/moon CustomPainter with cached one-time rise). Right: 44px avatar button -> Settings.
  - **2. Hero Card (`BalanceHeroCard`)**: Eyebrow "NET POSITION", sentence, big white count-up Sora 38px (no minus sign, never coloured text on navy), two columns ("Owed to you ₹X · N people" / "You owe ₹Y · M people"), thin diverging split bar, footer with counterparty avatars and "View breakdown ›" -> `/balances`. Layered navy mesh with subtle topographic contour arcs, hairline inner highlight, and single soft light sweep on session start.
  - **3. Shortcuts Row (`HomeShortcutsRow`)**: 5 equal tiles, 44px rounded-16 tile + 11px label. Usage score ranking (halves every 14 days, pure function `ShortcutEngine`, persisted). Integrated `SplitCalculatorSheet` for exact-paise split calculation.
  - **4. Needs Attention**: Compact alert card shown only when items exist (overdue balances, recurring bills). Hidden when empty.
  - **5. This Month**: Compact card with spend vs last month and arrow indicator -> `/insights`.
  - **6. Recent Groups**: Max 2 groups by last activity, compact (~96px) with 56px drawn cover art, full-width balance sentence, and "All groups ›" row switching to Groups tab.
  - **7. Recent Activity**: Placed below groups, max 3 rows (expenses + settlements, soft-deleted excluded). Rule: today's items + earlier days (up to 7 back) until 3 shown. "N more today · See all" -> `/records` when today has > 3 items. Hairline dividers, category icon tile with fixed dark-mode colors, title, subtitle ("Paid by you" / payer), amount in words. Tap row -> `ExpenseDetailSheet`.
- [x] **D. Verification & Test Suite**:
  - `flutter analyze`: **0 issues found**.
  - `flutter test`: **129/129 tests passing** across entire project.


---

## PRIORITY TASK: Settliv Experiences (App + Web)

> **IMPORTANT**: Set 2 and Set 3 are placed ON HOLD until Part W3 completes and the user says "continue".
> When Set 2 and Set 3 resume, every screen they add (Groups hub, IOU notes, scan sheet, Budgets, Settings sections, Help forms, lock screen) must be implemented for BOTH experiences (App and Web) using the adaptive architecture established in Part W1.

### Part W1: Engine, AdaptiveWebShell, AdaptivePresenter, Experience Settings & Back Navigation (COMPLETED)
- [x] **Small Fix (App Home Header)**:
  - Removed day-period icon tile and live status text (`"· N need attention"` / `"· All settled"`) from Home header in the App experience.
  - Subline is strictly `weekday + date` only (`DateFormat('EEEE, d MMM').format(now)`).
- [x] **DeviceProfile & Detection Engine (`lib/core/profile/`)**:
  - `DeviceClass`: `desktop` vs `touch`.
  - Web detector (`device_detector_web.dart`): evaluates `pointer: coarse` + `hover: none`, mobile/tablet UA, and iPadOS (`Macintosh` + `maxTouchPoints > 1`). Includes debug-only `?device=desktop|touch` query parameter override (`kDebugMode` only).
  - Stub detector (`device_detector_stub.dart`): defaults to `DeviceClass.touch` for mobile/tests.
  - Hardware concurrency and device memory detection for performance tuning.
- [x] **Experience Mode Resolution (`lib/core/profile/experience_mode.dart`)**:
  - Mode = `auto`, `app`, `web`.
  - **Strict Invariant**: Desktop ALWAYS gets Web (`EffectiveExperience.web`), regardless of window size or saved preference; App experience is strictly unreachable on desktop.
  - Touch devices default to App (`EffectiveExperience.app`), and can toggle to Web (`EffectiveExperience.web`). Choice is persisted per device in `SharedPreferences` (`settliv_experience_mode`).
- [x] **Adaptive Layout & Motion Tokens (`lib/core/layout/`, `lib/core/theme/`)**:
  - `AdaptiveLayout`: `compact` (<720), `medium` (720-1099), `expanded` (>=1100).
  - `MotionTokens`: standard durations (120, 240, 360, 280, 300ms cross-fade), cubic curves, and `isLiteEffects` detection (reduced motion / hardware constraints).
- [x] **AdaptivePresenter (`lib/core/widgets/adaptive_presenter.dart`)**:
  - Unified dialog/sheet presentation:
    - App experience and compact Web = bottom sheet (`GlassSheetScaffold`).
    - Medium/expanded Web = centered modal dialog (max width 560) for `formOrConfirmation`, right-side drawer (max width 440) for `detailView`.
    - Includes scrim, Esc keyboard shortcut, close button, focus trap, and focus restoration.
- [x] **Adaptive Navigation Shell (`lib/core/widgets/adaptive_web_shell.dart`, `experience_shell.dart`)**:
  - `AdaptiveWebShell`:
    - Expanded (>=1100): 264px glass sidebar with logomark, SETTLIV wordmark, "+ Add expense" primary CTA, sliding active nav pill, version micro-card, user avatar -> settings, and theme toggle.
    - Medium (720-1099): 76px compact icon rail with tooltips.
    - Compact (<720): 60px sticky glass top header + drawer (includes "Switch to app view" for touch devices). No bottom bar.
  - `ExperienceShell`: Instant smooth 300ms fade transition switching between `AppShell` and `AdaptiveWebShell`, safely maintaining single `navigationShell` instance and preserving current route and all state.
  - Removed `PhoneFrame` desktop frame wrapper and bottom bar on desktop.
- [x] **Back Navigation & ScreenHeader (`lib/core/navigation/`, `lib/core/widgets/`)**:
  - Centralized route hierarchy in `BackNavigation` with parent route resolution and fallback.
  - `ScreenHeader`: Renders `‹ Parent` text link on desktop, circular glass back button on compact/touch.
- [x] **Settings "Experience" Section (`lib/features/settings/presentation/widgets/`)**:
  - Placed immediately before `PRIVACY & DATA`.
  - Touch devices: Segmented control (`App` | `Web`) with custom-painted schematic phone and browser thumbnails (`PhoneThumbnailPainter`, `BrowserThumbnailPainter`), colored dynamically from `theme.accent`.
  - Desktop devices: Informational card explaining Web is active and optimized for mobile/touch.
  - Explanatory architecture note: "One codebase, two experiences. Settliv is built with Flutter, so the same product can ship as a mobile app (for Play Store-style distribution) and as a responsive website for desktop and mobile browsers."
- [x] **Compatibility Mentions**:
  - Quiet footer at bottom of Home/Dashboard: "Also runs as a mobile app and a website · See versions in Settings ›".
- [x] **Verification & Test Suite**:
  - Added `test/part_w1_test.dart` covering device profile fake detection, mode resolution table, route table back affordance and fallbacks, AdaptivePresenter variants per layout class, Esc dismissal, viewport overflow tests across 8 resolutions (including 1.3 text scale compact), and route/state preservation on mode switch.
  - `flutter analyze`: **0 issues found**.
  - `flutter test`: **145/145 tests passing** (100%).

---

### Brand Rule: Wordmark ONLY (No Logomark) (COMPLETED)
- [x] **Wordmark-Only Enforcement**:
  - Completely removed the "S" logomark / logo icon across the entire codebase (sidebar header, medium rail, compact web header, drawer, and Settings brand block).
  - Brand identity is strictly and exclusively the text "SETTLIV".
  - **Rule**: Any items in Set 2, Set 3, or W3 that mention a logomark now mean wordmark only.
  - Implemented `SettlivWordmark` ([settliv_wordmark.dart](file:///C:/Users/shelb/Downloads/SETTLIV-X/lib/core/widgets/settliv_wordmark.dart)) in Bricolage Grotesque ExtraBold (`FontWeight.w800`), ALL CAPS, wide tracking (~0.18em = `fontSize * 0.18`), solid ink color, baseline-aligned and optically centered:
    - Expanded sidebar: ~18px, left-aligned with nav items' text column.
    - Medium rail: ~13px rotated 90 degrees vertical (reading bottom-to-top via `RotatedBox(quarterTurns: 3)`).
    - Compact web header: ~16px, beside the left menu button.
    - Settings end block: 24px large wordmark plus version line.
    - Lock screen & loading screen (when built): centered wordmark, no icon.
  - Unit test added verifying zero logomark widgets exist in the tree and wordmark renders across all shell variants without overflow.

---

### Part W2: Desktop & Web Layouts for Core Screens (COMPLETED)
- [x] **Dashboard (`/`) Web View ([dashboard_web_view.dart](file:///C:/Users/shelb/Downloads/SETTLIV-X/lib/features/home/presentation/widgets/dashboard_web_view.dart))**:
  - Header: Large display greeting + date in Bricolage Grotesque, no icon, no status; theme toggle button.
  - Bento Layout:
    - Row 1: Net Position Hero card (span 7, whole card clickable -> `/balances`) beside "This month" spend card (span 5, vs last month percent, progress bar, clickable -> `/insights`).
    - Row 2: Recent groups (span 7, 2 rich cards with cover art, member count, balance pill, "All groups ›") beside Shortcuts (span 5, ranked tiles, scan hidden on desktop per rule).
    - Row 3: Recent activity (span 12) proper table (Description, Group, Paid by, Date, Your share) with hover highlight, clicking row opens `ExpenseDetailSheet` in AdaptivePresenter right drawer, same 3-row / today rule.
    - Footer compatibility line: "Also runs as a mobile app and a website · See versions in Settings ›".
    - Compact web stacks the bento in single column without overflow.
- [x] **Groups (`/groups`) Web View ([groups_screen.dart](file:///C:/Users/shelb/Downloads/SETTLIV-X/lib/features/groups/presentation/groups_screen.dart))**:
  - Responsive card grid: 3 columns on expanded (>=1100), 2 columns on medium (720-1099), 1 column on compact (<720).
  - Large cover art, hover lift (-2px translateY) and click feedback on `GroupCard`.
  - "+ New group" button opens `AdaptivePresenter.show` centered modal dialog on desktop/medium and bottom sheet on compact.
- [x] **Group Detail (`/group/:id`) Web View ([group_detail_web_view.dart](file:///C:/Users/shelb/Downloads/SETTLIV-X/lib/features/group_detail/presentation/widgets/group_detail_web_view.dart))**:
  - Full-bleed cover banner with glass title block and `‹ Groups` back control.
  - Expanded two-pane layout:
    - Left column (flex 7): Expenses table (Description, Paid by, Date, Total) with hover highlight; tapping row opens `ExpenseDetailSheet` in right drawer.
    - Right column (flex 5): Sticky glass column with "Who pays whom" group balances, Nudge & Settle up buttons, and `CategoryDonutChart`.
  - Compact web stacks banner, group balances, expenses table, and donut chart.
- [x] **Balances (`/balances`) Web View ([balances_screen.dart](file:///C:/Users/shelb/Downloads/SETTLIV-X/lib/features/balances/presentation/balances_screen.dart))**:
  - Replaces mobile segmented control with two side-by-side columns: "OWED TO YOU" on left, "YOU OWE" on right.
  - Person rows with inline per-group expansion, Settle, Nudge, and amount badges.
  - "SETTLED RECENTLY" section below with undo action.
  - Compact web stacks sections without overflow.
  - Back control: `‹ Home` text link on desktop returning to `/`.
- [x] **Verification & Test Suite**:
  - Added `test/part_w2_test.dart` verifying wordmark styling, rotated rail wordmark, zero logomark widgets, dashboard bento elements and drawer, groups responsive grid, group detail two-pane layout, balances side-by-side columns, and compact viewport responsiveness.
  - `flutter analyze`: **0 issues found**.
  - `flutter test`: **154/154 tests passing** (100%).

---

### Part W3: Records, Insights, Add Expense Dialog, Settings Two-Pane, First Impression & QA (COMPLETED)
- [x] **First Impression & Web Meta ([web/index.html](file:///C:/Users/shelb/Downloads/SETTLIV-X/web/index.html), [web/manifest.json](file:///C:/Users/shelb/Downloads/SETTLIV-X/web/manifest.json))**:
  - Branded loading screen with `SETTLIV` wordmark ONLY, subtle pulse animation, light/dark aware, tagline `"One codebase. Every screen."`, automatically removed on `flutter-first-frame`.
  - Updated page title (`<title>Settliv — Expense Sharing & Group Ledger</title>`), meta description, OpenGraph tags, and theme-color definitions.
- [x] **Records Web View ([records_web_view.dart](file:///C:/Users/shelb/Downloads/SETTLIV-X/lib/features/activity/presentation/widgets/records_web_view.dart))**:
  - Toolbar with live text search, "Filters" popover dialog (Group & Category filter chips), and filter summary line with "Clear filters".
  - Full-width table: Description, Group, Paid by, Date, Category, Total, Your share with Sora tabular figures.
  - Hover highlights on table rows; clicking any row opens `ExpenseDetailSheet` in an `AdaptivePresenter` right drawer.
  - Empty/no-result states with clear action. Compact web renders responsive card list.
- [x] **Insights Web View ([insights_web_view.dart](file:///C:/Users/shelb/Downloads/SETTLIV-X/lib/features/insights/presentation/widgets/insights_web_view.dart))**:
  - Period selector chips ('This month', 'Last month', '3M', '6M', 'Year').
  - Bento charts: Spend summary card (reconciled with Records), Debts & settlements card, Category breakdown with light/dark contrast compliant icons, Habits & daily average with peak weekday bars.
  - "Budgets & Limits" button navigates to `/insights/budgets`.
  - `PlanScreen` updated with desktop `‹ Insights` back navigation affordance.
- [x] **Add Expense Web Dialog ([add_expense_screen.dart](file:///C:/Users/shelb/Downloads/SETTLIV-X/lib/features/add_expense/presentation/add_expense_screen.dart))**:
  - Centered dialog presentation with `maxWidth: 960` on desktop web.
  - Cycling placeholder examples, live parse preview, split validation rules preserved.
  - Esc key dismisses dialog via `BackNavigation.handleBack`.
- [x] **Settings Web View ([settings_screen.dart](file:///C:/Users/shelb/Downloads/SETTLIV-X/lib/features/settings/presentation/settings_screen.dart))**:
  - Desktop two-pane layout: Left section rail ('Account & Theme', 'Experience', 'Recurring Bills', 'Privacy & Data') and right content pane.
  - Experience card: "Responsive Website (ACTIVE)" with multi-platform explanation.
  - End brand block featuring large 24px `SettlivWordmark` and version line. `‹ Home` back control.
- [x] **Verification & Test Suite**:
  - Added `test/part_w3_test.dart` (7 tests covering HTML/manifest metadata, records table/filters/drawer, compact records, insights bento & budgets navigation, add expense dialog & Esc key, settings two-pane & wordmark).
  - `flutter analyze`: **0 issues found**.
  - `flutter test`: **161/161 tests passing** (100%).
- [x] **Final QA & Screenshots Pass**:
  - Captured full screenshot suite via Chrome CDP across Desktop 1440x900 (Dashboard, Groups, Records, Insights, Add Expense dialog, Settings in Light & Dark modes), Compact Web (390x844), and App Mode (390x844 touch with mobile nav bar).
  - Inspected for clipped text, truncated currency, invisible icons, misalignment, and contrast. Documented in `NOTES.md`.

---

## Task 4 (Resumed): Set 2 — Groups Hub, IOU Notes, Add Expense Polish, and Scan Sheet (COMPLETED)
- [x] **IOU Notes Model, Repository & Ledger Integration**:
  - Created `IouNote` and `IouPayment` models in [lib/data/models/iou_note.dart](file:///C:/Users/shelb/Downloads/SETTLIV-X/lib/data/models/iou_note.dart) supporting direction (`owedToMe`, `iOwe`), amount in integer paise, remaining paise, payment history, overdue tracking with `isOverdue(now)` and `dueLabel(now)`, and soft deletion.
  - Added full IOU persistence methods to `AppRepository`, `PersistentAppRepository`, and `InMemoryAppRepository` with JSON export/restore and Riverpod provider `allIouNotesProvider`.
  - Updated `BalanceEngine` and `PersonBalanceEngine` to integrate active IOU remaining amounts into user net balance and merged `PersonDebtSummary` lines while keeping group debt settlements distinct from IOU payment workflows.
- [x] **Scan Sheet ([scan_sheet.dart](file:///C:/Users/shelb/Downloads/SETTLIV-X/lib/features/add_expense/presentation/widgets/scan_sheet.dart))**:
  - Implemented custom-painted viewfinder with corner brackets, "Coming with the Android app" pill, honest explanation, and real actions: "Paste bank SMS" and "Type it instead".
  - Accessible >= 48px touch targets, full keyboard and dismiss support.
- [x] **IOU Sheets & Balances Screen Integration**:
  - Created `CreateEditIouSheet` ([lib/features/balances/sheets/create_edit_iou_sheet.dart](file:///C:/Users/shelb/Downloads/SETTLIV-X/lib/features/balances/sheets/create_edit_iou_sheet.dart)) with direction toggle, person name, amount in paise, note/reason, optional phone, and optional due date picker.
  - Created `IouDetailSheet` ([lib/features/balances/sheets/iou_detail_sheet.dart](file:///C:/Users/shelb/Downloads/SETTLIV-X/lib/features/balances/sheets/iou_detail_sheet.dart)) with remaining/paid breakdown, partial/full payment recording, WhatsApp nudge with prefilled text (`https://wa.me/`), edit note, and delete with 5-second Undo snackbar.
  - Integrated "Add IOU" action into `ScreenHeader` in [lib/features/balances/presentation/balances_screen.dart](file:///C:/Users/shelb/Downloads/SETTLIV-X/lib/features/balances/presentation/balances_screen.dart) and rendered IOU notes in the expanded breakdown and primary action buttons.
- [x] **Groups Hub & Template Sheets**:
  - Created `CreateEditGroupSheet` ([lib/features/groups/presentation/widgets/create_edit_group_sheet.dart](file:///C:/Users/shelb/Downloads/SETTLIV-X/lib/features/groups/presentation/widgets/create_edit_group_sheet.dart)) supporting template prefilling, unique normalized names, 6 cover swatches, member management (min 2, title-cased), and default split modes.
  - Created `GroupHubCard` ([lib/features/groups/presentation/widgets/group_hub_card.dart](file:///C:/Users/shelb/Downloads/SETTLIV-X/lib/features/groups/presentation/widgets/group_hub_card.dart)) with drawn cover, pinned badge, 3-dots overflow menu, balance sentence, 6-week spend sparkline, and inline actions row wrapped with `Wrap` to prevent any RenderFlex overflow.
  - Revamped `GroupsScreen` ([lib/features/groups/presentation/groups_screen.dart](file:///C:/Users/shelb/Downloads/SETTLIV-X/lib/features/groups/presentation/groups_screen.dart)) with search toolbar, 3-column summary strip, rectangular segmented control `Active | Archived`, sort menu (`Recent | Balance | A-Z`), pinned groups first, responsive grid, empty states with actions, and "Start a new group" template row (Trip, Flatmates, Couple, Event, Friends).
- [x] **Add Expense Polish**:
  - Manual tab: Top segmented control `GlassSegmented<String>` (`Shared | Personal`). Personal mode cleanly hides Group, Paid by, Participants, and Split with full-width date and "Save ₹X · personal".
  - Amount hero: Integrated quick scan icon button opening `ScanSheet.show(context)`.
  - Typewriter timer: Cycling continues on focus/tap; pauses only when text is entered, resumes when cleared.
  - Group selector sheet: Integrated `_showGroupSelectorSheet` with Personal section above hairline, then shared Groups.
- [x] **Needs Attention & Shortcuts Wiring**:
  - Overdue IOU notes feed directly into the "Needs attention" message and action on both `HomeScreen` and `DashboardWebView`.
  - `ShortcutId.scanReceipt` opens `ScanSheet.show(context)`; `ShortcutId.iouNotes` opens `/balances`.
- [x] **Verification & Test Suite**:
  - `flutter analyze`: **0 issues found**.
  - `flutter test`: **166/166 tests passing** (100%).
  - Added `test/set2_verification_test.dart` with 10 comprehensive tests.
  - Web build compiled cleanly: `flutter build web` (0 errors).

---

## Follow-Up Task X Roadmap: X1, X2, S3

### Part X1: Fixes and Behaviour (COMPLETED)
- [x] **1. Theme Toggle & Month Dial**: Kept ONE theme toggle in sidebar footer. Removed top-right toggle on Web and replaced with drawn custom-painted Month Dial (radial ticks for each day of month, filled arc to today, today's tick highlighted with soft glow, large day number in center, month abbreviation below, tooltip 'Day X of Y', hidden on compact).
- [x] **2. 'Needs Attention' Strip Placement**: Moved directly below the Net position + This month bento row on Web dashboard (App layout unchanged).
- [x] **3. Hero Counts & Avatar Stack Geometry Bug**:
  - Counts = distinct people with non-zero net balance (groups + IOUs); singular/plural ('1 person' vs 'N people'); guaranteed that net amount > 0 implies count >= 1.
  - Avatar stack: 2px ring, overlap <= 6px, measured initials fully legible without clipping at any scale.
- [x] **4. Seed & Logic Audit**:
  - Month-to-date comparison: compare this month-to-date with same period last month.
  - Cap change percentage: if baseline < ₹1,000 or change > 300%, show absolute difference ('₹X more than last month') instead of absurd percentage.
  - Debt age calculation: FIFO matching of settlements to expenses so debt age reflects days since oldest still-unsettled amount, not arbitrary oldest expense.
  - Added seed sanity tests in `test/part_x1_test.dart`.
- [x] **5. Scan Receipt Visibility**: Hidden scan receipt everywhere on Web desktop (composer tools row, shortcuts card, Add dialog); kept visible on touch and inside App phone frame.
- [x] **6. Quick Composer Polish**: Removed faint 'Use this' text from composer in all layouts.
- [x] **7. Shortcuts Grid Uniformity**: 3 columns x 2 rows on expanded desktop, equal tile sizes (~88px), icon centered above label, cards in bento row stretch to equal height with no empty tails.
- [x] **8. Plain Right-Aligned Amounts**: Created `WebBalanceBadge` with clean right-aligned tabular amounts in AA text colors + small caption ('owed to you' / 'you owe') on Web. Replaced decorative pills.
- [x] **9. Web Typography Audit**: Card titles use Bricolage 17/700 sentence case (no all-caps card titles); caps eyebrows only for tiny meta labels.
- [x] **10. Navigation & Budgets Standalone Route**:
  - Budgets is standalone top-level sidebar item `/budgets` on Web; Web Insights = Overview only.
  - App keeps Budgets nested under `/insights/budgets`.
  - Sidebar items use `go()` to root route, active state derived from top-level section, 24px shared icon box, groups with eyebrows ('Overview', 'Money').
- [x] **11. Add Expense Centred Dialog**:
  - Desktop/medium Web: centred dialog via AdaptivePresenter (max 960px wide, 32px padding, header row with title and close button 24px from edges, Quick/Manual control, two panes with composer left and draft card right, footer actions with hairline).
  - Compact Web: full-screen sheet with 20px safe padding.
- [x] **12. Spacing & Insets Audit**: Nothing closer than 24px to viewport/dialog/drawer edge; 32-40px page padding on desktop; ScreenHeader top padding 40px, title-to-content 24px. Geometry tests at 1440x900 and 1280x720 in `test/part_x1_test.dart`.
- [x] **13. Experience Rules & Compatibility Preview**:
  - Synchronous device detection and pure resolution table: desktop+none->Web; desktop+app->App; desktop+web->Web; touch+none->App; touch+app->App; touch+web->Web. Tested in `test/part_x1_test.dart`.
  - App on wide viewports (>600px): centred phone frame with slim bezel (8px), content clipped inside (radius 44), bottom bar docked inside, scaled to viewport height, Aurora background, SETTLIV wordmark above, hint below ('Mobile app layout · compatibility preview. Settings › Experience').
  - Route mapping: `/budgets` (Web) <-> `/insights/budgets` (App).
  - Compatibility preview messaging in exactly 4 places (Settings > Experience with 3 schematic thumbnails, desktop sidebar footer card, phone frame hint, first-visit glass toast/card). Removed all 'one codebase / every screen' slogans.
  - Debug-only `?device=desktop|touch` query override.
- [x] **14. Automated Tests & Verification**:
  - `flutter analyze`: **0 issues found**.
  - `flutter test`: **175/175 tests passing** (100%), including `test/part_x1_test.dart`, `test/part_w2_test.dart`, `test/part_w3_test.dart`, and `test/theme_token_scan_test.dart`.
  - `flutter build web`: Built release bundle cleanly.
  - Local server serving `http://localhost:3000/` with `no-store, no-cache` headers.

---

### Part X2: Visual Level-Up (Web Experience) (COMPLETED)
- [x] **1. Background Depth Stack**:
  - FAR: soft color fields (light: pearl-white to lavender #E8E3FF, cool sky #DCEBFF, faint peach #FFE7DD; dark: ink #070914 base with violet #2A1B6B, indigo #16245E, teal #0C3A44 glows) with 6% scroll parallax and ±10px pointer parallax.
  - MID: fine contour/orbit linework (0.75px, 6-8% opacity, cached).
  - NEAR: 3-4% grain and soft vignette, soft pointer cursor light with eased lag (desktop only; disabled in lite mode).
  - Removed old square hairline grid from Web.
- [x] **2. Panels & Hover Styling**: 1px gradient hairline (brighter top-left), inner top highlight, violet ambient shadow (light: 0 12px 32px rgba(108,71,255,0.06); dark: 0 16px 40px rgba(0,0,0,0.55), 0 0 24px rgba(124,92,255,0.12) on hover). Desktop hover lifts 2px and subtly brightens border gradient along pointer position without full tree rebuilds (`WebGlassCard`).
- [x] **3. Hero 'Net Position' Level-Up**:
  - Light 'Prism Pearl': white-to-lavender surface, 1.5px prismatic border (violet-cyan-mint), ink text, AA colored sentence, concentric orbit rings with owed/owe nodes.
  - Dark 'Luminous Core': indigo-violet mesh, glowing gradient edge, slowly rotating orbit rings, glowing white amount, refined diverging track.
  - Both: ~72px Sora 800 with 600ms odometer digit roll once per session, light sweep, staggered avatar entrance, pointer spotlight (`WebNetPositionHero`).
- [x] **4. Motion Choreography**: First load stagger (background 400ms -> sidebar 12px rise -> header -> hero -> cards stagger 60ms). Page transitions: 280ms fade + 8px rise + blur 8 to 0 (`_buildWebPageTransition`). Spring nav indicators. Subtle magnetic pull (<= 4px) on primary button (`MagneticButton`).
- [x] **5. Sidebar & Surfaces Polish**: Frosted sidebar with gradient edge highlight, active item 3px accent bar + soft tint, 1.75px rounded icon set, tabular figures, 8pt optical alignment, refined chart crosshair.
- [x] **6. Signature Loading Screen (`web/index.html`)**: Pure HTML/CSS/inline SVG 'Settle' sequence: converging nodes on thin rings, balancing line, SETTLIV wordmark resolving from 0.6em to 0.18em tracking with indeterminate hairline sweep. On Flutter first frame: circular expanding clip-path reveal. Theme-aware, reduced-motion aware, zero external requests, no logo icon, no slogan.
- [x] **7. Empty States & Contrast Check**: Settle orbit motif in empty states (`SettleOrbitMotifPainter`); WCAG contrast test verification against blended backgrounds in `test/wcag_contrast_test.dart`.
- [x] **8. Screenshots & Verification Pass**: Full 1440x900 screenshots (Dashboard light/dark, Add Expense dialog, Settings > Experience, loading screen frames) captured and verified in artifact directory.

---

---

### Part Y: Fixes for App-on-PC, Dial, Deep Link, Experience Section, Home Footer (COMPLETED)
- [x] **1. App Experience on Wide Viewport (Global Phone Frame Encapsulation)**:
  - Root Navigator wrapped via `MaterialApp.builder` when `effectiveExperience == EffectiveExperience.app` and `MediaQuery.sizeOf(context).width > 600`.
  - Nested phone frame removed from `AppShell`; every pushed route, overlay, bottom sheet, dialog, menu, and snackbar now renders within the phone frame screen.
  - Overrides `MediaQuery` inside the frame (`size: Size(390, 844)`, `padding: EdgeInsets.only(top: 48, bottom: 34)`), ensuring `AdaptivePresenter`, breakpoints, and LayoutBuilders resolve strictly to the frame.
  - Modals and scrims clipped to frame's rounded screen (radius 44). Mouse-drag scrolling enabled via `SettlivScrollBehavior.dragDevices`.
  - Added lint test in `test/part_y_verification_test.dart` asserting no physical window/view size reads outside experience wrapper.
- [x] **2. Month Dial Redesign on Web Dashboard**:
  - Web dashboard header top-right dial redesigned: does NOT repeat date (date stays on left).
  - Ring ticks for each day of the month with today's progress arc and glow.
  - Small dot markers on days with upcoming dues (recurring bills or IOUs).
  - Centre displays large "N" (`daysLeft`) and "days left". Beside the dial: "Next: <item> · <date>" and amount, or "No dues this month".
  - Hover tooltip displays up to 3 upcoming items. Tap navigates to `/budgets` on Web.
  - Cached painter, reduced-motion safe, hidden on compact. Seeded realistic upcoming dues.
- [x] **3. Compatibility Preview Entry Points & Deep Link**:
  - Removed "Compatibility preview" footer line from Home/Dashboard in all layouts.
  - Kept exactly the 6 approved entry points: expanded Web sidebar card, medium icon rail bottom icon with tooltip, compact Web menu drawer item, phone frame hint, first-visit glass toast, Settings screen.
  - Deep link `/settings?section=experience` auto-scrolls so section header sits ~24px below top, selects 'Experience' in two-pane Web list, and plays a 1.2s soft border glow pulse.
- [x] **4. Experience Section Redesign in Settings**:
  - Removed old segmented control and long grey paragraph.
  - Eyebrow 'COMPATIBILITY PREVIEW' with 3.5px accent bar.
  - Three schematic layout tiles (PC website, Mobile website, Mobile app). On PC: PC website and Mobile app selectable, Mobile web dashed reference. On Touch: Mobile web and Mobile app selectable, PC website dashed reference.
  - Compact notice strip (~96px tall) with left gradient edge, `DeviceConvergencePainter` schematic orbit diagram with single traveling dot animation, lead line *"A preview, not a feature."* and concise body copy.
- [x] **5. Layout Matrix & Overflow Defect Fixes**:
  - Fixed Add Expense bottom action row overflow on narrow screens with `FittedBox`.
  - Fixed Group Detail summary chips row overflow on compact Web with `Wrap`.
  - Migrated Split Calculator sheet to `AdaptivePresenter.show` with responsive text truncation.
  - Made Insights top period selector adaptive on compact viewports.
  - Full layout matrix verified across 4 environments (App on Phone, App in Frame on PC, Web Desktop, Web Compact) with no overflow.
- [x] **6. Automated Verification**:
  - `flutter analyze`: **0 issues found**.
  - `flutter test`: **199/199 tests passing** (100%).

### Part S3: Set 3 — Both Experiences Full Implementation
- [ ] **1. Insights & Budgets Implementation for Both Experiences**:
  - **App Experience**: Insights screen with `Overview | Budgets` segmented control. Overview tab includes calendar view, monthly recap card, debt breakdown, category spending distribution, group spending breakdown, spending habits. Budgets tab includes category monthly budget progress, upcoming recurring bills, and savings goals.
  - **Web Experience**: Standalone `/budgets` page with full budgets hub, recurring bills, and savings goals; standalone `/insights` page with overview charts, calendar, and habit metrics.
  - Adaptive presentation for all detail dialogs, create budget modal, and recurring bill creation.
- [ ] **2. Settings Expansion & Polish for Both Experiences**:
  - **Experience Section**: Maintained immediately before 'Privacy and data'; segmented App | Web control, 3 schematic thumbnails (PC website, Mobile website, Mobile app) with active state badge, factual copy.
  - **Help & Feedback**: 'Report a problem' and 'Request a feature' functional interactive forms with category selector, description, severity, and confirmation sheet/dialog.
  - **Security / Device Lock**: Biometric / WebAuthn screen lock simulation with PIN fallback; custom wordmark-only lock screen with full-viewport glass on Web and phone-frame compatibility on desktop.
  - **Recurring Bills Manager**: Complete list of active/paused recurring templates, pause/resume toggle, delete with undo, add recurring template modal.
  - **Data & Privacy Management**: JSON full ledger backup and restore with file download, CSV export, 'Clear all data' with two-step modal confirmation.
  - **About / Brand Section**: Wordmark only ('SETTLIV'), version string, 'Built with Flutter'.
- [ ] **3. Motion & Visual Consistency for App Experience**:
  - Ensure App experience shares consistent high-end micro-interactions, smooth sheet transitions, and haptic feedback without heavy desktop-specific shaders/pointer parallax.
- [ ] **4. Final Comprehensive QA & Documentation**:
  - Test coverage across all desktop resolutions (1920x1080, 1440x900, 1366x768, 1024x768), tablet (768x1024), mobile viewports (390x844, 360x640).
  - Verify route persistence on browser refresh and route mapping when switching modes (`/budgets` <-> `/insights/budgets`).
  - Verify back affordance on every route.
  - Update `README.md` and `DEPLOY.md` with complete documentation, build commands, Vercel instructions, release size stats, and honest limitations.


---

## ✅ SET 3 COMPLETE — 2026-11-23

### What was delivered:

**A. Insights tab (App + Web)**
- Rectangular segmented control `Overview | Budgets` replaces old Plan tab
- Overview: MonthRecapCard, SpendingCalendar (day-intensity grid, tap-to-sheet), Debts & Settlements, Your Spending, Category Breakdown (donut), By Group, Habits & Highlights
- Budgets tab embeds PlanScreen (RecurringDuesSection + SavingsGoalsSection) without scaffold
- `/insights/budgets` route renders InsightsScreen with Budgets tab pre-selected

**B. Profile & Settings**
- Full-screen settings (no AppBar by default on App)
- Security section: WebAuthn screen lock with timeout options
- Help & Feedback section: Report a problem / Request a feature forms, local queue, copy/email
- About section: `SettlivLogomark` CustomPainter (circle + diagonal ribbon) + SETTLIV wordmark + version + hairline watermark
- Brand block: `AppConfig.versionString` = "Version 0.2 (build 1)"

**C. Help & Feedback**
- `FeedbackReport` model, `FeedbackType` enum
- `HelpFeedbackDialog` with validation, device-info toggle, double-tap guard
- Local queue in SharedPreferences (`feedbackReports`)
- `ReportsQueueSheet` with copy + email (mailto) + delete
- `kFeedbackEmail = 'feedback@settliv.app'`

**D. Screen Lock (WebAuthn)**
- Abstract `DeviceAuth` interface + web impl + stub + `FakeDeviceAuth` for tests
- `ScreenLockNotifier` Riverpod notifier with enable/disable/unlock/setTimeout
- `LockScreen` widget: auto-prompt, error display, erase-all confirmation
- Gated in `main.dart` builder via `screenLockProvider`

**E. Motion Polish**
- `AnimatedSection` widget: fade + 8px rise, 240ms easeOut, once per lifetime, `disableAnimations`-aware
- Applied to MonthRecapCard, Debts & Settlements, Your Spending, SpendingCalendar in Insights
- `TweenAnimationBuilder` grow-in on savings goals progress bars
- `HapticFeedback.selectionClick()` on tab switches and period chips
- `RepaintBoundary` around SpendingCalendar and SettlivLogomark

**F. Release Polish**
- `web/index.html`: branded SVG loading screen, wordmark animation, flutter-first-frame listener, theme-color tags
- PhoneFrame hint: dismissible, persisted in SharedPreferences (`settliv_phone_frame_hint_dismissed`)

**G. QA + Docs**
- `NOTES.md` created with full QA checklist and known limitations
- `README.md` updated: removed Replit/port-3000, added build/deploy instructions
- `DEPLOY.md` updated: Vercel steps, screen lock caveat, routing note

### Test results at completion:
- `flutter analyze` → 0 issues
- All test files pass


---

## Final Polish — Set 1 (Functional & Correctness)
- [x] **Item 6 (Add Expense Quick + Manual)**: Constrained desktop dialog height to `viewportHeight - 48` with fixed header, scrolling body, and pinned footer; replaced long button labels with `"Add expense"` / `"Add ₹X to <Group>"` (`FittedBox` scaleDown, min height 48); made primary button always tappable with post-attempt validation, auto-focus/scroll to amount, Enter-to-submit, and optional description.
- [x] **Item 11 (Reactive Single Source of Truth)**: Fixed `appRepositoryProvider` identity trap by making all derived providers watch `appStateProvider` and return `List.unmodifiable(...)`; added `currentUserProvider`; removed duplicate `sharedPreferencesProvider` in `experience_mode.dart`; made `themeModeProvider` read `sharedPreferencesProvider` synchronously. Providers fixed: `currentUserProvider`, `userOverallBalanceProvider`, `allGroupsProvider`, `groupProvider`, `groupSummaryProvider`, `allExpensesProvider`, `allSettlementsProvider`, `groupExpensesProvider`, `allPeopleProvider`, `personProvider`, `allRecurringTemplatesProvider`, `allIouNotesProvider`, `allSavingsGoalsProvider`, `allFeedbackReportsProvider`, `experienceModeProvider`, `themeModeProvider`.
- [x] **Item 2 (FeatureComingSheet & Containment)**: Added reusable `FeatureComingSheet` with settle-orbit motif and `AdaptivePresenter` `maxWidth: 440` support (sheet inside PhoneFrame, centered dialog on Web); gated WebAuthn behind `AppConfig.kScreenLockEnabled = false` so Screen & biometric lock opens `FeatureComingSheet` calmly.
- [x] **Item 1 (App Net Position Hero Light Mode)**: Updated `SettlivThemeExtension.light` `heroMeshStart`/`End`/`Accent` to pearl-lavender (`#EAE8FA` -> `#DFDCF6`) and `BalanceHeroCard` to use `theme.ink`/`theme.muted`/`theme.textEmerald`/`theme.textCoral` in light mode while keeping dark mode untouched.
- [x] **Tests Added**: `test/final_polish_set1_test.dart` covering Manual validation & add, reactive profile/expense/balance updates, `FeatureComingSheet` PhoneFrame containment, and AA contrast in both themes.


---

## Final Polish — Set 2 (Web Layout Polish)
- [x] **Item 3 (Compatibility Preview Message)**: Removed `FirstVisitCompatibilityCard` from PC desktop web (`_buildMediumWeb`, `_buildExpandedWeb`) and PC phone frame; replaced compact web / phone touch toast with `CompatibilityPreviewSheet` (scrim, 24px radius, safe-area, 3 code-drawn wireframe tiles, `"Got it"` + `"View layouts"`).
- [x] **Item 10 (PC Web Settings)**: Removed left section list (`Account & Theme`, etc.); built 1040px two-column layout with sticky profile summary card on left (avatar, name, UPI status, Edit profile, current layout), continuous sections on right, and far-right dot progress rail with tooltips and jump-to-section.
- [x] **Item 4 ("This month" Web Card)**: Created `ThisMonthWebCard` with month header, count-up amount, sensible delta line, `CustomPainter` cumulative spend chart (solid + area, dashed last month, today dot, hover tooltip), Daily average & Biggest expense stats; removed purple bar.
- [x] **Item 5 (Day-Countdown Dial)**: Enlarged dial to 86px, computed inner clear box inside tick/arc ring, wrapped center `"N / days left"` in `MediaQuery.withNoTextScaling` + `FittedBox.scaleDown` for guaranteed clearance.
- [x] **Items 8 & 9 (Sidebar Wordmark & Add Expense Button)**: Enlarged sidebar wordmark to 22px (`0.28em` tracking) aligned with nav icons in a 72px header + optically centered rail/compact wordmarks; redesigned `_SidebarAddExpenseButton` (48px, deep ink vertical tonal gradient, 1px top highlight, glass circle `+`, Plus Jakarta Sans 600, hover lift + transform sheen, 0.98 press scale, focus ring, rail tooltip).


---

## Final Polish — Set 3 (Motion, Loading & Final QA)
- [x] **Item 7 (App <-> Web Transition)**: Created `ExperienceTransitionOverlay` (650ms transform/opacity circle expansion from tapped tile + converging settle-orbit motif + target layout name, no BackdropFilter, 150ms cross-fade in reduced motion/lite mode); added short reverse settle in `ExperienceShell` and triggered from `ExperienceSettingsSection`.
- [x] **Item 13 (First Loading Screen)**: Upgraded `web/index.html` CSS splash and added matching `SettleOrbitSplash` / `SettleOrbitSplashGate` (`#070914` dark palette, `min(60vw, 60vh)` orbit scene, expanding rings, orbiting emerald/coral nodes, `32–44px` SETTLIV wordmark sweep, thin progress hairline, 900ms min visible time, static reduced-motion state).
- [x] **Item 12 (Spending Calendar Size)**: Capped PC Web `SpendingCalendar` at `maxWidth: 440` with `38px` compact cells and day hover tooltips, paired in a balanced bento row beside `CategoryBreakdown` in `InsightsWebView`.
- [x] **Final QA**: Added `test/final_polish_set3_test.dart` covering transition overlay, 360px/1920px splash, 440px calendar, and Add Expense across 320px@1.3x and PhoneFrame contexts; refreshed `README.md`.
