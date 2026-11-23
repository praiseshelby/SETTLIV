# Settliv — QA Notes & Release Findings

> Generated: 2026-11-23 | Build: 0.2+1

---

## QA Checklist Results

### Themes
- [x] Light theme — all screens, no raw color values (`flutter analyze` token scan passes)
- [x] Dark theme — accent, emerald, coral, navy all use theme-extension tokens; hairline adapts correctly

### Viewport Sizes
- [x] 390px (compact/phone) — bottom-sheet presenter, single-column layout, no overflow
- [x] 768px (medium) — icon rail sidebar, two-column forms where applicable
- [x] 1440px (wide/desktop) — full two-pane layout, desktop nav rail, bento grid on Insights web view
- [x] App-in-frame 1440×900 — PhoneFrame renders at 390×844 with MediaQuery override; all routes constrained to frame

### Experience Switching
- [x] Web → App → Web: state preserved, route stays, no double-push
- [x] Deep link `/settings?section=experience` scrolls to Experience section with highlight pulse
- [x] App-in-frame hint (PhoneFrame) dismissible; preference persisted in SharedPreferences (`settliv_phone_frame_hint_dismissed`)

### Screen Lock
- [x] Toggle appears only when WebAuthn is available (secure context + platform authenticator)
- [x] On plain HTTP / unavailable: toggle is disabled with explanation text
- [x] Timeout options: 1 min, 5 min, 15 min, 30 min, Never
- [x] Lock screen auto-prompts on first view; erase-all confirmation is double-confirmed
- [x] Unit tests use `FakeDeviceAuth`; no real biometric/PIN called in test suite

### Insights & Spending Calendar
- [x] Overview tab: MonthRecapCard (plain-language sentences), SpendingCalendar (day-intensity grid, tap-to-sheet)
- [x] Budgets tab: embeds PlanScreen without scaffold; RecurringDuesSection + SavingsGoalsSection
- [x] Segmented control taps trigger `HapticFeedback.selectionClick()`
- [x] SpendingCalendar wrapped in `RepaintBoundary`

### Savings Goals
- [x] Create / contribute / withdraw / delete — all update SharedPreferences
- [x] Animated progress bar (TweenAnimationBuilder, 300ms easeOutCubic, keyed by goal id)
- [x] Achieved state shown with emerald color and "Goal achieved!" badge
- [x] No goal data in backup export (privacy)

### Help & Feedback
- [x] Report a problem / Request a feature forms with validation
- [x] Device info toggle (opt-in)
- [x] Local queue in `feedbackReports` SharedPreferences key
- [x] "Your reports" sheet: copy text, send via mailto, delete
- [x] Email button shown (kFeedbackEmail = 'feedback@settliv.app')

### Logomark
- [x] `SettlivLogomark` CustomPainter: circle with diagonal ribbon band, single colour, `RepaintBoundary`
- [x] Shown above SETTLIV wordmark in Settings About/brand block

### Motion
- [x] `AnimatedSection`: fade + 8px rise, 240ms easeOut, once per widget lifetime, respects `disableAnimations`
- [x] Applied to: MonthRecapCard, Debts & Settlements, Your Spending, SpendingCalendar in Insights
- [x] Progress bar grow-in: TweenAnimationBuilder on savings goals (0 → actual value)
- [x] No looping animations anywhere (except Quick-tab typewriter which was pre-existing)
- [x] No BackdropFilter in lists

### Release Polish
- [x] `web/index.html`: branded SVG loading screen, wordmark animation, flutter-first-frame listener
- [x] Page title: "Settliv — Expense Sharing & Group Ledger"
- [x] Meta description, Open Graph tags, theme-color (light + dark)
- [x] Phone-frame prototype note: dismissible, remembered via SharedPreferences

### Back Control
- [x] GoRouter handles browser back button on web
- [x] All routes have back navigation (AppBar back or custom back gesture in settings)
- [x] Modal sheets dismiss on swipe-down and Escape key on web

---

## Known Limitations

| Area | Limitation |
|---|---|
| **Screen Lock** | WebAuthn requires a secure context (HTTPS or `localhost`). On plain HTTP the toggle is disabled. No fallback PIN by design. |
| **Spending Calendar** | Shows current month only (no month-navigation in this version). |
| **Savings Goals** | Stored locally in SharedPreferences; not synced across devices or included in ledger backup. |
| **Feedback Reports** | No backend: reports are stored locally and can be emailed manually. No tracking or analytics. |
| **WebAuthn Credential** | Credential ID is stored in SharedPreferences; re-registration required if prefs are cleared. |
| **Motion — AnimatedSection** | Animates once per widget lifetime. Page reload re-triggers animations (acceptable for prototype). |
| **App-in-frame MediaQuery** | Frame overrides size to 390×844. If the viewport is very short (< 844px height), FittedBox scales the frame; content inside still sees 390×844. |
| **Category Donut** | Custom painter; not interactive via keyboard (hover/tap only). |
| **Recurring** | Templates are pre-seeded only; creation UI is in the Manage Recurring sheet (Settings). Auto-posting is intentionally disabled. |

---

## Build Info

- Flutter channel: stable
- Build command: `flutter build web --release --no-web-resources-cdn`
- Output: `build/web/`
- Deploy: copy `vercel.json` into `build/web/`, then `npx vercel --prod --yes` from `build/web/`

---

## Test Results (last run)

```
flutter analyze → No issues found
flutter test    → All tests pass
                  theme_token_scan_test.dart     → pass
                  balance_engine_test.dart        → pass
                  extended_features_test.dart     → pass
                  part_s3_verification_test.dart  → 10/10 pass
```
