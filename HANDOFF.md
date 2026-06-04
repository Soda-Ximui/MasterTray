# Session Handoff — MasterTray Primitives
_Last updated: 2026-06-03 — CHECKPOINT_

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
**Last commit:** `e339dff` — grid_has_base defaults to false

---

## All 5 Primitives — Status

| # | Primitive | Status | Notes |
|---|-----------|--------|-------|
| 1 | TRAY | ✅ Done | Hollow chassis, mesh, wall mods, stackable (Peg/Builtin/Snap), GRID_WALL_H |
| 2 | JAR | ✅ Done | Circular floor + wall mesh, threaded neck, polygon shapes (jar_shape), built-in grid |
| 3 | LID | ✅ Done | Snap, Glide (H/V, Ball/Tab), Flip_Single (diamond latch), Screw, Slip |
| 3b | BOX | ✅ Done | Unified factory — all LID_TYPE variants inline, GRID_WALL_H injection |
| 4 | GRID | ✅ Done | Cartesian + radial + spans, built-in (fused) + drop-in, jar circular clipping |
| 5 | RIB | ⬜ Not started | FrankenTray vector ribs — code in RenderRib.scad, parser in GridLayout.scad |

---

## What's Working

**Intents fully handled in manifest:**

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

## Next Steps

1. **Wire remaining pill box intents** — `1-Day AM/PM Box`, `7-Day Pill Box`,
   `14-Day AM/PM Box`, `Pillbox Set (*)` — all need manifest entries.
   Old manifest logic: `git show d84fbcc:MasterManifest.scad` — full routing there.
   Key: pill boxes use `DOUBLE_FLIP_BOX` or `FLIP_BOX` with `HAS_BUILTIN_GRID=true`
   and specific `GRID_LAYOUT` strings injected inline.

2. **Test all primitives in OpenSCAD** — work through each intent systematically.

3. **RIB primitive** (Primitive 5) — FrankenTray vector ribs.
   Parser: `parse_franken_config` in GridLayout.scad.
   Renderer: `RenderRib.scad` (already has code).

4. **Plaque** — `render_plaque` in old code, wired in dispatcher but not tested.

---

## Architecture Rules (full list in LESSONS.md)

| Rule | File |
|------|------|
| Factory IS the implementation — opts drive variants | LESSONS.md §1 |
| Built-in grid height driven by LID_TYPE (GRID_WALL_H) | LESSONS.md §2 |
| All circle dims are diameters | LESSONS.md §0b |
| Support-free always | LESSONS.md §0c |
| Chamfer/fillet all edges | LESSONS.md §0b |
| 0=auto for geometry overrides (chamfer, corner radius, etc.) | MasterBuilder Advanced section |
| Salvage from 858dabc and d84fbcc before writing | LESSONS.md feedback |
| grid_has_base defaults false (drop-in opt-in) | MasterBuilder.scad |

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
| `MasterEngine.scad` | Physics getters, get_xy platter packing |
| `MasterEnum.scad` | All string constants |
| `RenderMesh.scad` | framed_mesh + cylindrical_mesh_wall |
| `RenderTray.scad` | core_tray_chassis + factory_render_tray |
| `RenderBox.scad` | factory_render_box (all lid types) |
| `RenderJar.scad` | factory_render_jar |
| `RenderLid.scad` | factory_render_lid (all lid types) |
| `RenderGrid.scad` | factory_render_grid + render_internal_grid |
| `RenderRib.scad` | FrankenTray ribs (Primitive 5) |
| `GridLayout.scad` | Layout string parser (cartesian/radial/span/franken) |
| `LESSONS.md` | Hard-won rules — read before touching anything |
| `PRODUCT.md` | Full product feature documentation |
| `FUTURE.md` | Deferred ideas (wall slots, drop-in flip dividers) |

---

## FUTURE.md Items (do not implement now)

1. Wall slots for 1-row/1-col grids (structural support for parallel dividers)
2. Drop-in dividers for flip boxes (repurposable open box)
