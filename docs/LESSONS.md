# MasterTray — Lessons Learned

---

## 0. Structural integrity and strength are non-negotiable

**Rule:** All generated containers must have decent structural integrity. These are
functional storage objects — desiccant containers, pill organizers, general storage —
not display models. They must survive real use.

**How we achieve it:**
- **Wall thickness** = snapped to nozzle multiples via `m_safe_wall` — no partial
  extrusions, no weak inter-layer gaps
- **Floor/lid thickness** = snapped to layer-height multiples via `m_safe_floor` /
  `m_safe_lid` — flat surfaces align to layer boundaries, no micro-stepping
- **Corner bosses** on stackable trays — solid cylinder pillars at all 4 corners
  distribute stacking load into the tray walls, not just the floor
- **Strut widths** = nozzle-multiple snapped (see Lesson 0c) — every mesh strut
  is a complete extrusion pass, no weak partial lines
- **Minimum wall** = `nozzle × wall_loops` — never thinner than the slicer's
  configured perimeter count
- **Mesh strut proportion** = 25% of hole diameter minimum — large holes get
  proportionally thicker struts

**Flag immediately** if any geometry change reduces wall count below `wall_loops`,
thins a load-bearing surface below `m_safe_floor`, or introduces a mesh so open
that the remaining struts can't bear typical storage loads.

---

## 0b. All edges use chamfer or fillet — no sharp 90° overhangs

**Rule:** Every edge in the system is either chamfered or filleted. No sharp 90°
horizontal edge is left exposed on a downward-facing surface.

**Why:** FDM printers cannot print a sharp 90° overhang without supports. A chamfer
≤45° is self-supporting. A fillet on a vertical edge avoids stress concentrations
and improves layer adhesion at corners.

**How we achieve it:**

| Edge type | Treatment | Mechanism |
|-----------|-----------|-----------|
| Vertical corners (XY plane) | Fillet | `apply_master_bounds` → `cuboid(rounding=m_c_rad)` |
| Bottom outer edge of walls | Chamfer | `m_chamf(data)` passed to BOSL2 `cuboid`/`cyl` |
| Top of cylinder (lid, boss, peg) | Chamfer2 | `cyl(..., chamfer2=m_chamf(data))` |
| Bottom of cylinder (jar floor) | Chamfer | `cyl(..., chamfer=m_chamf(data))` |
| Peg rod ends | Chamfer both ends | `cyl(..., chamfer=0.5)` |
| Snap bead | Diamond cross-section | All faces ≤45° by geometry — no explicit chamfer needed |

**Standard values** (both physics-derived from printer settings):
- `m_chamf(data)` = `nozzle × MAX_CHAMFER_MULT` — horizontal edge chamfer
- `m_c_rad(data)` = derived from wall thickness — vertical corner fillet radius

**Flag immediately** if any new geometry introduces a horizontal edge > 45° on a
downward-facing surface, or a sharp vertical corner on an outer wall.

---

## 0c. All generated models must print support-free

**Rule:** Every primitive and composite must be printable on FDM without supports.

**How we achieve it:**
- Overhangs: `m_chamf(data)` = nozzle × 2.5 caps all chamfers at 45° max
- Mesh holes: Teardrop pattern is self-bridging (pointed tip closes without drooping)
- Lids: printed **face-down** (flat visible surface on bed) so the interior cavity
  prints upward from a solid base — no bridges, no supports
- Threads: external threads (jar body) are on vertical walls ✓; internal thread
  (lid) is subtracted from a vertical cylinder wall ✓
- Grids/dividers: vertical walls, no overhangs ✓

**Flag immediately** if any new geometry introduces: overhangs > 45°, horizontal
bridges > ~60mm, or any surface that requires the model to be printed upside-down
from the orientation it ships in.

---

## 0a. Optimal print orientation — design geometry for the print bed, not the assembly

**Rule:** All primitives ship in their optimal FDM orientation. Every factory renders
geometry as it sits on the print bed — Z=0 is the bed surface, geometry builds upward.
Users adjust slicer settings (brim, speed, enclosure temp); we never change orientation
to compensate for extreme height/width ratios.

| Primitive | Optimal orientation | Reason |
|-----------|--------------------|----|
| JAR | Upright (floor on bed) | Side needs supports under curved wall; diameter becomes oval |
| TRAY / BOX | Flat (floor on bed) | Layer lines horizontal through floor = maximum strength |
| LID (Screw) | Face-down (flat top on bed) | Full-circle adhesion; interior thread on vertical walls |
| LID (Snap / Glide / Slip) | Face-down (flat outer surface on bed) | Best finish on visible face; retention features build upward |
| LID (Flip_Single / Flip_Double) | Face-down | C-clip arc at top of print — self-supporting. **Opening must face −Z (toward bed).** |
| PEG | Horizontal, flat-cut underside on bed | `yrot(90)` + flat cut prevents rolling, prints without supports |
| GRID (built-in) | Part of container — inherits container orientation | |
| GRID (drop-in) | Flat (base on bed) | Divider walls print vertically; flag very long/thin — warp risk |

**Every factory's Z=0 = bed.** If you add a new factory, the lowest point of the
geometry must sit at Z=0. Use `anchor=BOTTOM` on the outermost solid or `up(sf)` for
floor-offset geometry. A factory that floats above Z=0 will print mid-air.

**Flip lid critical rule:** C-clip arc opens **downward** (slot at `−clip_outer_d/2`).
Opening at `+clip_outer_d/2` leaves arm tips unsupported at the top of the print —
floating cantilever. See B3 in BUGS.md.

**Extreme ratios:** A 49×140mm jar prints upright regardless. A 300×200×8mm tray
prints flat regardless. Extreme geometry is a slicer concern, not an orientation concern.

**Never introduce supports** to enable a non-standard orientation. If a geometry
requires supports in its natural orientation, fix the geometry.

---

## 0b. All circle dimensions are diameters, always

**Rule:** Every circular dimension in the system (jar width, hole size, peg diameter) is
an **outer diameter** — never a radius.

**Why:** Users measure physical objects with calipers. Calipers give diameter. Asking
users to divide by 2 before typing caused real frustration. The UX loss is not worth
the cleaner internal math that radius would give.

**Consequence:** `m_bw(data)` for a jar = outer diameter. All geometry uses `d=` not
`r=` when sizing the jar cylinder.

---

Hard-won lessons from building and debugging this system. Read before touching
the include graph.

---

## 0c. Mesh hole spacing snaps to nozzle-width multiples

**Rule:** `get_grid_step` produces a step (hole + strut) that is always a whole-nozzle
multiple. Never change this to a simpler formula without understanding why.

**The formula:**
```
step = hole + max(min_sp,
                  max(noz,
                      round(max(noz*2, hole*0.25) / noz) * noz))
```

**What each layer does:**

| Layer | Expression | Purpose |
|-------|-----------|---------|
| Raw strut | `max(noz*2, hole*0.25)` | Strut is at least 2 nozzle widths wide, OR 25% of the hole diameter — whichever is larger. Large holes get proportionally thicker struts. |
| Nozzle snap | `round(.../noz) * noz` | Rounds the raw strut to the nearest nozzle-width multiple. This is the critical step — the slicer always lays complete extrusion passes. A strut of 0.6mm with a 0.4mm nozzle forces a partial pass (0.2mm leftover), which can delaminate or look ugly. Snapping to 0.8mm (2 passes) is mechanically correct. |
| Floor | `max(noz, ...)` | Guards against rounding down below 1 nozzle width. |
| Override | `max(min_sp, ...)` | Caller's physics minimum (e.g. `wall_loops × nozzle`) wins if it's larger. User-set hole spacing (`HOLE_SPACING`) flows in here. |

**Why hole*0.25?** For a 4mm hole, a 0.8mm strut (2 nozzle widths) is structurally too
thin. `hole*0.25 = 1.0mm` gives a more robust strut. For small holes (≤3.2mm with a
0.4mm nozzle), `noz*2 = 0.8mm` dominates and the minimum printable strut is used.

**The result:** Every mesh tile is a printable unit. Slicer never generates micro-moves
or partial extrusions between holes. This is the difference between a mesh that looks
right in preview and one that actually prints cleanly.

**Desiccant containers** (S4 system) lock `HOLE_SPACING=1.2mm` explicitly — this
overrides `min_sp` so airflow geometry is consistent regardless of printer wall-loop
settings.

---

## 0d. Round features must fit within their host body's Z range

**Rule:** Before placing any sphere, hemisphere, or rounded protrusion at height `h/2`
within a host body of height `h`, verify: `feature_radius ≤ h/2`.

If `feature_radius > h/2`, the feature escapes the host body:
- Below Z=0 → clips the print bed (slicer truncates it)
- Above Z=h → pokes past the top face with no wall support at those layers

The top portion prints as a **floating shell** that detaches mid-print. The slicer
may not warn — it only warns if the feature has *no* connection at all. A feature
that starts connected but loses its wall attachment partway up passes slicer checks
and fails in print.

**Two confirmed failures (see BUGS.md B3, B4):**
1. C-clip hinge arm tips — arc opening at +Z left tips floating above lid top
2. Glide ball catch — sphere at sl/2 with ball_r > sl/2 → top of ball floats above lid

**Fixes by case:**

| Situation | Fix | Do not |
|-----------|-----|--------|
| Feature too tall for host Z | Add full-height connecting rib from feature back to host wall | Just move the ball — you'll break the mating geometry |
| Arc/C-shape printed face-down | Opening faces −Z; arc at top = self-supporting | Opening at +Z = arm tips float |
| Spherical snap catch on thin slab | Rib spans Z=0..sl, inset inside host wall boundary | Bare sphere at sl/2 |

**Rib pattern for ball catches:**
```scad
// Ball at correct protrusion (mating geometry unchanged)
translate([sx * (wall_edge + ball_r - ball_protr), y, sl/2])
    sphere(d=ball_d);
// Full-height rib — inset inside wall, no groove protrusion
translate([sx * (wall_edge - ball_r/2), y, sl/2])
    cuboid([ball_r + EPS, ball_d * 0.7, sl + EPS], anchor=CENTER);
```

**Flag immediately** any sphere, hemisphere, or cylindrical snap feature placed at the
midpoint of a thin slab without verifying the Z-range containment condition.

---

## 1. Factory IS the implementation — opts drive all variants

**Rule:** Each primitive shape has exactly ONE factory function. All behavioural
variants are driven by opts, not by separate factory functions or wrapper chains.

**Why:** Multiple render_*() wrappers around a single chassis create layered
indirection. Every new derived intent requires fighting through all layers to inject
behaviour — contorted, fragile, and hard to reason about.

**The pattern:**
```
factory_render_box(data, opts, phys) {
    lid_type = get_val("LID_TYPE", opts, "Snap");
    if      (lid_type == "Glide")        { ... groove + ball dimples inline ... }
    else if (lid_type == "Flip_Single")  { ... hinge boss + axle inline ... }
    else if (lid_type == "Flip_Double")  { ... dual hinge inline ... }
    else                                 { ... plain chassis ... }
}
```

**What this eliminates:**
- render_box() / render_flip_box() / render_double_flip_box() wrapper chain
- NEEDS_GROOVE flag smuggled through data to cross layer boundaries
- Separate factory_render_flip_box() that does nothing but call the real thing
- Adding a new variant = add one `else if` branch in ONE file

**Corollary:** The manifest is the only place that decides WHAT to build.
The factory is the only place that decides HOW to build it.
Never let behaviour bleed from manifest into data (via data overrides) just to
cross a factory boundary.

---

## 2. Built-in grid height is driven by LID_TYPE — the tray adapts to its lid

**Rule:** When a tray/box has a built-in grid (`HAS_BUILTIN_GRID=true`), the internal
divider wall height is NOT simply "tray height minus floor". It is capped by whatever
the lid type requires to close properly.

**The constraint per lid type:**

| LID_TYPE | Grid wall height cap | Reason |
|----------|---------------------|--------|
| Plain / Snap / Glide | `bh - sf - sl` | Full interior height |
| `Flip_Single` | `axle_z` = `bh - clip_outer_d/2` | Lid must flip closed over dividers |
| `Flip_Double` | `axle_z` (same) | Same hinge geometry |

**How it flows:**
```
factory_render_box(data, opts, phys)
  lid_type = get_val("LID_TYPE", opts)
  grid_wall_h = lid_type == "Flip_*" ? axle_z : bh - sf - sl
  d = concat([[GRID_WALL_H, grid_wall_h]], data)  ← inject before chassis call
  core_tray_chassis(d)
    → render_internal_grid(d)
        → reads GRID_WALL_H from d
        → dividers capped at grid_wall_h
```

**The hinge pillars ARE the grid divider pillars** (on the hinge side). In
`factory_render_box` with `Flip_Single`, the inter-column divider stubs at the +Y
face serve both as structural hinge support AND as grid column separators. They
are built by `factory_render_box`, NOT by `render_internal_grid`. The internal
grid handles only the full-depth dividers running front-to-back.

**Implementation note:** `GRID_WALL_H` must be in MasterEnum and prepended to
data in the factory before calling `core_tray_chassis`. `render_internal_grid`
reads it with `get_val(GRID_WALL_H, data, bh - sf - sl)` — the fallback is the
full interior height for plain boxes.

---

## 3. `use` vs `include` for factory modules

**Rule:** Use `include` for your own factory files. Use `use` only for
third-party libraries (BOSL2).

**Why:** OpenSCAD's `use <file>` is supposed to import module and function
definitions without executing top-level code. In practice, when the used file
has nested `include` chains with complex dependencies, `use` silently fails to
register module definitions — producing "WARNING: Ignoring unknown module 'X'"
with no other explanation.

**What happened:** MasterBuilder used `use <RenderJar.scad>`. RenderJar
includes RenderMesh which includes MasterMeshPatterns and MasterEngine.
Through this chain, `factory_render_jar` was never registered in MasterBuilder's
scope. The fix was changing to `include <RenderJar.scad>`.

**Safe because:** None of the factory files (RenderJar, RenderTray, RenderLid,
etc.) contain top-level executable geometry — they are pure module definitions.
`include` on a file with no top-level execution is identical in effect to `use`,
except it reliably brings module names into scope.

**Rule of thumb:**
```
include <your_own_factory.scad>   // always safe, always works
use     <BOSL2/std.scad>          // correct for third-party libraries
```

---

## 2. `return` is not valid at the top level of an OpenSCAD file

**Rule:** Never use `return` outside a function body in OpenSCAD.

**Why:** `return` is only valid as the implicit last expression inside a
function definition. At the top level of a file, OpenSCAD may parse it as a
call to an unknown module named "return", which silently aborts processing of
the rest of the file — including all module definitions below that line.

**What happened:** RenderMesh.scad had a double-inclusion guard:
```scad
if (!is_undef(MESH_LOADED)) return;
MESH_LOADED = true;
```
When this file was included, the `return` call aborted processing of the rest
of the file. Any file that included RenderMesh.scad and defined modules *after*
that include had those modules silently dropped.

**Fix:** Remove top-level `return` guards entirely. OpenSCAD handles
double-inclusion naturally — variables and modules defined multiple times just
take the last value, and the overhead is negligible.

---

## 3. Hardcoded physics values in the manifest are wrong

**Rule:** Always compute physics from data. Never hardcode them.

**Why:** The manifest stub originally hardcoded safety values:
```scad
[["SAFE_WALL", 2.4], ["SAFE_FLOOR", 2.0]]
```
These are the defaults for a 0.4mm nozzle with specific settings. A user with
a 0.6mm nozzle, different wall loops, or a thick floor setting would silently
get wrong geometry — walls that don't match their slicer, floors that don't
align to their layer height.

**Fix:** Always call `get_physics_profile(data)` which computes safe values
from the actual user payload:
```scad
get_physics_profile(data)  // derives from nozzle, layer height, wall loops
```

---

## 4. File-level version numbers create false confidence

**Rule:** Don't version individual files — use git.

**Why:** File headers like `[v4.13]` diverge from reality the moment a file
is edited without updating the number. They also create confusion when two
files claim the same version for different states of the code.

**Fix:** Remove all `[vX.Y]` tags from file headers. `git log -- filename`
shows the real history with actual context. The header should describe
*purpose*, not version.

---

## 5. Duplicate function definitions cause silent wrong-output bugs

**Rule:** Every function lives in exactly one file.

**Why:** OpenSCAD silently uses whichever definition it sees last (determined
by include order). If two files define `get_mesh_cfg` with different signatures,
callers get unpredictable behavior depending on which file was included first —
no error, no warning, just wrong geometry.

**What happened:** `get_mesh_cfg` existed in both `MasterEngine.scad` (correct
version with `needs_margin` guard) and `MasterLegacyBridge.scad` (simplified
version with `is_lid` parameter that ignored NONE patterns). Callers passing
`true` to apply lid minimum-solid logic were silently getting wrong mesh configs.

**Fix:** Delete the duplicate. Keep the canonical version in MasterEngine.

---

## 6. `include` inside a `use`d file may not propagate module definitions upward

**Rule:** If module A is defined in file X, and file Y does `include <X>`,
then `use <Y>` from file Z may or may not make module A visible in Z's scope.

**Why:** OpenSCAD's `use` processes the direct file for definitions. Modules
from transitively `include`d files may not be promoted into the calling scope.

**Consequence:** Even if `factory_render_jar` is defined in RenderJar.scad and
RenderJar.scad is `use`d by MasterBuilder.scad, the module might not be visible.
The only reliable solution is `include`.

---

## 7. Ternary `? :` cannot select between module calls in OpenSCAD

**Rule:** Use `if/else` to choose between modules. Use `? :` only for value
expressions inside functions or variable assignments.

**Why:** In OpenSCAD, `? :` is an expression operator — it returns a value.
Module instantiations (`circle()`, `rect()`, `cyl()`) are statements, not
values. Using ternary to choose between module calls is a syntax error:

```scad
// WRONG — syntax error
linear_extrude(h) is_cyl ? circle(d=w) : rect([w, l]);

// CORRECT
linear_extrude(h) {
    if (is_cyl) circle(d=w);
    else        rect([w, l]);
}
```

**What happened:** `framed_mesh` in RenderMesh.scad used ternary to select
between `circle()` and `rect()` children of `linear_extrude`. This was masked
by the MESH_LOADED guard (lesson 2) which prevented the file from ever loading.
Removing the guard exposed the underlying syntax error.

---

## 8. Enum values must be human-readable to work with the Customizer

**Rule:** Enum constant names follow code convention (ALL_CAPS). Enum string
values must match the Customizer dropdown labels exactly (human-readable,
mixed-case).

**Why:** The OpenSCAD Customizer reads the dropdown options from inline
comments and sets the variable to that exact string:

```scad
mesh_pattern = "Teardrop"; // ["Honeycomb", "Teardrop", "Slotted"...]
//                                           ↑ this exact string becomes the value
```

So enum values must be the same human-readable strings the Customizer shows.

**The pattern that works for both worlds:**
```scad
// MasterEnum.scad — constant name is ALL_CAPS, value is human-readable
TEARDROP = "Teardrop";
HONEYCOMB = "Honeycomb";

// MasterBuilder.scad Customizer dropdown — values match enum strings
mesh_pattern = "Teardrop"; // ["Honeycomb", "Teardrop", ...]

// Dispatcher — use the constant, not a raw string
if (pat == TEARDROP) ...   // "Teardrop" == "Teardrop" ✓
```

Using the constant everywhere means a label change only needs fixing in
MasterEnum — it propagates automatically. Raw strings scattered through
dispatchers (`"TEARDROP"`) break silently when the enum value differs.

**What happened:** `MasterMeshPatterns.scad` dispatched on `"HONEYCOMB"`,
`"TEARDROP"` (all-caps raw strings). The enums and Customizer both used
`"Honeycomb"`, `"Teardrop"` (mixed-case). Every pattern check silently
fell through — no mesh holes were ever cut, no warning issued.

**Fix:** Use the enum constants in all dispatchers. Never use raw strings
in comparisons.

---

## 9. Boolean Epsilon (`EPS` / `EPS2`) — what it is and when to change it

### What the problem is

When a `difference()` cutter's face sits exactly flush with the face it is supposed to
pierce, OpenSCAD cannot determine which side of the boundary each floating-point point
belongs to. The result is:

- **F5 preview** — the face flickers or shimmers (Z-fighting). The renderer oscillates
  between "inside" and "outside" on each redraw.
- **F6 render / STL export** — the coincident face may produce a non-manifold edge.
  Some slicers (Bambu Studio, PrusaSlicer) will warn "model has holes" or silently
  mis-slice the affected region.

### The fix

Extend every cutter slightly past the face it needs to pierce.

```
Without EPS:                   With EPS = 0.1:
┌──────────┐                   ┌──────────┐
│  solid   │                   │  solid   │
├──────────┤  ← ambiguous      │          │
│  cutter  │                   ├──────────┤ 0.1mm past face
└──────────┘                   │  cutter  │
                                └──────────┘
```

`EPS = 0.1` extends one end of a cutter by 0.1mm.  
`EPS2 = EPS * 2` extends both ends — used when a cutter must pierce through completely
(e.g., a socket hole that starts above the solid and exits below).

### Effect on printed geometry

`EPS` is a **display and export artifact only**. The 0.1mm overlap on a socket cutter
makes the hole 0.1mm deeper than the nominal dimension. At FDM tolerances (±0.1–0.2mm)
this is invisible. The rule is:

> If the cutter is subtracted from a face, add `EPS` on that end.  
> If it must pierce both faces, use `EPS2` total (split as `up(-EPS)` + `h + EPS2`).

### When to change the slider

| Symptom | Action |
|---------|--------|
| Flickering face in F5 preview | Raise to 0.2 |
| Slicer reports non-manifold on a flat cut surface | Raise to 0.2–0.3 |
| Visible step or ridge at cut edge in physical print | Lower back toward 0.1 |
| No symptoms | Leave at 0.1 — it has worked for every tested geometry |

**Never set below 0.05.** Very small values lose the benefit and can reintroduce
Z-fighting on high-$fn cylindrical geometry where floating-point rounding is aggressive.

**0.5 is the practical ceiling.** Above that, the cutter overlap starts to visibly
mis-dimension features like snap beads and hinge sockets.

### Where it is used in code

Every `difference()` cutter that cuts a face at a shared boundary uses `EPS` or `EPS2`.
Defined in `MasterEngine.scad`; overridden by `bool_overlap_eps` from the Customizer
(the MasterBuilder assignment runs after all includes, so it wins).

Files that consume `EPS` / `EPS2`:

| File | Use |
|------|-----|
| `RenderGrid.scad` | Hollow span cutter; radial spoke-to-hub fusion overlap |
| `RenderTray.scad` | Nesting ledge, peg socket cutters, corner boss fusion nudge |
| `RenderBox.scad` | Glide groove cutter length |

---

## 10. How to override user input and set flags from the manifest

### How data lookup works

`get_val(KEY, data, default)` scans `data` linearly and returns the **first** value
whose key matches. The user's Customizer payload is the tail of the array. Prepend
to win:

```scad
// User set GRID_LAYOUT = "2x3" in the Customizer.
// Manifest injects a different value:
d = concat([[GRID_LAYOUT, "7x1"]], data);
// get_val(GRID_LAYOUT, d, "") → "7x1"  ← manifest wins
```

### Overriding one key

```scad
(intent == "7-Day Pill Box") ?
    let(d = concat([[GRID_LAYOUT, "7x1"]], data))
    [["BOX", d, [["LID_TYPE", "Flip_Single"]], get_physics_profile(data)], ...]
```

### Overriding multiple keys

```scad
let(d = concat([[GRID_LAYOUT, "7x1"], [HAS_BUILTIN_GRID, true]], data))
```

Order within the prepended block does not matter — they are all before any user key.

### Named override block (S4 pattern)

When many keys need overriding, build the block separately for readability:

```scad
let(d = concat([["WIDTH", 49], ["LENGTH", 49], ["HEIGHT", 140]], DESICCANT_MESH_CYL, data))
```

`DESICCANT_MESH_CYL` is itself an array of `[KEY, val]` pairs — `concat` flattens
one level, so this works cleanly.

---

### `data` vs `opts` — what goes where

| Channel | What it carries | Read by |
|---------|----------------|---------|
| `data`  | Geometry, physics, grid config, flags that affect the *container* shape | `factory_render_*`, `core_tray_chassis`, `render_internal_grid` |
| `opts`  | Per-component dispatch flags that affect *which variant* is built | The factory's first `let` block — e.g. `lid_type = get_val("LID_TYPE", opts, "Snap")` |

If a flag controls **how a container is shaped** (grid layout, built-in grid, thread neck, desiccant mesh) → put it in `data`.  
If a flag controls **which factory branch to take** (lid type, thread on/off, jar grid mode) → put it in `opts`.

---

### Common flags

| Flag | Where | Effect |
|------|-------|--------|
| `HAS_BUILTIN_GRID` | `data` | Activates `render_internal_grid` inside the chassis. Must also set `GRID_LAYOUT`. |
| `GRID_LAYOUT` | `data` | Layout string parsed by `GridLayout.scad`. Format: `"NxM"` cartesian, `"RN"` radial rays, `"SR/C/RS/CS"` span, combinable with spaces. |
| `GRID_WALL_H` | `data` | Max divider height (injected by `factory_render_box` — do not set from manifest). |
| `IS_JAR_GRID` | `opts` | Tells `factory_render_grid` to clip cartesian walls to the jar's circular boundary. Set this on standalone `GRID` parts for jar contexts. |
| `IS_THREADED` | `opts` | Adds threaded neck to a JAR. |
| `SKIP_PILLARS` | `data` | Suppresses flip-box hinge pillars (used for single-lid multi-compartment boxes where the lid spans the full width). |
| `GRID_HAS_BASE` | `data` | Adds a solid floor layer to a drop-in grid. Defaults `false` — opt-in only. |
| `DESICCANT_MESH_RECT` / `DESICCANT_MESH_CYL` | prepended to `data` | Forces teardrop mesh with airflow-optimized hole/strut geometry. Overrides all user mesh settings. |

---

### Grid layout string reference

```
"3x4"              → 3 columns, 4 rows (cartesian)
"R6"               → 6 radial dividers from centre (jar only)
"C20%"             → radial core radius = 20% of jar radius (default 6mm absolute)
"S2/3/2/2"        → span at row 2, col 3, spanning 2 rows × 2 cols, full height
"S2/3/2/2/60%"    → same span, height capped at 60% of interior height
"3x4 R6 C20%"     → cartesian + radial combined
"3x4 S2/3/2/2 R6" → cartesian + span + radial
```

Tokens are space-separated and order-independent. `parse_cartesian`, `parse_radial`,
and `parse_spans` each scan the full token list independently.

---

## 7. Slicer-aware geometry — Arachne speed optimization

These rules eliminate two distinct slicer slowdown mechanisms that cause visible print
artifacts and wasted print time. Both are fixed by tying geometry thresholds to
`nozzle_d` (available everywhere via `MasterEngine.scad`).

**Extrusion width** = `nozzle_d * 1.05` — Bambu Studio's default line width at 105% of
nozzle diameter. This is the minimum printable feature size. Any geometry smaller than
this forces the slicer into a slow-path.

---

### 7a. Arachne pressure pinch — tip truncation

**What it is:** Arachne (variable-width extrusion engine) must taper the bead to match
the geometry. When a tip comes to a point narrower than the extrusion width, Arachne
slows the head to near-zero to control pressure. Result: blobs, surface marks, wasted time.

**Rule:** No printed geometry tip narrower than `nozzle_d * 1.05`.

**Applied in this codebase:**

| Geometry | File | Fix |
|----------|------|-----|
| Teardrop mesh hole | `MasterMeshPatterns.scad` | Triangle tip → trapezoid flat top of `nozzle_d * 1.05` width |
| Diamond mesh hole | `MasterMeshPatterns.scad` | Pointed rhombus → vertical tips truncated to `nozzle_d * 1.05` |
| Flip latch tab | `RenderLid.scad` | Hull Z-tips: `0.1mm` → `noz*1.05` |
| Flip latch recess | `RenderBox.scad` | Cutter mirrors tab shape — same fix |

**Teardrop geometry note:** The roof must also be exactly 45° from horizontal (the FDM
critical overhang angle for PETG). The roof polygon starts at the 45° points on the
circle — `[r·cos45, r·sin45]` — not from the base diameter. Starting from the base
produces ~56° sides that need support.

```scad
// Correct: 45° roof + flat top
bx = r * cos(45);  by = r * sin(45);  th = r + by;  w = nozzle_d * 1.05;
polygon([[-bx, by], [bx, by], [w/2, th], [-w/2, th]]);
```

---

### 7b. Motion planner jerk — corner rounding

**What it is:** A sharp 90° corner forces the print head to dead-stop on one axis before
accelerating on the other. The motion planner's jerk limit kicks in, causing a pressure
spike that leaves a corner blob and wastes time.

**Rule:** Round all sharp 90° corners on mesh holes to `rounding = nozzle_d`.

**Applied in this codebase:**

| Geometry | File | Fix |
|----------|------|-----|
| Square mesh holes | `MasterMeshPatterns.scad` | `rect([hole, hole], rounding=nozzle_d)` |
| Diamond mesh holes | `MasterMeshPatterns.scad` | Side corners covered by truncated rhombus polygon |
| Slotted mesh holes | `MasterMeshPatterns.scad` | `rounding=max(hole*0.2, nozzle_d*1.05)` |

**Note:** Honeycomb (`$fn=6`) is intentionally left un-rounded. The straight hex sides
bridge cleanly as long as struts are wide enough. Rounding would distort the shape.

---

### 7c. Circle quality — `$fs` / `$fa` over `$fn`

**Rule:** Never use a global `$fn` for print quality. Use `$fs` (max chord length) and
`$fa` (max angle) so each circle auto-computes the right facet count for its diameter.

```scad
$fn = $preview ? 24 : 0;        // 0 = let $fs/$fa control
$fs = $preview ? 2  : nozzle_d; // chord ≤ nozzle diameter
$fa = $preview ? 10 : 1;        // secondary angle guard
```

A global `$fn=128` is too coarse for circles > ~16mm diameter (visible faceting) and
wasteful for small circles. `$fs = nozzle_d` scales correctly for every circle size.

**Hard-coded `$fn` overrides are intentional and win over `$fs`:**
- `$fn=6` → hexagon mesh holes (not a smooth circle)
- `$fn=30` → threaded neck (thread pitch geometry)
- `$fn=36` → hinge/clip cylinders (mechanical fit tolerance)

---

### 7d. What NOT to change

The `0.6mm` offsets in Glide lid and Screw lid geometry are **mechanical clearance
tolerances** — intentional fit values, not print-quality thresholds. Do not replace
these with nozzle-parametric expressions.
