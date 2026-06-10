# MasterTray — Bug Registry
_Each entry: root cause, affected code, fix, and test to verify._

---

## B1 — Circular strut % uses diameter scaling instead of area scaling

**Status:** Fixed in `RenderMesh.scad` line 52  
**Severity:** Medium — solid border on jar floor/lid is larger than user-dialled value  
**Reported:** 2026-06-04 session (strut semantics review)

### Definition of strut %

Strut % is the **fraction of the surface that is solid border**.  
10% strut → 90% of the surface area is open mesh.

| Surface | Strut applies to |
|---------|-----------------|
| Flat rectangle | Each linear dimension independently: mesh rect = W×(1−s%) by L×(1−s%) |
| Flat circle | **Area**: mesh circle area = (1−s%) × total area |
| Cylindrical wall | Height only: mesh zone = (1−s%) of height, split equally top and bottom |

### The bug

`framed_mesh` with `is_cyl=true` (jar floor, jar lid) computed the mesh circle diameter as:

```scad
// BEFORE (wrong): linear diameter scaling
circle(d = get_mesh_dim(w, strut));   // = w * (1 - strut/100)
```

Area scales as diameter², so this gives mesh area = `(1−strut/100)²` of total — not `(1−strut/100)`.

**Error at common strut values:**

| Strut % | Expected mesh area | Actual mesh area (bug) | Error |
|---------|-------------------|----------------------|-------|
| 10% | 90% | 81% | −9 pp |
| 20% | 80% | 64% | −16 pp |
| 30% | 70% | 49% | −21 pp |
| 50% | 50% | 25% | −25 pp |

### Fix

Scale by √ so the area relationship is preserved:

```scad
// AFTER (correct): area-preserving scaling — see RenderMesh.scad line 52
circle(d = w * sqrt(max(0, 1 - strut / 100)));
```

Verification: at strut=10%, `d = w * sqrt(0.9) = w * 0.9487`.  
Area = π(0.9487d/2)² = 0.9 × πd²/4. ✓

### What is NOT a bug (for reference)

**Flat rectangle pad:** `framed_mesh` subtracts `pad = noz × 4.5` from the mesh rect
on each axis to prevent half-holes at the boundary. This makes the actual solid border
slightly wider than strut% alone specifies (by ~0.9mm each side at 0.4mm nozzle).
This is **intentional** — without it, holes at the mesh boundary are clipped to partial
shapes that print as blobs. Strut% sets the coarse border; pad adds a small fixed
print-quality margin on top.

**Threaded neck:** The mesh zone never reaches the threaded neck because the jar geometry
is split into separate pieces (`cyl_wall_h` for mesh wall, then taper + thread above).
Strut% only governs the mesh wall section; the neck is structurally isolated above it.

---

## B2 — Screw lid cap height inherits jar neck height instead of minimum thread engagement

**Status:** Fixed in `RenderLid.scad` line 141  
**Severity:** High — lid prints ~70% taller than necessary; wastes filament and print time  
**Reported:** 2026-06-04 (user: "jar lid too tall")

### Root cause

The Screw lid cap height was derived by copying the jar neck geometry:

```scad
// BEFORE (wrong): RenderLid.scad line 141
lip_h = JAR_LIP_HEIGHT;              // 8.0mm — the jar's threaded neck height
cap_h = max(0.1, lip_h + sw * 1.5); // 8.0 + 2.4×1.5 = 11.6mm
```

`lip_h + sw*1.5` is the sum of the jar neck's thread section (`lip_h`) and its taper
cone (`sw*1.5`). The taper is a feature on the **jar body** — it transitions the jar
wall diameter down to the neck diameter. The lid cap slides over the neck; it has no
taper and does not need taper clearance.

**Total lid height at defaults:** `sl + cap_h` = `2.0 + 11.6` = **13.6mm**

### Fix

Cap height = minimum thread engagement: 3 full turns at the configured pitch,
floored at `sw*2` (ensures at least 2 full wall passes on the cap cylinder).

```scad
// AFTER: RenderLid.scad line 141
cap_h = max(m_thread_pitch(data) * 3, sw * 2);
```

**Total lid height at defaults** (`pitch=2.0, sw=2.4`):  
`max(6.0, 4.8) = 6.0mm cap` → `sl + cap_h = 2.0 + 6.0` = **8.0mm** (−5.6mm, −41%)

### Height comparison at common settings

| pitch | sw | Before cap_h | After cap_h | Saving |
|-------|----|-------------|-------------|--------|
| 2.0mm | 2.4mm | 11.6mm | 6.0mm | −5.6mm |
| 2.0mm | 3.2mm | 12.8mm | 6.4mm | −6.4mm |
| 3.0mm | 2.4mm | 11.6mm | 9.0mm | −2.6mm |

### All other lid types — confirmed correct

| Lid type | Height | Verdict |
|----------|--------|---------|
| Snap | `sl` only | ✅ |
| Glide | `sl` only | ✅ |
| Flip_Single | `sl` + C-clip hinge above (mechanically required) | ✅ |
| Slip | `sl` only | ✅ |
| **Screw** | **Was `sl + lip_h + sw*1.5`; now `sl + max(pitch×3, sw×2)`** | **Fixed** |

---

## B3 — Flip_Single C-clip hinge: floating cantilever when printed face-down

**Status:** Fixed in `RenderLid.scad` — commit `51487cb`
**Severity:** High — lid fails to print; Bambu Studio flags floating cantilever
**Reported:** 2026-06-07 (print failure on Flip_Double half-lids, STL_12 + STL_13)

### Root cause

The C-clip slot was cut from the **top** of the arc:

```scad
// BEFORE (wrong):
translate([0, 0, +clip_outer_d/2])
    cuboid([clip_len+2, hinge_d*0.8, clip_outer_d], anchor=CENTER);
```

With the slot at `+clip_outer_d/2`, the opening faces upward. When the lid is printed
face-down (flat outer surface on bed), the two C-arm tips are at the top of the print
with nothing below them — a floating cantilever. Bambu Studio warns; the arms either
fail to print or detach during the print.

### Fix

Move slot to `-clip_outer_d/2` — opening faces **downward**. The arc is now at the
top of the print (self-supporting). The pin enters from below as the lid is pressed
onto the box hinge.

```scad
// AFTER (correct):
translate([0, 0, -clip_outer_d/2])
    cuboid([clip_len+2, hinge_d*0.8, clip_outer_d], anchor=CENTER);
```

### General rule

When a cylindrical arc or C-shape is printed face-down, the **opening must face the
bed** (−Z) so the arc body is at the top (self-supporting). An opening facing +Z leaves
the two arm tips as unsupported cantilevers.

---

## B4 — Glide lid ball catch: floating shell when ball_r > sl/2

**Status:** Fixed in `RenderLid.scad` — commit `03068d4`
**Severity:** High — balls detach from lid in print; no slicer warning
**Reported:** 2026-06-07 (post-print: "balls fell wholesale, no warning")

### Root cause

Ball catch spheres were placed at `Z = sl/2` (mid-lid-height) with no connection spine.
When `ball_r > sl/2` (common — e.g. 1.2mm radius, 0.8mm half-lid-height):

- Bottom of sphere: `sl/2 − ball_r < 0` → clips below the print bed
- Top of sphere: `sl/2 + ball_r > sl` → pokes above the lid top

The upper portion of the ball (from where the lid wall ends to `sl + ball_r`) has **no
lid-wall connection at those Z layers**. It prints as a floating shell that detaches.
Slicer does not warn because the ball starts connected — only the top separates mid-print.

```scad
// BEFORE (wrong): bare sphere, no Z-spanning connection
for (sx = [-1, 1])
    translate([sx * (lid_w/2 + ball_r - ball_protr), ball_y, sl/2])
        sphere(d=ball_d);
```

### Fix

Add a full-height rib inset into the lid wall. The rib spans Z=0 to Z=sl, giving the
ball solid attachment at every print layer. The rib stays inside the lid wall so it
does not protrude into the groove channel. Box dimple geometry unchanged.

```scad
// AFTER: ball + full-height connection rib
for (sx = [-1, 1]) {
    translate([sx * (lid_w/2 + ball_r - ball_protr), ball_y, sl/2])
        sphere(d=ball_d);
    translate([sx * (lid_w/2 - ball_r/2), ball_y, sl/2])
        cuboid([ball_r + EPS, ball_d * 0.7, sl + EPS], anchor=CENTER);
}
```

### General rule

Before placing any sphere or round feature at height `h/2` within a host body:
**verify `ball_r ≤ h/2`**. If `ball_r > h/2`, the sphere escapes the host body in Z.
Fix with a full-height connecting rib (preferred — preserves mating geometry) or by
clamping diameter to `h` (requires updating all mating geometry too).

---

## B5 — Flip lid diamond clasp recess bulges outward instead of into the wall

**Status:** Fixed (2026-06-10) — recess-direction fix applied and rendered clean with
  `--hardwarnings` for both Flip_Single and Flip_Double. Flip_Double's separate
  "reopens under light force" retention-strength issue is **not** addressed by this fix
  — needs a follow-up `ENG_CLASP_*`/recess-depth tuning pass (see Update below), tracked
  as a new bug if it persists after reprint with this fix.
**Severity:** High for both — Flip_Single has no retention at all; Flip_Double closes
  with a satisfying snap but **reopens under very light/accidental force** (insufficient
  holding strength)
**Reported:** 2026-06-09 (printed Flip_Single + Flip_Double, photos: latch arm sits flat
against the front wall with a visible straight gap behind it, no retention)
**Update 2026-06-10:** Corrected — Flip_Double's close action **feels right** (good
snap on closing), but it **can spill open from very light/incidental contact** — the
latch isn't holding it shut, not that it's hard to shut. This points at insufficient
**engagement depth / retention force** of the diamond clasp once seated (too shallow a
catch, or too little material overlap to resist being pried open), separate from
Flip_Single's complete lack of any pocket. Flip_Single is still the higher-priority
case (no retention whatsoever); Flip_Double needs the clasp to *hold* once closed, not
just *click* on closing — likely an `ENG_CLASP_*` (engagement depth) / recess depth
tuning issue rather than (only) the recess-direction issue below. Re-test both
independently after any change.

### Symptoms (from photos)

- **Flip_Double**: the latch arm runs straight down the outside of the front wall with
  a continuous vertical gap behind it — "nothing to clasp to ... the latch goes
  STRAIGHT DOWN, nothing to hold it in." Length and overall fit are good; the flat-top
  tip geometry (B-series fix) prints cleanly. *(2026-06-10: turns out this does snap
  shut with a hard push — see Update above.)*
- **Flip_Single**: no gap at all behind the arm — tip presses flush against the wall
  and would likely snap off if forced. ("likely break")
- Box-side latch recess is not visibly engaging the lid's diamond tip in either case.

### Root cause

`RenderLid.scad`'s diamond tip (lines ~207-212) protrudes from the latch arm **toward
+Y** (toward the box wall — "Protrudes 0.9mm in +Y from arm inner face"):

```scad
translate([0, -lid_l/2 - 1.5, sl + clasp_depth])
    hull() {
        translate([0, 0,   -lz]) cuboid([lid_w-sw*4+EPS, 0.1,   noz*1.05], anchor=CENTER);
        translate([0, 0.9,   0]) cuboid([lid_w-sw*4+EPS, noz*2, 0.1     ], anchor=CENTER);
        translate([0, 0,    lz]) cuboid([lid_w-sw*4+EPS, 0.1,   noz*1.05], anchor=CENTER);
    }
```

But `RenderBox.scad`'s matching latch recess cutter (Flip_Single line ~274-279,
Flip_Double line ~366-372) bulges the **opposite** way — toward **-Y** (outward, away
from the box, into open air in front of the wall):

```scad
// Flip_Single — RenderBox.scad ~277
translate([0, -l/2 + EPS, latch_z])
    hull() {
        translate([0,  0,   0.8]) cuboid([w-sw*4, 0.1, noz*1.05], anchor=CENTER);
        translate([0, -0.8, 0  ]) cuboid([w-sw*4, noz*2, 0.1   ], anchor=CENTER);  // <- wrong sign
        translate([0,  0,  -0.8]) cuboid([w-sw*4, 0.1, noz*1.05], anchor=CENTER);
    }
```

The cutter's local origin (`-l/2 + EPS`) sits just **inside** the wall's outer face, so
local `+Y` points further into the wall (toward the box interior) and local `-Y` points
out into open air beyond the wall. The cutter's bulge is at local `y = -0.8` —
**outside the wall solid** — so subtracting it removes essentially nothing (only an
EPS-thin sliver at the face). No pocket is ever cut into the wall, so the lid's
diamond bump (which protrudes +Y, *toward* the wall) has no recess to seat in and no
surrounding wall material to act as a retention lip. It just presses flat against a
solid face.

For Flip_Double, both recesses use `translate([0, sy*0.8, 0], ...)` for `sy = [-1, 1]`
— same bug, same direction (outward) on both the front and back walls.

### Fix (applied 2026-06-10)

Flipped the sign of the bulge so the recess cuts **into** the wall (toward the box
interior), matching the direction the lid's diamond bump protrudes (`RenderBox.scad`
~277-282 for Flip_Single, ~376-381 for Flip_Double — middle hull element changed from
`-0.8`/`sy*0.8` to `0.8`/`-sy*0.8`).

Verified: `mastertray.py build --intent Container --lid "Flip (Single|Double)"` and
`--intent "Container Lid"` for both, all with `--hardwarnings`, render clean. **Still
needs a physical reprint to confirm** the resulting pocket depth (~0.8mm into a wall of
thickness `sw`) gives a real retention lip without breaking through to the box interior
on thin-wall configs, and to check whether Flip_Double's "reopens under light force"
issue is improved.

---

## B6 — Flip_Single hinge sits low/skewed; hinge open angle limited to ~80-90°

**Status:** Partial fix applied (2026-06-10) — see "Update 2026-06-10 (3)" below for the
  back-wall-collision root cause, which is the part addressed. The earlier
  spine-height/skew framing (Updates 1-2) is **not** separately fixed — re-evaluate
  after reprint, since it may turn out to be the same "not fully seated due to B5"
  story as Flip_Double was.
**Severity:** High — narrow open angle puts the hinge neck at risk of snapping under
normal use; Single flip lid sits skewed when closed
**Reported:** 2026-06-09 (same photo set as B5)
**Update 2026-06-10:** Double flip's skew is **gone once properly/fully closed** — that
was a seating artifact, not a geometry defect. The skew symptom below is now isolated
to **Single flip only**, where it's still tangled up with B5 (no clasp gap means the
lid can't seat fully either). Re-check Single flip's skew once B5 is fixed for
Single — it may turn out to be the same "not fully seated" story as Double.
**Update 2026-06-10 (2):** On the printed Flip_Double half-lid, the hinge geometry
itself **physically stops rotation at ~90°** ("perfect accident" per user) — the lid
body hits the hinge pillar/boss and can't over-rotate. So the ~80-90° figure may
already be a built-in hard stop rather than just "as far as it gets before stalling."
That reframes the breakage-line concern: it's likely not about the lid being forced
*past* 90° (the geometry won't allow that), but about whether the hinge neck
cross-section can survive repeated cycling **up to** that hard stop without fatiguing/
cracking at the stop point. Worth checking whether the crack line photographed
coincides with the stop-contact point.

### Symptoms (from photos)

- **Single flip**: the hinge/spine area sits lower than the Double-flip version and the
  lid sits **skewed** (not flat) when placed on the box. With B5 unfixed there's also
  no clasp gap, so it's unclear how much of the skew is from B5 vs. an independent
  hinge-height issue — "not sure if raising the spine would give the gap or if the gap
  just needs to be added in" (user's own framing).
- **Double flip**, side view of the open hinge: the C-clip arc does not wrap "all the
  way around" the axle pin. At a ~80-90° open angle the hinge arms are already visibly
  stressed near their thinnest cross-section, with a visible crack/breakage line
  starting. User's assessment: if the lid could open closer to ~180° the load on the
  hinge neck at any given position would be lower; at the current geometry, normal use
  (opening past ~90°) risks snapping the hinge.

### Notes for investigation

- The C-clip geometry (`hinge_d`, `clip_outer_d`, `clip_gap`, `clip_z` in
  `RenderLid.scad` ~134-181, mirrored in `RenderBox.scad` ~205-269) determines both the
  axle position and how far the arc extends — this likely also bounds the rotation
  range before the lid body or hinge pillars collide with the box.
- `axle_z = h - cc_z` (`RenderBox.scad` ~215/298) ties hinge height to box height `h`
  and `cc_z = clip_od/2` — worth checking whether `cc_z` (hence `clip_od`, hence
  `hinge_d`/`clearance`/`clip_wall`) needs to differ between Single and Double to avoid
  the height/skew difference observed.
- Likely needs a kinematic check (lid body sweep vs. box hinge pillar/chassis profile)
  to find the actual achievable open angle, then either reshape the hinge pillar to
  allow a wider sweep or thicken the hinge neck cross-section so it survives the
  current ~80-90° range.

**Update 2026-06-10 (3):** On the Single flip print, the **box's back wall** is what
the C-clip's connecting block (`RenderLid.scad` ~170-172,
`cuboid([clip_len, hinge_y_off+2.0, (clip_z-sl)+2.0], ...)`) hits during rotation —
that collision is what's stopping/distorting the cylinder, and the visible deformation
("rough ugly looking rectangular part," "back of the hinge is quite deformed... isn't
quite a perfect cylinder") is that connecting block printing fused/squashed against
the back wall instead of clearing it.

Two changes suggested by the user:
1. **Lower the back wall** in the hinge area (or just in front of it) so it doesn't
   reach up to where the C-clip assembly sits — i.e. reduce `grid_wall_h`/back-wall
   height locally near the hinge, not the C-clip geometry itself.
2. **Be generous with clearance** between the C-clip cylinder/connecting block and the
   back wall (`l/2`) — currently the hinge sits at `l/2 - hinge_y` (`RenderBox.scad`
   ~242/268) with `hinge_y = clip_od/2`, i.e. the assembly is tangent-ish to the back
   wall by construction. Needs an explicit extra margin so the connecting block has
   room to clear the wall through the full rotation.

This is likely the dominant cause of B6 for Single flip — separate from (and probably
more impactful than) the spine-height/skew framing above.

### Fix (applied 2026-06-10) — option 2

Enlarged the hinge bore relief cylinder cut into the box (`RenderBox.scad` ~239-247,
the `cyl(d=clip_od + clearance*4, ...)` cut against `core_tray_chassis`) by an extra
`+3.0mm` diameter (`clip_od + clearance*4 + 3.0`). This gives the rotating C-clip
connecting block ~1.5mm of extra radial clearance against the back wall through the
sweep, without touching the back-wall height (option 1, not attempted — would require
locating/trimming `core_tray_chassis`'s wall geometry specifically in the hinge region,
a larger change).

Verified: Flip_Single box+lid and standalone lid render clean with `--hardwarnings`.
**Needs reprint** to confirm the extra clearance is enough to stop the connecting block
from scraping/deforming against the back wall during rotation, and to re-check the
skew/seating symptoms from Updates 1-2 now that B5 + B9 are also fixed.

**Update 2026-06-10 (4) — flat +3.0mm margin insufficient at larger nozzles:** At
`Nozzle_Diameter=0.6` (`clip_wall = noz*4` grows, so `clip_od`/`cc_z` grow too while the
flat `+3.0mm` bore margin stays fixed), the bore's circular cross-section fell ~0.1mm
short of breaching the back wall's outer face right at the box-top edge — a thin uncut
sliver of wall remained, blocking the C-clip cylinder from passing through ("thin line
on top there ... the cylinder won't go through", user report on a v10 print at
Nozzle 0.6). The Flip_Double bore cutters (`RenderBox.scad` ~340/344/346,
`cyl(d=clip_od + clearance*4, ...)`) had no extra margin at all — same/worse issue.

Fixed by scaling the bore diameter with `clip_od` instead of adding a flat constant:
`d=clip_od*1.5 + clearance*4` (both Single ~248 and Double ~340/344/346). This keeps a
~0.5–0.9mm breach margin at the box-top edge regardless of nozzle diameter.

Verified: Flip_Single and Flip_Double boxes (60x80x30, Nozzle 0.6, Teardrop mesh
3mm/1.2mm) render manifold with `--hardwarnings` (Genus 515 / 532 respectively).
**Needs reprint** to confirm the back wall is now fully cleared at the hinge.

**Update 2026-06-10 (5) — top-of-wall mesh/solid-band coplanar NM edges (real cause
of "8/15 manifold errors"):** The slicer's manifold-error count (15 on the single box,
8 on the double box) was a **separate issue**, unrelated to the hinge bore — same
root-cause family as commit 6b24215's floor/wall fix, but at the top of each wall
instead of the bottom. `render_wall_face` (`RenderTray.scad` ~31-43) splits each wall
into a lower meshed band (`h_mesh = face_h - top_margin`) and an upper solid band
(`top_margin`, kept hole-free for the lid mechanism). The two bands met at an exact
coplanar seam (Z = 27.2mm for this 60x80x30 box) — the Teardrop hole pattern's border
vertices along that seam didn't align with the solid band's flat bottom face, producing
4-face-sharing NM edges along the entire top-of-wall seam on all four walls (35 edges
on the double box, all at Z=27.2).

Fixed by extending the meshed band by `EPS` into the solid band (same overlap pattern
as the floor/wall fix): `h_mesh+EPS` height, bottom edge unchanged. Verified with
pymeshlab on both Flip_Single and Flip_Double boxes (60x80x30, Nozzle 0.6, Teardrop
3mm/1.2mm): 0 non-manifold edges (was 35 on the double box pre-fix).

---

## B7 — Flip lid hinge/latch span scales to full wall width on large boxes

**Status:** Deferred (2026-06-10) — out of scope for the B5-B9 fix pass. Capping
  `clip_len`/arm width and re-centring requires repositioning the hinge pillars and
  axle pins independently of the span calculation in both `RenderLid.scad` and
  `RenderBox.scad`, and interacts with B6's hinge geometry — needs its own design pass
  rather than a quick edit alongside B5/B6/B8/B9. No fix proposed yet.
**Severity:** Medium — cosmetic/structural on large parts; not a print failure
**Reported:** 2026-06-09 (same session as B5/B6, user observation)

### Symptoms

The C-clip hinge (`clip_len = w - sw*6`) and the diamond latch arm
(`lid_w - sw*4`, `w - sw*4`) are sized as "box width minus a fixed margin" — so as `w`
grows, the hinge/latch span grows with it and approaches the full width of the wall on
large boxes. A single hinge/latch spanning an entire long edge is unnecessary (and
looks/feels wrong) — for big boxes we probably want the hinge and latch to stay a
modest, fixed-ish width (or scale much more slowly) rather than occupying the whole
side.

### Notes for investigation

- Affects `RenderLid.scad` (`clip_len`, arm width `lid_w - sw*4`) and the matching
  `RenderBox.scad` hinge-pillar/latch-recess widths (`clip_len`, `w - sw*4`) — both
  sides must stay in sync.
- Likely fix shape: cap the span at some max width (e.g. a fixed mm value or a
  fraction of `w` with a ceiling), and centre the hinge/latch within the wall rather
  than running edge-to-edge. Needs a decision on what "modest width" should be
  (probably informed by the hinge/latch's own mechanical requirements, not box size).
- Should be considered together with B6 (hinge geometry/open-angle) since both touch
  the same hinge dimensions.

---

## B8 — Flip_Double centre spine gap (ROOM_SPINE) is overcompensated, leaves a visible gap when closed

**Status:** Fixed (2026-06-10) — `ROOM_SPINE_PLA`/`ROOM_SPINE_PETG` reduced from `4.00`
  to `1.00` (`MasterTolerance.scad` ~31). Reasoning: each half-lid's hinge already
  hard-stops against its own wall at ~90° (per B6 Update 2), so the two C-clips never
  approach closely enough during normal opening to need the full `clip_od/2` collision
  margin. Flip_Double box+lid renders clean with `--hardwarnings`. **Needs reprint** to
  confirm (a) the visible centre gap is now reasonable and (b) the two C-clips don't
  bind when both half-lids are opened simultaneously — if they do, increase back toward
  an intermediate value (e.g. 2.0-2.5mm) rather than back to 4.00.
**Severity:** Medium — cosmetic gap between the two half-lids when both are closed
**Reported:** 2026-06-09 (photo: printed Flip_Double spine, two hinge bosses with a
wide open slot between them)

### Symptoms

`ROOM_SPINE_PLA = 4.00` (and `ROOM_SPINE_PETG = 4.00`) sizes the gap between the two
Flip_Double C-clip hinges at the box centre (`hinge_y = clip_od/2 + spine_gap`,
`spine_w = hinge_y*2 + hinge_d + EPS*2` — `MasterTolerance.scad` ~31,
`RenderBox.scad` ~291/297). The comment justifying `4.00` says it must be
`≥ clip_od/2 ≈ 3.85mm` so each C-clip can sweep a full 90° without colliding with the
other hinge during simultaneous opening.

In practice this clearance is **too generous** — it leaves a visible open slot down
the centre of the box between the two half-lids when both are closed (see photo). The
two hinges clearly don't need the full `clip_od/2` of clearance from each other to
each independently sweep 90°; the current value over-compensates for the collision
case.

**Update 2026-06-10:** Second photo (single half-lid seated, second half failed to
print) confirms the gap is large in absolute terms — the open spine slot looks to be
roughly **1/3 of the total opening width**. That's a substantial fraction, not a minor
cosmetic sliver — reinforces that `ROOM_SPINE_*` (4.00mm) needs a real reduction, not
just a tweak.

### Notes for investigation

- `ROOM_SPINE_*` (`MasterTolerance.scad` ~31) is the single tuning knob —
  `spine_gap = breathing_room(COMP_SPINE, data)`.
- Needs the same kind of geometric sweep check as B6 (does each C-clip's 90° rotation
  arc actually reach into the other hinge's footprint at a smaller `spine_gap`?) —
  likely the real required clearance is much less than `clip_od/2`, and B6's hinge
  rotation/skew investigation may inform what the *true* minimum is.
- Should be tuned together with B6/B7 since all three involve the same hinge
  geometry constants (`clip_od`, `hinge_y`, `cc_z`).

---

## B9 — Flip lid C-clip hinge is barely fused to the lid body (no gusset, near-zero contact area)

**Status:** Fixed (2026-06-10) — gusset applied
**Severity:** High — hinge is the highest-stress feature on a flip lid; a thin seam
  there is the likely site of the breakage line seen on the printed Single flip
**Reported:** 2026-06-10 (user: "the hinge and the lid aren't an integrated solid
part," visible breakage line on printed Single flip)
**Update 2026-06-10:** This and B6's back-wall collision are **two symptoms of the
same culprit**: the rectangular connecting block (`RenderLid.scad` ~170-172,
`cuboid([clip_len, hinge_y_off+2.0, (clip_z-sl)+2.0], ...)`). As printed, that slab
sits hard up against both the lid body (this bug — near-zero fused area) *and* the
box's back wall (B6 — physically blocks rotation). User's framing: "unless you are
generous in clearance space, that rectangular slab will stop the cylinder" — i.e. the
slab needs room on **both** sides: pulled back from the back wall (B6) and properly
gusseted into the lid body (this bug). Any geometry change to this block should solve
both at once — don't treat them as two independent edits to the same cuboid.

### Root cause

`RenderLid.scad` ~159 attaches the entire C-clip hinge assembly to the lid body with:

```scad
translate([0, lid_l/2 + hinge_y_off + EPS, clip_z])
    difference() { ... }
```

The `+EPS` offset is there *specifically* to break a tangent contact between the C-clip
cylinder and the lid body's flat `+Y` face (comment ~155-158: "Tangent contact ...
can produce degenerate edges in CGAL"). That fixes the render, but the structural
result is that the hinge — the single most load-bearing feature of the whole lid — is
joined to the lid body across essentially **a line, not a face**. Every open/close
cycle puts bending load through that seam.

This is the same class of problem B4 (glide ball) and the latch arm's "root gusset"
(~192-198, hull-based fillet) were fixed for — a round/offset feature needs an explicit
solid fillet connecting it to its host body, or it either floats (B4) or is barely
attached (this case).

### Fix (applied 2026-06-10, revised twice same day)

**Final approach:** instead of adding a separate gusset shape, extend the *existing*
connecting-block cuboid's overlap into the lid body (`RenderLid.scad` ~170-176). The
cuboid is defined in the C-clip assembly's local coordinate frame; growing its `-Y`/`-Z`
bounds (toward the lid interior — the `+Y`/`+Z` side facing the back wall, relevant to
B6, is untouched) via `ext_y = 3.0, ext_z = 2.0` turns the previous ~1mm x 1mm tangent-
line overlap into a ~4mm x 3mm buried anchor — a real load-bearing joint, with no new
disconnected geometry.

**Revision history:**
1. First attempt added a separate hull-based gusset confined to the top ~1.5mm of the
   lid. This *rendered* clean with `--hardwarnings`, but a connected-component check on
   the STL (`build/sandbox/count_components.py`) found extra 12-vertex islands —
   floating fragments disconnected from both the lid and the hinge. These showed up in
   the slicer as "extraneous cylinders" floating above each part. Root cause: the
   gusset's coordinates were written as if global, but the code sits inside
   `translate([0, lid_l/2 + hinge_y_off + EPS, clip_z])`, so the shape was offset by
   that translation into empty space.
2. An earlier full-lid-height version of that same (mispositioned) gusset was also the
   "hinge is too wide" complaint — moot now since the whole separate-gusset approach
   was replaced.
3. The `ext_y=3.0, ext_z=2.0` connecting-block extension (v3) fixed the fusion/floating-
   fragment issues but made the hinge bar visibly bulkier than the pre-B9 version —
   user reported "still too wide" from a new screenshot. A first attempt shrank
   `ext_y`/`ext_z` directly (v4), but the user pointed out the actual culprit is the
   hinge's *length* (`clip_len`, previously a hardcoded `w - sw*6` ≈ full part width)
   rather than the connecting-block's depth — and asked for a tunable percentage +
   floor instead of another one-off shrink.
4. **v5 (final):** kept `ext_y=3.0, ext_z=2.0` (the load-bearing joint from v3) and
   instead replaced `clip_len = w - sw*6` with `flip_hinge_len(part_w, sw)`
   (`MasterEngine.scad`), defined as
   `min(part_w - sw*6, max(part_w * HINGE_WIDTH_PERCENT0, MIN_HINGE_WIDTH0))` with
   `HINGE_WIDTH_PERCENT0 = 0.6` and `MIN_HINGE_WIDTH0 = 16`. For the 60mm-wide test
   part this shrinks the hinge from ~45.6mm to 36mm (60% of width), while small parts
   are floored at 16mm so the hinge stays structurally viable. Used by both
   `RenderLid.scad` (lid-side C-clip) and `RenderBox.scad` (box-side bore/pillars), so
   the two halves stay matched.

5. **v6:** user reported the printed Flip (Double) lid had an "open cantilever" — one
   half's diamond latch arm pointed into the empty centre-spine gap instead of at its
   outer wall. Root cause: `MasterManifest.scad` emitted both half-lids identically,
   but each half's hinge sits at the spine and its latch at the *opposite* outer wall —
   the second half needs a 180° Z rotation to swap which end is which. Fixed via a new
   `ROTATE_180` option on the second half-lid (`MasterManifest.scad` ~327), applied in
   `MasterBuilder.scad`'s `build_part` dispatcher.
6. **v7:** a slicer layer-1 screenshot of v6 showed a disconnected rectangular bump +
   open-air gap at the hinge. Root cause: the v3 connecting block's bottom face was
   placed at `local Z = -(clip_z-sl)/2 - ext_z/2`, which for `ext_z=2.0` and a 2mm-thick
   lid (`sl=2`) works out to **global Z = -1** — 1mm below the print bed. Fixed by
   anchoring the block's bottom flush to the bed (`local Z = -clip_z` → global `Z=0`,
   `anchor=BOTTOM`) with a fixed-height `clip_z+2.0` reaching 2mm into the C-clip
   cylinder above — gives the maximum possible fused area for any lid thickness `sl`,
   and can never go negative.

Verified (v7): Flip_Single lid (1 component, 353 verts) and Flip_Double lid (2
components, 351 verts each — the two half-lids, correctly mirrored) — no stray
fragments, no sub-bed geometry — and both render clean with `--hardwarnings`.
**Needs reprint** to confirm the hinge bar size, the double-lid latch orientation, and
that layer 1 no longer shows the floating bump/gap.

---

_Add new entries as B10, B11, … in order of discovery._
