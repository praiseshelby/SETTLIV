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
- [ ] 3a. Floating bottom bar (pill shape, frosted layer, slots: Home, Groups, [+], Activity, You).
- [ ] 3b. Home screen refinement (greeting, hero balance, groups, recent activity, empty/all-settled states).
- [ ] 3c. Groups screen with in-memory "New group".
- [ ] 3d. Activity screen with search and "All groups" filter.
- [ ] 3e. Settle flow polish (partial settle, simulated UPI label, double-tap guard, Undo).
- [ ] 3f. Nudge sheet polish and clipboard copy.
- [ ] 3g. Final QA pass in light/dark at 360x640, 390x844, and desktop; release web build.
