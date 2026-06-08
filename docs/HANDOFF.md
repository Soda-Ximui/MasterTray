# Session Handoff — MasterTray
_Last updated: 2026-06-08 — Post-print fixes round 2 (9cff93c)_

---

## Branch
`refactor/code-clarity-and-safety`

## Recent Commits (newest first)

| Hash | Message |
|------|---------|
| `9cff93c` | fix: glide ball dimples as full circles + flip_single corner gap |
| `4720b25` | fix: revert MIRROR_Y (direction was correct), document snap/flip lessons |
| `16c58cd` | fix: resolve 4 print failures from physical test |
| `edaa23e` | fix: plaque peg mount — solid patch before hole punch for meshed lids |

---

## What Was Fixed (This Session — Post Second Print Test)

### Snap lid fell through (RenderLid.scad)
- Bead outer face was flush with lid edge; all-edges chamfer ate it → zero protrusion → no click.
- **Fix:** `snap_protr = noz`. Translate: `sx * (lid_w/2 + clearance/2 + snap_protr - sw/2)`. Bead outer face now noz past box interior wall.

### Glide lid wouldn't enter groove (RenderBox.scad)
- `groove_h = sl + tol = 2.4mm` but lid `sl_glide = max(sl, ball_d) = 3.2mm`.
- **Fix:** `groove_h = max(sl_glide + tol, ball_d + tol + noz*4)`.

### C-clip broke on PLA (RenderLid.scad)
- Gap hardcoded `hinge_d * 0.80` regardless of material.
- **Fix:** `clip_gap = (filament=="PLA") ? hinge_d*0.90 : hinge_d*0.80`.

### Flip_Double half-lids too long (MasterManifest.scad)
- All Flip_Double intents used `flip_lid_l` (full-box formula). Lids ~2× too long.
- **Fix:** All Flip_Double intents use `flip_half_lid_l = l/2 - flip_hinge_y`.
- Direction was already correct — MIRROR_Y was wrong and reverted.

### Glide ball dimples were broken arcs (RenderBox.scad)
- Sphere cutter diameter = groove_h → sphere cut to groove edges → arc not circle. Structurally weak.
- **Fix:** `groove_h = max(sl_glide + tol, ball_d + tol + noz*4)`. noz*4 adds 2-nozzle margin above/below sphere so it prints as a full contained circle.

### Flip_Single hinge corner hollow (RenderBox.scad)
- Pillars started at `l/2 - 0.5`; box inner wall is at `l/2 - sw`. 1.9mm hollow corner at the hinge.
- **Fix:** Pillar front face moved to `l/2 - sw`. Depth updated to `hinge_y + sw + 0.5`. Applied to all three pillar types (left corner, right corner, centre grid columns).

---

## Open Issues — Needs Next Print + Fix

### CRITICAL: Flip_Double — both lids can't open 90° simultaneously
- User confirmed physically. Also described as "rough and ugly" at lid-hinge interface.
- **Root cause:** `spine_gap = ROOM_SPINE_PETG = 0.5mm`. When one lid opens, its C-clip sweeps through an arc. The inner face of the C-clip (at `hinge_y - clip_od/2 = spine_gap = 0.5mm` from box center) comes within 1mm of the other lid's C-clip inner face. There is no arc clearance.
- **Fix needed:** Increase `ROOM_SPINE` to `clip_od/2 ≈ 4mm` minimum so each C-clip has a full quarter-turn of clearance before hitting the other. Files: `MasterTolerance.scad` (ROOM_SPINE_PLA, ROOM_SPINE_PETG) and `MasterManifest.scad` (flip_hinge_y formula recheck).
- **Also:** Clean up the structural web connecting C-clip to lid face (the foot/gusset) — currently rough where it meets the lid slab.

### LOW: Rabbet snap geometry fundamentally wrong
- Box groove at `groove_z = h - sl - bead_h`. Lid bead at lid top (Z=sl). When seated flush, bead is at Z=h, groove at h-sl-bead_h to h-sl → no overlap, no click.
- **Fix needed:** Move groove to `groove_z = h - bead_h` (just below box rim). Move lid bead to `Z = sl - bead_h/2` (near lid top, within lid body). Coordinated change in RenderBox + RenderLid snap sections.

### LOW: F6, F14, F15
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
| `COMP_SPINE` | 0.30mm | 0.50mm | **← too small, needs ~4mm** |
| `COMP_CLASP` | 4.0mm | 4.6mm | Latch engagement depth |
| `COMP_BELLY` | 0.5mm | 0.8mm | Clip flat zone |

### Flip_Double geometry (PETG, 0.4mm nozzle, current values)
```
hinge_d     = 4.0mm
clip_wall   = noz * 4 = 1.6mm
clip_od     = hinge_d + clearance*2 + clip_wall*2 = 7.7mm
cc_z        = clip_od/2 = 3.85mm
spine_gap   = ROOM_SPINE_PETG = 0.50mm   ← PROBLEM: needs ≥ clip_od/2 = 3.85mm
hinge_y     = clip_od/2 + spine_gap = 4.35mm
spine_w     = hinge_y*2 + hinge_d = 12.7mm
flip_half_lid_l(data) = l/2 - hinge_y
```

---

## Suggested New Session Prompt

```
We're continuing MasterTray on branch refactor/code-clarity-and-safety.
Read docs/HANDOFF.md first — it has the full list of what was fixed and
what's still open.

Two fixes are needed:

1. CRITICAL — Flip_Double simultaneous 90° open:
   spine_gap = ROOM_SPINE in MasterTolerance.scad is 0.5mm — far too
   small. The C-clip arc radius is clip_od/2 ≈ 3.85mm. Two C-clips
   facing each other 2*spine_gap = 1mm apart will collide during opening.
   ROOM_SPINE_PETG and ROOM_SPINE_PLA need to be increased to at least
   clip_od/2 so each C-clip can swing 90° without hitting the other.
   After updating ROOM_SPINE, verify flip_hinge_y() in MasterManifest.scad
   recalculates spine_w and flip_half_lid_l correctly.
   Also: clean up the visual appearance of where the C-clip foot meets the
   lid slab in RenderLid.scad Flip_Single section.

2. LOW — Rabbet snap groove_z is wrong (see HANDOFF for details).

After fixes, run "Lid Testing" intent to review. Then push branch + open PR.
```
