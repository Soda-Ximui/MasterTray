# Print Parameter Effects — MasterTray System Reference

How the four Customizer printer parameters drive geometry throughout the system.
All formulas are live — changing a parameter in the Customizer recalculates everything
downstream automatically. No manual tuning required.

---

## 1 — Nozzle Diameter (`Nozzle_Diameter`, default 0.4 mm)

The most pervasive parameter. Almost every structural minimum in the system is
expressed as a multiple of the nozzle diameter because the nozzle is the smallest
reliable feature the printer can extrude.

### Global rendering precision
```
$fs = nozzle_d   (max chord length per arc facet)
```
Circles, cylinders, and spheres get exactly as many facets as the nozzle can
resolve — a 10 mm bore at 0.4 mm nozzle gets ~78 facets; the same bore at
0.8 mm nozzle gets ~39. Smaller nozzles produce smoother curves automatically.

### Wall thickness (`sw = m_safe_wall`)
```
sw = round(Wall_Loops × nozzle_d / nozzle_d) × nozzle_d
   = Wall_Loops × nozzle_d   (already a whole multiple)
```
sw is always a whole multiple of nozzle diameter so the slicer fills each wall
pass exactly — no fractional passes, no micro-gap shells.

### Chamfer size (`m_chamf`, default auto)
```
chamf_max = nozzle_d × 2.5
```
All edge chamfers are capped at 2.5 × nozzle. Beyond that, the chamfer face
becomes a bridging span the slicer can't print without support.

### EPS2 (boolean overlap / cutter extension)
```
EPS2 = nozzle_d
```
Every difference() cutter that must bury its face inside a solid (to avoid
coplanar non-manifold edges) extends by exactly one nozzle width. At 0.8 mm
nozzle this doubles to 0.8 mm — still geometrically safe, always one line.

### Lid mechanisms — nozzle-scaled features

| Feature | Formula | 0.4 mm | 0.8 mm |
|---|---|---|---|
| C-clip wall thickness | `noz × 4` | 1.6 mm | 3.2 mm |
| C-clip chamfer | `noz × 3` | 1.2 mm | 2.4 mm |
| Snap bead protrusion | `noz` | 0.4 mm | 0.8 mm |
| Diamond latch Y-width | `noz × 2` | 0.8 mm | 1.6 mm |
| Diamond tip flat-top | `noz × 1.05` | 0.42 mm | 0.84 mm |
| Glide pull-tab depth | `noz × 4` | 1.6 mm | 3.2 mm |
| Glide thumb-notch depth | `noz × 4` | 1.6 mm | 3.2 mm |
| Glide ball minimum diameter | `noz × 5` | 2.0 mm | 4.0 mm |
| Ball socket boss thickness | `ball_d + noz × 4` | 3.6 mm | 5.2 mm |
| Ball socket boss diameter | `ball_d × 2 + noz × 4` | 5.6 mm | 9.2 mm |
| Groove height minimum | `ball_d + glide_tol + noz × 4` | varies | varies |
| Screw lid top chamfer | `noz × 4` | 1.6 mm | 3.2 mm |

### Grid strut width
```
strut = max(noz, round(max(noz×2, hole×0.25) / noz) × noz)
```
Struts snap to the nearest whole nozzle-width multiple. At 0.4 mm nozzle the
minimum strut is 0.8 mm (2 passes). At 0.8 mm nozzle it's 1.6 mm (2 passes).

---

## 2 — Layer Height (`Layer_Height`, default 0.20 mm)

Layer height drives anything that must align to a print layer boundary to
avoid micro-stepping artifacts or weak layer adhesion.

### Safe floor and lid thickness (`m_safe_floor`, `m_safe_lid`)
Both are snapped to the nearest layer-height multiple:
```
sf = round(raw_floor / lh) × lh
sl = round(raw_lid   / lh) × lh   (min 3 layers)
```
This ensures the floor and lid top face land exactly on a layer boundary —
the slicer never has to split a layer to hit a fractional height.

### Snap bead height
```
bead_h = lh × max(3, ceil(noz×2 / lh))
```
The bead is always a whole number of layers tall (minimum 3). At 0.28 mm lh
and 0.4 mm nozzle: `ceil(0.8 / 0.28) = 3 layers → 0.84 mm`. At 0.20 mm lh:
`ceil(0.8 / 0.20) = 4 layers → 0.80 mm`. Clean layer boundaries = reliable
click force (no fractional-layer pressure variation).

### Diamond latch Z-extent (`layer_snap`)
```
lz = round(0.8 / lh) × lh
```
The diamond tip height is snapped to the nearest layer boundary so the slicer
generates the same extrusion count on every print, regardless of layer height.

### Groove Z origin (Glide External)
```
groove_z = h - sl - lh × ceil(1.0 / lh)
```
The 1 mm drop from box top to groove floor is rounded up to the nearest full
layer. At 0.28 mm lh: 4 layers = 1.12 mm. Groove always sits on a clean
layer boundary — prevents the thin layer-fraction artifacts that cause groove
walls to delaminate under lid insertion force.

---

## 3 — Wall Loops (`Wall_Loops`, default 3)

Wall loops directly set the structural wall thickness via `sw`:

```
sw = Wall_Loops × Nozzle_Diameter
```

Wall loops flow into every dimension that uses `sw` as a structural unit:

| Dimension | Formula | 3-loop / 0.4 mm | 4-loop / 0.4 mm |
|---|---|---|---|
| Wall thickness | `sw` | 1.2 mm | 1.6 mm |
| Safe lid thickness (raw) | `sw × 1.5 − margin` | ~1.3 mm | ~1.9 mm |
| C-clip length clearance | `w − sw×6` | w − 7.2 mm | w − 9.6 mm |
| Hinge pillar width | `sw × 3` | 3.6 mm | 4.8 mm |
| Latch arm width | `w − sw×4` | w − 4.8 mm | w − 6.4 mm |
| Diamond latch X-width | `w − sw×4` | w − 4.8 mm | w − 6.4 mm |
| Snap groove ring | `bead_h×2` | via lh | via lh |
| Glide rabbet depth | `sw / 2` | 0.6 mm | 0.8 mm |
| Glide lid width | `w − sw − tol` (Rabbet) | varies | varies |

**Critical floor:** `Wall_Loops` has a hard minimum for Flip lids:
```
clip_len = w − sw×6   must be > 0
```
If `Wall_Loops` is too high for the box width, the C-clip has no room and
the system asserts with a clear error message. Example: 30 mm wide box at
4-loop / 0.4 mm needs `30 > 9.6 mm` — fine. At 6-loop: `30 > 14.4 mm` — fine.
At 8-loop: `30 > 19.2 mm` — fine. But a 20 mm wide box at 8-loop fails.

---

## 4 — Filament Type (`Filament_Type`, default `"PLA"`)

Filament affects **clearances** (how much gap between mating parts) and
**engagement depths** (how deep a snap clicks). Stiffer materials need wider
gaps and shallower engagements; flexible materials can run tighter.

### Clearance gaps (`breathing_room`)

| Component | PLA | PETG | TPU |
|---|---|---|---|
| C-clip / hinge bore | 0.15 mm | 0.25 mm | 0.10 mm |
| Glide track / snap bead | 0.20 mm | 0.40 mm | 0.60 mm |
| Flip_Double spine gap | 4.00 mm | 4.00 mm | 0.20 mm |

*All values shift ±0.05 mm per Fit_Profile step (Tighter / Standard / Looser).*

### Snap engagement depths (`engagement_depth`)

| Component | PLA | PETG | TPU |
|---|---|---|---|
| Diamond clasp depth | 4.0 mm | 4.6 mm | 5.5 mm |
| C-clip flat belly (no-snap zone) | 0.5 mm | 0.6 mm | 0.4 mm |

*Clasp depth shifts ∓0.20 mm per Fit_Profile step.*

### C-clip gap width (in `RenderLid`)
```
clip_gap = hinge_d × 0.90   (PLA — arms flex less, need wider opening)
clip_gap = hinge_d × 0.80   (PETG / default)
```
PLA is more brittle: each C-clip arm must flex only 0.2 mm to accept the
axle pin (vs 0.4 mm for PETG). The wider gap reduces the required flex,
keeping stress below PLA's elastic limit.

---

## Summary: What changes when you re-slice

| You change | Primary effect | Secondary effects |
|---|---|---|
| Nozzle diameter ↑ | Walls thicker (if loops fixed), circles coarser | Chamfers larger, all noz× features scale up, EPS2 larger |
| Layer height ↑ | Floor/lid thicker (rounded up), bead taller | Diamond lz snaps to coarser grid, groove_z shifts |
| Wall loops ↑ | Walls thicker, latch arm narrower, C-clip shorter | May hit clip_len > 0 assert on narrow boxes |
| Filament PLA→PETG | Gaps wider (parts fit looser raw) | Clasp deeper, C-clip gap narrower (arms flex more) |
| Fit_Profile Tighter | All gaps −0.1 mm, clasp +0.4 mm deeper | Harder close/open, more retention |
| Fit_Profile Looser | All gaps +0.1 mm, clasp −0.4 mm shallower | Easier open, less retention |
