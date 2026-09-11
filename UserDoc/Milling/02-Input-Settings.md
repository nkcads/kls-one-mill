# 02 — Input Settings

The Input Settings panel is where a session's fixed context — region, material, machine, fixture
— and the raw part / implant data live. It sits above the 3D viewport.

> 🖼️ *Screenshot: Input Settings panel.*

## Session-wide fields

**Region**, **Material**, **Machine**, and **Fixture** are chosen from dropdowns that filter each
other — the material list reflects what the selected region supports, the machine list reflects
region+material, and so on. **Titan**, **Peek**, and **MultiPurpose** are the available material
types.

Machines (and, by extension, any region/material combination only reachable through one) flagged
as test-only in their configuration are hidden from these lists during normal use — they only
appear once the application is switched into Test mode. The same applies to machining strategies
flagged as test-only. This keeps in-development machine setups out of the way without deleting
them.

Switching the machine re-validates the current workpiece position (hole/csys angle checks against
the new fixture) immediately, rather than waiting for the next **Refresh**.

## Machining strategy selection

Each implant has its own assigned machining strategy (a factory-standard template for the current
machine/material). Changing it updates the session's strategy tree — see
[06 — Strategy Tree & Session](06-Strategy-Tree-and-Session.md) for what that tree shows and how
to adjust individual entries afterward.

## Raw part

The raw part group covers plate dimensions (thickness/width/height) and material — see
[03 — Raw Part & Implant](03-Raw-Part-and-Implants.md).

> 🖼️ *Screenshot: Raw Part group, showing dimensions.*

## Work-piece (implant)

The work-piece group covers loading the implant's file and shows the detected base shape once
loaded.

## Extended Settings

A separate **Extended Settings** panel groups the less-frequently-touched controls: bulk strut
defaults, milling-window/surface offset fields, and the action buttons **AddManual Strut**,
**Generate EdgePlanes**, **Detect Holes**, and **Remove Detected Holes**. See
[10 — Extended Settings](10-Extended-Settings.md) for the full breakdown.

> 🖼️ *Screenshot: Extended Settings panel.*
