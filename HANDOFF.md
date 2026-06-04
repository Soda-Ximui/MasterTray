# Session Handoff — MasterTray Primitives
_Last updated: 2026-06-03 — CHECKPOINT_

---

## How to Resume

Open Claude Code **from inside `C:\repos\3D\MasterTray`** — memory loads automatically.
Do NOT start a generic Claude chat first. Run:
```
cd C:\repos\3D\MasterTray
claude
```
Claude executable: `C:\Users\hobbes\AppData\Roaming\Claude\claude-code\<version>\claude.exe`

---

## Branch & State

**Branch:** `feature/architecture-revamp`
**Base:** `refactor/code-clarity-and-safety`
**Last commit:** `fe6bf7f` — GRID_WALL_H injected by factory_render_box

---

## Primitive Status

| # | Primitive | Status | Notes |
|---|-----------|--------|-------|
| 1 | TRAY | ✅ Done | Hollow chassis, mesh, wall mods, stackable (Peg/Builtin/Snap), GRID_WALL_H injected |
| 2 | JAR | ✅ Done | Circular floor + wall mesh, threaded neck, polygon shapes (jar_shape) |
| 3 | LID | ✅ Done | Snap, Glide (H/V, Ball/Tab), Flip_Single (incl. diamond latch), Screw, Slip |
| 3b | BOX | ✅ Done | Unified factory_render_box: all LID_TYPE variants inline, no wrappers |
| 4 | GRID | 🔶 Next | Layout string parser exists in GridLayout.scad; render_box_grid_core in old code |
| 5 | RIB | ⬜ Not started | FrankenTray ribs — in RenderRib.scad |

---

## GRID Architecture (ready to implement)

**Layout string format:** `RxC [S row/col/width/height/wall_h] ...`
- `2x7` = 2 rows × 7 cols
- `S1/1/2/3/150%` = span at (row 1, col 1), 2 wide, 3 tall, wall = 150% of grid_wall_h
- `S1/1/2/3/25` = same but wall = 25mm absolute
- Span that fills full height → divider omitted (open cell)

**Built-in grid (HAS_BUILTIN_GRID=true):**
- `core_tray_chassis(data_g)` → calls `render_internal_grid(data_g)` internally
- Grid is fused to walls, no separate manifest item
- `GRID_WALL_H` already injected into data_g by `factory_render_box`
- Only makes sense with a container intent

**Drop-in grid:**
- Manifest emits separate GRID item(s) — printed separately with tolerance gap
- 1 GRID normally; 2 if w≠l (dual-spawn, same logic as jars)
- Sized with `GRID_DROP_IN_TOLERANCE` clearance on outer dims

**What to salvage from old code:**
- `git show d84fbcc:RenderGrid.scad` — WRONG FILE (contained internal grid content)
- Actually search for `render_box_grid_core` and `render_cartesian_walls` in old commits
- `GridLayout.scad` — layout string parser (already in repo, check if complete)
- `git show 858dabc:RenderGrid.scad` — might have better content

**GRID_WALL_H flow:**
```
factory_render_box computes:
  Flip lids → axle_z  (dividers below hinge line)
  Others    → bh-sf-sl (full interior)
Injects as GRID_WALL_H into data_g → core_tray_chassis → render_internal_grid reads it
```

---

## Next Steps

1. **GRID primitive** — salvage from old commits, implement render_internal_grid
   - Read GRID_WALL_H for wall height cap
   - Handle spans (S token) — open cells, variable wall heights
   - Built-in: called from core_tray_chassis
   - Drop-in: factory_render_grid produces standalone piece
2. **RIB** — FrankenTray vector ribs (RenderRib.scad already has code)
3. **Expand manifest** — remaining pill box intents, S4 set, etc.

---

## Key Architecture Rules

| Rule | Where documented |
|------|----------------|
| Factory IS the implementation, opts drive variants | LESSONS.md §1 |
| Built-in grid height driven by LID_TYPE | LESSONS.md §2 |
| All circle dims are diameters | LESSONS.md §0b |
| Support-free always | LESSONS.md §0c |
| All edges chamfered/filleted | LESSONS.md §0b |
| Salvage from 858dabc and d84fbcc first | LESSONS.md §0 (feedback) |
| No hardcoded values — Advanced section | MasterBuilder.scad |
| `$fn = $preview ? 24 : 128` | MasterEngine.scad |

---

## Factory API

```
factory_render_*(data, opts, phys)
  data  — ui_payload [["KEY", val], ...]  — get_val(KEY, data, fallback)
  opts  — switches: LID_TYPE, IS_THREADED, JAR_SIDES, STACKABLE, STACK_MODE, ...
  phys  — [["SAFE_WALL",sw],["SAFE_FLOOR",sf],["CLEARANCE",c],["NOZZLE",n]]

Key injected-data patterns:
  factory_render_box → injects GRID_WALL_H, NEEDS_GROOVE (glide) into data_g
  S4 intents → desiccant mesh params prepended to data
  Dual-spawn → concat([[WIDTH, w]], data) to override diameter
```

---

## Intents Handled in Manifest

| Intent | Produces |
|--------|---------|
| Simple Tray | TRAY |
| Box | BOX(Snap) + LID(Snap) |
| Standalone Box | BOX(Glide) + LID(Glide) |
| Flip Box | BOX(Flip_Single) + LID(Flip_Single) |
| Double Flip Box | BOX(Flip_Double) + 2×LID(Flip_Single) |
| Nesting Tray | TRAY(Snap stack) |
| Modular Peg Tray | TRAY(Peg stack) + 4×PEG |
| Open Jar | 1 or 2 JAR |
| Threaded Jar | 1 or 2 JAR (threaded) |
| Jar with Lid | JAR+LID pairs |
| S4 Jar / Spool Jar | JAR+LID (desiccant mesh locked) |
| S4 Wedge | BOX(Glide)+LID(Glide) (desiccant mesh) |
| S4 Set | S4 Jar + Spool Jar + S4 Wedge |
| ~15 others | → fallback TRAY + warning echo |
