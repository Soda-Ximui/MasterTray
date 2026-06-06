# MasterTray Architecture & Program Flow

## Table of Contents

1. [System Overview](#system-overview)
2. [Layer Architecture](#layer-architecture)
3. [Program Flow: MasterBuilder Entry Point](#program-flow-masterbuilder-entry-point)
4. [The Data Structure: `ui_payload`](#the-data-structure-ui_payload)
5. [Layer 0 — Lexicon: Enums & Constants](#layer-0--lexicon-enums--constants)
6. [Layer 1 — The Math Kernel](#layer-1--the-math-kernel)
7. [Layer 2 — Domain Processors](#layer-2--domain-processors)
8. [Layer 3 — Factory Renderers](#layer-3--factory-renderers)
9. [Subsystem: Mesh Generation](#subsystem-mesh-generation)
10. [Subsystem: Grid Layout Parsing](#subsystem-grid-layout-parsing)
11. [Subsystem: FrankenTray Rib Topology](#subsystem-frankentray-rib-topology)
12. [Subsystem: FDM Safety Validation](#subsystem-fdm-safety-validation)
13. [Subsystem: Tolerances & Fit Profiles](#subsystem-tolerances--fit-profiles)
14. [Include & Dependency Graph](#include--dependency-graph)
15. [Adding a New Part Type — Step-by-Step](#adding-a-new-part-type--step-by-step)

---

## System Overview

MasterTray is an OpenSCAD parametric 3D printing system that generates printable storage containers — rectangular boxes, threaded jars, flip-lid boxes, stackable trays, grid dividers, and more.

The system is structured as a **strict layered pipeline**. Data flows from the user (OpenSCAD Customizer UI) through successively deeper layers — validation, physics, factory — before emerging as final geometry. No layer reaches up to a higher one; data flows one direction only.

```
User (Customizer) → MasterBuilder → Manifest → Dispatcher → Factories → Geometry
```

---

## Layer Architecture

| Layer | Files | Responsibility |
|-------|-------|----------------|
| **Layer 0** | `MasterEnum.scad`, `MasterConstants.scad` | String key constants, part-type enums, physical engineering constants |
| **Layer 1.0** | `MasterEngine.scad` | Universal data extractor (`get_val`), FDM safety math, mesh config, layout helpers |
| **Layer 1.1** | `MasterSafety.scad`, `MasterChecks.scad` | FDM alignment rules (layer-height/nozzle snapping); `MasterChecks` is a thin shim that re-exports Safety |
| **Layer 1.1.5** | `MasterValidation.scad` | Pre-build warnings: dimension bounds, thickness minimums, grid cell sizes |
| **Layer 1.2** | `MasterText.scad` | Text/font geometry and width estimation for plaques |
| **Layer 1.3** | `MasterGridParser.scad`, `GridLayout.scad` | Grid string tokenizing, cartesian/radial/span/FrankenTray parsing |
| **Layer 1.5** | `MasterUtility.scad` | Preflight console reports; Vector Math Engine for FrankenTray rib geometry |
| **Layer 1.5.1** | `MasterBug.scad` | FrankenTray state telemetry (echoes diagnostic dumps to console) |
| **Layer 1.8** | `MasterTolerance.scad` | Per-material clearance gaps and snap-fit engagement depths |
| **Layer 2.0** | `MasterRender.scad` | Umbrella include + `apply_master_bounds` + `process_part` pipeline |
| **Layer 2.1** | `RenderMesh.scad`, `RenderBox.scad`, `RenderPlaque.scad`, `MasterMeshPatterns.scad` | Shared geometry primitives: mesh surfaces, box chassis, label plates, pattern tiles |
| **Layer 2.2** | `RenderRib.scad` | FrankenTray vector rib builder |
| **Layer 2.3** | `MasterDispatcher.scad` | Alternative build entry point (platter layout mode) |
| **Layer 3** | `RenderTray.scad`, `RenderJar.scad`, `RenderLid.scad`, `RenderGrid.scad`, `RenderPeg.scad` | Final factory functions: `factory_render_*` |
| **Entry Point** | `MasterBuilder.scad` | OpenSCAD Customizer UI, `ui_payload` assembly, `build_part()` dispatcher |

---

## Program Flow: MasterBuilder Entry Point

`MasterBuilder.scad` is the file you open in OpenSCAD. Everything starts here.

### Step 1 — User Sets Parameters (Customizer UI)

```
Nozzle_Diameter = 0.4;
Wall_Loops      = 2;
Layer_Height    = 0.20;
Part_To_Build   = "Threaded Jar";
part_width      = 100;
...
```

OpenSCAD's Customizer renders these as interactive controls (sliders, dropdowns). The variable names, types, and inline comments (`// ["opt1", "opt2"]`) control how controls are presented.

### Step 2 — Package Parameters into `ui_payload`

All UI variables are wrapped into a single key-value array:

```scad
ui_payload = [
  ["WIDTH",          part_width],
  ["HEIGHT",         part_height],
  ["NOZZLE_DIAMETER", Nozzle_Diameter],
  ["GRID_LAYOUT",    grid_layout],
  // ... ~15 more entries
];
```

This is the **single data structure** that flows through the entire system. Every layer reads from it via `get_val(KEY, data, fallback)` — never by positional index or global variable.

### Step 3 — `build_part()` Dispatches

```scad
build_part(Part_To_Build, ui_payload);
```

`build_part` calls `compile_manifest()` to determine which sub-parts to render, then loops through the manifest and dispatches each item to the appropriate factory:

```
build_part("Threaded Jar", ui_payload)
  └─ manifest = compile_manifest("Threaded Jar", ui_payload)
       └─ returns: [ ["JAR", data, opts, phys], ["LID", data, opts, phys] ]
  └─ for each item in manifest:
       "JAR"  → factory_render_jar(data, opts, phys)
       "LID"  → factory_render_lid(data, opts, phys)
```

### Step 4 — Factory Renders Geometry

Each `factory_render_*` function:
1. Extracts dimensions with engine getters (`m_bw`, `m_bh`, etc.)
2. Reads physics from the `phys` array (pre-computed safe thicknesses)
3. Builds geometry using BOSL2 primitives (`cuboid`, `cyl`, `threaded_rod`)
4. Applies mesh cutouts via `framed_mesh` / `cylindrical_mesh_wall`

### Complete Call Stack (Threaded Jar Example)

```
MasterBuilder.scad
  build_part("Threaded Jar", ui_payload)
    compile_manifest(...)                        → MasterManifest.scad
      get_physics_profile(data)                  → MasterProcessor.scad
        m_safe_wall(data)                        → MasterEngine.scad / MasterSafety.scad
        m_safe_floor(data)                       → MasterEngine.scad / MasterSafety.scad
      get_build_options(type, data, ...)         → MasterProcessor.scad
    factory_render_jar(data, opts, phys)         → RenderJar.scad
      framed_mesh(data, w, w, sf, true, cfg)     → RenderMesh.scad
        get_mesh_cfg(...)                        → MasterEngine.scad
        render_rectangular_pattern(...)          → MasterMeshPatterns.scad
      cylindrical_mesh_wall(data, w, h, sw, cfg) → RenderMesh.scad
      threaded_rod(...)                          → BOSL2
    factory_render_lid(data, opts, phys)         → RenderLid.scad
      (lid geometry with tolerance clearances)   → MasterTolerance.scad
```

---

## The Data Structure: `ui_payload`

All data in MasterTray is passed as a **key-value array-of-arrays**:

```scad
data = [
  ["WIDTH",         100],
  ["HEIGHT",         50],
  ["NOZZLE_DIAMETER", 0.4],
  ["PATTERN",      "Teardrop"],
  // ...
]
```

**Reading** — always use the universal extractor:
```scad
w = get_val(WIDTH, data, 50);  // Returns 100, or 50 if key missing
```

`WIDTH` is a string constant defined in `MasterEnum.scad` (`WIDTH = "WIDTH"`). This prevents typos and enables grep-based usage tracking.

**Writing** — functions prepend new entries to override existing ones:
```scad
// enforce_safety prepends computed thicknesses so they take precedence
function enforce_safety(data) =
  concat([[THICK_WALL, m_safe_wall(data)], [THICK_FLOOR, m_safe_floor(data)]], data);
```

Because `get_val` returns the **first** match it finds, prepending overrides the original value without mutation. This is the functional update pattern for OpenSCAD's immutable arrays.

**Manifest items** extend the base data with per-component arrays:
```scad
manifest_item = ["JAR", data_payload, options_array, physics_array]
//               [0]    [1]           [2]             [3]
```

`options_array` — built by `get_build_options()`: `[["IS_THREADED", true], ["IS_STACKABLE", false], ...]`

`physics_array` — built by `get_physics_profile()`:
```scad
[
  ["SAFE_WALL",  2.4],   // phys[0][1]
  ["SAFE_FLOOR", 2.0],   // phys[1][1]
  ["CLEARANCE",  0.2],   // phys[2][1] — PETG=0.2, others=0.1
  ["NOZZLE",     0.4],   // phys[3][1]
]
```

---

## Layer 0 — Lexicon: Enums & Constants

### `MasterEnum.scad` — String Key Definitions

All key names used in `get_val` are defined here as string constants:

```scad
WIDTH     = "WIDTH";
PATTERN   = "PATTERN";
TEARDROP  = "Teardrop";
BOX       = "Box";
JAR       = "Threaded Jar";
// etc.
```

Using constants instead of raw strings means the compiler catches typos and grep finds all usages.

**Part type enums** (used as `TYPE` values):
`BOX`, `LID`, `LID_GLIDE`, `FLIP_BOX`, `FLIP_LID`, `DOUBLE_FLIP_BOX`, `JAR`, `JAR_LID`, `JAR_GRID`, `BOX_GRID`, `TRAY_SIMPLE`, `TRAY_STACK_NEST`, `TRAY_STACK_PEG`, `PEG`, `PLAQUE`, `PLAQUE_JAR`, `DESICCANT_BOX`, `DESICCANT_LID`, `SPEC_TAG`

**Mesh pattern enums**: `HONEYCOMB`, `TEARDROP`, `SLOTTED`, `CIRCLE`, `SQUARE`, `DIAMOND`, `NONE`

### `MasterConstants.scad` — Engineering Constants

Physical/engineering values that should never be scattered as magic numbers in geometry code:

| Category | Key Constants |
|----------|--------------|
| Snap-fit geometry | `HINGE_DIAMETER=4.0`, `HINGE_DIAMETER_FLIP=5.5`, `HINGE_CLEARANCE=0.2`, `CLIP_WALL_THICKNESS_MULT=4.0` |
| FDM safety limits | `MAX_FLOOR_THICKNESS_PCT=35`, `MAX_WALL_THICKNESS_PCT=45`, `MAX_LID_THICKNESS_PCT=35`, `MAX_CHAMFER_MULT=2.5` |
| Jar threading | `JAR_LIP_HEIGHT=8.0`, `THREAD_CHAMFER=0.5` |
| Mesh geometry | `MIN_HOLE_SPACING=1.2`, `HEXAGON_HEIGHT_MULT=0.866` |
| Grid system | `GRID_DROP_IN_TOLERANCE=0.4`, `GRID_BASE_HEIGHT_MULT=4.0` |
| Platter layout | `PLATTER_DEFAULT_GAP=15`, `MAX_BUILD_PLATE_WIDTH=250` |
| Layer height presets | `LAYER_HEIGHT_FAST=0.24`, `LAYER_HEIGHT_STANDARD=0.20`, `LAYER_HEIGHT_DETAILED=0.12` |
| Nozzle presets | `NOZZLE_FINE=0.2`, `NOZZLE_STANDARD=0.4`, `NOZZLE_MEDIUM=0.6` |

---

## Layer 1 — The Math Kernel

### `MasterEngine.scad` — Core Parameter Getters

The foundation every other module builds on. Two classes of functions:

**Universal Extractor:**
```scad
function get_val(key, data, fallback) = ...
// Scans the data array for the first matching key; returns fallback if missing
```

**Dimension Getters** (all enforce minimum safe values):
```scad
m_bw(data)   // Build Width  — minimum 10mm
m_bl(data)   // Build Length — minimum 10mm
m_bh(data)   // Build Height — minimum 5mm
m_noz(data)  // Nozzle diameter
m_lh(data)   // Layer height (converts string presets like "Detailed (0.12mm)" to numeric)
m_wloops(data) // Wall loop/perimeter count
```

**FDM Safety Getters** (all enforce physics-based constraints):
```scad
m_safe_floor(data)  // Floor thickness: rounded to layer-height multiple, capped at 35% of height
m_safe_lid(data)    // Same logic for lid
m_safe_wall(data)   // Wall thickness: rounded to nozzle multiple, min = nozzle × loops, capped at 45% of XY
m_c_rad(data)       // Safe inner corner radius: wall + (nozzle × loops / 2) − 0.5mm
m_chamf(data)       // Max safe chamfer: nozzle × 2.5
```

**Mesh Configuration:**
```scad
function get_mesh_cfg(data, h_key, s_key, needs_margin=false)
// Returns [hole_size, strut_percentage] or undef (when pattern=NONE, holes too small, or strut ≥ 99%)
// needs_margin=true applies LID_MIN_SOLID constraint (enforces minimum solid border for lids)
```

**String/Number Utilities:**
```scad
function get_digits(s)  // "S2/3/50%" → [2, 3, 5, 0] (digit characters as int array)
function to_num(d)      // [5, 0] → 50 (up to 3 digits)
```

### `MasterSafety.scad` — FDM Alignment Rules

Contains the same safety functions as MasterEngine but as standalone definitions with detailed engineering rationale in comments. `MasterChecks.scad` is a shim that just includes MasterSafety — any legacy code that includes MasterChecks gets Safety transitively.

The key insight: **all thicknesses must align to printer hardware increments**:
- Floor/lid → must be exact multiples of `layer_height` (prevents Z micro-stepping)
- Walls → must be exact multiples of `nozzle_diameter` (prevents partial extrusion loops)

### `MasterValidation.scad` — Pre-Build Warnings

Runs validation checks and echoes warnings to the OpenSCAD console. Never blocks rendering — only warns. Called as part of `process_part()` or explicitly via `validate_all(data)`.

Checks performed:
- Dimensions < 10mm or > 500mm
- Wall/floor/lid thickness below nozzle diameter or above 10mm
- Grid layout string fails tokenization
- Grid cells < 5×5mm (too small to print reliably)
- Mesh holes outside 0.5–5mm printable range
- Strut percentages producing structurally unsound results

---

## Layer 2 — Domain Processors

### `MasterManifest.scad` — Build Intent Compiler

`compile_manifest(intent, data)` translates a user-facing intent string into a manifest array.

```
"Threaded Jar" → [["JAR", data, opts, phys], ["LID", data, opts, phys]]
"Box"          → [["TRAY", data, opts, phys]]
(default)      → [["TRAY", data, opts, phys]]
```

Each manifest item is assembled using `MasterProcessor`:
- `get_physics_profile(data)` → computes the `phys` array
- `get_build_options(type, data)` → computes the `opts` array

### `MasterProcessor.scad` — Data Transformation Pipeline

**`get_physics_profile(data)`** — pre-computes all safety values once so factories don't each call the math independently:
```scad
[
  ["SAFE_WALL",  m_safe_wall(data)],
  ["SAFE_FLOOR", m_safe_floor(data)],
  ["CLEARANCE",  filament == "PETG" ? 0.2 : 0.1],
  ["NOZZLE",     m_noz(data)]
]
```

**`get_build_options(type, data, custom_opts)`** — builds the options array merged with any caller-specific options:
```scad
[["IS_THREADED", get_val("HAS_THREADS", data, false)],
 ["IS_STACKABLE", get_val("INTENT", data, "") == "Stackable Tray"],
 ["OFFSET_XYZ", [0,0,0]],
 ...custom_opts]
```

### `MasterRender.scad` — Render Pipeline Umbrella

Acts as a hub `include` that pulls in all domain modules. Also defines:

**`process_part(part_data)`** — the standard pre-processing pipeline:
```scad
function process_part(part_data) = enforce_safety(apply_inductions(part_data));
```

1. **`apply_inductions(data)`** — automatic overrides based on part type:
   - Desiccant box/lid: forces `PATTERN=SLOTTED` (required for moisture absorption)
   
2. **`enforce_safety(data)`** — prepends computed safe thicknesses so they override raw UI values:
   ```scad
   concat([[THICK_WALL, m_safe_wall(data)], [THICK_FLOOR, m_safe_floor(data)]], data)
   ```

**`apply_master_bounds(w, l, h, r, c)`** — clips child geometry to a rounded-corner bounding box. Used by factories to ensure nothing escapes the outer container walls:
```scad
intersection() {
  children();
  cuboid([w, l, h*3], rounding=c_r, edges="Z", anchor=BOTTOM);
}
```

### `MasterDispatcher.scad` — Alternate Entry Point (Platter Mode)

An alternative to `MasterBuilder`'s `build_part()` for rendering multiple parts arranged on a print bed:

```scad
build_platter(manifest)  // iterates manifest, calls factory_render_* per item
build_part(data)         // compile_manifest then build_platter
```

### `MasterUtility.scad` — Preflight Reports & Vector Math

**Preflight reporting:** `generate_preflight_report(data)` echoes a structured factory report to the OpenSCAD console including part type, builder version, nozzle size, computed wall/floor thicknesses, and slicer wall-order recommendation.

**Vector Math Engine (FrankenTray):**
```scad
parse_val(s)                                      // Parse signed number from string
get_rib_angle(traj, w, l, ox, oy)                // Trajectory label → bearing angle (degrees)
calc_touch_dist(angle, ox, oy, w, l, is_jar)     // Ray-to-wall intersection distance
get_rib_length(angle, beh, traj, ox, oy, w, l, is_jar)  // Rib length from behavior code
```

These are consumed by `RenderRib.scad` and `RenderGrid.scad` for FrankenTray rib layout.

### `MasterTolerance.scad` — Physical Fit Profiles

Provides per-material, per-fit-profile clearance gaps and snap engagement depths for mechanical joints.

```scad
breathing_room(COMP_SPINE, data)   // Clearance for the hinge spine pin
breathing_room(COMP_GLIDE, data)   // Clearance for sliding lid
engagement_depth(COMP_CLASP, data) // Snap depth for front clasp
```

Fit profiles: `FIT_TIGHTER` (−2) through `FIT_LOOSER` (+2). Each step adjusts clearance by ±0.05mm and engagement by ±0.20mm. Filament types have different baseline values (PETG is more flexible than PLA, needs more room).

---

## Layer 3 — Factory Renderers

Each factory receives `(data, opts, phys)` and produces printable geometry.

### `factory_render_tray(data, opts, phys)` — `RenderTray.scad`

Simple rectangular open container. When `IS_STACKABLE=true`, cuts 4 cylindrical peg holes at the corners for stacking connectors.

```
[floor]
[four walls]
[4 × peg cutout at corners, if stackable]
```

### `factory_render_jar(data, opts, phys)` — `RenderJar.scad`

Cylindrical jar body. Z-stack from bottom:

```
Z = 0              → jar starts
Z = sf/2           → circular floor mesh (framed_mesh, is_cyl=true)
Z = sf             → cylindrical wall mesh begins (cylindrical_mesh_wall)
Z = sf + cyl_h     → neck transition cone (if IS_THREADED)
Z = sf + cyl_h + sw×1.5  → external BOSL2 threading section (if IS_THREADED)
```

The neck tapers from the jar's outer diameter down to a narrower threading diameter. The interior is hollowed with `difference()` to save material.

### `factory_render_lid(data, opts, phys)` — `RenderLid.scad`

Dispatches on `LID_TYPE` option:
- **`"Glide"`** — a flat panel that slides into a groove on the box; uses `breathing_room(COMP_GLIDE)` for fit
- **`"Flip_Single"`** — hinged lid with C-clip spine, front clasp; uses `engagement_depth(COMP_CLASP)` for snap depth
- **`"Screw"`** — internally threaded cap for threaded jar; uses `threaded_rod(internal=true)`
- **default** — simple slip-on lid (press fit)

### `factory_render_grid(data, opts, phys)` — `RenderGrid.scad`

Renders FrankenTray rib geometry. Reads `GRID_LAYOUT`, calls `parse_franken_config()`, then for each rib:
1. Compute bearing angle via `get_rib_angle(traj, ...)`
2. Compute rib length via `get_rib_length(angle, beh, ...)`
3. Place an oriented `cuboid` from anchor point to computed distance

### `factory_render_peg(data, opts, phys)` — `RenderPeg.scad`

Single stacking peg: a 10mm diameter cylinder (minus tolerance clearance) placed 5mm below the container's top edge, at `OFFSET_XYZ` position. Used for stacking tray interlocking.

### `render_box(data)` / `render_flip_box(data)` — `RenderBox.scad`

Older-style domain modules (Layer 2.1, not Layer 3 factories). Still called by `MasterRender.scad`:

- **`render_box`** — rectangular tray with optional glide-lid groove cut into the top edge
- **`render_flip_box`** — adds hinge pin boss, C-clip relief, front diamond latch, and optional internal grid pillars
- **`render_double_flip_box`** — two-sided version: hinges on both Y faces, spine gap clearance, two latches

---

## Subsystem: Mesh Generation

Mesh is applied to flat surfaces (floors, lids) and cylindrical surfaces (jar walls).

### Flat Mesh: `framed_mesh(data, w, l, h, is_cyl, cfg)` — `RenderMesh.scad`

```
cfg = get_mesh_cfg(data, "HOLE_FLOOR", "STRUT_FLOOR")
    → [hole_size, strut_percentage] or undef
```

If `cfg = undef`, renders a solid slab. Otherwise:

```
solid_block
  difference()
    tiled pattern of holes (centered in inner mesh area)
```

For circular surfaces (`is_cyl=true`), the pattern area is circular (used for jar floors).

The inner mesh area is reduced by the strut percentage:
```
mesh_dim = full_dim × (1 - strut_pct/100)
```

### Cylindrical Mesh: `cylindrical_mesh_wall(data, d, h, wall_t, cfg)` — `RenderMesh.scad`

Creates a hollow cylinder shell, then cuts the mesh pattern through the shell. Each hole primitive is a 3D solid sized to pass through `wall_t` mm of material.

### Pattern Primitives: `MasterMeshPatterns.scad`

Two classes of patterns:

**Flat (2D extruded through a slab):**
```
pattern_honeycomb(hole, step, nx, ny)  — staggered hex grid
pattern_teardrop(hole, step, nx, ny)   — regular teardrop grid
pattern_slotted(hole, step, nx, ny)    — horizontal oval slots
pattern_circle(hole, step, nx, ny)     — regular circle grid
pattern_square(hole, step, nx, ny)     — square grid
pattern_diamond(hole, step, nx, ny)    — 45°-rotated squares
```
Dispatcher: `render_rectangular_pattern(pat, hole, step, nx, ny)`

**Cylindrical (3D primitives for difference-cutting a cylinder shell):**
```
pattern_cylindrical_honeycomb/teardrop/slotted/circle/square/diamond(hole, wall_t)
```
Dispatcher: `render_cylindrical_pattern(pat, hole, wall_t)`

---

## Subsystem: Grid Layout Parsing

The `GRID_LAYOUT` string is a compact ASCII specification for internal dividers.

### Grid String Syntax

```
"[CartesianSpec] [SpanSpec...] [RadialSpec] [CenterSpec]"
```

| Token | Example | Meaning |
|-------|---------|---------|
| Cartesian | `3x2` | 3 columns × 2 rows of equal cells |
| Span | `S1/2/2/1/80%` | Custom cell at row 1, col 2, spanning 2 cols × 1 row, height 80% of default |
| Radial | `R6` | 6 radial rays (for jars) |
| Center | `C20%` | Center hub diameter = 20% of jar diameter |

Span format: `S[row]/[col]/[col_span]/[row_span]/[height]`
Height can be absolute mm or a percentage of the default internal height.

### Parsing Pipeline: `GridLayout.scad`

```
get_grid_tokens(g_str)       → split on spaces, filter empty
parse_cartesian(g_str)       → [cols, rows]
parse_radial(g_str)          → [rays, center_value, is_percent]
parse_spans(g_str, ...)      → array of [row, col, row_span, col_span, height, req_h, is_closed]
get_grid_config(data)        → [cart_dims, rad_dims, spans, has_base, base_t, default_h]
```

`get_grid_config` is the master router that combines all parsers and computes `default_h` from the available internal height (total height minus floor and optionally lid).

### Geometry Rendering: Old `RenderGrid.scad` vs. New Factory

The old architecture (`RenderBox.scad`) embedded cartesian wall rendering directly. The new factory (`factory_render_grid`) focuses on FrankenTray rib geometry and reads from `parse_franken_config`.

---

## Subsystem: FrankenTray Rib Topology

FrankenTray is the vector-based rib system for non-cartesian divider layouts — radial spokes, diagonal walls, angled partitions.

### FrankenTray Grid String Syntax

```
"P[rays]/[hub_d] O[x],[y] [traj]-[behavior] ..."
```

| Token | Example | Meaning |
|-------|---------|---------|
| Hub definition | `P6/20` | 6 rays, 20mm diameter hub |
| Offset | `O10,-5` | Anchor point at X=10, Y=−5 from center |
| Rib | `N-T` | Ray traveling North, length = touch-wall (T) |
| Rib | `NE-F50%` | Northeast ray, 50% of wall-touch distance |
| Rib | `45-D` | 45° bearing ray, displacement behavior |

### Rib Behavior Codes

| Code | Meaning |
|------|---------|
| `T` | Touch — extends until it hits the container wall |
| `D` | Displacement — uses the trajectory vector magnitude as length |
| `F50%` | Fraction — 50% of the wall-touch distance |

### Parsing: `GridLayout.scad`

```
parse_franken_config(g_str)
  parse_rib_node(token)    → [trajectory_string, behavior_code]
  parse_offset(o_str)      → [x, y]
→ [rays, hub_diameter, [ox, oy], [[traj, beh], ...]]   or undef if no "P" token
```

### Geometry: `MasterUtility.scad` + `RenderRib.scad`

```
get_rib_angle(traj, w, l, ox, oy)
  "N"/"S"/"E"/"W"  → cardinal angles (90, −90, 0, 180)
  "NE"/"NW"/etc.   → atan2 to corner
  "45"             → parse_val → 45°
  "10,20"          → parse_val per component → atan2(20, 10)

calc_touch_dist(angle, ox, oy, w, l, is_jar)
  rectangular: ray-AABB intersection
  cylindrical: ray-circle intersection (quadratic formula)

get_rib_length(angle, beh, ...)
  "T" → t_dist
  "D" → vector magnitude from traj string
  "F50%" → t_dist × 0.50
```

`RenderRib.render_franken_ribs(data)` assembles all ribs using the above math and clips them to the container interior (rectangular: `apply_master_bounds`; cylindrical: `intersection()` with a cylinder).

---

## Subsystem: FDM Safety Validation

All thickness values pass through safety normalization before use:

### Floor & Lid Thickness

```
safe_floor = max(
  layer_height,                                    // absolute minimum: 1 layer
  round(
    min(requested_floor, height × 35%)             // cap: no more than 35% of total height
    / layer_height
  ) × layer_height                                 // snap to layer multiple
)
```

**Why:** The slicer converts the STL to layers at exactly `layer_height` increments. If the floor is `2.05mm` on a `0.20mm` layer printer, the slicer rounds to 10 layers (2.00mm) anyway — but may introduce a micro-step that causes poor adhesion. Snapping in CAD eliminates slicer ambiguity.

### Wall Thickness

```
safe_wall = max(
  nozzle × wall_loops,                             // minimum: can't print thinner than this
  round(
    min(requested_wall, min(width, length) × 45%)  // cap: no wall thicker than 45% of XY
    / nozzle_diameter
  ) × nozzle_diameter                              // snap to nozzle multiple
)
```

**Why:** Each perimeter loop is exactly `nozzle_diameter` wide. A 2.1mm wall on a 0.4mm nozzle requires 5.25 loops — impossible. The slicer either makes it 5 loops (2.0mm) or 6 (2.4mm). Snapping prevents this ambiguity.

---

## Subsystem: Tolerances & Fit Profiles

`MasterTolerance.scad` provides per-joint, per-material clearance values.

### Components

| Constant | Joint | Use |
|----------|-------|-----|
| `COMP_SPINE` | Hinge pin in boss | Flip-box rotation axis |
| `COMP_CCLIP` | C-clip spring tab | Hinge retention |
| `COMP_CLASP` | Front snap latch | Lid-closed engagement |
| `COMP_BELLY` | Belly snap bump | Internal engagement depth |
| `COMP_GLIDE` | Glide-lid rail | Sliding lid clearance |

### Fit Profiles

Applying `FIT_TIGHTER` tightens every joint by 0.05mm (clearance) / 0.20mm (engagement) per step. PETG needs more room than PLA due to different shrinkage and flexibility characteristics.

---

## Include & Dependency Graph

```
MasterEnum.scad ─────────────────────────────────────────────┐
MasterConstants.scad ─────────────────────────────────────── │
                                                              ▼
MasterEngine.scad ←── [MasterEnum + MasterConstants]         │
    ▲                                                         │
    ├─── MasterSafety.scad ←── MasterConstants               │
    │         ▲                                               │
    │    MasterChecks.scad (shim)                             │
    │                                                         │
    ├─── MasterValidation.scad ←── MasterGridParser.scad     │
    │                                                         │
    ├─── MasterGridParser.scad ←── MasterEnum                │
    │                                                         │
    ├─── GridLayout.scad ←── [BOSL2, MasterEnum, MasterEngine]
    │         (provides parse_franken_config)
    │
    ├─── MasterMeshPatterns.scad ←── [BOSL2, MasterEngine]
    │
    ├─── MasterText.scad ←── MasterEnum
    │
    ├─── MasterUtility.scad ←── [Engine, Checks, Text, Validation]
    │         (provides get_rib_angle, get_rib_length)
    │
    ├─── MasterBug.scad ←── MasterEngine
    │
    ├─── MasterTolerance.scad  (standalone)
    │
    ├─── MasterProcessor.scad ←── MasterEngine
    │
    ├─── MasterManifest.scad ←── MasterEngine
    │
    ├─── RenderMesh.scad ←── [BOSL2, MasterEngine]
    │
    ├─── RenderBox.scad ←── MasterTolerance (→ engine transitively)
    │
    ├─── MasterLegacyBridge.scad ←── [BOSL2, Engine, MeshPatterns, RenderMesh]
    │
    ├─── RenderJar.scad ←── [BOSL2, Engine, LegacyBridge, RenderMesh]
    │
    ├─── RenderLid.scad ←── [BOSL2, Engine, LegacyBridge, Tolerance, RenderMesh]
    │
    ├─── RenderTray.scad ←── [BOSL2, MasterEngine]
    │
    ├─── RenderGrid.scad ←── [BOSL2, Engine, GridLayout, MasterUtility]
    │
    ├─── RenderRib.scad ←── [BOSL2, GridLayout, MasterBug, MasterUtility]
    │
    ├─── RenderPeg.scad ←── [BOSL2, MasterEngine]
    │
    ├─── RenderPlaque.scad  (depends on Engine via caller's include)
    │
    └─── MasterRender.scad ←── [Utility, MeshPatterns, GridParser, all Render*]

MasterDispatcher.scad ←── [BOSL2, Engine, Manifest, all Render*]
MasterBuilder.scad ←── [Engine, Manifest, use Render*]
```

---

## Adding a New Part Type — Step-by-Step

To add a new part type (e.g. `"Pill Box"`):

**1. Define the enum in `MasterEnum.scad`:**
```scad
PILL_BOX = "Pill Box";
```

**2. Add the manifest entry in `MasterManifest.scad`:**
```scad
(intent == "Pill Box") ?
  [["PILL", data, get_build_options(PILL_BOX, data), get_physics_profile(data)]] :
```

**3. Create the factory in a new `RenderPillBox.scad`:**
```scad
include <BOSL2/std.scad>
include <MasterEngine.scad>
include <RenderMesh.scad>

module factory_render_pill_box(data, opts, phys) {
  w = m_bw(data); l = m_bl(data); h = m_bh(data);
  sf = phys[1][1]; sw = phys[0][1];
  // ... geometry here
}
```

**4. Wire it into `MasterBuilder.scad`:**
```scad
use <RenderPillBox.scad>
// Inside build_part() dispatcher:
else if (type == "PILL") {
  factory_render_pill_box(data_payload, options, physics);
}
```

**5. Add to Customizer dropdown in `MasterBuilder.scad`:**
```scad
Part_To_Build = "Threaded Jar"; // ["Box", "Threaded Jar", "Flip Box", "Simple Tray", "Pill Box"]
```

No other files need changes. The key-value data structure means the new factory can read any existing parameter (`GRID_LAYOUT`, `PATTERN`, etc.) without API changes to the engine.
