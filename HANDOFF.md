# Session Handoff — MasterTray Primitives
_Last updated: 2026-06-03 — CHECKPOINT_

---

## How to Resume

Open Claude Code **from inside `C:\repos\3D\MasterTray`** — memory loads automatically.
Do NOT start a generic Claude chat first. If Claude says "load me the code", you're in
the wrong session. Navigate to the project directory and reopen.

---

## Branch & State

**Branch:** `feature/architecture-revamp`
**Base:** `refactor/code-clarity-and-safety`
**Last commit:** `728217b` — orientation rules documented

---

## Primitive Status

| # | Primitive | Status | Notes |
|---|-----------|--------|-------|
| 1 | TRAY | ✅ Done & tested | Hollow chassis, mesh, wall mods, printer-aware |
| 2 | JAR | ✅ Done, visually confirmed | Circular floor + cylindrical wall mesh, threaded neck |
| 2b | JAR polygon | ✅ Done | jar_shape dropdown: Circle/Quad/Hexa/Octa/Dodeca |
| 3 | LID | 🔶 Partial | Screw ✅ face-down; Glide ✅; Flip_Single needs review; Slip needs review |
| 4 | GRID | ⬜ Not started | Cartesian + radial. Old code in d84fbcc:RenderGrid.scad |
| 5 | RIB | ⬜ Not started | FrankenTray. Already in RenderRib.scad |

---

## Intents Wired in Manifest

| Intent | Produces | Dims |
|--------|----------|------|
| Simple Tray | TRAY | user dims |
| Box | BOX | user dims |
| Open Jar | 1×JAR or 2×JAR (w≠l) | user dims |
| Threaded Jar | 1×JAR or 2×JAR (w≠l) | user dims |
| Jar with Lid | JAR+LID or 2×(JAR+LID) | user dims |
| S4 Jar | JAR+LID | d=49, h=140 |
| Spool Jar | JAR+LID | d=55, h=55 |
| S4 Wedge | BOX+Glide LID | 140×46×140 |
| S4 Set | S4 Jar + Spool Jar + S4 Wedge | hardcoded |
| Flip Box | FLIP_BOX | user dims |
| Double Flip Box | DOUBLE_FLIP_BOX | user dims |
| All others (19) | → fallback TRAY + warning echo | needs manifest entries |

---

## Next Steps (in order)

1. **Test S4 Set** — confirm 6 parts lay out on plate correctly
2. **Primitive 3 — LID** — review Flip_Single and Slip orientations for support-free
3. **Primitive 4 — GRID** — salvage from `git show d84fbcc:RenderGrid.scad`
   - `render_box_grid_core`, `render_jar_grid_core`, `render_cartesian_walls`
   - Wire `render_internal_grid` stub for built-in grids in TRAY/JAR
4. **Expand manifest** — 19 intents still fall through to TRAY warning

---

## Hard Rules (full list in LESSONS.md)

- **Salvage first**: `git show d84fbcc:<file>` before writing anything
- **All dims are diameters** — never radius (caliper UX, users were pissed)
- **Support-free always** — every primitive prints without supports in shipped orientation
- **Optimal orientation**: JAR upright, TRAY/BOX flat, LID face-down
- **Never lay on side** for extreme ratios — slicer concern, not model concern
- **Strut %** = solid border surrounding mesh region (NOT hole spacing)
- **Tile count** = `get_n_steps(dim, strut, step)` — sized to mesh region only
- **Hole spacing** = `m_wloops(data) × m_noz(data)` — physics-derived
- **F5 preview** = 2× step → 4× fewer tiles
- **Always `include`** Render files, never `use`
- **MasterBuilder.scad** is the real file — not MasterBuild2.scad
- **Document proactively** — write to LESSONS.md without asking

---

## Key Files

| File | Purpose |
|------|---------|
| `MasterBuilder.scad` | Customizer UI + main dispatcher |
| `MasterManifest.scad` | Intent → [type, data, opts, phys] tuples |
| `MasterEngine.scad` | Physics getters, get_xy platter packing |
| `MasterEnum.scad` | All string constants |
| `RenderMesh.scad` | framed_mesh + cylindrical_mesh_wall |
| `RenderTray.scad` | core_tray_chassis + factory_render_tray |
| `RenderJar.scad` | factory_render_jar |
| `RenderLid.scad` | factory_render_lid (Screw, Glide, Flip, Slip) |
| `RenderGrid.scad` | factory_render_grid (only FrankenTray ribs currently) |
| `RenderBox.scad` | factory_render_box, flip variants |
| `LESSONS.md` | Hard-won rules — read before touching anything |

---

## Factory API

```
factory_render_*(data, opts, phys)
  data  — ui_payload [["KEY", val], ...]  — use get_val(KEY, data, fallback)
  opts  — component switches [["IS_THREADED", true], ["JAR_SIDES", 8], ...]
  phys  — [["SAFE_WALL", sw], ["SAFE_FLOOR", sf], ["CLEARANCE", c], ["NOZZLE", n]]
          phys[0][1]=SAFE_WALL   phys[1][1]=SAFE_FLOOR

compile_manifest(intent, data) → list of [type, data, opts, phys]
build_part() loops manifest, calls get_xy() for platter position, dispatches factory
```

---

## System Design Principles

- Optimized for **Nozzle diameter × Wall loops × Layer height** — all geometry derived
- **Teardrop** mesh = self-bridging, support-free by design
- **Dual-jar spawn**: w≠l → two jars (one per dimension) placed side by side
- **jar_shape** Customizer: Circle/Quad/Hexa/Octa/Dodeca — JAR_SIDES flows through opts
- **S4 Set** uses recursive `compile_manifest` concat — functional, no loops
