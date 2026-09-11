# 06 — Strategy Tree & Session

## The session tree

The bottom toolbox area holds a tree view of the entire session, expanding automatically while the
Milling module is active:

1. **Milling Setup** — machine and fixture.
2. **Geometry** — implant, detected holes, curves, csys.
3. **Raw Part**.
4. **Strategy** — the assigned machining strategy, its entries, and each entry's dynamic values.
5. **Operations** — the generated toolpaths, once Generation has run (see
   [07 — Generation, Validation & Toolpath](07-Generation-Validation-and-Toolpath.md)).

> 🖼️ *Screenshot: session tree showing Strategy entries expanded with dynamic values.*

## Editing values from the tree

Selecting a dynamic-value item installs an inline editor for it — a spin box for a numeric value,
a checkbox for a boolean one — right in the tree, with its range (if any) taken from that value's
configured min/max. Changes apply immediately, no separate "commit" step.

Some strategy entries are **optional**: they show their own checkbox to switch that entry on or
off entirely for this session, independent of every other entry.

## Resetting values

Right-clicking gives context-appropriate reset actions:

- On a dynamic value that's been changed from its default: **Reset Value**.
- On a strategy entry: **Reset Entry** — resets every dynamic value inside that one entry.
- On the strategy itself: **Reset Strategy** — resets everything under it back to the template's
  defaults.

Other tree items (geometry, raw part, etc.) show separate **Show** and **Hide** context-menu
entries reflecting their current visibility — only the applicable one of the pair is enabled at a
time. Individual generated-operation entries under Operations additionally offer **Show
Toolpath** — see
[07 — Generation, Validation & Toolpath](07-Generation-Validation-and-Toolpath.md) for what that
displays.

## Per-strategy post-processor variables

A machining strategy can carry its own set of post-processor variables — for example, a machine
option that should only take effect for sessions using that one specific strategy. These are
merged with the machine's regular post-processor settings when the NC program is generated,
without changing anything about the machine's own configuration for other sessions.
