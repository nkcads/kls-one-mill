# 04 — Holes, Csys & Milling Templates

## Detection

**Detect Holes** (Extended Settings) finds drilling holes and coordinate-system markers (csys) on
the loaded implant automatically. **Remove Detected Holes** clears them if you need to redo
detection after a change. Detection parameters are admin-level settings, see
[09 — Configuration Reference](09-Configuration-Reference.md).

## Assigning how a hole or csys gets machined

Clicking a hole or csys marker in the 3D viewport opens a persistent panel (not a popup menu) with
a combo box and checkboxes for that item. From here you can:

- Assign a specific machining strategy ("hole norm") to just this hole/csys, overriding whatever
  the machine's default would otherwise use.
- Enable or configure an **Open Milling Template** override for it — a cone-shaped pocket shape,
  configured per machine as a named, reusable set (see
  [09 — Configuration Reference](09-Configuration-Reference.md)).

Confirm with OK to commit, or Cancel to discard. Committing an override updates the on-screen
preview/coloring immediately, but does **not** by itself rebuild the full milling geometry — click
**Geometry** (or, if geometry was already generated, the change may regenerate automatically for
that one geometry element) to see the actual effect in the toolpath.

> 🖼️ *Screenshot: hole/csys settings panel with the machining-strategy combo and Open Milling
> Template checkbox.*

The machine-wide default strategy for holes/csys can also be changed from Input Settings — that
changes the fallback used by every hole/csys that doesn't have its own explicit override.

## Angle and position validation

Before generating, and whenever **Refresh** runs, each hole's axis and each csys's normal
direction is checked against the current fixture's configured angle tolerance (currently a single
tolerance, the same for every direction). A hole/csys that fails is drawn in the error color
(applied to every visible part of its marker, not just the outline) so it's obvious at a glance
which ones need attention. Switching machine/fixture re-runs this check immediately.

Separately, a **reference-point check** can verify that each hole's/csys's reference point sits on
the correct side of the implant surface along its normal (near or far side, set per machining
entry) before generation starts — this stays reliable even on imperfect geometry, since it
raycasts against the real surface rather than requiring an exact positional match. Anything that
fails either check is listed in a **Validation Warning** dialog before generation, with the option
to continue anyway. A separate, off-by-default setting can also show a confirmation dialog when
validation finds *no* issues at all, giving a chance to double-check (or cancel) even a clean run.

> 🖼️ *Screenshot: Validation Warning dialog listing failed holes/csys.*

## IGES-driven milling passes

A machining strategy entry can drive its geometry from an authored IGES file instead of (or in
addition to) built-in shapes:

- A single **curve** or **surface** reference for straightforward wireframe/surface milling.
- Multiple typed inputs at once — a trimmed surface plus detected top/center/bottom edge curves
  from that same surface's geometry. When both a top and bottom edge curve are present, the pass
  mills by morphing between the two curves rather than following the full surface or a single
  wireframe.
