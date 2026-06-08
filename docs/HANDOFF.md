# Session Handoff — MasterTray
_Last updated: 2026-06-07 — Post-print fixes: C-clip cantilever + glide ball floating shell (03068d4)_

---

## How to Resume

```
cd C:\repos\3D\MasterTray
claude
```

Tell Claude: **"Read HANDOFF.md and continue."**
_(Root-level `HANDOFF.md` is a one-line stub that points here — Claude will find it immediately.)_

---

## Branch & State

**Branch:** `refactor/code-clarity-and-safety`
**Last commit:** `03068d4` — Glide ball rib fix. All files committed, NOT pushed.

```
03068d4 fix: glide ball rib — prevent floating shell when ball_r > sl/2
cd1bc33 docs: session handoff — Pre-Print Test codebase (51487cb)
51487cb feat: FrankenTray v2 + private box intents + cantilever fix — Pre-Print Test
c018d82 docs: add handoff history tracking + Astro nav for Status and FrankenTray
1adaffb docs: FrankenTray v2 spec + updated handoff
```

**Untracked (leave alone):**
```
?? .claude/settings.json
?? astro/.vscode/
?? build.pl
?? output/
```

---

## Post-Print Bug Fixes (this session)

### BUG 1 — C-clip hinge: floating cantilever (Bambu STL_12, STL_13)
**Symptom:** Bambu Studio warning "floating cantilever". Flip_Double half-lids failed.
**Root cause:** The C-clip slot was at `+clip_outer_d/2` — cutting the TOP of the arc.
Printed face-down, the two arm tips at the top of the print had nothing below them.
**Fix:** Move slot to `-clip_outer_d/2` — arc opens downward, arms point toward lid body.
Arms are self-supporting. Pin enters from below when lid is pressed onto box hinge.
**File:** `RenderLid.scad` — Flip_Single C-clip hinge block. Commit `51487cb`.

### BUG 2 — Glide ball: floating shell, no slicer warning, print detachment
**Symptom:** Balls fell off wholesale in print. No Bambu warning fired.
**Root cause:** Ball center at `sl/2` but `ball_r > sl/2` (e.g. 1.2mm radius, 0.8mm half-thickness).
Sphere clipped below bed when printed face-down. Top portion of ball (above `sl`) had
no lid-wall support — a floating shell. Slicer missed it because ball *starts* connected;
only the top detaches mid-print.
**Fix:** Add full-height rib (`cuboid([ball_r+EPS, ball_d*0.7, sl+EPS])`) inset into the lid
wall at `lid_w/2 - ball_r/2`. Rib gives the ball solid attachment at every layer.
Box dimple geometry unchanged.
**File:** `RenderLid.scad` — Glide Ball branch. Commit `03068d4`.

### LESSON: Spheres/round features must fit within host body Z range
Before placing any sphere at `h/2`, verify `ball_r <= h/2`. If not, the sphere clips
the bed or top face. Slicer may not warn. Fix: rib (preferred) or clamp diameter.

---

## What Earlier Sessions Did

### 1. Private box intent architecture
`MasterManifest.scad` restructured so each lid variant is a self-contained private intent.
Public aggregators (Box, Jar) read checkbox flags and fan out via `compile_manifest()`.

Private box intents:
- `Snap Box (External)` / `Snap Box (Internal)`
- `Glide Box (External)` / `Glide Box (Internal)`
- `Flip Box (Single)` / `Flip Box (Double)`

`Flip Box (Double)` uses `flip_half_lid_l(data) = LENGTH/2 - flip_hinge_y` — half-lids.
Single-flip and pill boxes use `flip_lid_l(data) = LENGTH - flip_hinge_y`.

### 2. New MasterEnum constants
`SNAP_EXTERNAL`, `SNAP_INTERNAL`, `GLIDE_EXTERNAL`, `GLIDE_INTERNAL`,
`BUILD_FLIP_SINGLE`, `BUILD_FLIP_DOUBLE` — replaced deleted `BUILD_GLIDE`.

### 3. MasterBuilder ui_payload fixed
Old references to deleted variables (`Glide`, `lid_glide_direction`, `lid_glide_snap`,
`lid_style`) replaced with new variables.

### 4. % coordinates in FrankenTray v2
`parse_anchor_def` extended to 8 elements with `x_is_perc` / `y_is_perc` flags.
Helpers `_anchor_sw_mm(val, is_perc, int_dim)` and `_anchor_center_mm(val, is_perc, int_dim)`.
All 4 RenderRib.scad + 1 RenderGrid.scad call sites updated from `_sw_to_mm` to `_anchor_center_mm`.

### 5. Grid bounds validation
`grid_bounds_ok(g_str, data)` added to GridLayout.scad.
`has_grid(data)` now calls it — if any anchor is outside container interior, returns false.
Console echo: `*** GRID SPECIFICATION OUT OF BOUNDS — anchor(s) [...] exceed interior (...). NO GRID WILL BE GENERATED. ***`

### 6. EPS overlap fixes (slicer shell separation)
- Snap lid bead: lowered to `sl - EPS`, height increased by EPS.
- Flip lid diamond latch: Y-shifted by `+EPS` so latch body overlaps into lid.

### 7. C-clip hinge cantilever fix
Slot changed from `translate([0, 0, +clip_outer_d/2])` → `translate([0, 0, -clip_outer_d/2])`.
Arc now opens downward → arms point toward lid body → self-supporting when printed face-down.
Fixes Bambu Studio floating cantilever warning on STL_12 and STL_13 (Flip_Double half-lids).

---

## Primitives Status

| # | Primitive | Status |
|---|-----------|--------|
| 1 | TRAY | ✅ Done |
| 2 | JAR | ✅ Done |
| 3 | LID | ✅ Done |
| 3b | BOX | ✅ Done |
| 4 | GRID | ✅ Done |
| 5 | RIB / FrankenTray v2 | ✅ Done |

---

## Immediate Next Step

**Wait for print results.** The full plate (21 items — 5 box types × box+lid+builtin variants,
Flip_Double 2 half-lids, 2 drop-in grids) was sent to Bambu A1.

After print:
1. Evaluate lid retention forces, hinge snap, latch click.
2. Push branch + open PR.
3. Fix open items (F15, F6, F14 — see table below).
4. UI polish: expose SNAP_EXTERNAL/INTERNAL etc. as Customizer checkboxes.

---

## Open Code Items

| ID | File | Issue |
|----|------|-------|
| F15 | RenderBox.scad ~L103 | flip-box hinge assert |
| F6 | RenderLid.scad ~L120 | diamond latch layer_snap |
| F14 | RenderLid.scad ~L44 | snap bead layer-align |

---

## Test Defaults (leave in MasterBuilder.scad)

```scad
part_width = 54.5;  part_length = 54;  part_height = 55;
mesh_hole_size = 1.6;   mesh_hole_spacing = 1.2;
strut_wall_perc  =  0;
strut_floor_perc = 25;
strut_lid_perc   = 75;
```

**Render command (PowerShell):**
```powershell
$o = "C:\Program Files\OpenSCAD\openscad.com"
& $o -o output/test.png --render --camera=80,0,30,55,0,20,500 --colorscheme=DeepOcean -D 'Part_To_Build="Box"' MasterBuilder.scad
```

**Color guide (DeepOcean):** blue = outer faces (correct), red = inner faces through holes (normal), magenta = geometry problem.

---

## Key Architecture Rules

| Rule | Where |
|------|-------|
| Private intents are self-contained; aggregators fan out | MasterManifest.scad |
| Drop-in grids emitted once by aggregator, never inside private intents | MasterManifest.scad |
| Threaded Jar: no drop-in grids (screw neck blocks access) | MasterManifest.scad |
| `flip_half_lid_l` for Double half-lids only; `flip_lid_l` for all others | MasterManifest.scad |
| EPS overlap on all boolean union geometry — face-to-face = slicer shells | RenderLid.scad |
| C-clip slot at -Z (bottom of arc) → self-supporting face-down | RenderLid.scad |
| `_anchor_center_mm(val, is_perc, int_dim)` at all anchor call sites | RenderRib, RenderGrid |
| `grid_bounds_ok` called from `has_grid` — bad bounds = no grid + CAPS echo | GridLayout.scad |
| strut% applies within safe zone (after min_margin) | RenderMesh.scad header |
| Container geometry owns the structural edge (not the mesh) | MasterEngine.scad |
| ray_heights in cfg[1][3] is always a LIST | GridLayout.scad |
| Factory IS the implementation — opts drive variants | LESSONS.md §1 |
| All circle dims are diameters | LESSONS.md §0b |
| Support-free always | LESSONS.md §0c |

---

## Key Files

| File | Purpose |
|------|---------|
| `MasterBuilder.scad` | Customizer UI — USE THIS |
| `MasterManifest.scad` | Intent compiler; private intents + aggregators |
| `MasterEngine.scad` | Physics getters, `get_mesh_cfg`, `get_grid_step` |
| `MasterEnum.scad` | All string constants |
| `GridLayout.scad` | Grid string parser — cartesian, span, radial, FrankenTray v2 |
| `RenderMesh.scad` | `framed_mesh` + `cylindrical_mesh_wall` with min_margin |
| `RenderGrid.scad` | Grid factories; radial with cycling heights |
| `RenderRib.scad` | FrankenTray v2 renderer |
| `RenderLid.scad` | All lid types — Snap, Glide, Flip_Single, Screw, Slip |
| `docs/FRANKENTRAY_SPEC.md` | FrankenTray v2 design spec |
| `docs/STATUS.md` | Human-readable project status + grid layout quick reference |
| `docs/BUGS.md` | B1 (sqrt scaling), B2 (screw lid height) |
