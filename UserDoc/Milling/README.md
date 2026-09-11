# KLS OneMill — Milling Module User Guide

This is the user documentation for the **Milling** module of KLS OneMill — the part of the
application that turns a positioned dental implant on its raw part into a validated,
machine-ready NC program.

**Scope: KLS OneMill 2.1.0.** This guide intentionally covers only what has actually shipped —
features still in progress on a feature branch (currently anything from the 2.2.0 release notes,
e.g. multiple implants per raw part, raw part marking, VHF Titan milling) are left out until they
release, rather than documented as "(Preview)". See "Keeping this document alive" below for the
update process each release.

It is a **living document**: it describes the workflow and features as they exist in the current
release, and is meant to be updated alongside the module rather than rewritten from scratch.
Screenshots are not included yet — every place one would help is marked with a placeholder like
the one below, ready to be filled in:

> 🖼️ *Screenshot: placeholder — add a capture of the relevant panel/dialog here.*

## Contents

| Page | Covers |
|---|---|
| [01 — Overview & Workflow](01-Overview-and-Workflow.md) | What the module does, the session state machine, the workflow toolbar |
| [02 — Input Settings](02-Input-Settings.md) | Region/Material/Machine/Fixture, strategy selection |
| [03 — Raw Part & Implant](03-Raw-Part-and-Implants.md) | Raw part setup, the Raw Part Library, placement tools |
| [04 — Holes, Csys & Milling Templates](04-Holes-Csys-and-Templates.md) | Hole detection, per-hole machining strategy, angle/position validation, IGES & Open Milling templates |
| [05 — Struts & Links](05-Struts-and-Links.md) | Manual struts, per-strut shape and milling-side settings |
| [06 — Strategy Tree & Session](06-Strategy-Tree-and-Session.md) | The session tree, dynamic values, resetting entries/strategies |
| [07 — Generation, Validation & Toolpath](07-Generation-Validation-and-Toolpath.md) | The Generate step, pre-generation checks, the Operations tree |
| [08 — Output & Post-Processing](08-Output-and-Postprocessing.md) | The Post step, what leaves the module, VHF-specific behavior |
| [09 — Configuration Reference](09-Configuration-Reference.md) | Admin-level settings: the Milling config tab, machines, fixtures, templates |
| [10 — Extended Settings](10-Extended-Settings.md) | Bulk strut defaults, milling-window/surface offsets, Special Options |

## Who this is for

Written for the person actually running a milling session day to day — planning an implant,
placing it on a raw part, choosing how each hole and strut gets machined, and generating and
posting the result. Pages 01–08 and 10 describe that workflow. Page 09 is aimed more at whoever
maintains machine/fixture/template configuration for the shop.

## Keeping this document alive

- **On each new release**, walk the "Milling" section of the matching
  [release notes](../../releaseNotes/) top to bottom and, for each entry that changes what a user
  sees or does, update the page that already covers it (add a new page only once an existing one
  has grown unwieldy). A feature still marked "(Preview)" in the release notes for the release
  you're documenting is still fair game to include — this guide tracks what's shipped, not what's
  finished changing shape.
- Add a screenshot wherever you see the 🖼️ placeholder — a capture of the actual panel/dialog is
  enough, no annotation required. Run `build_pdf.py` (see below) after updating placeholders to
  refresh the exported PDF.
- Bumping the documented scope to a new release is a content change, not a restructuring —
  resist renumbering pages unless one is actually added or removed.

## Generating the PDF

`build_pdf.py` (Python 3, needs the `markdown` package: `py -m pip install markdown`) concatenates
this README and pages 01–10 in order and prints the result to
`KLSOneMill-Milling-UserGuide.pdf` using Chrome's built-in headless PDF printer — no other
dependency (pandoc, LaTeX, …) required. From this folder:

```
py build_pdf.py
```

Pass `--chrome "C:\path\to\chrome.exe"` if Chrome isn't found automatically, or `--out
some-name.pdf` to write elsewhere. Add a new page to the `PAGES` list at the top of the script
when the contents table above gains one.
