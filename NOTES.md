# Settliv v0 - QA Report & Known Limitations

**Date:** 20 November 2026  
**Version:** Settliv v0 (Functional Correctness Release)  
**Status:** All 67 Unit, Widget, and QA Tests Passed · Zero `flutter analyze` Issues

---

## 1. QA Verification Matrix

### Responsive Form Factors & Typography Scale
- **320x568 (iPhone SE / Small Phone Width)**:
  - Navigation bar adapts with `FittedBox` scale-down and compact padding.
  - Group cards wrap both group name and balance pills with `Expanded`/`Flexible` and ellipsis without overflow.
  - Verified at `textScaler: 1.3`: 0 layout overflows detected.
- **360x640 (Standard Android Small / Budget Device)**:
  - Composer card headers wrap gracefully without overflow.
  - Verified at `textScaler: 1.3`: 0 layout overflows detected.
- **390x844 (Modern Phone Reference)**:
  - Clean floating pill bar with frosted glass background, hairline border, and 52px Sapphire proud center button.
- **Desktop Frame (>600px width)**:
  - Centered mobile frame inside phone bezel with background aurora, SETTLIV wordmark, and prototype note card.
  - Floating navigation bar remains strictly anchored within the phone frame container.

### Theme & Visual Integrity
- **Light & Dark Themes**:
  - Light mode: Clean Pearl surface, high-contrast dark navy typography, subtle glass tinting.
  - Dark mode: Deep midnight base, frosted dark pearl surfaces, crisp contrast on emerald, sapphire, and coral accents.
  - Red is strictly reserved for genuine errors and debt ("you owe"). Idle buttons stay neutral.
- **Rules 7 & 8 (App-wide Polish)**:
  - `SettlivScrollBehavior` hides scrollbars and overscroll glows app-wide on touch, web, and desktop without impeding scrollability.
  - Strict performance limits respected: ≤2 `BackdropFilter`s per screen, static cover art cached in `RepaintBoundary`, no per-frame grain or heavy animations.

### Functional Edge Cases & Validation Matrix
| Scenario | Input | Expected Outcome | Verified Result |
| :--- | :--- | :--- | :--- |
| **Zero Amount** | `0` / `₹0` | Rejected, cannot add or settle | Handled (returns `null`, save/settle blocked) |
| **Negative Amount** | `-50` | Rejected | Handled (returns `null`) |
| **Decimal Amount** | `0.5` | Parsed as 50 paise, formatted as `₹0.50` | Handled (50 paise) |
| **Over-Cap Amount** | `1e18` / `> ₹10,00,00,000` | Hard block with clear notice | Handled (`isOverCap: true`, blocked) |
| **Large Amount Dialog** | `₹1,00,00,000` | Confirmation modal in digits + words | Handled ("₹1,00,00,000 · One crore") |
| **Pasted Junk** | `abc!@#$%^&*` | Cleanly ignored, parser remains robust | Handled (returns `null`, no crash) |
| **Ambiguous Amounts** | `"dinner 200 400"` | Asks instead of guessing | Handled (`isAmbiguous: true`) |
| **3-Way ₹100 Split** | `10000 paise / 3` | Leftover paise assigned to payer first | Handled (payer: ₹33.34, others: ₹33.33 each, sums to ₹100.00) |
| **Rapid Double Taps** | Rapid double press | Blocked by `_isSaving` / `_isSettling` guard | Handled (prevents duplicate requests) |
| **Duplicate Guard** | Same group, amount, title < 2m | "Looks like a duplicate. Add anyway?" dialog | Handled |
| **Repeat Suggestions** | Logged 3+ times in same group | "Repeat" chip appears on Quick tab only | Handled (seed data has 0, dynamic triggers at 3+) |
| **Unknown Routes** | `/non_existent` | Friendly "Page not found" with "Home" button | Handled |
| **Invalid Group ID** | `/group/invalid_id` | Friendly "Group not found" with "Back to Home" | Handled |
| **Back Button / Sheets** | Back press on dirty composer | "Discard changes?" modal confirmation | Handled via `PopScope` |

---

## 3. Settliv Experiences (App + Web) QA Report — Part W1, W2, W3

**Date:** 22 November 2026  
**Status:** 161/161 Tests Passing · 0 `flutter analyze` Issues · Complete Screenshot Pass

### Visual QA Verification Matrix
- **Desktop 1440x900 (Expanded Web)**:
  - **Dashboard (Light & Dark)**: Bento grid layout (Hero Net Position ₹860 span 7, This Month ₹36,239 span 5, Recent Groups span 7, Shortcuts span 5, Recent Activity table span 12). Row clicks open `ExpenseDetailSheet` in an `AdaptivePresenter` right drawer. Invariant and "Paid by you" display verified.
  - **Groups (Light & Dark)**: Responsive 3-column grid of rich group cards with cover art, balance badges, member avatars, and "+ New group" modal dialog.
  - **Records (Light & Dark)**: Live search toolbar, "Filter Records" popover with Group and Category filters, full 7-column table with Sora tabular currency, and drawer inspection.
  - **Insights (Light & Dark)**: Period selector chips, reconciled spend (₹36,239), category bars with light/dark contrast-compliant palette, and spending habits weekday histogram. Back link to `/insights/budgets`.
  - **Add Expense Dialog (Light & Dark)**: Centered dialog presentation with `maxWidth: 960`, cycling placeholder examples, instant parse preview, and Esc key dismissal.
  - **Settings (Light & Dark)**: Two-pane layout with left rail sections and right content pane, Experience card ("Responsive Website ACTIVE"), and large 24px SETTLIV wordmark end block.

- **Compact Web 390x844**:
  - Web header with hamburger menu, `SETTLIV` wordmark, and `+` action.
  - Bento items stacked vertically into responsive cards.
  - No mobile bottom navigation bar rendered (spec compliant).

- **App Mode 390x844 (Touch Device)**:
  - Mobile Home screen: day-period icon and status text removed per W1 small fix (`Sunday, 22 Nov` subline only).
  - Floating pill navigation bar anchored at bottom with 52px proud Sapphire `+` button.
  - Experience setting toggle (App | Web) with phone and browser thumbnail illustrations.

### Defect Audit & Resolutions
- **Brand Consistency**: Zero logomark widgets remain in tree; brand is exclusively the `SETTLIV` wordmark in Bricolage Grotesque ExtraBold with ~0.18em tracking.
- **Overflow / Layout Checks**: Verified at both 1440x900 and 390x844 viewports with text scale 1.3. No layout overflow or clipped currency text.
- **Contrast**: Category palette contrast verified (Rent tile, icon, and donut slices pass ≥3:1 contrast in both light and dark themes).

   - Newly created groups default to either the Goa Trip or Flatmates procedural artistic painter based on group type (`trip` vs `home`/`other`). Custom user image uploading or palette pickers are not yet implemented.
4. **Group Member Editing**:
   - Dynamic group creation allows adding members with arbitrary names (min 2 members, unique names enforced). Editing or removing members from an existing group post-creation is not supported in v0.
5. **Multi-Currency Support**:
   - Fixed to Indian Rupee (INR / ₹) with integer paise precision and Indian numeral grouping (`12,34,567.50`). Cross-currency conversion is out of scope for v0.
