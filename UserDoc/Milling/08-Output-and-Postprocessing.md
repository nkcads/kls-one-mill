# 08 — Output & Post-Processing

## Handing off to the Post Processor

Clicking **Post** activates the Post Processor module for the current implant/session, which is
what actually writes the machine-readable NC program from the toolpaths Generation produced.

> 🖼️ *Screenshot: Post Processor module after clicking Post from a generated Milling session.*

The Post Processor module is a separate plugin with its own settings and output options (job file
selection, machine-specific variables, output directory); this page only covers what's relevant
from the Milling side of that handoff. Detailed Post Processor usage belongs in that module's own
documentation once written.

## Machine-specific behavior worth knowing about

- **VHF machines** carry configurable output options for water processing, ionizer, preset
  raw-part number, estimated milling time, and material label, plus a configurable output file
  name (instead of a fixed `main.nc`). The estimated milling time is calculated once generation
  completes and written into the NC header automatically.
- A **toolbreak check** is emitted before a tool-change block whenever the preceding operation was
  a drilling operation, and at end-of-program when the last operation was a drilling operation.
- The generated post-processor job data includes the current Windows user name, available to
  post-processor scripts (e.g. for NC header information).

## Advanced/administrative note

Authoring the machine/fixture/post-processor configuration itself is shop/administrator-level
work rather than part of the everyday per-implant workflow — see
[09 — Configuration Reference](09-Configuration-Reference.md).
