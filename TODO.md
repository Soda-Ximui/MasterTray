# MasterTray — Optimization TODO
_Generated from full codebase audit. Run `TODO.ps1` to check completion status._

---

## Priority 1 — Do First (correctness / silent failures)

---

### [F15] Flip-box hinge: `echo` warning → `assert` hard failure
**File:** `RenderBox.scad` ~line 103  
**Category:** Structural — silent failure

**Discovery:** When `clip_len = w - sw*6 <= 0` (box too narrow for hinge geometry),
the code emits an `echo()` warning and silently renders a box without a hinge. The box
is labelled "Flip_Single" but cannot flip. The user only discovers this after the print.

**Physics:** The hinge C-clip needs `sw*6` of width — 3 walls on each side of the clip
channel. Anything narrower means the channel would cut through the outer wall. There is
no graceful fallback — the box is structurally broken.

**Fix:** Replace `echo()` with `assert()` so OpenSCAD halts at F5/F6 with a clear message.

```scad
// BEFORE:
if (clip_len <= 0)
    echo(str("WARNING: Flip_Single hinge suppressed — box too narrow (w=", w,
             " sw=", sw, " clip_len=", clip_len, "). Increase width or reduce wall_loops."));

// AFTER:
assert(clip_len > 0, str(
    "Flip_Single requires w > ", sw*6, "mm. Current w=", w,
    "mm, sw=", sw, "mm. Increase width or reduce Wall_Loops."));
```

Same fix applies to `Flip_Double` in RenderBox.scad (same pattern, ~line 151).

---

### [F18] `lip_h = 8.0` hardcoded in 3 files — constant unused
**Files:** `RenderJar.scad` line 22, `RenderLid.scad` line 136, `RenderGrid.scad` line 180  
**Category:** Code coupling — silent drift bug

**Discovery:** `JAR_LIP_HEIGHT = 8.0` is defined and documented in `MasterConstants.scad`
(line 11). But all three render files declare `lip_h = 8.0` as a local literal. If
`JAR_LIP_HEIGHT` is ever tuned, the three render files are silently left behind — the
constant change does nothing.

**Fix:** Replace all three local literals with the constant.

```scad
// BEFORE (all 3 files):
lip_h = 8.0;

// AFTER:
lip_h = JAR_LIP_HEIGHT;
```

Note: `MasterConstants.scad` is already included transitively through `MasterEngine.scad`
in all render files — no new include needed.

---

### [F6] Diamond latch offsets not layer-aligned
**File:** `RenderLid.scad` ~lines 120–131  
**Category:** Layer alignment — micro-stepping artifacts

**Discovery:** The flip latch tab is built from three cuboids placed at Y-offsets of
`1.1`, `2.2`, `1.5` and Z-offsets of `0.8`. At 0.28mm layer height:
- 0.8mm = 2.857 layers
- 0.9mm = 3.214 layers
- 1.1mm = 3.928 layers

These fractional-layer positions force the slicer to insert micro-moves between layers
causing surface roughness and potential delamination stress on fine latch geometry.

**Physics:** The slicer computes layer boundaries as `floor(z / lh) * lh`. Any geometry
surface sitting between two boundaries gets a partial layer — the extruder deposits a
thinner-than-intended bead, which cools faster and bonds less to the layer above.

**Fix:** Add a `layer_snap()` helper to `MasterEngine.scad` and apply it to all latch
Z-offsets. Y-offsets are horizontal (not in the build direction) — leave those alone.

```scad
// Add to MasterEngine.scad (near other helper functions):
function layer_snap(z, lh) = round(z / lh) * lh;

// BEFORE (RenderLid.scad):
translate([0, 0,  -0.8]) cuboid([lid_w-sw*4, 0.1, noz*1.05], anchor=CENTER);
translate([0, 0,   0.8]) cuboid([lid_w-sw*4, 0.1, noz*1.05], anchor=CENTER);

// AFTER:
lz = layer_snap(0.8, m_lh(data));
translate([0, 0,  -lz]) cuboid([lid_w-sw*4, 0.1, noz*1.05], anchor=CENTER);
translate([0, 0,   lz]) cuboid([lid_w-sw*4, 0.1, noz*1.05], anchor=CENTER);
```

---

### [F14] Snap bead height `noz*2` not layer-aligned
**File:** `RenderLid.scad` line 44  
**Category:** Layer alignment + mechanical fit

**Discovery:** The Snap lid retention bead is `bead_h = noz * 2 = 0.8mm` tall. At
0.28mm layer height this is 2.857 layers — a fractional boundary. The bead is also
very short: just 2 nozzle widths of retention height may not provide reliable PETG
click-force.

**Fix:** Round up to the nearest layer-height multiple, ensuring at least 3 layers.

```scad
// BEFORE:
bead_h = noz * 2;

// AFTER:
bead_h = m_lh(data) * max(3, ceil(noz * 2 / m_lh(data)));
// At 0.28mm lh, 0.4mm nozzle: ceil(0.8/0.28)=3 layers → bead_h = 0.84mm
```

---

## Priority 2 — Do Soon (print quality improvements)

---

### [F1] Glide ball minimum too small for small boxes
**File:** `MasterEngine.scad` line 428  
**Category:** Print quality — Arachne small-perimeter slowdown

**Discovery:** `glide_ball_d = min(sw*2, max(noz*5, max(w,l)*0.03))`. For a 30mm box:
`max(w,l)*0.03 = 0.9mm` and `noz*5 = 2.0mm`, so the ball is 2.0mm diameter. Arachne's
small-perimeter speed clamp typically activates below ~3mm diameter, causing the head
to slow significantly for each of the many ball-dimple circles.

**Physics:** A full sphere at 2mm diameter means Arachne traces ~25 perimeters of
<0.25mm circumference each. Each triggers the speed limiter. More dimples = more pauses
= more pressure spikes = more blobs.

**Fix:** Raise minimum from `noz*5` to `noz*8` (3.2mm at 0.4mm nozzle — safely above
Arachne's clamp zone).

```scad
// BEFORE:
function glide_ball_d(w, l, sw, noz) =
    min(sw * 2, max(noz * 5, max(w, l) * 0.03));

// AFTER:
function glide_ball_d(w, l, sw, noz) =
    min(sw * 2, max(noz * 8, max(w, l) * 0.03));
```

---

### [F2] Diamond latch hull — middle engagement cuboid Y=0.1mm
**File:** `RenderLid.scad` line 130, `RenderBox.scad` lines 133 & 193  
**Category:** Print quality — thin-wall extrusion

**Discovery:** The engagement-direction cuboid (middle of the three hull points) has
`Y = 0.1mm`. After the hull merges all three cuboids, the transition zone between the
truncated Z-tips and the engagement point is only 0.1mm wide in Y — well below the
0.42mm minimum printable width. Arachne will try to extrude a bead 0.1mm wide, fail to
maintain pressure, and leave an inconsistent line.

**Fix:** Widen the middle cuboid's Y-dimension to `noz * 2` (one solid extrusion pass
each side of center). This makes the snap engagement geometry reliably printable while
preserving the click-fit geometry.

```scad
// BEFORE (RenderLid.scad — lid tab):
translate([0, 0.9, 0  ]) cuboid([lid_w-sw*4, 0.1, 0.1], anchor=CENTER);

// AFTER:
translate([0, 0.9, 0  ]) cuboid([lid_w-sw*4, noz*2, 0.1], anchor=CENTER);

// BEFORE (RenderBox.scad — box recess, Flip_Single):
translate([0, -0.8, 0  ]) cuboid([w-sw*4, 0.1, 0.1], anchor=CENTER);

// AFTER:
translate([0, -0.8, 0  ]) cuboid([w-sw*4, noz*2, 0.1], anchor=CENTER);

// BEFORE (RenderBox.scad — box recess, Flip_Double):
translate([0, sy*0.8,  0  ]) cuboid([w-sw*4, 0.1, 0.1], anchor=CENTER);

// AFTER:
translate([0, sy*0.8,  0  ]) cuboid([w-sw*4, noz*2, 0.1], anchor=CENTER);
```

---

### [F16] Radial grid hub min-size threshold hardcoded at 1.5mm
**File:** `RenderGrid.scad` line 79  
**Category:** Structural — magic number

**Discovery:** `c_eff = (inner >= 1.5) ? c_dia : max(4.0, c_dia)`. Both thresholds
(1.5 and 4.0) are magic numbers that don't scale with nozzle. At a 0.6mm nozzle,
a 1.5mm inner diameter is only 2.5 passes — borderline structural. At 0.2mm nozzle,
4.0mm is 20 passes — excessive.

**Fix:** Derive both thresholds from nozzle diameter.

```scad
// BEFORE:
c_eff = (inner >= 1.5) ? c_dia : max(4.0, c_dia);

// AFTER:
min_hollow = m_noz(data) * 6;   // minimum hollow hub: 6 extrusion passes across diameter
min_solid  = m_noz(data) * 10;  // minimum solid hub: 10 passes (if too small to hollow)
c_eff = (inner >= min_hollow) ? c_dia : max(min_solid, c_dia);
```

Note: `m_noz(data)` is available — `data` is passed down to `_render_radial_core` via
the grid config. If `data` is not in scope, use the global `nozzle_d` from MasterEngine.

---

### [F7] Jar grid clearance `-0.5` breaks layer alignment
**File:** `RenderJar.scad` line 33  
**Category:** Layer alignment

**Discovery:** `grid_h = cyl_wall_h - 0.5`. The `0.5mm` constant subtracted from a
layer-aligned wall height produces a non-layer-aligned grid height. Grid dividers then
sit at a fractional Z position.

**Fix:** Round up to the next full layer.

```scad
// BEFORE:
grid_h = cyl_wall_h - 0.5;

// AFTER:
grid_h = cyl_wall_h - m_lh(data) * ceil(0.5 / m_lh(data));
// At 0.28mm lh: ceil(0.5/0.28)=2 → subtracts 0.56mm (2 layers) — slightly more clearance,
// fully aligned.
```

---

### [F8] Glide groove Z-position not layer-aligned
**File:** `RenderBox.scad` line 51  
**Category:** Layer alignment

**Discovery:** `groove_z = h - sl - 1.0`. The `1.0mm` drop places the groove bottom
at a fractional layer boundary (1.0 / 0.28 = 3.57 layers).

**Fix:**

```scad
// BEFORE:
groove_z = h - sl - 1.0;

// AFTER:
groove_z = h - sl - m_lh(data) * ceil(1.0 / m_lh(data));
// At 0.28mm: ceil(1.0/0.28)=4 → 1.12mm drop — groove sits on a clean layer boundary.
```

---

### [F9] Thread rod Z-offset hardcoded at 0.1mm
**File:** `RenderLid.scad` line 143  
**Category:** Layer alignment

**Discovery:** `up(sl - 0.1) threaded_rod(...)`. The 0.1mm pullback is a cutter overlap
guard (like `EPS`), but 0.1mm is not layer-aligned (0.1/0.28 = 0.357 layers).

**Fix:** Use half a layer height — already in scope, semantically correct as a
sub-layer overlap guard.

```scad
// BEFORE:
up(sl - 0.1) threaded_rod(...)

// AFTER:
up(sl - m_lh(data)/2) threaded_rod(...)
```

---

## Priority 3 — Defer (minor / cosmetic)

---

### [F4] Nesting ledge lip sharp outer corner
**File:** `RenderTray.scad` ~line 97  
**Category:** Jerk / motion planner — minor cosmetic

The outer ledge perimeter has no chamfer on its Z-edges. A small `chamfer=m_chamf(data)`
on `edges="Z"` would eliminate a jerk event at the ledge corners. Low priority —
the ledge is a small feature and the effect is subtle.

```scad
// BEFORE:
cuboid([w, l, ledge_h + EPS], anchor=BOTTOM, chamfer=m_chamf(data), edges=BOTTOM);

// AFTER:
cuboid([w, l, ledge_h + EPS], anchor=BOTTOM, chamfer=m_chamf(data), edges=BOTTOM+Z_EDGES);
```

---

### [F5] Hinge pillar tops unrounded
**File:** `RenderBox.scad` ~lines 118, 120, 124  
**Category:** Jerk / motion planner — minor cosmetic

The flip-box hinge pillars (`cuboid([sw*3, hinge_y+1, axle_z+cc_z-sf], anchor=BOTTOM+FRONT)`)
have sharp top edges. Adding a small top chamfer eliminates the jerk event as the head
transitions from pillar top to the surrounding chassis.

```scad
// AFTER:
cuboid([sw*3, hinge_y+1, axle_z+cc_z-sf], chamfer=m_chamf(data), edges=TOP,
       anchor=BOTTOM+FRONT);
```

---

### [F17] Jar grid height not validated as layer-aligned
**File:** `RenderGrid.scad` ~line 181  
**Category:** Layer alignment — minor

`int_h = bh - sf - (has_threads ? lip_h + sw*1.5 : 0) - (is_builtin ? 0 : 0.5)`. The
compound subtraction may produce a non-layer-aligned result. Low risk but easy fix:

```scad
// AFTER: force alignment
int_h_raw = bh - sf - (has_threads ? lip_h + sw*1.5 : 0) - (is_builtin ? 0 : 0.5);
int_h = round(int_h_raw / m_lh(data)) * m_lh(data);
```

---

### [F19] Dead constants in MasterConstants.scad
**File:** `MasterConstants.scad` lines 37–38  
**Category:** Code maintenance

`HINGE_BOSS_DEPTH = 2.0` and `HINGE_BOSS_WIDTH = 1.2` are defined but never referenced
in any render file. Either wire them into the hinge pillar calculations or remove them.
No print impact.

---

## Findings NOT actioned (confirmed intentional)

| Finding | Reason left alone |
|---------|------------------|
| F10 — Snap bead `rotate_extrude` overhang | Existing builds print correctly; geometry is self-supporting at 45° |
| F11 — Hinge bore gap bridging | Gap is intentional C-clip clearance; bore walls are vertical (no overhang) |
| F12 — Glide groove `0.6mm` offset | Confirmed mechanical clearance tolerance, not a print threshold |
| F13 — Hinge wall `noz*8` | `CLIP_WALL_THICKNESS_MULT = 4.0` in MasterConstants already encodes this — correct |
| F3  — Radial hub `data` scope | Covered by F16 fix |

---

## Checklist

- [ ] F15 — Flip-box hinge `assert()` (RenderBox.scad)
- [ ] F18 — `lip_h` → `JAR_LIP_HEIGHT` (RenderJar, RenderLid, RenderGrid)
- [ ] F6  — Diamond latch layer_snap (MasterEngine + RenderLid)
- [ ] F14 — Snap bead height layer-align (RenderLid)
- [ ] F1  — Glide ball min `noz*8` (MasterEngine)
- [ ] F2  — Diamond hull middle cuboid Y=`noz*2` (RenderLid + RenderBox ×2)
- [ ] F16 — Radial hub thresholds nozzle-parametric (RenderGrid)
- [ ] F7  — Jar grid clearance layer-align (RenderJar)
- [ ] F8  — Glide groove Z layer-align (RenderBox)
- [ ] F9  — Thread rod Z-offset → `m_lh/2` (RenderLid)
- [ ] F4  — Ledge lip chamfer Z-edges (RenderTray)
- [ ] F5  — Hinge pillar top chamfer (RenderBox)
- [ ] F17 — Jar grid height layer-align (RenderGrid)
- [ ] F19 — Remove/wire dead constants (MasterConstants)
