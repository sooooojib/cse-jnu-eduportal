# `mobile/lib/shared/` — Design System UI Component Library Guide

In Flutter Clean Architecture, the **`mobile/lib/shared/`** directory ([`mobile/lib/shared/`](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/shared)) is the **Design System UI Component Library** of the mobile app.

While **`app/theme/`** defines raw design tokens (colors, font styles, radii) and **`features/`** builds specific screens, **`shared/` provides ready-to-use, pre-styled widgets** so developers never have to write raw Flutter buttons, text fields, or cards from scratch.

---

## 📁 Directory Layout of `mobile/lib/shared/`

```text
mobile/lib/shared/
├── presentation/
│   └── foundation_preview_screen.dart   # Interactive Living Design Catalog (Storybook)
│
└── widgets/
    ├── buttons/                         # Standardized Emerald Buttons
    │   ├── app_primary_button.dart
    │   ├── app_secondary_button.dart
    │   └── app_text_button.dart
    │
    ├── cards/                           # Rounded Surface Cards & Role Chips
    │   ├── app_card.dart
    │   ├── assigned_course_card.dart
    │   └── role_badge_chip.dart
    │
    ├── inputs/                          # Form Fields & Text Inputs
    │   └── app_text_field.dart
    │
    ├── states/                          # Loading, Empty & Error Views
    │   ├── app_loading_view.dart
    │   ├── app_empty_state_view.dart
    │   └── app_error_state_view.dart
    │
    ├── dialogs/                         # Modals & Confirmations
    │   ├── app_dialog.dart
    │   └── app_confirmation_dialog.dart
    │
    └── theme/                           # Quick Theme Toggle Elements
        ├── theme_toggle_button.dart
        └── theme_mode_selector_card.dart
```

---

## 1. 🎛️ Interactive Design Catalog (`shared/presentation/`)

* **`foundation_preview_screen.dart`**:
  * Acts like an in-app **Storybook / Living Style Guide**.
  * Accessible via the `/foundation-preview` route.
  * Showcases all color palettes, typography scales, primary/secondary buttons, input error validations, role chips, and dialogs in both light and dark themes.

---

## 2. 🔘 Button Suite (`shared/widgets/buttons/`)

All buttons follow the **Emerald Scholar** design specification with pill shapes (`StadiumBorder`) and built-in native micro-interactions:

* **`app_primary_button.dart`**:
  * Fixed 52px height matching mobile thumb ergonomics.
  * **Haptic Feedback**: Automatically triggers `HapticFeedback.lightImpact()` on tap.
  * **Loading State**: When `isLoading: true`, smoothly replaces button text with a centered `CircularProgressIndicator` and disables duplicate taps.
* **`app_secondary_button.dart`**:
  * Outlined stadium border for secondary screen actions (e.g. "Cancel" or "Save Draft").
* **`app_text_button.dart`**:
  * Minimalist borderless button for tertiary links (e.g. "Forgot password?", "Skip").

```dart
// Example usage across any feature screen
AppPrimaryButton(
  text: 'Verify 6-Digit Code',
  isLoading: state.isSubmitting,
  onPressed: () => controller.submitCode(),
)
```

---

## 3. 🃏 Cards & Badges (`shared/widgets/cards/`)

* **`app_card.dart`**:
  * Unified surface container with a 16px corner radius and subtle outline border.
  * Supports an optional `onTap` callback that wraps the card in a smooth `InkWell` ripple effect.
* **`role_badge_chip.dart`**:
  * Small, colored pill badge displaying the user's role:
    * 🟢 Student
    * 🟣 Class Representative (CR)
    * 🔵 Professor / Faculty
    * 🔴 Administrator
* **`assigned_course_card.dart`**:
  * Academic card displaying Course Code (e.g. `CSE-3101`), Course Title, and Credit hours with quick status indicators.

---

## 4. ✍️ Form Inputs (`shared/widgets/inputs/`)

* **`app_text_field.dart`**:
  * Unified text field that adheres to the Material 3 Emerald theme.
  * Built-in support for:
    * Custom label text and floating hints.
    * Prefix icons (e.g., mail icon, lock icon).
    * Password toggle: automatically displays an eye icon to toggle obfuscated text.
    * Form validation error display (`validator`).

---

## 5. ⏳ Feedback & State Views (`shared/widgets/states/`)

Prevents screens from repeating boilerplate loading spinners or error messages:

* **`app_loading_view.dart`**: Centered circular loading indicator with optional progress message.
* **`app_empty_state_view.dart`**: Clean vector illustration and helper message displayed when a list is empty (e.g., "No scheduled classes today").
* **`app_error_state_view.dart`**: Displays a warning icon, human-readable error description, and a "Retry" button that re-triggers the data fetch.

---

## 6. 💬 Modals & Dialogs (`shared/widgets/dialogs/`)

* **`app_dialog.dart`**: Base modal dialog with unified rounded corners and consistent padding.
* **`app_confirmation_dialog.dart`**: Standardized dialog for critical or destructive decisions (e.g., "Are you sure you want to end this attendance session?").

---

## 7. 🌓 Theme Widgets (`shared/widgets/theme/`)

* **`theme_toggle_button.dart`**: Sun/moon icon button placed in app bars for instant switching between light and dark mode.
* **`theme_mode_selector_card.dart`**: Radio-selection card allowing users to pick **Light**, **Dark**, or **System Default** in their profile settings.

---

### Why `shared/` is Crucial:
1. **Consistency**: Changes to button styling, radii, or borders update across the entire app instantaneously.
2. **Zero Code Duplication**: Screens in `features/` remain lean and concise, focusing purely on layout and business data.
