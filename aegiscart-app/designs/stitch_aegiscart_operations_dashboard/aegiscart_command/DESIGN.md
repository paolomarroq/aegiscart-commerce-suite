---
name: AegisCart Command
colors:
  surface: '#031427'
  surface-dim: '#031427'
  surface-bright: '#2a3a4f'
  surface-container-lowest: '#000f21'
  surface-container-low: '#0b1c30'
  surface-container: '#102034'
  surface-container-high: '#1b2b3f'
  surface-container-highest: '#26364a'
  on-surface: '#d3e4fe'
  on-surface-variant: '#c7c4d8'
  inverse-surface: '#d3e4fe'
  inverse-on-surface: '#213145'
  outline: '#918fa1'
  outline-variant: '#464555'
  surface-tint: '#c3c0ff'
  primary: '#c3c0ff'
  on-primary: '#1d00a5'
  primary-container: '#4f46e5'
  on-primary-container: '#dad7ff'
  inverse-primary: '#4d44e3'
  secondary: '#d2bbff'
  on-secondary: '#3f008e'
  secondary-container: '#6001d1'
  on-secondary-container: '#c9aeff'
  tertiary: '#ffb695'
  on-tertiary: '#571f00'
  tertiary-container: '#a44100'
  on-tertiary-container: '#ffd2be'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e2dfff'
  primary-fixed-dim: '#c3c0ff'
  on-primary-fixed: '#0f0069'
  on-primary-fixed-variant: '#3323cc'
  secondary-fixed: '#eaddff'
  secondary-fixed-dim: '#d2bbff'
  on-secondary-fixed: '#25005a'
  on-secondary-fixed-variant: '#5a00c6'
  tertiary-fixed: '#ffdbcc'
  tertiary-fixed-dim: '#ffb695'
  on-tertiary-fixed: '#351000'
  on-tertiary-fixed-variant: '#7b2f00'
  background: '#031427'
  on-background: '#d3e4fe'
  surface-variant: '#26364a'
typography:
  display-lg:
    fontFamily: Sora
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Sora
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Sora
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-md:
    fontFamily: Sora
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  ui-bold:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '700'
    lineHeight: 24px
  ui-medium:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
  body-base:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-xs:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.05em
  code-sm:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 20px
  code-xs:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '400'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 16px
  lg: 24px
  xl: 32px
  gutter: 24px
  sidebar_width: 280px
  max_content_width: 1440px
---

## Brand & Style
The design system is engineered for high-stakes ecommerce management, emphasizing security, traceability, and operational precision. It adopts a **Modern B2B SaaS** aesthetic that leans into a "Command Center" feel—clean, structured, and technically sophisticated.

The visual narrative focuses on reliability and real-time control. By utilizing a deep midnight foundation contrasted with vibrant indigo and violet accents, the interface evokes a sense of advanced monitoring and data integrity. The style avoids unnecessary decoration, favoring functional clarity and a systematic approach to information density.

## Colors
The palette is rooted in a deep **Midnight Blue** (#0D1B2A) to provide a high-contrast environment for data visualization and monitoring.

- **Primary & Secondary:** A gradient of Indigo (#4F46E5) and Violet (#7C3AED) identifies primary actions and active states, signifying intelligence and flow.
- **Accent:** Pink (#EC4899) is reserved strictly for alerts, highlights, and critical data points requiring immediate attention.
- **Surfaces:** Content containers use a lighter navy (#1B263B) to create depth against the background.
- **Text:** White is used for maximum legibility on headlines, while Gray (#64748B) is used for secondary metadata and inactive labels.

## Typography
This design system utilizes a tiered typographic approach to separate high-level metrics from operational data.

- **Headlines:** Sora is used for all titles and large metrics to provide a modern, geometric, and authoritative feel.
- **UI & Body:** Inter serves as the workhorse font for labels, inputs, and general interface text, set at Medium weight for UI elements to ensure clarity at small sizes.
- **Technical Logs:** JetBrains Mono is used exclusively for transaction IDs, SKU numbers, security logs, and developer-facing data to reinforce the traceability aspect of the brand.

## Layout & Spacing
The layout follows a **Fixed-Fluid hybrid grid** system. The primary navigation sidebar remains fixed at 280px, while the main content area utilizes a 12-column fluid grid.

- **Rhythm:** An 8px base unit governs all padding and margins to maintain strict mathematical alignment.
- **Gutter & Margin:** 24px gutters are standard for desktop layouts to provide sufficient breathing room between dense data modules.
- **Breakpoints:**
  - **Mobile (<768px):** Sidebar collapses into a drawer; margins reduce to 16px; 4-column grid.
  - **Tablet (768px - 1024px):** 8-column grid; 24px margins.
  - **Desktop (>1024px):** Full 12-column grid; 280px sidebar.

## Elevation & Depth
Depth is created through **Tonal Layering** and subtle ambient shadows rather than heavy skeuomorphism.

- **Base Layer:** Midnight Blue (#0D1B2A) - Background.
- **Secondary Layer:** Indigo-tinted Navy (#1B263B) - Card backgrounds and sidebar.
- **Hover Layer:** #243049 - Interactive states for cards and list items.
- **Shadows:** Use extremely soft, low-opacity indigo-tinted shadows (e.g., `rgba(0, 0, 0, 0.4)`) with a high blur radius (12px - 24px) to make modal elements appear as if they are floating above the surface without breaking the flat, technical aesthetic.

## Shapes
The design system uses a **Rounded** (Level 2) shape language to balance the technical "hardness" of the data with a modern, approachable SaaS feel.

- **Standard Elements:** Buttons, inputs, and small cards use a 0.5rem (8px) radius.
- **Large Components:** Dashboard containers and primary modals use a 1rem (16px) radius.
- **Status Pills:** Use a full pill radius (999px) to distinguish them from interactive buttons.

## Components
Consistent component styling ensures the dashboard feels like a unified operational tool.

- **Buttons:** Primary buttons use a solid Indigo (#4F46E5) fill. Secondary buttons use a ghost style with an Indigo border and transparent background.
- **Inputs:** Fields use the surface color (#1B263B) with a subtle border. On focus, the border transitions to Primary Indigo with a soft outer glow.
- **Cards:** Dashboard modules should have a subtle 1px border (#243049) to define their boundaries against the background.
- **Activity Logs:** Use JetBrains Mono for log text, organized in a condensed list format with vertical lines to indicate traceability paths.
- **Chips/Status:** Use low-saturation backgrounds with high-saturation text for status indicators (e.g., a "Secure" status uses a deep green tint with bright green text).
- **Icons:** Linear 2px stroke icons are preferred for their precision and clarity. Use primary or neutral colors for icons, reserving accent colors for error or warning states.