# Session Handoff — MasterTray
_Last updated: 2026-06-04 — post print-quality sweep + magic number elimination_

---

## How to Resume

Open Claude Code **from inside `C:\repos\3D\MasterTray`**:
```
cd C:\repos\3D\MasterTray
claude
```
Claude executable: `C:\Users\hobbes\AppData\Roaming\Claude\claude-code\<version>\claude.exe`
Do NOT start a generic Claude chat — it will have no context.

---

## Branch & State

**Branch:** `feature/architecture-revamp`
**Base:** `refactor/code-clarity-and-safety`
**Last commit:** `0900f17` — `refactor: promote STRUT_HOLE_RATIO 0.25 magic number to named constant`
**Commits ahead of base:** 6

Recent commit log:
```
0900f17 refactor: promote STRUT_HOLE_RATIO 0.25 magic number to named constant
01d71de docs: clarify Corner_Round_Ratio Arachne floor threshold; expand FDM symptom guide
f92dd19 refactor: eliminate magic numbers in mesh patterns; fix slotted spacing bug; expose corner rounding as Customizer knob
af0cec5 feat: add bottom chamfer to apply_master_bounds — elephant foot relief on all primitives
7224e8e fix: chamfer all user-facing sharp edges — box/tray top rims, jar walls, screw lid cap
61aa64f feat: FDM print-quality sweep — nozzle-adaptive geometry, Arachne fixes, layer alignment
```

**Status:** All committed, NOT pushed. No active PR yet on this branch.

---

## All 5 Primitives — Status

| # | Primitive | Status | Notes |
|---|-----------|--------|-------|
| 1 | TRAY | ✅ Done | Hollow chassis, mesh, wall mods, stackable (Peg/Builtin/Snap), GRID_WALL_H |
| 2 | JAR | ✅ Done | Circular floor + wall mesh, threaded neck, polygon shapes, built-in grid |
| 3 | LID | ✅ Done | Snap, Glide (H/V, Ball/Tab), Flip_Single (diamond latch), Screw, Slip |
| 3b | BOX | ✅ Done | Unified factory — all LID_TYPE variants inline, GRID_WALL_H injection |
| 4 | GRID | ✅ Done | Cartesian + radial + spans, built-in + drop-in, jar circular clipping |
| 5 | RIB | ⬜ Not started | FrankenTray vector ribs — code in RenderRib.scad, parser in GridLayout.scad |

---

## What's Working (Manifest Intents)

| Intent | Produces |
|--------|---------|
| Simple Tray | TRAY |
| Box | BOX(Snap) + LID(Snap) |
| Standalone Box | BOX(Glide) + LID(Glide) |
| Flip Box | BOX(Flip_Single) + LID(Flip_Single) |
| Double Flip Box | BOX(Flip_Double) + 2×LID(Flip_Single) |
| Nesting Tray (Short) | TRAY(Snap stack) |
| Modular Peg Tray (Long) | TRAY(Peg stack) + 4×PEG |
| Open Jar | 1 or 2 JAR (dual-spawn w≠l) |
| Threaded Jar | 1 or 2 JAR threaded |
| Jar with Lid | JAR+LID pairs |
| Simple Jar / S4 Jar / Spool Jar | JAR+LID (S4 = desiccant mesh locked) |
| S4 Wedge | BOX(Glide)+LID(Glide) desiccant |
| S4 Set | S4 Jar + Spool Jar + S4 Wedge |
| Standalone Box Grid | GRID (drop-in box) |
| Standalone Jar Grid | GRID (drop-in, circular clip, dual-spawn w≠l) |
| ~13 others | → fallback TRAY + warning echo (pill boxes, etc.) |

---

## What Changed This Session (2026-06-04)

### Sharp edges / elephant foot (commits 7224e8e + af0cec5)

**Problem:** Print test showed knife-sharp rims on jar and lid.

**Root cause:** `apply_master_bounds(w, l, h, r, c)` accepted `c` chamfer parameter but never
used it — the body only applied `r` (vertical corner rounding). Cylindrical mesh wall had
no edge treatment at all.

**Fix — `apply_master_bounds` rewritten to two-pass intersection:**
```scad
module apply_master_bounds(w, l, h, r, c) {
  c_r = max(0.1, min(r, (w/2)-0.1, (l/2)-0.1));
  intersection() {
    intersection() {
      children();
      cuboid([w, l, h*3], rounding=c_r, edges="Z", anchor=BOTTOM);  // Pass 1: vertical corners
    }
    cuboid([w+EPS, l+EPS, h], chamfer=max(0,c), edges=TOP+BOTTOM, anchor=BOTTOM); // Pass 2: horiz edges
  }
}
```
- `edges=TOP+BOTTOM` → top rim safe to handle + bottom elephant foot relief (45° lead-in ramp)
- `h*3` oversize on Pass 1 avoids BOSL2 clipping tall children

**Cylindrical mesh wall** (`RenderMesh.scad`): added `rim_chamf = m_noz(data) * 4` (1.6mm) to
both outer cyl calls.

**Screw lid cap** (`RenderLid.scad`): `chamfer2=noz*4` on top edge.

**Flip_Double spine pillars** (`RenderBox.scad`): added `chamfer=m_chamf(data), edges=TOP`
(Flip_Single already had it — now consistent).

**Snap nesting ledge** (`RenderTray.scad`): added `chamfer=m_chamf(data), edges=BOTTOM`
(matched Peg mode which already had it).

---

### Magic number elimination (commits f92dd19 + 0900f17)

**New globals in `MasterEngine.scad`:**
```scad
line_width         = nozzle_d * EXTRUSION_WIDTH_MULT;       // replaces 5× nozzle_d*1.05
corner_round_ratio = is_undef(Corner_Round_Ratio) ? RECT_HOLE_ROUND_RATIO : Corner_Round_Ratio;
```

**New constants in `MasterConstants.scad`:**
- `RECT_HOLE_ROUND_RATIO = 0.20` — square/slotted hole corner rounding fraction
- `EXTRUSION_WIDTH_MULT = 1.05` — Bambu Studio 105% extrusion width
- `STRUT_HOLE_RATIO = 0.25` — min strut width = 25% of hole diameter (large holes)

**New Customizer knob in `MasterBuilder.scad`:**
```scad
Corner_Round_Ratio = 0.20; // [0.05:0.05:0.45]
// Only affects holes > ~2.1mm (= line_width / RECT_HOLE_ROUND_RATIO)
// Below that, Arachne floor (line_width = 0.42mm) always wins
```

**Slotted pattern spacing bug fixed** (`MasterMeshPatterns.scad`):
```scad
// BEFORE (wrong): spacing=[step*1.5, step]  — pillars ~10% too thin
// AFTER (correct): spacing=[step+hole, step] — exact 2*hole + pillar_width
```
Impact: at hole=3mm, pillar was 7.02mm pitch (wrong) → now 7.68mm (correct, matches
structural guarantee from `get_grid_step`).

---

## Next Steps (Priority Order)

### 1. Wire remaining pill box intents (HIGHEST VALUE)
Intents that currently fall through to default TRAY:
- `1-Day AM/PM Box`, `1-Day 2-Compartment (Single Lid)`, `7-Day Pill Box`,
  `14-Day AM/PM Box`, `Pillbox Set (Double Lid)`, `Pillbox Set (Single Lid)`, `Pillbox Full Set`
- Old manifest logic: `git show d84fbcc:MasterManifest.scad`
- These use `DOUBLE_FLIP_BOX` or `FLIP_BOX` with `HAS_BUILTIN_GRID=true` and specific
  `GRID_LAYOUT` strings injected inline

### 2. Push branch + open PR
All 6 commits are local. Push to `feature/architecture-revamp` and open PR against
`refactor/code-clarity-and-safety`.
```
git push origin feature/architecture-revamp
gh pr create ...
```

### 3. Work through TODO.md checklist
See TODO.md — 14 items remain (F1–F19, some done). Priority 1 items are correctness
issues that silently produce broken prints.

### 4. RIB primitive (Primitive 5)
FrankenTray vector-based ribs. Code exists in `RenderRib.scad`, parser in `GridLayout.scad`.
Not started.

### 5. HTML rebuild
`docs/LESSONS.md`, `docs/3D Print Symptoms.md`, `docs/FEATURES.md` all updated but not in
`index.html`. Do NOT run `just` — rebuild manually or defer.

---

## Open Code Quality Issues (from prior audit)

These are confirmed bugs not yet addressed:

| ID | File | Issue |
|----|------|-------|
| CQ1 | MasterManifest.scad | `is_closed` jar span clamping — may over-clamp valid layouts |
| CQ2 | build pipeline | `write_params_file` called twice |
| CQ3 | YAML output | `false` encoding wrong |
| CQ4 | Grid parser | `1.5x3` string strip drops decimal dot |
| CQ5 | GridLayout.scad | Dead `is_closed` 7th element in `parse_single_span` |

---

## Architecture Rules (full list in LESSONS.md)

| Rule | File |
|------|------|
| Factory IS the implementation — opts drive variants | LESSONS.md §1 |
| Built-in grid height driven by LID_TYPE (GRID_WALL_H) | LESSONS.md §2 |
| All circle dims are diameters | LESSONS.md §0b |
| Support-free always | LESSONS.md §0c |
| Chamfer/fillet all edges | LESSONS.md §0b |
| 0=auto for geometry overrides (chamfer, corner radius, etc.) | MasterBuilder Advanced |
| Salvage from 858dabc and d84fbcc before writing | LESSONS.md feedback |
| grid_has_base defaults false (drop-in opt-in) | MasterBuilder.scad |
| apply_master_bounds: chamfer=m_chamf(data), rounding from phys | MasterEngine.scad |
| Cylindrical rims: nozzle_d×4 chamfer (4-pass structural rule) | RenderMesh.scad |

---

## Key Data Flow

```
MasterBuilder.scad (Customizer)
  → ui_payload [["KEY", val], ...]
  → compile_manifest(intent, data)
      → injects overrides inline: concat([[KEY, val]], data)
      → returns [[type, data, opts, phys], ...]
  → build_part() loops manifest
      → get_xy() positions on platter
      → dispatches factory_render_*(data, opts, phys)

Key injections:
  factory_render_box  → GRID_WALL_H (lid-aware height cap)
  factory_render_jar  → IS_JAR_GRID, HAS_THREADS, GRID_WALL_H
  S4 intents          → DESICCANT_MESH_RECT/CYL (locked airflow mesh)
  Dual-spawn          → concat([[WIDTH, w]], data)
```

---

## Important Files

| File | Purpose |
|------|---------|
| `MasterBuilder.scad` | Customizer UI — USE THIS, not MasterBuild2 |
| `MasterManifest.scad` | Intent routing + data injection |
| `MasterEngine.scad` | Physics getters, get_xy platter packing, apply_master_bounds |
| `MasterConstants.scad` | All magic numbers with documented rationale |
| `MasterEnum.scad` | All string constants |
| `MasterMeshPatterns.scad` | Pattern geometry (teardrop, diamond, slotted, etc.) |
| `RenderMesh.scad` | framed_mesh + cylindrical_mesh_wall |
| `RenderTray.scad` | core_tray_chassis + factory_render_tray |
| `RenderBox.scad` | factory_render_box (all lid types) |
| `RenderJar.scad` | factory_render_jar |
| `RenderLid.scad` | factory_render_lid (all lid types) |
| `RenderGrid.scad` | factory_render_grid + render_internal_grid |
| `RenderRib.scad` | FrankenTray ribs (Primitive 5 — not wired) |
| `GridLayout.scad` | Layout string parser (cartesian/radial/span/franken) |
| `LESSONS.md` | Hard-won rules — read before touching anything |
| `docs/FEATURES.md` | Full product feature documentation |
| `FUTURE.md` | Deferred ideas |
| `TODO.md` | Print-quality fix checklist (14 items) |

---

## FUTURE.md Items (do not implement now)

1. Wall slots for 1-row/1-col grids (structural support for parallel dividers)
2. Drop-in dividers for flip boxes
3. Desiccant box: 1.8mm holes confirmed safe — slotted pattern forced by `apply_inductions`,
   step=3.48mm, pillar=1.68mm, 3.6×1.8mm slot retains 2mm+ silica gel beads
