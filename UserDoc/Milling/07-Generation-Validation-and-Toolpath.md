# 07 — Generation, Validation & Toolpath

## Starting generation

Clicking **Generation** first asks a single deliberate confirmation — "Bone Surface Side checked?
Correct strategy?" — before doing anything. It exists to catch the single most common setup
mistake before committing to a run that can take a while and produce a lot of downstream output.
Answering **Cancel** aborts with nothing generated.

Before a new generation actually starts, the application also checks whether the selected working
directory already contains files from an earlier run, and offers the choice to overwrite the
existing output or write into a new, timestamped directory instead — protecting against
accidentally clobbering a previous result.

> 🖼️ *Screenshot: the "Bone-Surface-Correct?" confirmation dialog.*
> 🖼️ *Screenshot: working-directory overwrite-or-new-folder dialog.*

## Pre-generation validation

Before toolpaths are actually built, the session is checked for:

- **Hole/csys angle**, against the active fixture's configured tolerance.
- **Hole/csys reference-point position**, checking each one sits on the correct side of the
  implant surface for its configured direction.
- Anything else flagged as required by the assigned machining strategy.

Anything that fails is listed in a **Validation Warning** dialog, with the option to continue
anyway rather than being hard-blocked. A separate, off-by-default setting (Milling config tab →
Settings) can additionally show a confirmation dialog when validation finds **no** issues, giving
a deliberate chance to still cancel even a fully clean run.

> 🖼️ *Screenshot: Validation Warning dialog.*

## Reviewing the result

Clicking **Result** switches the session tree to its **Operations** view — a list of the
generated toolpath operations for the current implant. Selecting **Show Toolpath** on an
operation displays it in the 3D viewport.

> 🖼️ *Screenshot: Operations tree after generation.*
