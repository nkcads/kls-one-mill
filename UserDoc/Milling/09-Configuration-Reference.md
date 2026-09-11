# 09 — Configuration Reference

This page is aimed at whoever maintains machine, fixture, and template configuration for the shop,
rather than day-to-day session work. It's deliberately lighter on step-by-step instructions and
heavier on "what exists and where to find it," since this configuration changes far less often
than a normal session.

## Milling config tab

The application's configuration dialog has a dedicated **Milling** tab grouping module-specific
options in one place:

- Post-processor output settings.
- Hole-detection parameters (used by **Detect Holes**, see
  [04 — Holes, Csys & Milling Templates](04-Holes-Csys-and-Templates.md)).
- **Settings** → "Show info message when validation is successful" — off by default; shows a
  confirmation dialog before generation whenever pre-generation validation finds no issues at all
  (see [07 — Generation, Validation & Toolpath](07-Generation-Validation-and-Toolpath.md)).

> 🖼️ *Screenshot: Milling tab in the application configuration dialog.*

## Test mode

Machines, and machining strategies, can each be individually flagged as test-only. Flagged
entries — along with any region/material combination only reachable through one — are hidden from
the normal selection lists and only appear once the application is switched into **Test** mode
from the configuration window. Test mode is not persisted between sessions; it always resets back
to normal on the next application start.

## Fixtures

Each fixture defines its own hole/csys angle-check tolerance (see
[04 — Holes, Csys & Milling Templates](04-Holes-Csys-and-Templates.md)).

## Machining strategies & templates

- **Factory-standard templates** define the default machining approach per machine/material and
  can reference IGES-authored geometry or pre-posted subprogram files as their source, instead of
  only built-in shapes.
- **Open Milling Templates** (the cone-shaped pocket shapes referenced from
  [04](04-Holes-Csys-and-Templates.md)) are configured per machine as a named, reusable set.
