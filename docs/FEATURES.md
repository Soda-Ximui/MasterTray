# MasterTray — Features & System Design

## Overview

MasterTray is a parametric OpenSCAD system for generating 3D-printable storage
containers. The user sets parameters in the OpenSCAD Customizer; the system
computes safe geometry and outputs a printable STL.

---

## The Five Primitives

All geometry is assembled from five building blocks. Each primitive has one
factory (`factory_render_*`) that knows only how to build that shape. Decisions
about *what* to build are made upstream in the manifest; the factory just
executes.

### 1. TRAY
A rectangular open-top container: four walls + floor, no lid.

- Walls can be individually DROPPED (height reduced to zero) or height-modified
  by percentage (`WALL_MODIFY`, `WALL_TARGET`)
- Floor and walls independently support mesh patterns
- Opts control stacking: `STACKABLE=true` cuts four cylindrical peg-socket holes
  at the top corners, sized to accept RenderPeg connectors

### 2. JAR
A cylindrical open-top container: circular wall + circular floor.

- Wall and floor independently support mesh patterns
- Opts control threading: `IS_THREADED=true` adds a tapered neck transition and
  an external BOSL2 threaded section at the top for a screw-on lid
- Width parameter is the diameter (length is ignored; footprint is square)

### 3. LID
A cap geometry that closes a TRAY or JAR. The fit type is set by `LID_TYPE` in
opts:

| LID_TYPE | Description | Used with |
|----------|-------------|-----------|
| `"Snap"` | Press-on friction fit | BOX |
| `"Glide"` | Slides into a groove cut into the box top edge | BOX |
| `"Hinge_Single"` | C-clip on one Y face, front latch diamond | BOX / pill box |
| `"Hinge_Double"` | C-clips on both Y faces, opens from either end | Pill boxes |
| `"Screw"` | Internally threaded cap | JAR |

The BOX factory must read the same `LID_TYPE` to cooperate: a glide lid needs a
groove in the box walls; a hinge lid needs hinge boss geometry on the box body.

Lid surface supports mesh patterns independently from wall/floor mesh.

### 4. GRID
Internal dividers placed inside a TRAY or JAR. Two sub-types:

**Rectangular grid** — cartesian dividers specified as `RxC` (rows × cols).
Custom spans override individual cells:

```
S row/col/width/height/wall_h
```
- `row`, `col` — starting cell (1-based)
- `width` — how many columns this span covers
- `height` — how many rows this span covers
- `wall_h` — divider wall height: absolute mm, or `%` of container interior height

Multiple `S` tokens can appear in one layout string for multiple irregular spans.

**Circular grid** — radial spokes + optional center hub, specified as `RaCb`:
- `a` = number of spokes
- `b` = center hub radius (mm)
  - Below safety threshold → structural stub only (too small for storage)
  - Above threshold → usable center storage compartment; spokes divide the outer
    ring into `a` equal wedge compartments

**Deployment mode** (set by opts `GRID_MODE`):
- `"Built-in"` — unioned into the container render, no tolerance gap
- `"Drop-in"` — rendered as a separate printable object with `GRID_DROP_IN_TOLERANCE`
  (0.4mm) subtracted from outer dimensions so it slides in after printing

Rectangular grids also work inside jars (clipped to the cylindrical boundary).

### 5. RIB
FrankenTray vector-based dividers — free-form ribs defined by trajectory and
behavior, not by a cartesian grid. Specified in the layout string using
FrankenTray syntax:

```
PX/Y  OA,B  TRAJ-BEH  ...
```
- `PX/Y` — hub: X spokes, Y mm hub diameter
- `OA,B` — anchor offset from center: A mm in X, B mm in Y
- `TRAJ` — trajectory: cardinal (`N/S/E/W/NE/SW`...), degrees, or `X,Y` vector
- `BEH` — behavior: `T` (touch wall), `D` (displacement), `F50%` (50% of wall distance)

Clipping: rectangular containers use `apply_master_bounds`; jars use cylindrical
intersection.

---

## Pipeline: from User Input to Geometry

```
User (Customizer UI)
  ↓
ui_payload  — raw key-value array of all user settings
  ↓
validate    — FDM safety checks, dimension bounds, grid string validation
              (warnings echoed to console; values clamped where needed)
  ↓
compute_phys(data)         — safe wall, floor, clearance, nozzle (from data)
compute_opts(intent, data) — intent + data → build switches
  ↓
compile_manifest(intent, data)
  — maps intent string to list of [type, data, opts, phys] tuples
  — intents can be derived: "S4 Jar" delegates to "Jar with Lid"
  — hardwired data overrides prepended inline (no intermediate variables)
  ↓
build_part(intent, data)
  — loops manifest, dispatches each item to factory_render_*(data, opts, phys)
  ↓
factory_render_*(data, opts, phys)
  — dumb primitive builder, reads opts for behaviour switches
  — all decisions already made upstream
```

---

## Data, Opts, Phys — the Three Arrays

### `data` (ui_payload)
The full user configuration as `[["KEY", value], ...]`. Values are read with
`get_val(KEY, data, fallback)` which returns the first match, enabling
prepend-to-override without mutation.

Key parameters:

| Key | Description |
|-----|-------------|
| `WIDTH`, `LENGTH`, `HEIGHT` | Outer (Total) or inner (Usable) dimensions |
| `DIMENSION_MODE` | `"Total"` or `"Usable"` |
| `PATTERN` | Mesh pattern type |
| `HOLE_WALL`, `HOLE_FLOOR`, `HOLE_LID` | Hole diameter per surface (0 = no mesh) |
| `STRUT_WALL`, `STRUT_FLOOR`, `STRUT_LID` | Solid border % per surface (100 = no mesh) |
| `GRID_LAYOUT` | Layout specification string |
| `THICK_WALL`, `THICK_FLOOR`, `THICK_LID` | Target thicknesses (safety-snapped) |
| `WALL_MODIFY`, `WALL_TARGET` | Wall height modification |
| `FILAMENT_TYPE` | PLA / PETG / TPU / ABS (affects tolerances) |
| `FIT_PROFILE` | Tighter / Tight / Standard / Loose / Looser |

### `opts` (build options)
Computed from intent + data. Tells the factory how to behave differently from
default. Examples:

- `IS_THREADED=true` → JAR adds neck + threads; LID makes internal thread cap
- `STACKABLE=true` → TRAY cuts corner peg sockets
- `LID_TYPE="Hinge_Single"` → hinge boss + C-clip on one face
- `LID_TYPE="Hinge_Double"` → hinge bosses + C-clips on both faces
- `GRID_MODE="Drop-in"` → GRID adds tolerance gap, renders standalone

### `phys` (physics profile)
Computed from data via `get_physics_profile(data)`:

```
[["SAFE_WALL",  m_safe_wall(data)],   // wall snapped to nozzle multiples
 ["SAFE_FLOOR", m_safe_floor(data)],  // floor snapped to layer-height multiples
 ["CLEARANCE",  0.2 (PETG) / 0.1],   // filament-aware fit gap
 ["NOZZLE",     m_noz(data)]]
```

---

## Mesh Control

Three independent knobs, one set per surface (wall, floor, lid):

| Knob | Key | Disables mesh when |
|------|-----|--------------------|
| Pattern | `PATTERN` | Set to `"None"` |
| Hole size | `HOLE_WALL` / `HOLE_FLOOR` / `HOLE_LID` | Set to `0` |
| Strut % | `STRUT_WALL` / `STRUT_FLOOR` / `STRUT_LID` | Set to `100` |

Any one knob being "off" kills the mesh on that surface. `get_mesh_cfg` returns
`undef` when mesh should be skipped; the factory renders solid instead.

### Strut % Semantics

**Strut % = the fraction of the surface that is solid border.** 10% strut → 90%
of the surface is open mesh. The geometry changes per surface type:

| Surface | How strut % is applied |
|---------|------------------------|
| Flat rectangle | Each linear dimension independently: mesh rect = W×(1−s%) by L×(1−s%). Solid border = s%/2 on each of the four sides. An extra fixed pad (`nozzle×4.5`) is added to prevent half-holes at the boundary — actual border is slightly wider than s% alone. |
| Flat circle (jar floor/lid) | **Area-based**: mesh circle area = (1−s%) of total circle area. Diameter = `d × √(1−s%)`. Solid ring width scales correctly with s%. |
| Cylindrical wall | Height only: mesh zone occupies (1−s%) of wall height, centred. Solid band = s%/2 at top, s%/2 at bottom. No solid band around the circumference — holes go all the way around. |

**Threaded neck and strut priority:** On threaded jars, the mesh wall (`cyl_wall_h`)
is a physically separate geometry piece placed below the taper and thread sections.
Strut % governs only the mesh wall section. The threaded neck always gets its full
solid space regardless of strut setting — structural isolation by construction, not
by strut math.

**Flat mesh** (`framed_mesh`) — used on box/tray floor and lid. Pattern tiles
are `linear_extrude`d through a flat slab. `is_cyl=true` uses circular boundary
(jar floors/lids) with area-based strut scaling.

**Cylindrical mesh** (`cylindrical_mesh_wall`) — used on jar walls. Pattern
primitives are placed radially through the wall shell, distributed evenly around
the circumference and up the height. `n_rows` (up) is derived from strut % and
hole step size; `n_cols` (around) fills the full circumference.

---

## FDM Safety Constraints

Applied automatically before any factory sees the data (via `enforce_safety`).

**Floor / Lid thickness** — rounded to nearest multiple of `layer_height`.
Prevents slicer micro-stepping (tiny Z-movements that cause surface roughness
and warping on flat surfaces).

**Wall thickness** — rounded to nearest multiple of `nozzle_diameter`.
Prevents partial extrusion loops. Minimum = `nozzle × wall_loops`.

**Corner radius** — derived from wall thickness to prevent inverted inner
geometry when BOSL2 rounding is applied.

**Chamfer** — capped at `nozzle × 2.5` to stay within FDM's 45° overhang limit.

**Floor/lid thickness cap** — 35% of total height (prevents solid bricks on
small containers).

**Wall thickness cap** — 45% of smallest XY dimension.

**Edge chamfering (all primitives)** — every user-facing horizontal edge is automatically
chamfered at `nozzle × 2.5` (1 mm at 0.4 mm nozzle) via `apply_master_bounds`:

| Edge | Benefit |
|------|---------|
| Top rim | Removes knife edge — safe to handle straight off the printer |
| Bottom perimeter | Lead-in ramp for the first layer — first-layer squish expands into the chamfer angle instead of bowing the base outward (elephant foot elimination) |

Cylindrical primitives (jar wall, screw lid cap) use `nozzle × 4` (1.6 mm) for a more
pronounced grip-safe rim. All chamfer values scale automatically with `Nozzle_Diameter`.

---

## Dimension Modes

| Mode | Meaning |
|------|---------|
| `"Total"` | Width/Length/Height are the outside dimensions of the container |
| `"Usable"` | Width/Length/Height are the interior space; walls/floor added automatically |

Auto-math in MasterBuilder converts Usable to Total before packaging into
`ui_payload`:

```
raw_w = (mode == "Usable") ? part_width  + wall_thickness*2 : part_width
raw_l = (mode == "Usable") ? part_length + wall_thickness*2 : part_length
raw_h = (mode == "Usable") ? part_height + floor_thickness + lid_thickness : part_height
```

---

## Wall Modifications

`WALL_MODIFY` + `WALL_TARGET` allow per-wall height reduction:

| WALL_MODIFY | Effect |
|-------------|--------|
| `"None"` | Full height (100%) — default |
| `"Dropped"` | Wall removed entirely (0%) |
| `"50%"` | Wall at half height |
| `"25%"` | Wall at quarter height |

`WALL_TARGET` selects which wall(s): `"All Walls"`, `"Front"`, `"Back"`,
`"Left"`, `"Right"`.

---

## Grid Layout String Format

Full syntax (all tokens space-separated, all optional):

```
[RxC]  [S r/c/w/h/wall_h ...]  [Ra]  [Cb]
```

| Token | Meaning |
|-------|---------|
| `7x5` | 7 rows × 5 cols cartesian grid |
| `S2/3/2/1/80%` | Span: row 2, col 3, 2 cols wide, 1 row tall, 80% wall height |
| `S1/1/3/2/25` | Span: row 1, col 1, 3 wide, 2 tall, 25mm wall height |
| `R6` | 6 radial spokes |
| `C15%` | Center hub = 15% of container diameter |
| `C20` | Center hub = 20mm radius |

FrankenTray ribs use separate syntax triggered by a `P` token (see RIB above).

---

## Compound Intents

Intents can delegate to other intents with hardwired data overrides:

```
"S4 Jar"
  → override WIDTH=46, LENGTH=140, HEIGHT=140 (Total)
  → delegate to "Jar with Lid"
      → JAR  (IS_THREADED=true)
      → LID  (LID_TYPE="Screw")
```

Overrides are prepended to `data` inline using `concat([overrides], data)`
directly in the manifest expression — no intermediate variables, exploiting
`get_val`'s first-match semantics.

## Data-Conditional Intents

The manifest can branch on user data, not just intent string. This allows one
intent name to produce different primitive counts depending on inputs.

**"Simple Jar"** — adapts to the user's dimensions:

```
WIDTH == LENGTH  →  one JAR (diameter = WIDTH)

WIDTH != LENGTH  →  two JARs placed on the platter:
                      JAR(diameter = LENGTH)
                      JAR(diameter = WIDTH)
```

Each JAR overrides WIDTH with its own diameter by prepending to `data` inline.
The platter layout (`get_xy`) places them side by side automatically.

This is the "deduced from user intent + user data" principle: the user doesn't
choose "one jar or two" — the geometry decision falls out of the dimensions they
already provided.

---

## Tolerance & Fit Profiles

`MasterTolerance.scad` provides per-joint, per-filament clearance:

| Component | Joint |
|-----------|-------|
| `COMP_SPINE` | Hinge pin rotating in boss |
| `COMP_CCLIP` | C-clip spring tab retention |
| `COMP_CLASP` | Front snap latch engagement |
| `COMP_GLIDE` | Sliding lid rail clearance |

Fit profiles (`FIT_TIGHTER` → `FIT_LOOSER`) step clearance by ±0.05mm and
engagement depth by ±0.20mm. PETG has wider baselines than PLA due to material
flexibility and shrinkage differences.

---

## Known Gaps

| Gap | Status |
|-----|--------|
| TRAY factory renders solid block, not hollow box | `core_tray_chassis` needs implementation |
| GRID factory only handles FrankenTray ribs | Cartesian + radial divider code needs restoration |
| Manifest covers 4 of 23 intent strings | Remaining intents fall through to default TRAY |
