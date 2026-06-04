# 3D Print Symptoms — Diagnosis & Mitigation

_Material rows: PLA · PETG · TPU. Slicer steps are Bambu Studio unless noted._

---

## 1. Corner Blobs / Bulging at Direction Changes

| Material | Mitigation | Reason / Cause | Slicer How To |
|----------|-----------|----------------|---------------|
| **PLA** | Lower outer wall speed; enable Pressure Advance | Head decelerates at 90° corner → nozzle pressure builds up → blob deposited before direction change | 1. Filament → Pressure Advance: `0.04–0.08` <br>2. Quality → Outer wall speed: `40–50 mm/s` <br>3. Quality → Enable Arc Fitting (smooth corner paths) <br>4. Quality → Jerk: `8–10 mm/s` <br>5. Advanced → Smooth Speed Transition: ON |
| **PETG** | Same as PLA but PA needs higher tuning; PETG is more viscous | Higher melt viscosity = more pressure lag; blobs larger and stickier | 1. Pressure Advance: `0.06–0.12` <br>2. Outer wall speed: `30–40 mm/s` <br>3. Jerk: `5–8 mm/s` <br>4. Arc Fitting: ON <br>5. Wipe Distance: `1–2 mm` on outer wall |
| **TPU** | Use very low speed; disable PA or set near zero | Highly elastic filament — pressure advance model breaks down; PA overcorrects and starves the corner | 1. Pressure Advance: `0.0` (disable) <br>2. All speeds: `≤ 25 mm/s` <br>3. Jerk: `3–5 mm/s` <br>4. Retraction: OFF or `≤ 0.5 mm` <br>5. Combing: ON (eliminate travel blobs) |

---

## 2. Stringing / Oozing Between Moves

| Material | Mitigation | Reason / Cause | Slicer How To |
|----------|-----------|----------------|---------------|
| **PLA** | Retraction + combing; slight temp reduction | Low-viscosity melt oozes during travel when nozzle pressure isn't bled off | 1. Retraction: `0.4–0.8 mm` (direct drive) / `4–6 mm` (Bowden) <br>2. Retraction speed: `35–45 mm/s` <br>3. Combing: ON (travel over infill only) <br>4. Reduce nozzle temp by `5–10°C` <br>5. Z-Hop: `0.1 mm` on retract |
| **PETG** | Higher retraction; Z-hop essential; don't over-retract (causes jams) | PETG is stringy by nature — high surface tension keeps strands attached; too much retraction pulls melt into cold zone | 1. Retraction: `0.8–1.2 mm` (direct) / `6–8 mm` (Bowden) <br>2. Retraction speed: `25–35 mm/s` (slow — PETG tears) <br>3. Z-Hop: `0.2 mm` <br>4. Combing: ON <br>5. Min travel before retract: `3 mm` (avoid micro-retracts) |
| **TPU** | Minimal or zero retraction; rely entirely on combing | Flexible filament compresses in the Bowden tube — retraction causes inconsistent pressure; stringing is unavoidable without combing | 1. Retraction: `0–0.5 mm` direct drive only <br>2. Retraction speed: `15–20 mm/s` <br>3. Combing: ALWAYS ON <br>4. Wipe distance: `3–5 mm` (longer wipe compensates for no retract) <br>5. Travel speed: `≤ 80 mm/s` (fast travel flings strings) |

---

## 3. Layer Delamination / Splitting

| Material | Mitigation | Reason / Cause | Slicer How To |
|----------|-----------|----------------|---------------|
| **PLA** | Increase nozzle temp; reduce layer height; reduce speed | Insufficient heat transfer time between layers — cold layer surface can't reflow and bond to next deposit | 1. Nozzle temp: raise by `+5°C` incrementally <br>2. Layer height: reduce to `≤ 75%` of nozzle diameter <br>3. Print speed: reduce by `20%` <br>4. Fan speed: reduce to `50%` (more time for layer bonding) <br>5. Wall count: increase by 1 (more perimeter heat mass) |
| **PETG** | Increase temp; reduce fan; PETG needs heat to bond — over-cooling is the #1 cause | PETG has a narrow reflow window; aggressive part cooling locks layers before they can fuse | 1. Nozzle temp: `235–245°C` <br>2. Fan: `≤ 30%` on perimeters (Bambu: set Part Cooling Fan speed) <br>3. First layer fan: OFF <br>4. Print speed: `≤ 60 mm/s` on walls <br>5. Avoid layer height `> 0.28 mm` — reduces overlap |
| **TPU** | Print hotter; reduce speed significantly; layers flex apart under stress | Flexible layers spring back slightly on deposit, reducing contact area; compounded by any under-extrusion | 1. Nozzle temp: `+10°C` above nominal <br>2. Speed: `≤ 25 mm/s` all moves <br>3. Fan: `20–40%` only — full cooling prevents bonding <br>4. Flow rate: `+3–5%` (compensate for flex-back) <br>5. Line width: `+10%` of nozzle (wider bead = more overlap) |

---

## 4. Warping / Bed Adhesion Failure

| Material | Mitigation | Reason / Cause | Slicer How To |
|----------|-----------|----------------|---------------|
| **PLA** | PEI sheet; brim on large flat parts; no drafts | Differential cooling: top layers cool and contract faster than bed-adhered base → edges lift | 1. Bed temp: `55–65°C` <br>2. First layer speed: `≤ 20 mm/s` <br>3. Brim: `4–8 mm` on parts `> 80 mm` footprint <br>4. First layer flow: `+5%` <br>5. Enclosure: ON if available (eliminates drafts) |
| **PETG** | Higher bed temp; avoid glass (too sticky — tears off layer); let part cool before removing | PETG contracts significantly on cooling; large parts warp even with good first-layer adhesion if ambient is cold | 1. Bed temp: `80–90°C` <br>2. Brim: `6–10 mm` for parts `> 60 mm` footprint <br>3. First layer height: `0.3 mm` (more squish) <br>4. Enclosure: ON — PETG is sensitive to drafts <br>5. Avoid fan for first `3 layers` |
| **TPU** | Usually fine — flexible material conforms to bed; risk is the opposite (won't release) | TPU has very low shrinkage; warping is rare. Over-adhesion to PEI is the real risk — can tear the print | 1. Bed temp: `35–45°C` (lower than normal — reduces adhesion) <br>2. Apply glue stick to PEI as release agent <br>3. First layer speed: `≤ 15 mm/s` <br>4. Brim: usually not needed <br>5. Let bed fully cool to room temp before removing |

---

## 5. Elephant Foot (First Layer Squish-Out)

| Material | Mitigation | Reason / Cause | Slicer How To |
|----------|-----------|----------------|---------------|
| **PLA** | Live Z adjust; reduce first layer flow | Nozzle too close to bed → excess plastic has nowhere to go → squishes outward → base wider than model | 1. Live adjust Z: raise by `+0.02–0.05 mm` incrementally <br>2. First layer flow: `95–98%` <br>3. First layer speed: reduce to `≤ 20 mm/s` <br>4. First layer height: `0.2 mm` (don't over-squish) <br>5. Elephant foot compensation: `0.1–0.2 mm` in Bambu Advanced |
| **PETG** | More severe — PETG flows more under pressure; needs conservative Z offset | High melt flow index means PETG spreads further when over-squished; first layer accuracy directly affects snap/fit geometry | 1. Live adjust Z: raise `+0.05–0.1 mm` vs PLA baseline <br>2. First layer flow: `90–95%` <br>3. Elephant foot compensation: `0.15–0.25 mm` <br>4. First layer speed: `≤ 15 mm/s` <br>5. Verify with a calibration square before functional prints |
| **TPU** | Very prone — flexible filament deforms under nozzle pressure | Soft material compresses both vertically and laterally; Z offset must be generous or base geometry is completely wrong | 1. Live adjust Z: `+0.1–0.15 mm` (most generous of all materials) <br>2. First layer flow: `90%` <br>3. First layer speed: `≤ 10 mm/s` <br>4. Elephant foot compensation: `0.2–0.3 mm` <br>5. Print a single-layer calibration square first — TPU is unforgiving |

---

## 6. Bridging Sag / Collapse

| Material | Mitigation | Reason / Cause | Slicer How To |
|----------|-----------|----------------|---------------|
| **PLA** | Full fan; reduce bridge speed; limit bridge length to `< 60 mm` | Bridge filament must solidify before gravity deflects it; fan quenches the bead mid-air before it droops | 1. Fan: `100%` during bridges <br>2. Bridge speed: `25–40 mm/s` <br>3. Bridge flow: `85–95%` (less pressure → less sag) <br>4. Bridge angle: slicer auto-detects best direction — verify it's correct <br>5. Design: add a chamfer or 45° approach to avoid bridges `> 50 mm` |
| **PETG** | Moderate fan only — full fan causes delamination on next layer; keep bridges `< 40 mm` | PETG needs heat to bond layers, but bridges need cold to set — competing requirements; PETG bridges are inherently weaker | 1. Fan: `40–60%` during bridge only (Bambu: overhang fan speed) <br>2. Bridge speed: `20–30 mm/s` <br>3. Bridge flow: `80–90%` <br>4. Nozzle temp: reduce by `5°C` for bridge moves only (Bambu: custom G-code) <br>5. Design: 45° chamfer on all surfaces `> 30 mm` span — avoids the problem entirely |
| **TPU** | Cannot bridge reliably — design around it | Flexible filament sags before it can solidify; surface tension is insufficient to hold a span; TPU bridges always fail beyond `10–15 mm` | 1. Fan: `80–100%` (as much as possible without delamination) <br>2. Bridge speed: `≤ 15 mm/s` <br>3. Bridge flow: `75–85%` <br>4. Use support for any span `> 15 mm` — no exceptions <br>5. Redesign: use 45° chamfers universally; TPU is not bridgeable |

---

## 7. Under-Extrusion / Gaps in Walls

| Material | Mitigation | Reason / Cause | Slicer How To |
|----------|-----------|----------------|---------------|
| **PLA** | Check for partial clog; calibrate flow; verify extrusion multiplier | Partial blockage, worn PTFE, temp too low for speed, or incorrect flow multiplier — slicer asks for more than the extruder delivers | 1. Run flow calibration (Bambu: Calibration → Flow Rate) <br>2. Temp: raise `+5°C` <br>3. Max volumetric speed: reduce to `12–15 mm³/s` <br>4. Outer wall speed: `≤ 50 mm/s` <br>5. Cold pull to clear partial clog before any other fix |
| **PETG** | Reduce speed more aggressively; PETG needs time to melt fully | PETG has high viscosity — the melt pool can't replenish fast enough at high speeds, causing starvation | 1. Max volumetric speed: `8–11 mm³/s` (lower than PLA) <br>2. Nozzle temp: `235–245°C` <br>3. Outer wall speed: `≤ 40 mm/s` <br>4. Flow calibration: PETG often needs `+3–5%` flow multiplier <br>5. Check for PTFE degradation if printing `> 240°C` regularly |
| **TPU** | Use direct drive; reduce speed dramatically; increase flow | Flexible filament buckles in Bowden path; extruder grinds the soft filament instead of pushing it | 1. Speed: `≤ 25 mm/s` all moves — no exceptions <br>2. Flow: `+5–10%` multiplier <br>3. Temp: upper end of range `+5–10°C` <br>4. Disable retraction or set `≤ 0.5 mm` (prevents buckling) <br>5. Direct drive extruder required — Bowden cannot reliably feed TPU |

---

## 8. Ghosting / Ringing (Vibration Ripples After Corners)

| Material | Mitigation | Reason / Cause | Slicer How To |
|----------|-----------|----------------|---------------|
| **PLA** | Enable input shaping; reduce acceleration; check for frame wobble | Print head direction change creates mechanical resonance → frame oscillates → ripple pattern appears in wall surface at fixed frequency from the corner | 1. Bambu: Calibration → Resonance Compensation (auto) <br>2. Acceleration: `≤ 3000 mm/s²` outer wall <br>3. Jerk: `7–10 mm/s` <br>4. Check belt tension (loose belt amplifies ringing) <br>5. Outer wall speed: `≤ 60 mm/s` |
| **PETG** | Less prone than PLA — higher mass dampens resonance; still calibrate | PETG's heavier melt mass slightly damps oscillation; ghosting still occurs at high acceleration but amplitude is lower | 1. Resonance compensation: calibrate separately from PLA profile <br>2. Acceleration: `≤ 2500 mm/s²` outer wall <br>3. Jerk: `5–8 mm/s` <br>4. Outer wall speed: `≤ 50 mm/s` <br>5. If ghosting persists: check all eccentric nuts and linear rails |
| **TPU** | Not a concern — flexible material absorbs all vibration | TPU's elasticity dissipates mechanical energy before it propagates to the wall surface; ghosting is physically impossible in soft materials | 1. No specific slicer tuning needed for ghosting <br>2. Focus instead on speed (≤ 25 mm/s) and pressure advance (off) <br>3. Acceleration can be low by default from speed limits <br>4. — <br>5. — |

---

## 9. Poor Overhang Quality / Drooping

| Material | Mitigation | Reason / Cause | Slicer How To |
|----------|-----------|----------------|---------------|
| **PLA** | Fan 100%; reduce overhang speed; keep overhangs `≤ 55°` from vertical | Overhang filament has no support below — must solidify by air cooling before gravity deflects it; beyond 55° material sags | 1. Fan: `100%` on overhang perimeters <br>2. Overhang speed threshold: `25–30°` from horizontal → reduce speed <br>3. Overhang speed: `20–30 mm/s` <br>4. Enable Overhang Fan Boost (Bambu Advanced) <br>5. Design: chamfer all edges — 45° is self-supporting by definition |
| **PETG** | Reduced fan (delamination risk); overhangs `≤ 45°` only; chamfer aggressively | PETG needs cooling for overhangs but cooling degrades inter-layer bonding — the competing constraints mean PETG overhangs are worse than PLA | 1. Fan: `50–70%` on overhang perimeters only <br>2. Overhang speed: `15–25 mm/s` <br>3. Nozzle temp: reduce by `5°C` for overhang moves (reduces droop) <br>4. Design rule: chamfer all faces at 45° — PETG cannot do steep overhangs reliably <br>5. Max reliable overhang: `45°` — anything steeper needs support |
| **TPU** | Support for anything over `30°`; design specifically for TPU | Soft material droops under its own weight — surface tension is insufficient; any overhang over 30° requires support or redesign | 1. Fan: `60–80%` <br>2. Speed: `≤ 20 mm/s` on overhangs <br>3. Support threshold: `30°` (vs 45° for rigid materials) <br>4. Support Z distance: `0.15–0.2 mm` (TPU support is hard to remove — keep distance generous) <br>5. Design around it: TPU functional parts should have no overhangs |

---

## 10. Dimensional Inaccuracy (Prints Too Tight / Too Loose for Snap Fits)

| Material | Mitigation | Reason / Cause | Slicer How To |
|----------|-----------|----------------|---------------|
| **PLA** | XY hole compensation; calibrate flow; tune PA | Thermal expansion, first-layer squish, and extrusion width errors accumulate — holes print undersized, outer dims print oversized | 1. Bambu: Calibration → Flow Rate (correct volumetric accuracy) <br>2. Advanced → XY Hole Compensation: `+0.1–0.2 mm` (makes holes larger) <br>3. Advanced → XY Contour Compensation: `-0.05–0.1 mm` (shrinks outer walls) <br>4. Pressure Advance: calibrate accurately (PA errors directly affect line width) <br>5. Print a calibration cube + test fit before committing to functional prints |
| **PETG** | Same calibration but PETG shrinks more on cooling — add more clearance to fit geometry | PETG's higher thermal expansion means printed parts are slightly smaller than the model after cooling — snap fits that work in PLA may be too tight in PETG | 1. XY Hole Compensation: `+0.15–0.25 mm` <br>2. XY Contour Compensation: `-0.1–0.15 mm` <br>3. Flow calibration: PETG often runs `+3–5%` actual vs set <br>4. For snap fits: add `0.1–0.2 mm` extra clearance vs PLA models <br>5. Fit profile in MasterTray Customizer: use **Loose** for first PETG print, then tighten |
| **TPU** | Dimensions are meaningless without Shore hardness consideration — soft parts compress under measurement | TPU deforms under caliper pressure — a 2mm wall measures as 1.8mm. Fit tolerances must be wider. Over-extrusion also hides in soft material | 1. Flow: calibrate with a 0.4mm single-wall vase — measure wall thickness <br>2. XY Hole Compensation: `+0.3–0.5 mm` (TPU compresses into holes) <br>3. Fit profile: always use **Looser** in MasterTray — TPU fills gaps under load <br>4. Wall width: `+15%` line width (soft material needs more overlap to hit true dimension) <br>5. Measure parts under no load — caliper pressure causes false readings |

---

_Last updated: 2026-06-04_
