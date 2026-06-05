# MasterTray — Refactoring Log
_Intentional code-quality changes: consolidations, renamed constants, dead-code removal._
_Not bugs — nothing was broken. Each entry explains why the change was made._
_Entries are in reverse-chronological order (newest first). Each entry cites the git commit to diff._

---

## R1 — `mesh_params()` helper eliminates duplicated cfg-unpacking block

**File:** `RenderMesh.scad`  
**Commit:** `f9679cc`  
**Date:** 2026-06-04

### What was duplicated

Both `framed_mesh` and `cylindrical_mesh_wall` opened their `else` branch with
an identical 8-line block:

```scad
noz     = m_noz(data);
pat     = get_val(PATTERN, data, TEARDROP);
hole    = cfg[0];
strut   = cfg[1];
spacing = get_val(HOLE_SPACING, data, m_wloops(data) * noz);
min_sp  = (pat == SLOTTED) ? noz * 1.05 * 4 : spacing;
base_step = get_grid_step(hole, min_sp, noz);
step    = $preview ? base_step * 2 : base_step;
```

Any change to hole-spacing logic, the slotted-pillar rule, or preview scaling
had to be made twice and kept in sync manually.

### Fix

Extracted to a shared function returning `[noz, pat, hole, strut, step]`:

```scad
function mesh_params(cfg, data) =
  let(
    noz       = m_noz(data),
    pat       = get_val(PATTERN, data, TEARDROP),
    hole      = cfg[0],
    strut     = cfg[1],
    spacing   = get_val(HOLE_SPACING, data, m_wloops(data) * noz),
    min_sp    = (pat == SLOTTED) ? noz * EXTRUSION_WIDTH_MULT * 4 : spacing,
    base_step = get_grid_step(hole, min_sp, noz)
  )
  [noz, pat, hole, strut, $preview ? base_step * 2 : base_step];
```

Each module now unpacks in 3 lines:

```scad
mp    = mesh_params(cfg, data);
noz   = mp[0];  pat  = mp[1];  hole = mp[2];
strut = mp[3];  step = mp[4];
```

---

## R2 — `noz * 1.05 * 4` → `noz * EXTRUSION_WIDTH_MULT * 4`

**File:** `RenderMesh.scad` (inside `mesh_params`)  
**Commit:** `f9679cc`  
**Date:** 2026-06-04

The slotted-pillar minimum spacing rule was written as `noz * 1.05 * 4`.
The `1.05` is Bambu Studio's default extrusion width multiplier (105% of nozzle
diameter), already named `EXTRUSION_WIDTH_MULT` in `MasterConstants.scad`.

Replaced with `noz * EXTRUSION_WIDTH_MULT * 4` so the constant is used
consistently and the intent is self-documenting.

---

## R3 — `STRUT_HOLE_RATIO` promotes `hole * 0.25` in `get_grid_step`

**File:** `MasterEngine.scad`, `MasterConstants.scad`  
**Commit:** `0900f17`  
**Date:** 2026-06-04

`get_grid_step` computed minimum strut width as `hole * 0.25` — a bare literal
with no explanation. Extracted to `STRUT_HOLE_RATIO = 0.25` in `MasterConstants.scad`
with documented rationale (wins over the 2-nozzle floor only when `hole > nozzle_d * 8`).

---

## R4 — `corner_round_ratio` global + `Corner_Round_Ratio` Customizer knob

**Files:** `MasterEngine.scad`, `MasterBuilder.scad`, `MasterMeshPatterns.scad`,
           `MasterConstants.scad`  
**Commit:** `f92dd19`  
**Date:** 2026-06-04

Five call sites in `MasterMeshPatterns.scad` used `0.2` or `nozzle_d * 1.05`
bare literals for mesh hole corner rounding and teardrop/diamond tip width.

- `RECT_HOLE_ROUND_RATIO = 0.20` added to `MasterConstants.scad`
- `EXTRUSION_WIDTH_MULT = 1.05` added to `MasterConstants.scad`
- `line_width = nozzle_d * EXTRUSION_WIDTH_MULT` global added to `MasterEngine.scad`
- `corner_round_ratio` global added to `MasterEngine.scad`, driven by new
  `Corner_Round_Ratio` Customizer slider (range `[0.05:0.05:0.45]`, default `0.20`)
- All five call sites updated to use the named globals

Effect: `Corner_Round_Ratio` is now a live Customizer knob. Only affects holes
larger than `line_width / RECT_HOLE_ROUND_RATIO ≈ 2.1mm` — below that the Arachne
floor (`line_width`) always wins.

---

## R5 — `apply_master_bounds` two-pass intersection wires up dead `c` parameter

**File:** `MasterEngine.scad`  
**Commit:** `af0cec5`  
**Date:** 2026-06-04

`apply_master_bounds(w, l, h, r, c)` accepted a chamfer parameter `c` but the
body only used `r` (vertical corner rounding). Every call site passed
`m_chamf(data)` as `c` — silently ignored.

Rewritten to two-pass intersection:
- Pass 1: `cuboid([w, l, h*3], rounding=c_r, edges="Z")` — vertical corners,
  `h*3` oversize avoids BOSL2 clipping tall children
- Pass 2: `cuboid([w+EPS, l+EPS, h], chamfer=c, edges=TOP+BOTTOM)` — top rim
  safety + bottom elephant-foot relief

This was the root cause of knife-sharp jar and lid edges in print testing.

---

## R6 — Slotted pattern X-spacing bug: `step*1.5` → `step+hole`

**File:** `MasterMeshPatterns.scad`  
**Commit:** `f92dd19`  
**Date:** 2026-06-04

`pattern_slotted` used `spacing=[step*1.5, step]`. The slot is `hole*2` wide,
so the correct x center-to-center pitch is `hole*2 + pillar = hole + step`
(since `step = hole + pillar`). The old formula gave `1.5*hole + 1.5*pillar`
— pillars ~10% thinner than the structural rule required.

At `hole=3mm`, `pillar=1.68mm`: was `7.02mm`, corrected to `7.68mm`.

This was a geometry bug masquerading as a style issue — see BUGS.md for full
analysis. Listed here because the fix is in a pattern module alongside true
refactors; BUGS.md has the authoritative entry.

---

## R7 — FDM print-quality sweep: 16 findings across 8 files

**Files:** `MasterEngine.scad`, `MasterBuilder.scad`, `MasterMeshPatterns.scad`,
           `RenderBox.scad`, `RenderGrid.scad`, `RenderJar.scad`, `RenderLid.scad`,
           `RenderMesh.scad`  
**Commit:** `61aa64f`  
**Date:** 2026-06-04

Large sweep applying all Priority 1 and Priority 2 findings from `TODO.md`.
See `TODO.md` for full before/after code for each item. Summary:

**Correctness (P1):**
- `assert()` on Flip box hinge when `clip_len <= 0` — was silent `echo()` warning,
  box would render without a functional hinge (F15)
- `JAR_LIP_HEIGHT` constant used everywhere instead of hardcoded `8.0` (F18)
- `layer_snap()` helper added to `MasterEngine`; applied to diamond latch Z-offsets (F6)
- Snap bead height layer-aligned: `ceil(noz*2 / lh) * lh` (F14)

**Print quality (P2):**
- `$fn` replaced by `$fs`/`$fa` system — circles auto-compute facet count per nozzle diameter
- Teardrop rewritten: 45° roof start points (self-supporting) + truncated tip (Arachne pinch fix)
- Diamond: truncated rhombus polygon — vertical tips flattened to `nozzle_d * 1.05`
- Square/slotted corner rounding = `nozzle_d` for motion-planner jerk relief
- Slotted strut minimum raised to `noz * 1.05 * 4` (4 extrusion passes = 2 perimeters each side)
- Flip latch diamond Z-dimension: `noz * 1.05` (was `0.1mm` — below Arachne minimum) (F2)
- Glide ball min raised to `noz*8`, above Arachne small-perimeter clamp zone (F1)
- Radial hub thresholds nozzle-parametric: `min_hollow=noz*6`, `min_solid=noz*10` (F16)
- Jar grid clearance layer-aligned: `lh * ceil(0.5 / lh)` (F7)
- Glide groove Z layer-aligned: `lh * ceil(1.0 / lh)` (F8)
- Thread rod Z-offset uses `EPS` instead of bare `0.1` (F9)

**Minor (P3):**
- Hinge pillar top chamfer added (F5)
- Jar grid height layer-aligned: `round(int_h_raw / lh) * lh` (F17)

---

## R8 — `get_mesh_cfg` short-circuit evaluation

**File:** `MasterEngine.scad`  
**Commit:** `ae02712`  
**Date:** 2026-06-04

`get_mesh_cfg` previously computed all values before deciding whether mesh was
needed. Refactored to cascade early exits: `pat → hole → strut → margin`, so
`m_bw()`/`m_bl()` (which traverse the data array) are only called on lid
surfaces with a valid hole and strut. Solid surfaces and `None`-pattern surfaces
exit at the first check.

Also moved `noz`/`pat` lookups inside the `else` block of both mesh modules —
not evaluated at all when `cfg = undef` (solid surface).

---

## R9 — BOX factory unified: `LID_TYPE` in opts drives all body variants

**Files:** `RenderBox.scad`, `MasterManifest.scad`  
**Commit:** `3aa13f8`  
**Date:** 2026-06-03

Previously `render_box`, `render_flip_box`, `render_double_flip_box` were
separate functions with duplicated wall/floor geometry. Unified into a single
`factory_render_box()` where `LID_TYPE` in opts selects the body variant inline.

`factory_render_flip_box` / `factory_render_double_flip_box` are kept as thin
delegates for dispatcher compatibility but no longer emitted by the manifest.

Principle: **factory IS the implementation — opts drive variants**. See `docs/LESSONS.md §1`.

---

## R10 — Architecture revamp: 9 dead files deleted, pipeline consolidated

**Files:** 31 files changed (+2233 / −1071)  
**Commit:** `aef1546`  
**Date:** 2026-06-03

The largest single refactor. Deleted 9 files that had become dead code, shims,
or duplicates after prior work:

| Deleted | Reason |
|---------|--------|
| `MasterChecks.scad` | Logic absorbed into `MasterEngine` |
| `MasterSafety.scad` | `enforce_safety` moved to `MasterEngine` |
| `MasterRender.scad` | Replaced by per-primitive `Render*.scad` factories |
| `MasterDispatcher.scad` | Dispatcher inlined into `MasterBuilder` |
| `MasterPrimitives.scad` | Replaced by typed manifest + factory pattern |
| `MasterLegacyBridge.scad` | Shim no longer needed |
| `MasterGridParser.scad` | Validation functions moved to `GridLayout.scad` |
| `MasterBug.scad` | `log_franken_state` moved to `GridLayout.scad` |
| `blah.scad` | Scratch file |

Consolidated into surviving modules:
- `MasterEngine`: added `m_wall_mod_p`, `apply_master_bounds`, `apply_inductions`,
  `enforce_safety`, `process_part`
- `GridLayout`: absorbed validation + debug logging
- `RenderMesh`: explicit `MasterMeshPatterns` include (was hidden in `LegacyBridge`)

Completed the factory pipeline so all four dispatch types (`BOX`, `FLIP_BOX`,
`DOUBLE_FLIP_BOX`, `PLAQUE`) are wired in `MasterBuilder`.

Restored original `MasterBuilder.scad` as the canonical Customizer entry point
(23-option UI). Renamed the experimental builder to `MasterBuild2.scad`.

---

## R11 — Advanced geometry overrides: no hardcoded values in Customizer

**Files:** `MasterEnum.scad`, `MasterEngine.scad`, `MasterBuilder.scad`, `RenderTray.scad`  
**Commit:** `3883711`  
**Date:** 2026-06-03

Five geometry parameters (`chamfer_size`, `corner_radius`, `peg_socket_diameter`,
`nesting_ledge_depth`, `peg_protrusion`) were hardcoded in render files. Promoted
to Customizer knobs under `[Advanced - Geometry Overrides]`.

Convention: **0 = auto-compute from printer settings; non-zero = explicit override.**
`m_chamf()` and `m_c_rad()` in `MasterEngine` check data for a non-zero override
before falling back to the nozzle-derived formula.

---

## R12 — `$fn` → `$fs`/`$fa` across all circle geometry

**Files:** `MasterEngine.scad` (global), all `Render*.scad`  
**Commit:** `61aa64f`  
**Date:** 2026-06-04

Replacing `$fn` with `$fs`/`$fa` lets OpenSCAD auto-compute facet count based
on the circle's actual radius and the desired chord tolerance — larger circles
get more facets, small features stay fast. Hard-coded `$fn=36` or `$fn=64` values
produce either over-faceted small holes or under-faceted large circles.

Set globally in `MasterEngine`:
```scad
$fs = nozzle_d / 2;   // max chord length = half nozzle width
$fa = 2;              // max angle step = 2°
```

Explicit `$fn` overrides are kept only where geometry correctness requires a
specific facet count (e.g. hex jar `$fn=6`, threaded rod `$fn=30`).

---

_Add new entries as R13, R14, … in reverse-chronological order (newest at top — renumber on insert)._

## R1 — `mesh_params()` helper eliminates duplicated cfg-unpacking block

**File:** `RenderMesh.scad`  
**Commit:** `f9679cc`  
**Date:** 2026-06-04

### What was duplicated

Both `framed_mesh` and `cylindrical_mesh_wall` opened their `else` branch with
an identical 8-line block:

```scad
noz     = m_noz(data);
pat     = get_val(PATTERN, data, TEARDROP);
hole    = cfg[0];
strut   = cfg[1];
spacing = get_val(HOLE_SPACING, data, m_wloops(data) * noz);
min_sp  = (pat == SLOTTED) ? noz * 1.05 * 4 : spacing;
base_step = get_grid_step(hole, min_sp, noz);
step    = $preview ? base_step * 2 : base_step;
```

Any change to hole-spacing logic, the slotted-pillar rule, or preview scaling
had to be made twice and kept in sync manually.

### Fix

Extracted to a shared function returning `[noz, pat, hole, strut, step]`:

```scad
function mesh_params(cfg, data) =
  let(
    noz       = m_noz(data),
    pat       = get_val(PATTERN, data, TEARDROP),
    hole      = cfg[0],
    strut     = cfg[1],
    spacing   = get_val(HOLE_SPACING, data, m_wloops(data) * noz),
    min_sp    = (pat == SLOTTED) ? noz * EXTRUSION_WIDTH_MULT * 4 : spacing,
    base_step = get_grid_step(hole, min_sp, noz)
  )
  [noz, pat, hole, strut, $preview ? base_step * 2 : base_step];
```

Each module now unpacks in 3 lines:

```scad
mp    = mesh_params(cfg, data);
noz   = mp[0];  pat  = mp[1];  hole = mp[2];
strut = mp[3];  step = mp[4];
```

---

## R2 — `noz * 1.05 * 4` → `noz * EXTRUSION_WIDTH_MULT * 4`

**File:** `RenderMesh.scad` (inside `mesh_params`)  
**Commit:** `f9679cc`  
**Date:** 2026-06-04

The slotted-pillar minimum spacing rule was written as `noz * 1.05 * 4`.
The `1.05` is Bambu Studio's default extrusion width multiplier (105% of nozzle
diameter), already named `EXTRUSION_WIDTH_MULT` in `MasterConstants.scad`.

Replaced with `noz * EXTRUSION_WIDTH_MULT * 4` so the constant is used
consistently and the intent is self-documenting.

---

## R3 — `STRUT_HOLE_RATIO` promotes `hole * 0.25` in `get_grid_step`

**File:** `MasterEngine.scad`, `MasterConstants.scad`  
**Commit:** `0900f17`  
**Date:** 2026-06-04

`get_grid_step` computed minimum strut width as `hole * 0.25` — a bare literal
with no explanation. Extracted to `STRUT_HOLE_RATIO = 0.25` in `MasterConstants.scad`
with documented rationale (wins over the 2-nozzle floor only when `hole > nozzle_d * 8`).

---

## R4 — `corner_round_ratio` global + `Corner_Round_Ratio` Customizer knob

**Files:** `MasterEngine.scad`, `MasterBuilder.scad`, `MasterMeshPatterns.scad`,
           `MasterConstants.scad`  
**Commit:** `f92dd19`  
**Date:** 2026-06-04

Five call sites in `MasterMeshPatterns.scad` used `0.2` or `nozzle_d * 1.05`
bare literals for mesh hole corner rounding and teardrop/diamond tip width.

- `RECT_HOLE_ROUND_RATIO = 0.20` added to `MasterConstants.scad`
- `EXTRUSION_WIDTH_MULT = 1.05` added to `MasterConstants.scad`
- `line_width = nozzle_d * EXTRUSION_WIDTH_MULT` global added to `MasterEngine.scad`
- `corner_round_ratio` global added to `MasterEngine.scad`, driven by new
  `Corner_Round_Ratio` Customizer slider (range `[0.05:0.05:0.45]`, default `0.20`)
- All five call sites updated to use the named globals

Effect: `Corner_Round_Ratio` is now a live Customizer knob. Only affects holes
larger than `line_width / RECT_HOLE_ROUND_RATIO ≈ 2.1mm` — below that the Arachne
floor (`line_width`) always wins.

---

## R5 — `apply_master_bounds` two-pass intersection wires up dead `c` parameter

**File:** `MasterEngine.scad`  
**Commit:** `af0cec5`  
**Date:** 2026-06-04

`apply_master_bounds(w, l, h, r, c)` accepted a chamfer parameter `c` but the
body only used `r` (vertical corner rounding). Every call site passed
`m_chamf(data)` as `c` — silently ignored.

Rewritten to two-pass intersection:
- Pass 1: `cuboid([w, l, h*3], rounding=c_r, edges="Z")` — vertical corners,
  `h*3` oversize avoids BOSL2 clipping tall children
- Pass 2: `cuboid([w+EPS, l+EPS, h], chamfer=c, edges=TOP+BOTTOM)` — top rim
  safety + bottom elephant-foot relief

This was the root cause of knife-sharp jar and lid edges in print testing.

---

## R6 — Slotted pattern X-spacing bug: `step*1.5` → `step+hole`

**File:** `MasterMeshPatterns.scad`  
**Commit:** `f92dd19`  
**Date:** 2026-06-04

`pattern_slotted` used `spacing=[step*1.5, step]`. The slot is `hole*2` wide,
so the correct x center-to-center pitch is `hole*2 + pillar = hole + step`
(since `step = hole + pillar`). The old formula gave `1.5*hole + 1.5*pillar`
— pillars ~10% thinner than the structural rule required.

At `hole=3mm`, `pillar=1.68mm`: was `7.02mm`, corrected to `7.68mm`.

This was a geometry bug masquerading as a style issue — see BUGS.md for full
analysis. Listed here because the fix is in a pattern module alongside true
refactors; BUGS.md has the authoritative entry.

---

_Add new entries as R7, R8, … in order of date._
