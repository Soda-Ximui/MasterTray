# FrankenTray v2 — Multi-Anchor Grid Spec
_Status: DESIGN — not yet implemented_

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
A( name, position [, shape] [, height] )
```

| Field | Required | Values |
|-------|----------|--------|
| `name` | yes | any alphanumeric identifier: `A1`, `hub`, `mid` |
| `position` | yes | `x,y` as % of interior (0,0 = SW corner, 100,100 = NE corner) OR `C` for centre |
| `shape` | no | `C<r>` circle radius r, `S<s>` square side s, `T<s>` equilateral triangle side s |
| `height` | no | `<n>%` of interior height, or `<n>` absolute mm. Default = full interior height. Clamped for closed containers. |

### Examples

```
A(hub, C)                  — point anchor at centre, no shape, full height
A(hub, C, C20)             — circle hub r=20 at centre, full height
A(hub, C, C20, 150%)       — circle hub r=20 at centre, 150% height (pokes above open jar)
A(A1, 35, 60)              — point anchor at 35% x, 60% y
A(A1, 35, 60, S15)         — square hub side=15 at 35%,60%
A(A1, 35, 60, S15, 80%)    — square hub, 80% height
```

### Shape rendering

The shape is rendered as a solid prism AT the anchor position, at the
anchor's height. It acts as the physical hub that ribs connect to.

| Token | Shape | Notes |
|-------|-------|-------|
| `C<r>` | Cylinder, radius r | Hollow if inner diameter ≥ 6 extrusion passes (same rule as radial hub) |
| `S<s>` | Square prism, side s | Solid |
| `T<s>` | Equilateral triangle prism, side s | Solid, point facing +Y |

---

## Connection — `[...]`

```
[ from, to [, height] ]
```

| Field | Required | Values |
|-------|----------|--------|
| `from` | yes | anchor name |
| `to` | yes | anchor name, wall name, or angle in degrees |
| `height` | no | `<n>%` or `<n>` mm. Overrides anchor default for this rib only. |

### `to` — three target types

**1. Another anchor** — rib drawn as straight line between the two points.
```
[A1, A2]           — rib from A1 to A2
[A1, A2, 80%]      — same, at 80% height
```

**2. Wall name** — rib projected from anchor to the named wall face.
Keeps the anchor's perpendicular coordinate fixed (axis-aligned projection).
```
[A1, N]    — vertical rib northward from A1, endpoint at (A1.x, +int_l/2)
[A1, S]    — vertical rib southward from A1
[A1, E]    — horizontal rib eastward from A1, endpoint at (+int_w/2, A1.y)
[A1, W]    — horizontal rib westward
[A1, NE]   — diagonal rib to NE corner (+int_w/2, +int_l/2)
[A1, NW]   — diagonal rib to NW corner
[A1, SE]   — diagonal rib to SE corner
[A1, SW]   — diagonal rib to SW corner
```

Corner targets (NE/NW/SE/SW) produce diagonal ribs and are rarely needed.

**3. Angle (degrees)** — rib shoots from anchor at the given compass angle
until it hits the container wall (rectangular or cylindrical).
0° = east, 90° = north, 180° = west, 270° = south.
```
[A1, 45]         — northeast diagonal until wall
[A1, 270]        — due south until wall
[A1, 45, 60%]    — northeast, 60% height
```

> **v1 scope:** angle-based ribs extend to the container wall only.
> "Stop at another rib" is deferred to v2.

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

---

## Coordinate System

```
(0,100) NW -------- N -------- NE (100,100)
         |                       |
         W    interior           E
         |       (50,50)=C       |
         |                       |
(0,0)  SW -------- S -------- SE (100,0)
```

- Origin (0,0) = SW interior corner
- (100,100) = NE interior corner
- `C` = centre = (50,50) → resolves to (0,0) in OpenSCAD's centre-relative coords
- Coordinates are % of interior dimensions (after wall thickness subtracted)

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
Build `name → [x_pct, y_pct, shape, height_mm]` map.

**Step 3 — Extract `[...]` tokens.**
Find `[`, scan to `]`, split content on `,`.
Each gives `[from, to]` or `[from, to, height]`.

**Step 4 — Resolve and render.**
For each connection: look up `from` in anchor map → get (ax, ay).
Resolve `to`:
- Anchor name → look up (bx, by) → `rib_between(a, b, h)`
- Wall name → compute wall endpoint from (ax, ay) → `rib_between(a, wall_pt, h)`
- Number → ray-cast from (ax, ay) at angle → find intersection with boundary → `rib_between(a, hit_pt, h)`

**Geometry primitive — `rib_between(p1, p2, div_t, h)`:**
```
dx = p2.x - p1.x;  dy = p2.y - p1.y
mid = [(p1.x+p2.x)/2, (p1.y+p2.y)/2]
translate(mid) zrot(atan2(dy,dx)) cuboid([norm([dx,dy]), div_t, h], anchor=CENTER+BOTTOM)
```

---

## What Is NOT in v1

- Rib stopping at another rib (requires ray-segment intersection against all other ribs)
- Per-rib thickness (all ribs use `div_t`)
- Curved ribs
- Ribs between wall points (no anchor needed for wall-to-wall)
