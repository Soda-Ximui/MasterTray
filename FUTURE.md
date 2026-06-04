# MasterTray — Future Considerations

Ideas deferred from active development. Not bugs, not missing features — design
decisions worth revisiting when the right time comes.

---

## 1. Single-row / single-column grid: wall slot cuts

**Idea:** When `GRID_LAYOUT` has only 1 row OR 1 column (e.g. `7x1` or `1x4`),
the divider walls have no cross-members to keep them upright. The tray could cut
matching slots into the front/back (or left/right) walls so the dividers seat
into the wall geometry for structural support.

**Why it matters:** A 7x1 pill box divider has 6 thin walls running parallel.
Without slots, they rely entirely on the base plate for stability. Slots in the
opposing walls would hold each divider vertical and prevent racking.

**Considerations:**
- Slot depth = `div_t + clearance` (tight fit for rigidity)
- Slot height = full wall height OR `GRID_WALL_H` (for flip box)
- Only cuts the INNER face of the wall (not through to exterior)
- Support-free: slot is vertical, no overhang
- For drop-in grids the slots are in the box body; for built-in the cut is inline

---

## 2. Drop-in dividers for flip-lid boxes — repurposable open box

**Idea:** Instead of building the grid dividers as a permanent built-in feature
of a flip box, offer a drop-in divider tray that can be removed. This lets the
same printed box serve two purposes:
- With dividers: pill organizer, desiccant compartments, etc.
- Without dividers: open storage box for anything else

**Why it matters:** Reduces total printed parts across a user's collection.
A single "flip box" body becomes a platform; the divider insert is optional.

**Considerations:**
- The drop-in grid for a flip box must respect `GRID_WALL_H` (same axle_z cap)
  so it doesn't prevent the lid from closing when inserted
- The insert outer dims = box interior − `GRID_DROP_IN_TOL` (standard clearance)
- The insert has a base plate so it lifts out as a single piece
- Could be triggered as a separate intent: `"Flip Box (Drop-in Grid)"`
- The box body itself renders without any built-in grid — just the chassis + hinge

---
