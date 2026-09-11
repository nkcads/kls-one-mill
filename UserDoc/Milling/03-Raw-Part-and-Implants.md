# 03 — Raw Part & Implant

## The raw part

A raw part is the physical plate that gets loaded into the machine. Its dimensions
(thickness/width/height) and material are set in the Raw Part group of Input Settings — see
[02 — Input Settings](02-Input-Settings.md).

## Placing the implant

Dragging the implant shows a live outline of its footprint on the raw part's mounting plane. This
preview updates continuously while dragging, not just once you let go.

**Suggest Position** looks for a free spot for the implant automatically, respecting the
configured inter-implant clearance and whatever area a reused plate already reports as occupied
(see below).

## Raw Part Library

Instead of starting a fresh plate every time, a raw part can be **saved to** and **loaded from** a
library of named plates:

- **Save to Library** stores the plate's machine/fixture/dimensions and a snapshot of where the
  implant currently sits, together with a thumbnail.
- **Load from Library** opens a browser of previously saved plates (dimensions and thumbnail
  shown per entry) to reuse.
- **Reuse Raw Part** is the lighter-weight alternative: an ad-hoc folder picker over any earlier
  session's own working folder, with no catalog or thumbnail — useful for quickly picking up
  where a specific past session left off rather than a curated, named plate.

> 🖼️ *Screenshot: Raw Part Library browser dialog.*

Reusing a plate (either way) correctly restores its actual dimensions and whatever area was
already milled/occupied on it — placement tools and **Suggest Position** treat that occupied area
as unavailable.

## Materials

**Titan**, **Peek**, and **MultiPurpose** are the available raw part material types, selected
through the same region/material filters used everywhere else in the session.
