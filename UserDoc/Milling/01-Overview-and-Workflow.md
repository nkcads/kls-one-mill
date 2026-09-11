# 01 — Overview & Workflow

## What the Milling module does

The Milling module ("Simple Milling") is where a dental implant, positioned on its raw part, goes
from a positioned model to a validated, machine-ready NC program. It owns the raw part, the
implant's placement on it, hole and strut detection, per-hole/per-strut machining strategy,
geometry and toolpath generation, and hands the result to the Post Processor module for final NC
output.

> 🖼️ *Screenshot: the Milling module's main layout — 3D viewport, Input Settings panel, session
> tree, workflow toolbar.*

## The session workflow bar

Across the top of the module sits a row of buttons that double as a state indicator — a colored
dot (red while idle, green once a workpiece is loaded) shows whether the session has data to work
with. The buttons are meant to be used roughly left to right, though later ones only enable once
the earlier step has actually produced something to build on:

1. **AssignImplantPos** — commits the implant's current position (from the interactive transform
   gizmo) as its working placement. Available as soon as an implant is loaded.
2. **Refresh** — re-runs workpiece position validation (hole/csys angle checks, colors) without
   regenerating geometry. Useful after nudging the implant or switching machine/fixture.
3. **Geometry** — builds the milling geometry for the current implant: contours, milling windows,
   detected holes, struts. This is the step that turns "an implant sitting on a raw part" into
   something the Strategy tree and hole/strut tools can actually act on.
4. **Generation** — runs toolpath generation for the current implant, after a confirmation dialog
   ("Bone Surface Side checked? Correct strategy?") that exists specifically to catch the most
   common setup mistake before committing to a run.
5. **Result** — switches to the generated toolpaths for review (the session tree's Operations
   view) once Generation has produced them.
6. **Post** — hands the session to the Post Processor module to produce the actual NC file(s). See
   [08 — Output & Post-Processing](08-Output-and-Postprocessing.md).

> 🖼️ *Screenshot: the workflow toolbar in a mid-session state (Geometry done, Generation enabled).*

Each button's tooltip explains what's still missing when it's disabled (e.g. "Load implant first",
"Generate geometry first"), so the toolbar itself is a reasonable first place to check when
something further along seems unavailable.

## Where things live on screen

- **Input Settings** (top of the panel area) — region, material, machine, fixture, raw part, and
  per-implant workpiece settings. See [02 — Input Settings](02-Input-Settings.md).
- **3D Viewport** — the raw part, implant(s), holes/csys markers, struts, milling windows, and
  (once generated) the toolpath itself. Holes, csys markers, and struts are directly clickable to
  open their own per-item settings.
- **Session tree** (bottom toolbox area, expands when the module is active) — a structured view of
  the whole session: setup, geometry, raw part, the assigned machining strategy and its entries,
  and the generated Operations. See
  [06 — Strategy Tree & Session](06-Strategy-Tree-and-Session.md).
- **Graphics toolbar overlay** — floats above the 3D view and picks up controls specific to what's
  currently displayed. See
  [07 — Generation, Validation & Toolpath](07-Generation-Validation-and-Toolpath.md).

## A typical session, end to end

1. Pick Region / Material / Machine / Fixture and load the implant (
   [02 — Input Settings](02-Input-Settings.md)).
2. Set up the raw part — dimensions and material (
   [03 — Raw Part & Implant](03-Raw-Part-and-Implants.md)).
3. Click **AssignImplantPos**, then **Geometry** to detect holes and build the milling geometry.
4. Review detected holes/csys markers, assign machining strategies where the default doesn't fit,
   and add any manual struts ([04](04-Holes-Csys-and-Templates.md),
   [05](05-Struts-and-Links.md)).
5. Adjust dynamic values or optional entries on the assigned strategy if needed (
   [06 — Strategy Tree & Session](06-Strategy-Tree-and-Session.md)).
6. Click **Generation**, resolve anything the pre-generation validation flags, and review the
   result (
   [07 — Generation, Validation & Toolpath](07-Generation-Validation-and-Toolpath.md)).
7. Click **Post** to produce the NC output for the target machine (
   [08 — Output & Post-Processing](08-Output-and-Postprocessing.md)).
