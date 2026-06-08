# Session Handoff — MasterTray
_Last updated: 2026-06-08 — All non-manifold edges resolved; branch clean_

---

## Branch
`refactor/code-clarity-and-safety`

## Recent Commits (newest first)

| Hash | Message |
|------|---------|
| `84828bf` | fix: resolve all non-manifold edges across lid and box STLs |
| `30dfd94` | docs: update HANDOFF.md with post-print-2 status and next session prompt |
| `9cff93c` | fix: glide ball dimples as full circles + flip_single corner gap |
| `4720b25` | fix: revert MIRROR_Y (direction was correct), document snap/flip lessons |
| `16c58cd` | fix: resolve 4 print failures from physical test |

---

## What Was Fixed (This Session — Non-Manifold Cleanup)

All STL exports are now slicer-clean (zero non-manifold edges). Five root causes found and fixed:

### Snap lid retention bead (RenderLid.scad)
- **External:** `bead_z = sl - EPS` placed bead inside `apply_master_bounds` TOP chamfer zone (0.4mm deep). Complex CGAL interaction → 6 edges.
  - Fix: `bead_z = sl - chamf - EPS`; `bead_h_ext = bead_h + chamf + EPS` to keep bead-top position.
- **Rabbet:** `chamfer = bead_h/2` with height `bead_h + EPS` left only `EPS = 0.1mm` flat face → degenerate → 6 edges.
  - Fix: `bead_chamf = (bead_h_ext - m_lh(data)) / 2` — always leaves one full layer height of flat face.

### Flip_Single lid C-opening cutter (RenderLid.scad)
- Cutter top at local z=0 = connection-block top at local z=0 → coplanar in `difference()` → 10 edges (Flip_Single) / 16 (Flip_Double, two half-lids).
- Fix: `clip_outer_d + EPS2` on cutter height → top at local z=EPS.

### Flip_Single lid diamond hull (RenderLid.scad)
- Hull cuboids same X width as latch arm (`lid_w-sw*4`). In overlap zone, ±X faces coplanar → non-manifold.
- Fix: Hull cuboids widened to `lid_w-sw*4+EPS` so latch arm X faces are interior.

### Axle pins coplanar with inner walls (RenderBox.scad)
- `h = w - sw*2` → half-length = `w/2 - sw` = exact inner wall X face position. Chamfered end cap coplanar with inner wall → multiple edges per pin.
- Fix: `h = w - sw*2 + EPS2` for all three pins (Flip_Single 1×, Flip_Double 2×).
- This also resolved the "two other boxes with 6 edges" — they were Flip_Single boxes at different sizes.

### Documentation
- `docs/LESSONS.md` updated with §11c–§11g documenting each non-manifold pattern.
- Confirmed instances table updated.

---

## What Was Fixed (Previous Session — Post Second Print Test)

### Snap lid fell through (RenderLid.scad)
- Bead outer face was flush with lid edge; all-edges chamfer ate it → zero protrusion → no click.
- **Fix:** `snap_protr = noz`. Translate: `sx * (lid_w/2 + clearance/2 + snap_protr - sw/2)`.

### Glide lid wouldn't enter groove (RenderBox.scad)
- `groove_h = sl + tol = 2.4mm` but lid `sl_glide = max(sl, ball_d) = 3.2mm`.
- **Fix:** `groove_h = max(sl_glide + tol, ball_d + tol + noz*4)`.

### C-clip broke on PLA (RenderLid.scad)
- Gap hardcoded `hinge_d * 0.80` regardless of material.
- **Fix:** `clip_gap = (filament=="PLA") ? hinge_d*0.90 : hinge_d*0.80`.

### Flip_Double half-lids too long (MasterManifest.scad)
- All Flip_Double intents used `flip_lid_l` (full-box formula). Lids ~2× too long.
- **Fix:** All Flip_Double intents use `flip_half_lid_l = l/2 - flip_hinge_y`.

### Glide ball dimples were broken arcs (RenderBox.scad)
- Sphere cutter diameter = groove_h → sphere cut to groove edges → arc not circle.
- **Fix:** `groove_h = max(sl_glide + tol, ball_d + tol + noz*4)`.

### Flip_Single hinge corner hollow + inside footprint (RenderBox.scad / RenderLid.scad)
- Pillars started at `l/2 - 0.5`; axle at `l/2 + hinge_y` — both past the footprint boundary.
- **Fix:** Axle moved to `l/2 - hinge_y`; pillars fill `l/2 - clip_od` to `l/2`; `lid_l = l - clip_outer_d`.

### CRITICAL: Flip_Double simultaneous 90° open (MasterTolerance.scad)
- `ROOM_SPINE = 0.5mm` — two C-clips collide immediately on opening.
- **Fix:** `ROOM_SPINE_PETG = ROOM_SPINE_PLA = 4.00mm`.

### Rabbet snap groove_z (RenderBox.scad / RenderLid.scad)
- Groove and bead misaligned — no overlap when lid seated.
- **Fix:** `groove_z = h - bead_h`; Rabbet lid bead at `sl - bead_h`.

---

## Open Issues

### LOW: F6, F14, F15 (cosmetic, deferred)
- F6: RenderLid.scad ~L120 — diamond latch `layer_snap` call
- F14: RenderLid.scad ~L44 — snap bead layer-align
- F15: RenderBox.scad ~L103 — flip-box hinge assert

---

## Architecture Quick Reference

```
MasterBuilder.scad       ← Layer 4: Customizer UI + dispatcher
MasterManifest.scad      ← Layer 3: compile_manifest() + intent logic
  flip_half_lid_l()      ← MUST use for Flip_Double half-lids (not flip_lid_l)
  flip_hinge_y()         ← clip_od/2 + spine_gap
RenderBox.scad           ← Factory: boxes with all lid variants
RenderLid.scad           ← Factory: all lid types
  factory_render_lid(data, opts, phys)
  opts["LID_TYPE"]       ← "Snap" | "Glide" | "Flip_Single" | "Screw" | "Slip"
  data["FILAMENT_TYPE"]  ← "PLA" | "PETG" — affects clip_gap
RenderPlaque.scad        ← Factory: label plaques (Wall/Lid/Lid_Peg)
MasterTolerance.scad     ← breathing_room(), engagement_depth(), COMP_* constants
MasterEngine.scad        ← Pure functions: glide_ball_d(), flip_latch_z(), etc.
MasterEnum.scad          ← All key constants
```

### Key tolerance constants (MasterTolerance.scad)
| Constant | PLA | PETG | Note |
|----------|-----|------|------|
| `COMP_CCLIP` | 0.15mm | 0.25mm | C-clip clearance |
| `COMP_GLIDE` | 0.30mm | 0.40mm | Glide/snap |
| `COMP_SPINE` | 4.00mm | 4.00mm | Arc clearance for 90° C-clip swing |
| `COMP_CLASP` | 4.0mm | 4.6mm | Latch engagement depth |
| `COMP_BELLY` | 0.5mm | 0.8mm | Clip flat zone |

### Flip_Double geometry (PETG, 0.4mm nozzle, current values)
```
hinge_d     = 4.0mm
clip_wall   = noz * 4 = 1.6mm
clip_od     = hinge_d + clearance*2 + clip_wall*2 = 7.7mm
cc_z        = clip_od/2 = 3.85mm
spine_gap   = ROOM_SPINE_PETG = 4.00mm   (≥ clip_od/2 = 3.85mm ✓)
hinge_y     = clip_od/2 + spine_gap = 7.85mm
spine_w     = hinge_y*2 + hinge_d = 19.7mm
flip_half_lid_l(data) = l/2 - hinge_y
```

---

## Suggested New Session Prompt

```
We're continuing MasterTray on branch refactor/code-clarity-and-safety.
Read docs/HANDOFF.md first — it has the full list of what was fixed and
what's still open.

All STLs are currently non-manifold-free. Open items are LOW-priority
cosmetic bugs F6, F14, F15. After any fixes, push branch + open PR.
```
