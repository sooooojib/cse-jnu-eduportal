---
name: Emerald Scholar
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#3d4a42'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#6d7a72'
  outline-variant: '#bccac0'
  surface-tint: '#006c4a'
  primary: '#006948'
  on-primary: '#ffffff'
  primary-container: '#00855d'
  on-primary-container: '#f5fff7'
  inverse-primary: '#68dba9'
  secondary: '#5c5f61'
  on-secondary: '#ffffff'
  secondary-container: '#e0e3e5'
  on-secondary-container: '#626567'
  tertiary: '#5c5b5f'
  on-tertiary: '#ffffff'
  tertiary-container: '#757478'
  on-tertiary-container: '#fffbff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#85f8c4'
  primary-fixed-dim: '#68dba9'
  on-primary-fixed: '#002114'
  on-primary-fixed-variant: '#005137'
  secondary-fixed: '#e0e3e5'
  secondary-fixed-dim: '#c4c7c9'
  on-secondary-fixed: '#191c1e'
  on-secondary-fixed-variant: '#444749'
  tertiary-fixed: '#e4e1e6'
  tertiary-fixed-dim: '#c8c5ca'
  on-tertiary-fixed: '#1b1b1e'
  on-tertiary-fixed-variant: '#47464a'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
  auth-gradient: 'linear-gradient(135deg, #f1f2f1 0%, #f6f5ea 50%, #f0dfa1 100%)'
  canvas-gray: '#A4ADB4'
  student-bg: '#ecfdf5'
  student-text: '#047857'
  student-border: '#a7f3d0'
  teacher-bg: '#eff6ff'
  teacher-text: '#1d4ed8'
  teacher-border: '#bfdbfe'
  cr-bg: '#fff7ed'
  cr-text: '#c2410c'
  cr-border: '#fed7aa'
  admin-bg: '#faf5ff'
  admin-text: '#7e22ce'
  admin-border: '#e9d5ff'
  terminal-glow: '#34d399'
typography:
  display-terminal:
    fontFamily: JetBrains Mono
    fontSize: 72px
    fontWeight: '700'
    lineHeight: 80px
    letterSpacing: 0.25em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 38px
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  auth-input:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  input-height: 52px
  auth-card-max-width: 900px
  gutter: 1.5rem
  margin-mobile: 1rem
  margin-desktop: 2.5rem
---

## Brand & Style

This design system is built for a modern academic environment, specifically tailored for Computer Science and Engineering. It balances the precision of a technical field with the approachability of a contemporary educational platform.

The aesthetic follows a **Corporate / Modern** framework infused with **Glassmorphic** accents. It prioritizes clarity, information density, and rapid role-based recognition. The interface uses a clean, high-contrast approach for core data, while employing soft gradients and glowing elements for brand identity and high-importance status events like live attendance.

**Key Visual Pillars:**
- **Role-Based Context:** Immediate orientation through specific color-coding (Student, Teacher, CR, Admin).
- **Academic Precision:** Use of monospace elements for codes and terminals to reflect the technical nature of the department.
- **Fluid Efficiency:** Soft, pill-shaped interactive elements that reduce visual friction in high-frequency form filling.

## Colors

The palette is centered around **Emerald-600**, representing growth and the University's identity. 

- **Primary (Emerald):** Used for primary actions, branding, and student-role indicators.
- **Canvas (Slate & White):** A clean `Slate-50` background provides a soft foundation, while `Pure White` is reserved for elevated cards to ensure maximum legibility.
- **Surface (Zinc):** `Zinc-900` (Obsidian) is used for the Attendance Terminal to create a focused, high-contrast "dark mode" experience within the light interface.
- **Role Accents:** Four distinct color pairings (Emerald, Blue, Orange, Purple) are used to label and theme sections based on the user's role. These must be applied to backgrounds, borders, and text consistently.
- **Auth Shell:** Employs a specific tri-color linear gradient on a neutral gray canvas to distinguish the authentication flow from the internal application dashboard.

## Typography

The typography system uses **Plus Jakarta Sans** for its friendly yet professional geometry. 

- **Hierarchy:** Headlines use semi-bold and bold weights to establish clear structure. Large display sizes are reserved for the Auth flow and critical headers.
- **Terminal Display:** For attendance codes and terminal outputs, use a monospaced font (JetBrains Mono) with increased tracking to simulate a digital readout.
- **Contextual Styles:**
    - **Password Inputs:** Use `tracking-widest` to ensure masking bullets are clearly legible.
    - **Error Messages:** Set in `body-sm` with a medium weight to ensure visibility without overwhelming the layout.

## Layout & Spacing

The layout follows a **Hybrid Grid** model:
- **Auth Shell:** Centered split-panel layout (50/50) for login and registration, maximizing visual impact with illustrations on one side and forms on the other.
- **Main Dashboard:** A 12-column fluid grid. Common patterns include a 5-column grid for metrics cards and a 66%/33% split for main content and the "floating island" sidebar.
- **Spacing Rhythm:** Standard 8px (0.5rem) increments. Form elements are intentionally taller (52px) to provide a more touch-friendly and modern feel.

**Breakpoints:**
- **Mobile (<768px):** Single column, margins reduced to 16px. Sidebars transform into bottom-sheet or drawer navigation.
- **Desktop (>1024px):** Fixed sidebar with fluid content area.

## Elevation & Depth

This design system uses **Tonal Layering** and **Glassmorphism** instead of traditional heavy shadows.

- **Surface Tiers:** The background is `Slate-50`. Primary containers (Cards) are `Pure White` with a subtle 1px border.
- **The Emerald Glow:** High-priority items or active brand elements utilize an `emerald-600` glow (soft, diffused shadow with 30% opacity) to signify focus without adding visual weight.
- **Glassmorphism:** Auth inputs use a semi-transparent white background (`rgba(255, 255, 255, 0.7)`) with a solid 1px white border, creating depth against the brand gradients.
- **Terminal Depth:** The Attendance Terminal uses a "Pod" concept—a semi-transparent dark overlay (`rgba(2, 44, 43, 0.5)`) on an Obsidian background to create an immersive, recessed feel.

## Shapes

The shape language is defined by extreme roundedness for interactive elements and generous radii for containers.

- **Containers:** Large Auth cards use a specific **40px (2.5rem)** radius to feel soft and approachable. Standard dashboard cards use **12px (xl)**.
- **Interactive Elements:** All buttons and input fields must be **Pill-shaped (rounded-full)**. This creates a distinct "app-like" feel that differentiates it from traditional academic portals.
- **Emphasis:** "Assigned Course" cards feature a **top-heavy border (4px)** to provide a color-coded accent that identifies the role or category at a glance.

## Components

### Buttons
- **Primary:** Pill-shaped, Emerald-600 background, white text. Transitions to Emerald-700 on hover.
- **Quick Action:** Dashed border with centered icon and label, used for adding items or secondary choices.

### Form Fields
- **Inputs:** Height of 52px, pill-shaped. Background is semi-transparent white (in Auth) or pure white (in Dashboard). Borders use Emerald-200 for focus states.
- **Labels:** Floating or top-aligned labels using `label-md`.

### Cards & Chips
- **Dashboard Cards:** White background, 12px radius, subtle border.
- **Role Badges (Chips):** Use the role-based color palette (e.g., Student: Emerald-50 bg, Emerald-700 text, Emerald-200 border). These are always pill-shaped.

### Attendance Terminal
- A specialized component using an Obsidian background, terminal-glow text, and monospace typography. It should feel distinct from the rest of the management interface.

### Navigation
- **Sidebar:** A "floating island" sidebar with `rounded-xl` corners. Active states use Emerald-50 background and Emerald-600 text/iconography.