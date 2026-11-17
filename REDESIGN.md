# Settliv UI Redesign Plan & Checklist

## Part A: Foundation + Phone Frame + Home
- [x] A1. Verify fonts render (Manrope bundled in assets and registered in pubspec.yaml).
- [x] A2. Design tokens & theme v2 (Pearl Glass default light, Midnight Glass dark, aurora palette, sapphire anchor, emerald/coral money roles).
- [x] A3. Rebuild shared component kit & update `/gallery`: GlassSurface (3 levels), AuroraBackground, GradientPrimaryButton, GlassSegmented, GlassChip, MoneyText v2, PersonAvatar v2, CategoryTile v2, SectionHeader v2, GroupCoverArt v2, GlassSheetScaffold, FloatingAddPill.
- [x] A4. Refine PhoneFrame (thin graphite bezel, clean SETTLIV wordmark, responsive prototype note cards).
- [x] A5. Redesign Home screen (header with greeting+date, glass hero with count-up & split bar, quick-add card + 3 example chips, glass group cards, unified glass recent activity container, 140px bottom clearance).
- [x] A6. Shorten seed titles (<= 24 chars), implement sentence-case microcopy and motion specs.
- [x] A7. Quality gates: `flutter analyze` 0 issues, `flutter test` passing, `flutter build web --release --base-href /`, check 360/390/430px & desktop.

### Part A Notes:
1. Bundled genuine Manrope variable font in assets/fonts/ with weights 500, 600, 700, 800 registered in pubspec.
2. Built liquid glass tokens & surfaces (3 levels, AuroraBackground, Sapphire gradient CTA, FloatingAddPill).
3. Redesigned Home with 32px rhythm, glass balance hero card, button-style quick-add, and single grouped activity list.
4. Refined PhoneFrame with thin graphite bezel, small SETTLIV wordmark, and responsive prototype notes.
5. Seed titles shortened to <= 24 characters; 0 analyzer issues, 21/21 tests passing, release build verified.

## Part B: Add Expense + Sheets
- [x] B1. Add Expense shell (glass close, GlassSegmented, sticky glass bottom bar, clearance padding).
- [x] B2. Quick tab (glass composer, 4 example chips, hint row, springing DraftCard, dynamic CTA).
- [x] B3. Manual tab (centred amount hero with attached ₹ and blinking caret, description glass input, 4x2 category grid, group segmented + date/payer tiles, All/Clear toggle, Equal/Exact/Percent, CTA, morphing check, glass Undo pill).
- [x] B4. Restyle Expense Detail sheet and Profile/Theme sheet with GlassSheetScaffold.
- [x] B5. Verification: analyze, test, rebuild web release, clickthrough at 360/390/430px in light and dark.

### Part B Notes:
1. Replaced plain modal with Glass shell: circular close, GlassSegmented tab switch, and sticky glass CTA bar with 160px body clearance.
2. Quick tab rebuilt: 140px glass composer, 4 example chips, 3-icon hint row, springing DraftCard with prefilled edit switch.
3. Manual tab refined: attached ₹ prefix hero without gap, 4x2 category tile grid preventing clipping, and quiet All/Clear toggle.
4. Expense Detail, UserProfile, and UndoSnackbar converted to GlassSheetScaffold and floating glass pill.
5. Quality checks verified: 0 analyzer issues, 21/21 tests passing, and release web bundle rebuilt.

## Part C: Group Detail + Settle + Global Polish + Final Build
- [x] C1. Group Detail (collapsing header with cover art v2, glass summary card, trip progress line, GlassSegmented, grouped glass expenses, Balances who-pays-whom + thin bars + gradient donut chart, sticky bottom bar & non-colliding Add pill).
- [x] C2. Settle sheet (GlassSheetScaffold, UPI app picker, simulated ring, confirmation, check ring + confetti celebration, Undo).
- [x] C3. Restyle Coming Soon sheet, tags, empty states to glass system.
- [x] C4. Global audit (8pt rhythm, AA contrast, 60fps performance, light/dark parity, zero overflows).
- [x] C5. Final build: analyze, test, `flutter build web --release --base-href /`, Python zipfile with forward slashes for `Settliv-web.zip`, git commit "redesign".

### Part C Notes:
1. Redesigned Group Detail with AuroraBackground, frosted circular back button, glass summary card, and Day X of Y progress line.
2. Expenses tab unified in GlassSurface with date sections; Balances tab upgraded with simplified who-pays-whom, 6px balance bars, and clean donut chart.
3. SettleSheet converted to GlassSheetScaffold with GPay/PhonePe/Paytm/BHIM glass monogram tiles, simulated 900ms ring, and checkmark + confetti celebration.
4. Upgraded EmptyState and ComingSoonTag to modern glass aesthetic with zero hardcoded colors and full light/dark theme parity.
5. All quality gates passed: 0 analyzer issues, 21/21 tests passing, release web build generated, and Settliv-web.zip packaged with forward slashes.
