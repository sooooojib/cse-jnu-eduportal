# UI/UX & Emerald Scholar Design System

## 1. Design System Foundations

The **CSE JnU EduPortal** UI is built on the **Emerald Scholar** design language. It bridges clinical academic rigor with modern, tactile mobile aesthetics.

```
       ┌────────────────────────────────────────────────────────┐
       │             EMERALD SCHOLAR DESIGN SYSTEM              │
       ├────────────────────────────────────────────────────────┤
       │  • Primary Brand: Emerald (#006948)                    │
       │  • Terminal Canvas: Obsidian (#18181B) + Mint Glow     │
       │  • Typography: Plus Jakarta Sans + JetBrains Mono      │
       │  • Geometry: Rounded-3xl Cards & Pill Buttons (52px)   │
       │  • Theme Support: Light & Dark Modes                   │
       └────────────────────────────────────────────────────────┘
```

---

## 2. Color Palette & Token Specifications

### 2.1 Core Brand & Canvas Tokens
| Token Name | Hex Code | Purpose / Application |
| :--- | :--- | :--- |
| `primary` | `#006948` | Primary brand accent, active tabs, main CTAs. |
| `primaryContainer` | `#00855d` | Container surfaces, header highlights. |
| `onPrimary` | `#FFFFFF` | Text on primary surfaces. |
| `surface` (Light) | `#F8F9FF` | Base mobile canvas background in light mode. |
| `surface` (Dark) | `#0B1C30` | Base mobile canvas background in dark mode. |
| `surfaceContainer`| `#E5EEFF` | Nested card containers and section pods. |
| `outlineVariant` | `#BCCAC0` | Subtle card borders and dividers. |
| `error` | `#BA1A1A` | Critical alerts, rejection banners. |

### 2.2 Role Badge Color Matrix
| Role Key | Background | Text | Border | Icon Token |
| :--- | :--- | :--- | :--- | :--- |
| **`STUDENT`** | `#ECFDF5` (Emerald 50) | `#047857` (Emerald 700) | `#A7F3D0` | GraduationCap |
| **`TEACHER`** | `#EFF6FF` (Blue 50) | `#1D4ED8` (Blue 700) | `#BFDBFE` | UserCheck |
| **`CR`** | `#FFF7ED` (Orange 50) | `#C2410C` (Orange 700) | `#FED7AA` | Users |
| **`ADMIN`** | `#FAF5FF` (Purple 50) | `#7E22CE` (Purple 700) | `#E9D5FF` | ShieldAlert |

### 2.3 Attendance Terminal Canvas
- **Background**: `#18181B` (Deep Obsidian Zinc)
- **Glow Pod**: `rgba(2, 44, 34, 0.5)` with Emerald-500 border
- **Code Typography**: `#34D399` glowing text in **JetBrains Mono**, letter-spacing `0.25em`.

---

## 3. Typography Hierarchy

| Style Name | Font Family | Size | Weight | Line Height | Tracking |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `Display Terminal`| JetBrains Mono | 48–72px | Bold (700) | 1.1 | 0.25em |
| `Headline Large` | Plus Jakarta Sans | 30px | Bold (700) | 38px | -0.02em |
| `Headline Medium`| Plus Jakarta Sans | 24px | SemiBold (600)| 32px | -0.01em |
| `Body Large` | Plus Jakarta Sans | 16px | Regular (400)| 24px | normal |
| `Body Small` | Plus Jakarta Sans | 14px | Regular (400)| 20px | normal |
| `Label Medium` | Plus Jakarta Sans | 14px | SemiBold (600)| 20px | 0.01em |
| `Label Small` | Plus Jakarta Sans | 12px | Medium (500) | 16px | 0.02em |
| `Code / Data` | JetBrains Mono | 14px | Regular (400)| 20px | normal |

---

## 4. Interaction & Shape Guidelines

1. **Pill Form Fields & Buttons**:
   - Primary inputs and action buttons maintain a consistent **52px height** and `rounded-full` curvature.
2. **Card Radius Hierarchy**:
   - Standard content cards: `rounded-2xl` (16px) or `rounded-3xl` (24px).
   - Bottom sheets and floating modals: `rounded-t-[32px]`.
3. **Touch Targets & Accessibility**:
   - Minimum tap target of **48×48 dp** for all interactive elements.
   - High-contrast text meeting WCAG AA standards.
