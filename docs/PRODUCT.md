# MasterTray — Product Features

## What It Is

Parametric OpenSCAD system for generating 3D-printable storage containers.
The user sets parameters in the OpenSCAD Customizer; the system computes
printer-aware geometry and outputs a print-ready STL — no CAD knowledge required.

---

## Core Design Principles

- **Support-free** — every part prints without supports in its shipped orientation
- **Printer-aware** — geometry adapts to Nozzle Diameter, Layer Height, Wall Loops
- **Chamfered/filleted everywhere** — no sharp 90° overhangs; all edges ≤45°
- **Structural integrity** — walls, floors, and struts sized for real storage use
- **Platter-ready** — multi-part builds auto-arranged on the build plate

---

## Container Types

### Open-top Tray
Rectangular floor + four walls, no lid. Walls independently height-modifiable
(`WALL_MODIFY`: None / Dropped / 50% / 25%, per-wall target). Mesh on all surfaces.

### Box
Same chassis as Tray, with lid. Lid type determined by build intent.

### Jar
Cylindrical container. Diameter = outer diameter (caliper measurement).
- **Open** — no threading, no lid
- **Threaded** — external BOSL2 thread on neck; screw-on lid
- **Polygonal** — selectable shape: Circle / Quad / Hexa / Octa / Dodeca (`jar_shape`)
- Width ≠ Length → two jars auto-spawned on platter (one per dimension)

### Box = Tray + Lid

A TRAY with any lid type becomes a BOX. The lid type determines what geometry the
box body also needs (groove channels, hinge bosses, etc.) — the manifest pairs them.

### Lid
Printed face-down for best surface quality and bed adhesion.

| LID_TYPE | Variants | Snap mechanism | Notes |
|----------|----------|---------------|-------|
| `"Snap"` | — | Press-on friction | Simple, no hardware |
| `"Glide"` | `H` (horizontal) or `V` (vertical) | **Ball catch** (default) or Tab | Ball catch: two hemisphere bumps on lid sides click into wall dimples. More reliable than tab — distributed force, no thin part to snap, smooth operation. Tab: classic single snap at open end. |
| `"Hinge_Single"` | — | C-clip one Y face + front latch | Standard flip box |
| `"Hinge_Double"` | — | C-clips both Y faces | Pill box / AM-PM organizer |
| `"Screw"` | — | Threaded engagement | Jar lids only |

**Glide lid direction:**
- `"H"` (Horizontal) — lid slides along the length axis; grooves cut in left/right walls
- `"V"` (Vertical) — lid slides straight down; grooves cut in front/back walls

Ball catch geometry: small hemisphere protrusion on each lid side, matching concave
dimple in the box wall groove. Sized to `nozzle × 3` diameter for reliable click.

---

## Stackable Trays

All stackable modes add corner **bosses** (solid reinforcing pillars) that run the
full tray height and below the floor, distributing stacking loads into the walls.

| STACK_MODE | Description |
|------------|-------------|
| `"Peg"` | Top sockets + bottom sockets + 4 standalone peg rods on platter |
| `"Builtin"` | Pegs protrude from top corners + bottom sockets (no separate pieces) |
| `"Snap"` | Nesting ledge + diamond snap bead — click-together, no hardware |

Peg socket diameter: 8mm. Peg rod: horizontal, flat-bottomed for printing.
Snap mode: recommended PETG (flexes for click without fracturing like PLA).
Future: `"Magnet"` — boss holes for press-fit 6/8mm disc magnets.

---

## Mesh System

Three independent knobs per surface (wall, floor, lid):

| Parameter | Controls |
|-----------|---------|
| `mesh_hole_size` | Hole diameter (0 = solid surface) |
| `strut_*_perc` | Solid border surrounding mesh region (0% = edge-to-edge) |
| `mesh_pattern` | Teardrop / Honeycomb / Slotted / Circle / Square / Diamond / None |

- **Teardrop** is the default — self-bridging, support-free by shape
- Hole spacing derived from `Wall_Loops × Nozzle_Diameter` (nozzle-snap rounded)
- Per-surface control: wall, floor, and lid can each be solid or meshed independently

---

## Desiccant / S4 System

Purpose-built containers for silica gel desiccant packets. Mesh settings locked
regardless of Customizer — ensures consistent airflow geometry across all prints.

| Intent | Shape | Dims | Mesh |
|--------|-------|------|------|
| S4 Jar | Threaded jar + lid | Ø49 × 140mm | Teardrop 1.8mm, strut 15/15/15 |
| Spool Jar | Threaded jar + lid | Ø55 × 55mm | Teardrop 1.8mm, strut 15/15/15 |
| S4 Wedge | Box + glide lid | 140×46×140mm | Teardrop 1.8mm, strut 25/20/10 |
| S4 Set | All three above | — | Auto-arranged on platter |

---

## Pill / Medication Organizers

| Intent | Description |
|--------|-------------|
| 1-Day AM/PM Box | Double flip box, 2-compartment |
| 1-Day 2-Compartment (Single Lid) | Flip box, shared lid |
| 7-Day Pill Box | 7-compartment flip box, day labels |
| 14-Day AM/PM Box | 14-compartment double flip, AM/PM labels |
| Pillbox Set (Single/Double Lid) | Composite sets |
| Pillbox Full Set | Complete organizer system |

---

## Printer Optimisation

All geometry derives from three printer parameters set in the Customizer:

| Parameter | Drives |
|-----------|--------|
| `Nozzle_Diameter` | Wall thickness, strut width, corner radii, chamfer size |
| `Layer_Height` | Floor and lid thickness (layer-aligned) |
| `Wall_Loops` | Minimum strut width between mesh holes |

Change your printer settings → geometry adapts automatically. No manual recalculation.

---

## Tolerances & Fit Profiles

`Mechanical_Fit` dropdown: Tighter / Tight / Standard / Loose / Looser (±0.05mm/step).
Material-aware baselines: PETG has wider clearances than PLA (shrinkage + flexibility).

Tolerance components tracked separately:
- Hinge spine (C-clip rotation)
- C-clip retention
- Front snap latch
- Glide lid rail
- Peg/socket engagement depth

---

## Print Orientations

Every primitive is **designed to sit directly on the print bed** — Z=0 in the model
is the bed surface. No re-orientation is required in the slicer. This is a system
requirement, not a convenience: if any geometry requires supports in its shipped
orientation, that is a geometry bug, not a slicer configuration issue.

| Part | Orientation | Reason |
|------|-------------|--------|
| Tray / Box | Floor on bed, open top up | Layer lines horizontal through floor = maximum strength |
| Jar | Upright (floor on bed) | Accurate diameter; side-print needs supports (not allowed) |
| Snap / Glide / Slip Lid | Face-down (flat outer surface on bed) | Best finish on visible face; retention features build upward |
| Flip_Single / Flip_Double Lid | Face-down — C-clip arc at top | Arc self-supporting. **C-clip opening must face −Z** (toward bed). See design note below. |
| Screw Lid | Face-down (flat top on bed) | Full-circle adhesion; interior thread on vertical walls |
| Peg rod | Horizontal, flat-cut underside on bed | `yrot(90)` + underside flat cut prevents rolling; no supports needed |
| Drop-in grid | Flat (base on bed), dividers up | Divider walls print vertically; no overhangs |
| Built-in grid | Part of container — inherits container orientation | Not a separate print piece |

### Design rule: round features must fit within their host body's Z range

Any spherical or rounded feature placed at height `h/2` must satisfy `feature_radius ≤ h/2`.
If the feature exceeds the host body in Z:
- The portion below Z=0 is clipped by the slicer (feature loses bed contact)
- The portion above Z=h has no wall support → prints as a detached floating shell

The slicer does not always warn — it only flags geometry with *zero* connection.
A feature that starts connected but loses its wall partway up will pass slicer checks
and fail in print. **Fix: add a full-height rib connecting the feature to the host wall.**

### Design rule: C-clip arcs open toward the bed

Flip lid C-clips are printed face-down. The arc slot must cut the **bottom** of the
arc (`−clip_outer_d/2`) so the opening faces the bed. Slot at `+clip_outer_d/2`
(opening faces up) leaves the two arm tips as floating cantilevers at the top of the
print. The slicer warns; the arms detach or fail to print.
