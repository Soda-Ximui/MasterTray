# MasterTray — Refactoring Log
_Intentional code-quality changes: consolidations, renamed constants, dead-code removal._
_Not bugs — nothing was broken. Each entry explains why the change was made._

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

_Add new entries as R7, R8, … in order of date._
