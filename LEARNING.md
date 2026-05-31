When building the central spine for the 14-day box in v3.1, I told the engine to place the two 4mm hinge bars 6mm apart. Then, to make it strong, I told it to build a solid block underneath them.

The Bug: The math for that solid block was too wide. It engulfed the hinge bars entirely. The cylinders were physically there in the code, but they were 100% buried flush inside a giant rectangular prism, leaving zero undercut clearance for the C-clip to wrap around.

The Fix: "The Pedestal Architecture" (v3.3)
To fix this, we can't just attach the cylinders to a flat wall. The C-clip needs empty space underneath the "equator" of the cylinder so the plastic arms can snap around the bottom.

I rewrote the hinge math in MasterRender for both the FLIP_BOX and the DOUBLE_FLIP_BOX.
Instead of a giant block, the cylinders now sit on top of 2mm wide pedestals. Because the cylinder is 4mm wide and the pedestal underneath it is only 2mm wide, the entire bottom half of the cylinder is exposed on the left and right sides. Your C-clips will now snap perfectly onto them!

I also reset the grid_layout in MasterBuilder back to "7x2" so your AM/PM box works perfectly out of the gate.

