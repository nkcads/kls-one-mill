# 10 — Extended Settings

The **Extended Settings** panel holds the controls that don't need to be visible all the time:
bulk strut defaults, the milling-window/surface offsets that shape the generated geometry, and a
small set of administrator tools.

> 🖼️ *Screenshot: Extended Settings panel.*

## Action buttons

- **AddManual Strut** — arms the strut-placement tool; click a point on the implant/raw part to
  drop a strut there. See [05 — Struts & Links](05-Struts-and-Links.md) for placing and editing
  individual struts.
- **Generate EdgePlanes** — builds the chamfer/edge-milling planes for edge-plane milling strategy
  entries, from the raw part's geometry and the configured angle/offset.
- **Detect Holes** *(currently labeled "Detect Holes (Peek-Beta)" in the UI, reflecting its
  current material scope)* — runs automatic hole/csys detection on the current implant.
- **Remove Detected Holes** — clears detection results so it can be re-run after a change.

> 🖼️ *Screenshot: the action buttons in Extended Settings.*

## Strut Settings

This group holds the **bulk defaults** applied to every newly created strut and to a "change all
struts at once" edit:

- **Strut Count** — how many struts a bulk (non-manual) strut generation places.
- **Strut Start-Offset** — where along the contour the first strut is placed.
- **Strut Direction Offset** — shift value along the contour applied to every strut.
- **Strut Geometry Inside** — how far a strut is moved inward from the contour.
- **Strut Orientation** — **MeshNormal** or **MillingPlane**, i.e. whether a strut's own
  orientation follows the implant's mesh surface or the flat milling plane.
- **Strut Shape** — **Round** or **Rectangle**; picking one reveals the matching size fields below
  it (**Strut Size Inner/Outer** for Round, **Strut Size Inner/Outer (w×h)** for Rectangle).
- **NextGenStruts** — selects the newer, more robust strut-generation engine for this session
  instead of the legacy one. Leave this on unless you have a specific reason to fall back to the
  legacy behavior.
- **GeometryCenter** — centers a strut's cross-section on the contour surface rather than the
  older placement method.

> 🖼️ *Screenshot: Strut Settings, Round shape fields visible.*

These are **global, per-session** defaults — they're what a freshly placed or bulk-regenerated
strut uses. An individual strut's own context menu (see
[05 — Struts & Links](05-Struts-and-Links.md)) can still override shape, orientation, or offset
for just that one strut without touching these session-wide values.

## Window / Surface Offset Settings

This group holds the offsets that shape the generated milling window and its associated
surfaces:

- **ContourSimplification Offset** — how aggressively the detected contour is simplified before
  building the milling window from it.
- **Main Window Offset** — how far the main milling window extends outward from the implant
  contour.
- **Center Surface Inner Offset** — inward offset for the center working surface.
- **Depth Surface Direction Offset** *(shown as "Dept Surface Direction Offset" in the current
  UI)* — offset along the milling direction for the depth/center surface.
- **BottomSurface Geometry Offset** — offset for the bottom working surface. Only visible in Test
  mode; hidden otherwise.

> 🖼️ *Screenshot: Window / Surface Offset Settings.*

## Special Options

A group labeled **"Special Options"** holds two administrator tools plus one behavior switch:

- **ParseParameter** — picks an input and an output directory and converts legacy parameter files
  between them. A one-off migration tool, not part of everyday session work.
- **Default Configuration** — picks an output directory and writes a fresh set of default
  configuration files into it. Also an administrator tool — see
  [09 — Configuration Reference](09-Configuration-Reference.md) for the configuration this feeds
  into.
- **Whether this group is expanded also changes what AddManual Strut does**: with Special Options
  expanded, a manually placed strut attaches to the currently selected contour curve; with it
  collapsed (the default), a manually placed strut is placed independently of any curve. This
  isn't labeled as a strut option in the UI today — if a manually placed strut isn't behaving the
  way you expect, check whether this group happens to be open.

> 🖼️ *Screenshot: Special Options group expanded.*
