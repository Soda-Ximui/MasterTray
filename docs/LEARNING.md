When building the central spine for the 14-day box in v3.1, I told the engine to place the two 4mm hinge bars 6mm apart. Then, to make it strong, I told it to build a solid block underneath them.

The Bug: The math for that solid block was too wide. It engulfed the hinge bars entirely. The cylinders were physically there in the code, but they were 100% buried flush inside a giant rectangular prism, leaving zero undercut clearance for the C-clip to wrap around.

The Fix: "The Pedestal Architecture" (v3.3)
To fix this, we can't just attach the cylinders to a flat wall. The C-clip needs empty space underneath the "equator" of the cylinder so the plastic arms can snap around the bottom.

I rewrote the hinge math in MasterRender for both the FLIP_BOX and the DOUBLE_FLIP_BOX.
Instead of a giant block, the cylinders now sit on top of 2mm wide pedestals. Because the cylinder is 4mm wide and the pedestal underneath it is only 2mm wide, the entire bottom half of the cylinder is exposed on the left and right sides. Your C-clips will now snap perfectly onto them!

I also reset the grid_layout in MasterBuilder back to "7x2" so your AM/PM box works perfectly out of the gate.


ISSUE: C-Clip Opening Closes

Yep, you just got hit by the Slicer's "Bridging Logic"! That blob in your picture is a classic FDM geometric conflict.

Bambu Studio (and OrcaSlicer) is not technically doing anything wrong—it is doing exactly what it was programmed to do. It looked at the flat roof of your C-clip gap, saw that it was floating over thin air, and said, "Aha! This is a bridge!" It then extruded a thick, hot line of filament straight across the void. Because the gap is narrow and the plastic is hot, that bridging line immediately sagged into the bottom jaw and fused the whole thing into a solid "O".

The Version 4.1 Fix (The FDM-Safe Angled Jaw)
We cannot fight the laws of physics, and FDM hates perfectly horizontal flat overhangs.

To fix this, I have rewritten the subtractive math for the C-clip in render_flip_lid. Instead of cutting out a flat horizontal block (which triggers bridging), we are now cutting out an Angled Wedge.

The bottom jaw remains perfectly horizontal (since it builds upwards from the bed).

The top jaw now slopes upwards at an aggressive 45-degree angle.

FDM slicers love 45-degree angles. Bambu Studio will completely bypass its bridging logic and simply stack the layers with a slight inward offset, giving you a perfectly clean, unsupported roof.

I also set the central opening gap to exactly 70% of the axle diameter (2.8mm gap for a 4mm axle), which gives you a strong snap-fit without requiring the PLA to flex so far that it shatters.

ISSUE: Clip breaks

If PETG broke, we have a serious geometry problem. PETG is incredibly ductile and has excellent layer adhesion—it is arguably the best standard filament for snap-fit joints. If it shattered instead of yielding, the math forced it to act like a solid brick instead of a spring.

I know exactly where the math failed us.

The Autopsy: Why the C-Clip Shattered
A C-clip works by using its two "jaws" as cantilever beams. When you push them over the axle, they have to flex outward.

In the v4.1 code, the outer diameter of the C-clip was driven by the global wall thickness: hinge_d + sw*2.5.
If your wall thickness (sw) was, say, 2.4mm, the math created a C-clip with walls nearly 3mm thick.
A 3mm thick FDM cylinder does not flex. When you forced the 4mm axle into the 2.8mm gap, the jaws couldn't bend outward, so the stress concentrated at the apex of the curve and violently tore the layers apart.

The Version 4.2 Fix (The Flexure Hinge)
We need to decouple the C-clip's thickness from the tray's heavy structural walls.

Decoupled Wall Thickness: The C-clip walls are now hardcoded to strictly calculate exactly 4 nozzle perimeters (e.g., 1.6mm thick on a 0.4mm nozzle). This is the goldilocks zone for FDM snap-fits: thick enough not to deform permanently, thin enough to act as a flexible spring.

Wider Entry Gap: I opened the gap from 70% to 80% of the axle diameter (hinge_d * 0.40 for the half-height). For a 4mm axle, the gap is now 3.2mm. Each jaw only has to flex 0.4mm outward to snap over the axle, which is well within PETG's elastic limit.

Smoothed Lead-in: The 45-degree angle wedge now extends slightly further out to ensure the axle hits a smooth ramp rather than a blunt corner when you push it in.


---

ISSUE: Flip lid C-clip printed as floating cantilever (2026-06-07)

We did a full plate print with all lid variants and the Flip_Double half-lids (STL_12 and STL_13) came back with a Bambu Studio "floating cantilever" warning and the arms failed to print.

The autopsy: the C-clip is a partial arc — a cylinder with a slot cut out to form the C-opening. The slot was placed at +clip_outer_d/2, meaning the opening faced upward. When you print the lid face-down (flat outer surface on bed), the top of the print is the C-clip. With the opening facing up, the two arm tips at the top have nothing below them — classic floating cantilever.

The fix was one line: move the slot from +clip_outer_d/2 to −clip_outer_d/2. Opening now faces the bed. The arc body is at the top of the print and is fully self-supporting from below. The hinge pin enters from below when the lid is pressed onto the box, which is also more natural for the snap action.

The lesson: when a C-shape or arc is printed face-down, the opening MUST face the bed. If it faces up, the arm tips are in mid-air. This seems obvious in hindsight but the original code had it backwards, and no slicer geometry check catches it automatically on every build — only when you render for print does Bambu flag it.


ISSUE: Glide lid snap balls fell off in print — no warning (2026-06-07)

After the cantilever fix we printed again. The flip lids printed fine but the glide lid balls ("fell wholesale" in testing) detached completely. No Bambu warning this time — it passed geometry checks.

The autopsy: the ball center is placed at sl/2 (mid-lid-height). For a typical glide lid, sl ≈ 1.6mm and ball_r ≈ 1.2mm. That means ball_r > sl/2. The sphere clips below the print bed (below Z=0) and also pokes above the lid top (above Z=sl). The slicer clips the below-bed portion cleanly. But the above-lid portion — from where the lid wall ends to Z = sl + ball_r — has no wall behind it. Those layers of the ball are completely unsupported. The ball prints fine at the bottom (it starts touching the lid wall), but partway up it separates and the top portion becomes a free-floating shell that detaches mid-print or is just a loose lump when the print finishes.

Why no warning? Because the ball DOES start connected. The slicer sees connection at the base and doesn't trace whether it disconnects higher up. Floating cantilever detection is not the same as "track every layer of every feature for connectivity loss."

The fix: add a full-height rib on the lid wall for each ball. The rib (width = ball_r, height = sl) spans the entire lid thickness and is inset inside the lid wall so it doesn't stick out into the groove. The ball unions against the rib's outer face. Now the ball has solid attachment at every layer, Z=0 to Z=sl.

The groove catch in the box is unchanged — ball_protr is the protrusion amount that the box dimple was sized for, and that doesn't change with the rib.

The general lesson: whenever you place a sphere or round feature at h/2 inside a thin slab, check that ball_r ≤ h/2. If it isn't, the feature escapes the slab in Z and you get a floating shell. The slicer won't catch it.


---

DESIGN EVOLUTION: Ball auto-sizing, thickening, and the "embed, don't patch" rule (2026-06-07)

The glide ball catch had two separate problems that happened to overlap:

Problem 1 — wrong size on large lids. The ball diameter formula is:
  ball_d = min(sw×2, max(noz×8, max(w,l)×0.03))

The 3% footprint scaling ensures a 200mm lid gets a larger ball than a 60mm lid — retention force scales with the surface area the ball must hold. The noz×8 floor (3.2mm at 0.4mm nozzle) prevents balls from going below Arachne's small-perimeter speed clamp. The sw×2 ceiling is a hard geometric constraint: ball_r = sw is the point where the ball would punch through the box groove wall. No gain from going bigger. The formula is already self-correcting — tiny balls on massive lids can't happen as long as sw is appropriate for the part size.

Problem 2 — ball floated above lid top. The rib fix we applied earlier was a patch: we added a full-height connecting rib to keep the ball attached at every layer. But the root cause was that the lid slab (sl ≈ 2mm) was thinner than the ball diameter (ball_d ≈ 3.2–4.8mm), so ball_r > sl/2 and the top of the ball had no support.

The cleaner fix (applied now): sl_glide = max(sl, ball_d). The lid is made at least as thick as the ball diameter, so ball_r ≤ sl_glide/2 is always true. No rib needed. Side effect: a large glide lid on a big box is now noticeably thicker than the default 2mm lid. This is correct behavior — a 200mm glide lid at 2mm would flex under load; 4.8mm is more appropriate. The thickening is proportional to part size because ball_d is proportional to part size.

The same logic was applied to the plaque face plate socket: p_t_eff = max(p_t, od). The face plate is widened to fully back the socket diameter, eliminating any bridging at the socket base.

General rule captured: when a round feature (ball, socket, cylinder) doesn't fit within its host body, thicken the host rather than adding a rib or repositioning the feature. Ribs are the fallback when host geometry is constrained by mating parts.

