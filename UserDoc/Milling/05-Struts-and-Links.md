# 05 — Struts & Links

Struts (also called links) connect the implant to the raw part or bridge between milling features
so the part stays attached — and machinable — through the whole job.

## Placing struts manually

**AddManual Strut** (Extended Settings) arms a placement tool — click on the implant/raw part to
drop a strut there. A newly placed strut starts out using the session's current bulk strut
defaults (count, shape, orientation, sizing) — see
[10 — Extended Settings](10-Extended-Settings.md) — before any of its own per-strut overrides
below are applied.

> 🖼️ *Screenshot: manual strut placement.*

## Editing a strut

Each strut has its own context menu (right-click, or the per-strut settings panel) covering:

- **Shape** — round or rectangular cross-section, with the matching dimension fields (diameter, or
  width/height).
- **Orientation** and **shift value** along the contour.
- **Mill bone side** / **Mill opposite side** — independent toggles for whether each side of the
  strut gets machined.
- **Offset** — how far the strut's milling extends outward.

A strut can also be repositioned or rotated directly with the interactive transform gizmo in the
3D view; editing its shape afterward keeps that manual placement rather than resetting it.

> 🖼️ *Screenshot: strut context menu with shape/orientation/mill-side fields.*
