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



