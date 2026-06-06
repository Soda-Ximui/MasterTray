# FrankenTray v2 — Multi-Anchor Grid Spec
_Status: IMPLEMENTED_

---

## Overview

FrankenTray v2 extends the grid layout string with named anchor points and
explicit connections between them. It handles irregular compartment dividers
that can't be described by a regular cartesian or radial grid.

The parser strips ALL whitespace before tokenising — humans may format the
string however they like for readability.

---

## Syntax

```
A(name, position, shape, height)   — anchor definition (one or more)
[from, to, height]                 — connection (one or more)
```

Whitespace around commas, brackets, and parentheses is ignored.

---

## Anchor Definition — `A(...)`

```
A( name, position [, shape [, shape_height]] )
```

| Field | Required | Values |
|-------|----------|--------|
| `name` | yes | any alphanumeric identifier: `A1`, `hub`, `mid` |
| `position` | yes | `x,y` in mm from the SW (bottom-left) interior corner, OR `C` for centre |
| `shape` | no | `C<n>`, `S<n>`, `T<n>`, `D<n>` — see table below. `n` absent or `n=0` → decorative nub. |
| `shape_height` | no | `<n>%` or `<n>` mm height of the hub shape only. Default = max internal height. |

**Shape height is independent of rib height.** Ribs that originate from this
anchor use the full max internal height by default; override per-rib with the
height field in `[from, to, height]`. The `shape_height` field only controls
how tall the hub prism itself is.

### Shape rendering

| Token | Shape | Notes |
|-------|-------|-------|
| `C<n>` | Cylinder, diameter `2n` | Hollow when inner diameter ≥ 6 extrusion passes |
| `S<n>` | Square prism, side `n` | Solid |
| `T<n>` | Equilateral triangle prism, side `n` | Solid, point facing +Y |
| `D<n>` | Diamond prism (square side `n` rotated 45°) | Solid |
| any with `n=0`, `n` absent, or `n` below ~2 mm | Decorative nub | Minimal solid shape — marks the anchor visually, structurally negligible |

### Height — `<n>%`

Percentage is relative to the object's **max internal height** — full usable
interior depth after floor is subtracted. Closed containers cap at lid
clearance height; the renderer hard-clamps any value above that cap.

| Container type | What `100%` means |
|----------------|-------------------|
| Open tray / open jar | Full interior depth |
| Box / flip box | Full interior depth minus lid clearance |
| Threaded jar | Full interior depth (poke-through not allowed) |

### Coordinate system

```
y=int_l  NW ──────── N ──────── NE  x=int_w
          │                      │
          W    interior           E
          │       C=(int_w/2,     │
          │         int_l/2)      │
y=0      SW ──────── S ──────── SE  x=int_w
         x=0
```

- Origin `(0, 0)` = SW interior corner (bottom-left)
- `x` increases eastward (mm), `y` increases northward (mm)
- `C` = centre = `(int_w/2, int_l/2)` — shorthand, size-independent
- Coordinates are mm of **interior** space (wall thickness already subtracted)

### Examples

```
A(hub, C)                  — point anchor at centre, no shape
A(hub, C, C20)             — circle hub diameter 40 at centre, full height
A(hub, C, C20, 150%)       — circle hub, 150% shape height (pokes above open jar)
A(hub, C, C)               — decorative nub at centre (no size given)
A(A1, 35, 60)              — point anchor at (35, 60), no shape
A(A1, 35, 60, S15)         — square hub side=15 at (35, 60), full height
A(A1, 35, 60, S15, 80%)    — square hub, 80% shape height; ribs still default to 100%
A(A1, 35, 60, D12)         — diamond hub (12mm side, rotated 45°) at (35, 60)
A(A1, 35, 60, T0)          — decorative triangle nub at (35, 60)
```

---

## Connection — `[...]`

```
[ from, to [, height [, length]] ]
```

| Field | Required | Values |
|-------|----------|--------|
| `from` | yes | anchor name |
| `to` | yes | anchor name, wall name, or angle in degrees |
| `height` | no | `<n>%` or `<n>` mm. Overrides the anchor's own height for this rib only. |
| `length` | no | `<n>` mm. Caps how far the rib travels from the anchor. See below. |

### `to` — three target types

**1. Another anchor** — rib drawn as straight line between the two points.
```
[A1, A2]           — rib from A1 to A2
[A1, A2, 80%]      — same, at 80% of max internal height
```
`length` is ignored when `to` is an anchor name (distance is fixed by the two points).

**2. Wall name** — rib projected from anchor to the named wall face.
```
[A1, N]    — rib northward from A1, endpoint at (A1.x, int_l)
[A1, S]    — rib southward from A1, endpoint at (A1.x, 0)
[A1, E]    — rib eastward from A1, endpoint at (int_w, A1.y)
[A1, W]    — rib westward from A1, endpoint at (0, A1.y)
[A1, NE]   — diagonal rib to NE corner (int_w, int_l)
[A1, NW]   — diagonal rib to NW corner (0, int_l)
[A1, SE]   — diagonal rib to SE corner (int_w, 0)
[A1, SW]   — diagonal rib to SW corner (0, 0)
```

**3. Angle (degrees)** — rib shoots from anchor at the given compass angle
until it hits the container wall (rectangular or cylindrical).
0° = east, 90° = north, 180° = west, 270° = south.
```
[A1, 45]         — northeast diagonal until wall
[A1, 270]        — due south until wall
[A1, 45, 60%]    — northeast, 60% of max internal height
```

### `length` field *(PROPOSED — not yet implemented)*

Applies to wall-name and angle targets only. Caps the rib at `length` mm from
the anchor instead of running all the way to the wall. The rib endpoint is
`min(natural_length, length)` along the direction of travel.

```
[A1, N, 100%, 60]    — northward rib, full height, stops after 60 mm
[A1, 90, 80%, 45]    — same direction written as angle
[A1, E, 70%,  30]    — eastward stub, 30 mm long
```

This makes free-floating dividers possible without placing virtual anchor nodes
at every endpoint — the primary motivation for maze-style layouts where many
short ribs radiate or branch without reaching the container wall.

---

## Full Example — Photo Layout

```
A( A1, 30, 65 )
A( A2, 68, 58 )
A( A3, 30, 28 )
[ A1, N ]  [ A1, E ]  [ A1, A2 ]
[ A2, E ]
[ A3, S ]
```

As a single Customizer string (whitespace stripped by parser):
```
A(A1,30,65) A(A2,68,58) A(A3,30,28) [A1,N] [A1,E] [A1,A2] [A2,E] [A3,S]
```

*(Coordinates are mm from SW corner. For a 115×240 interior these anchors
are at roughly 26%, 27% / 59%, 24% / 26%, 12% — use real mm, not percents.)*

---

## Coexistence with Other Grid Tokens

FrankenTray v2 tokens (`A(...)` and `[...]`) live alongside existing tokens
in the same grid_layout string:

```
4x3 R4 C15% A(hub,C,C20) [hub,N] [hub,S]
```

Tokens are dispatched by prefix:
- `AxB` or `xB` → cartesian grid
- `R...` → radial spokes
- `C...` → radial hub
- `S...` → span
- `A(...)` → FrankenTray anchor
- `[...]` → FrankenTray connection

---

## Parser Implementation Notes

**Step 1 — Strip all whitespace** from the raw string before tokenising.
`"A( A1, 35, 60 )"` → `"A(A1,35,60)"`. One character-loop pass.

**Step 2 — Extract `A(...)` tokens.**
Find `A(`, scan to matching `)`, split content on `,`.
Build name → `[x_mm_sw, y_mm_sw, shape_str, height_str, is_center]` map.

**Step 3 — Extract `[...]` tokens.**
Find `[`, scan to `]`, split content on `,`.
Each gives `[from, to]` or `[from, to, height]`.

**Step 4 — Resolve and render.**
Convert `x_mm_sw` to centred OpenSCAD coords: `real_x = x_mm_sw - int_w/2`.
For each connection: look up `from` in anchor map → get `(ax, ay)`.
Resolve `to`:
- Anchor name → look up → `rib_between(a, b, h)`
- Wall name → compute wall endpoint → `rib_between(a, wall_pt, h)`
- Number → ray-cast from `(ax, ay)` at angle → `rib_between(a, hit_pt, h)`

**Geometry primitive — `rib_between(p1, p2, div_t, h)`:**
```
dx = p2.x - p1.x;  dy = p2.y - p1.y
mid = [(p1.x+p2.x)/2, (p1.y+p2.y)/2]
translate(mid) zrot(atan2(dy,dx)) cuboid([norm([dx,dy]), div_t, h], anchor=CENTER+BOTTOM)
```

---

## What Is NOT in v1

- **`length` field** *(PROPOSED above)* — free-floating / truncated ribs
- Rib stopping at another rib (requires ray-segment intersection against all other ribs)
- Per-rib thickness (all ribs use `div_t`)
- Curved ribs
- Ribs between wall points (no anchor needed for wall-to-wall)
