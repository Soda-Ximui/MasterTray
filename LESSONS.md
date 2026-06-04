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

## 0a. All generated models must print support-free

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

## 0a. Optimal print orientation — never lay on side for extreme ratios

**Rule:** All primitives ship in their optimal FDM orientation. Users adjust in their
slicer (brim, speed, enclosure temp) — we do not change orientation to compensate
for extreme height/width ratios.

| Primitive | Optimal orientation | Reason |
|-----------|--------------------|----|
| JAR | Upright (floor on bed) | Side needs supports under curved wall; diameter becomes oval |
| TRAY / BOX | Flat (floor on bed) | Layer lines horizontal through floor = maximum strength |
| LID (Screw) | Face-down (top surface on bed) | Full-circle adhesion; interior thread on vertical walls |
| LID (Glide/Slip) | Face-down | Best surface finish on visible face |
| GRID (built-in) | Part of tray — inherits tray orientation |
| GRID (drop-in) | Flat (base on bed) | Flag if very long/thin — warp risk, slicer brim recommended |

**Extreme ratios:** A 49×140mm jar prints upright regardless. A 300×200×8mm tray
prints flat regardless. Extreme geometry is a slicer concern (brim, slow first layer,
enclosure), not an orientation concern.

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

## 1. `use` vs `include` for factory modules

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
