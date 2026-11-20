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
- [ ] 2a. Quick Tab overhaul (rotating examples placeholder, live parse preview, disabled until valid, draft card).
- [ ] 2b. Suggestion threshold logic (Repeat row appears only for descriptions logged 3+ times).
- [ ] 2c. Manual Tab validation on save (amount rules, required description <= 60 chars, category, participants, exact & percent split validation).
- [ ] 2d. Duplicate guard within 2 minutes.
- [ ] 2e. Expense Detail sheet (shares breakdown, Edit reopening prefilled, soft Delete with 5s Undo).
- [ ] 2f. Vertical layout stability and keyboard handling.
- [ ] 2g. Tests for Quick parser, validation, duplicate guard, and suggestion threshold.

---

## Part 3: Floating Bar, New Screens, Settle Flow, Final QA
- [ ] 3a. Floating bottom bar (pill shape, frosted layer, slots: Home, Groups, [+], Activity, You).
- [ ] 3b. Home screen refinement (greeting, hero balance, groups, recent activity, empty/all-settled states).
- [ ] 3c. Groups screen with in-memory "New group".
- [ ] 3d. Activity screen with search and "All groups" filter.
- [ ] 3e. Settle flow polish (partial settle, simulated UPI label, double-tap guard, Undo).
- [ ] 3f. Nudge sheet polish and clipboard copy.
- [ ] 3g. Final QA pass in light/dark at 360x640, 390x844, and desktop; release web build.
