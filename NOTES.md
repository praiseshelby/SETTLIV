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

## 2. Honest List of Known Limitations

1. **In-Memory Ledger Storage**:
   - Data persists for the active session in memory. In a future milestone, offline SQLite (`sqflite` or `drift`) or persistent local storage will sync state across cold app restarts.
2. **UPI Payment Execution**:
   - UPI application launch (GPay, PhonePe, Paytm, BHIM) is simulated with clear "Simulated in prototype" badges on screen per assignment constraints. Native UPI deep-linking (`upi://pay`) requires native mobile channels.
3. **Dynamic Group Cover Customization**:
   - Newly created groups default to either the Goa Trip or Flatmates procedural artistic painter based on group type (`trip` vs `home`/`other`). Custom user image uploading or palette pickers are not yet implemented.
4. **Group Member Editing**:
   - Dynamic group creation allows adding members with arbitrary names (min 2 members, unique names enforced). Editing or removing members from an existing group post-creation is not supported in v0.
5. **Multi-Currency Support**:
   - Fixed to Indian Rupee (INR / ₹) with integer paise precision and Indian numeral grouping (`12,34,567.50`). Cross-currency conversion is out of scope for v0.
