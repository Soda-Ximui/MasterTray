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


