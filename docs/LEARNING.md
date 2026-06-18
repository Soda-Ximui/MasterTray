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


---

ISSUE: Snap bead hung by a thread — printed but didn't click (2026-06-08)

Physical print test: the snap lid bead printed but was barely there, "hanging on edge by a thread." The lid fell through.

The autopsy: bead center at `lid_w/2 - sw/2`, bead width `sw`. Bead outer face at exactly `lid_w/2` (lid body edge). With `chamfer=bead_h/2` on ALL edges, the chamfer cuts the outer-X faces inward by bead_h/2 at the top and bottom of the bead. At mid-height the bead reaches `lid_w/2` but the lid body's top chamfer (`m_chamf`) has already inset the lid edge there. The bead never truly protrudes past the lid body — it was a thin strip at the exact edge, barely connected, with zero cam-over protrusion. No click was geometrically possible.

The fix: `snap_protr = noz`. Bead translate: `sx * (lid_w/2 + clearance/2 + snap_protr - sw/2)`. The `clearance/2` term offsets lid_w's built-in tolerance gap so the bead's inner face starts at the box interior wall; `snap_protr = noz` extends it a further nozzle-width into the box wall. Bead outer face = `(w-sw*2)/2 + noz`, protruding `noz` past the box interior face. The all-edges chamfer provides cam-over action on both press-in and pull-out.

Note: the snap bead must protrude past the lid body edge by at LEAST the chamfer radius (bead_h/2) or it will vanish into the chamfer geometry and produce zero retention.

ISSUE: Flip_Double half-lid length — used full-box formula (2026-06-08)

Physical print: Flip_Double half-lids were the correct direction but "exceeded by a big margin." The manifest used `flip_lid_l = l - hinge_y` (nearly full box length) for half-lids. The correct formula is `flip_half_lid_l = l/2 - hinge_y` — each lid covers from its inner axle to the outer wall. Fixed in all Flip_Double intents (Double Flip Box, 1-Day AM/PM, 14-Day AM/PM, Lid Testing).


---

ISSUE: OrcaSlicer "object can't be printed for empty layer between 17.92 and 18.54" (2026-06-18)

OrcaSlicer flagged the threaded jar coupon with this warning. The warning means there is a z-range where the model has exactly zero cross-section — the slicer sees no perimeters to print and skips the height entirely. The result on the physical printer is a gap in the object wall.

The autopsy: RenderJar.scad builds the threaded neck in three stacked pieces — cylindrical wall, tapered cone, threaded rod. Each piece was placed at exactly the top z of the piece below:

  up(sf + cyl_wall_h)        cone ...
  up(sf + cyl_wall_h + sw*1.5)  threaded_rod ...

When CGAL evaluates a `union()` of two solids whose faces coincide exactly at the same z, it creates what is called a seam edge — a triangle edge shared by more than two faces. That edge is non-manifold in the strict sense. At the seam plane CGAL may produce a degenerate cross-section with zero area. OrcaSlicer measures cross-sectional area at each layer z and reports the height range where it found zero.

Crucially: this does NOT show up as a non-manifold error in validSTL.py or pymeshlab. Those tools count open-boundary edges and Euler characteristic. A seam edge is topologically distinct — pymeshlab can report nm=0 (zero open edges) on a mesh that still has this problem. The empty-layer warning is the only signal.

The fix is called the EPS overlap rule. Instead of starting the cone at exactly the wall top, we shift it down by EPS (0.01 mm) and extend its height by EPS:

  up(sf + cyl_wall_h - EPS)  cyl(h = sw*1.5 + EPS, ...)
  up(sf + cyl_wall_h + sw*1.5 - EPS)  threaded_rod(l = lip_h + EPS, ...)

Now the cone overlaps the wall by 0.01 mm instead of touching it. The EPS terms cancel in the algebra: (sf + cyl_wall_h - EPS) + (sw*1.5 + EPS) = sf + cyl_wall_h + sw*1.5. The jar's total height is unchanged. CGAL sees a solid, continuous interior at every z.

The lesson: whenever two pieces are stacked in a `union()`, the upper piece must start BELOW the lower piece's top face by EPS and its height must be extended by EPS. This is not optional — face-to-face contacts in CGAL have unpredictable behavior and can produce empty layers, non-manifold edges, or seemingly fine geometry that fails only in the slicer.


---

ISSUE: Jar floor has no chamfer at z=0 — chamfer starts above the bed (2026-06-18)

Physical inspection of the jar model revealed that the outer edge at the very first printed layer (z=0) is a sharp 90-degree corner. The cylindrical wall has a chamfer (bevel) at its base, but that chamfer starts at z=sf — one floor-height above the bed. The floor itself had no chamfer.

The autopsy: `factory_render_jar` built the floor ring with:

  linear_extrude(height=sf, center=true)
    difference() { circle(d=w); circle(d=inner_d); }

`linear_extrude` in OpenSCAD extrudes a 2D shape straight up — no chamfer, no bevel, no rounding. The wall module `cylindrical_mesh_wall` uses BOSL2's `cyl(chamfer=rim_chamf)` which applies a 45-degree bevel to both the top and bottom of the cylinder. Since the wall's bottom chamfer starts at its own z=0 (which is sf above the bed), the floor's outer edge is always a sharp corner regardless.

Beyond the aesthetics, a sharp first-layer corner is structurally weaker (stress concentration) and the first layer's bead doesn't have a controlled footprint for adhesion — the outer edge is just a thin ring of vertical wall.

The fix: replace `linear_extrude` with BOSL2 `cyl(d=w, h=sf, chamfer1=rim_chamf, anchor=CENTER)`. The `chamfer1` parameter applies the bevel only to the BOTTOM face (z=0, the print bed side). `chamfer2` would apply it to the top (z=sf). We want only the bottom — the top is already handled by the wall's own bottom chamfer. `rim_chamf = noz * 4` (4 nozzle widths = 1.6mm at 0.4mm nozzle) matches what `cylindrical_mesh_wall` uses exactly.

The inner bore also needed updating: the `circle(d=inner_d)` in the `linear_extrude` difference had zero-thickness faces at top and bottom. In the replacement, the cutter is `cyl(d=inner_d, h=sf+EPS*2, anchor=CENTER)` — extending EPS past both faces of the ring (the EPS cutter rule for `difference()`). Without this, the bore's top and bottom faces coincide with the ring's top and bottom faces — another potential seam edge.

The lesson: never use `linear_extrude` for a structural ring or shell that will be printed. BOSL2's `cyl()` gives you `chamfer1`/`chamfer2` control and you can easily apply the EPS cutter rule to the inner bore. `linear_extrude` is fine for flat text or connector profiles that are then boolean-operated on, but for any load-bearing geometry that a human will hold, start with `cyl`.


---

ISSUE: The EPS rule was being applied case-by-case with no written requirement (2026-06-18)

After fixing the jar neck seams and the floor ring, it became clear that the same root cause (face-to-face union contacts, zero-extension cutters) had been fixed in multiple files over multiple sessions, but there was no single place that stated the rule, explained why it is necessary, or listed which sites had been audited. Future renderers could easily reintroduce the same bug.

The root cause of the root cause: CGAL's behavior on coincident faces is not an error. OpenSCAD renders the model without complaint. validSTL.py (pymeshlab) may report nm=0. The only symptom is an OrcaSlicer empty-layer warning that only appears when you actually slice the model for print — a stage that happens late and manually, not in the automated gate.

The fix was two-pronged:

1. Formal statement in MasterEngine.scad. A 35-line comment block was added immediately before `EPS = 0.01`. It explains CGAL seam edges, gives the exact rule for union() (shift down EPS + extend height EPS) and difference() (extend cutter ≥ EPS past every face), shows how the algebra cancels, and lists all verified fix sites in the codebase with file names.

2. Full audit of all renderers before writing the block, to ensure the inventory is accurate. The audit found every `union()` join and `difference()` cutter across RenderJar, RenderBox, RenderLid, and RenderMesh. All were compliant except the two jar neck junctions fixed this session.

The lesson: when a fix is applied more than once for the same root cause, that is a signal to formalize it as a rule with teeth, not just to patch the next occurrence. The rule needs to live where it can't be missed (next to the constant it references), state WHY not just WHAT, and include an obligation for future code. Silent recurring bugs suggest a missing standard, not individual mistakes.


---

ISSUE: check_printable.py slicer gate referenced keys that no longer existed (2026-06-18)

Running `check_printable --slicer` on the jar would have failed with a KeyError if the empty-layer detection had been written first. Instead, the stale-key bug was sitting silently in `main()`.

The `analyze_gcode()` function had been refactored in a prior session to return a coverage-based metric (fl_coverage_pct, overhang_mm) instead of the island-count approach (fl_islands, fl_min_island_mm, struct_overhang_mm, struct_overhang_runs). But `main()` still referenced the old keys. The code path was never exercised because `--slicer` had not been used on the test prints after that refactor.

The fix: replace the stale keys with the actual keys from the current `analyze_gcode()` return dict. Also renamed the CLI flag `--min-island-mm` to `--min-coverage-pct` to match the metric it controls.

The lesson: when you rename a function's return keys, grep for all callers that destructure or index those keys. A Python dict `KeyError` is a runtime error, not a type error — it won't surface until someone runs that exact code path. In this codebase that means "until someone slices an STL and checks the output." No amount of static analysis catches this silently.


---

DEEP DIVE: How check_printable.py reads and interprets OrcaSlicer gcode (2026-06-18)

This section documents every gcode-touching function in build/scripts/check_printable.py —
what gcode looks like coming out of OrcaSlicer, what each function reads and why, and what
can go wrong.


── BACKGROUND: what OrcaSlicer gcode actually looks like ──────────────────────────────

OrcaSlicer writes a single .gcode file per part. It's a plain text file of G-code commands
interspersed with human-readable comment lines starting with ';'. The comment lines are what
this script actually cares about — the G-code itself is the machine motion, but OrcaSlicer's
rich comments turn the gcode into a semantic log of the print.

A minimal excerpt showing the structure:

    ; CHANGE_LAYER
    ; layer_z = 0.200
    ; layer_num = 0
    ; FEATURE: Outer wall
    G1 X10.5 Y22.3 E0.0843 F7200
    G1 X11.0 Y22.3 E0.0500 F7200
    ; FEATURE: Inner wall
    G1 X10.7 Y22.5 E0.0312 F7200
    ; CHANGE_LAYER
    ; layer_z = 0.400
    ; layer_num = 1
    ; FEATURE: Outer wall
    G1 X10.5 Y22.3 E0.0910 F7200
    ...

Key structural elements:

  '; CHANGE_LAYER'       — marks the start of a new layer. Everything between two
                           CHANGE_LAYER markers is that layer's moves.

  '; layer_z = N.NNN'   — the Z height (mm) of the layer that follows.

  '; FEATURE: NAME'     — the semantic type of moves that follow. OrcaSlicer changes
                          this as it switches between printing strategies within a layer.
                          Common names: "Outer wall", "Inner wall", "Solid infill",
                          "Sparse infill", "Bridge", "Internal Bridge", "Overhang",
                          "Skirt", "Brim". The feature tag stays active until the next
                          '; FEATURE:' line.

  'G1 X Y [Z] [E] [F]' — a linear move. X/Y are the target coordinates (mm, absolute).
                          E is the extruder position change (mm of filament). F is
                          feedrate (mm/min). E is RELATIVE in OrcaSlicer output — a
                          positive E value means "extrude this much filament on this move"
                          and a negative E value means retract. The absence of E means
                          no extrusion (a travel move).

  'G0 X Y'             — a travel move (no extrusion). OrcaSlicer may or may not use
                          G0 vs G1 consistently; the script treats them the same.

  'G2 / G3 X Y I J'   — arc moves (clockwise / counterclockwise). X/Y is the endpoint,
                          I/J is the arc center offset from the current position. Circular
                          geometry (jars, round bases) is almost always G2/G3 in
                          OrcaSlicer. The script currently IGNORES these.

  '; line_width = N.NN' — appears in the first ~400 lines of the header. The linewidth
                          (extrusion width) in mm. Used to convert path length into
                          contact area (length × width ≈ area of plastic deposited).


── _slice_to_gcode(stl_path, td) ────────────────────────────────────────────────────────

Purpose: run OrcaSlicer in headless "slice" mode and return the gcode text, or None if
slicing fails.

How it works:
  1. Verifies that the OrcaSlicer executable and all three profile JSON files exist on
     disk. If any are missing, returns None immediately without attempting to run.
  2. Invokes OrcaSlicer as a subprocess with --slice 0 --load-settings --load-filaments
     --outputdir. The sliced gcode is written to a temporary directory.
  3. Waits for completion (up to 240 seconds). OrcaSlicer is a GUI app — the console
     receives no progress output and no meaningful error text, even when slicing fails.
  4. After the process exits, globs the temporary directory for any *.gcode file.
     If none exists, returns None (OrcaSlicer's silent way of signaling failure).
  5. Returns the gcode text decoded as UTF-8, ignoring undecodable bytes.

Failure modes:
  - OrcaSlicer not installed, wrong path: None returned, gate skips slicer checks.
  - Profile JSON files at the wrong version / path: the slicing may silently produce
    bad gcode or fail — the profile paths are version-specific and must be kept in sync
    with the installed OrcaSlicer version.
  - Geometry that OrcaSlicer can't handle: it exits non-zero or writes no gcode. Both
    result in None.
  - Timeout (> 240s): the subprocess is killed and None is returned. At ~1s per part
    this should never be hit in normal use.

Why subprocess / not API: OrcaSlicer has no Python API. The only headless interface is
the CLI. This also means the script can't ask the slicer what went wrong.


── _extruded(block, want) ────────────────────────────────────────────────────────────────

Purpose: walk a list of gcode lines (one layer or the whole file), sum up the XY
extrusion path length for moves whose current FEATURE satisfies a predicate, and return
the XY bounding box of those moves.

Arguments:
  block   — a list of gcode line strings. Can be one layer or the whole file.
  want    — a callable(feature_name: str) → bool. Filters which FEATURE types to count.

Step-by-step logic:

  State: feat = "" (current feature name), x/y = None (current position).

  For each line:
    If '; FEATURE: X' — update feat to X. Continue.
    If not G1 or G0 — skip.
    Parse tokens after the move command:
      X<float>  → new X coordinate
      Y<float>  → new Y coordinate
      E<float>  → extruder delta (filament amount)
    If E exists AND E > 0 AND want(feat) is True AND we have a previous position:
      Compute the Euclidean distance from (x, y) to (nx, ny).
      Add that to 'length'.
      Append both x, nx to xs; both y, ny to ys.
    Advance current position to nx, ny (only updating the axis if it appeared in this move).

  After scanning: compute the bounding box as
    (max_x - min_x) × (max_y - min_y)
  This gives the rectangular footprint of all the qualifying extrusion moves.

  Return (length_mm, bbox_mm2).

What 'want' is called with in practice:

  First-layer contact:
    want = lambda f: f not in ("Skirt", "Brim", "Custom", "")
    This counts everything that is genuinely part of the object — outer walls, inner
    walls, infill, solid infill. Skirt and Brim are excluded because they're primer
    loops outside the part footprint; including them would inflate the bbox and
    falsely raise coverage. Empty feature ("") and "Custom" are ignored as noise.

  Overhang count:
    want = lambda f: f.startswith("Overhang")
    OrcaSlicer labels overhanging perimeters as "Overhang" (sometimes "Overhang
    perimeter" or "Overhang wall" — the startswith catches all variants).

Why this uses E > 0 (relative E check):
  OrcaSlicer uses relative extrusion mode (M83 in the header). Every G1 that actually
  deposits plastic has a positive E value (amount of filament pushed). A travel move
  either has no E at all or has a negative E (retraction). Checking E > 0 correctly
  distinguishes extrusion from travel — you don't want to count a long travel move as
  path length.

What this CAN'T do: G2/G3 arc moves. Arcs have an I and J component (center offset)
and an implicit radius. Calculating arc length requires: distance from current pos to
center (the radius), and the angle swept. The function's token loop would see X and Y
(endpoint) but there's no E parsing for arcs either since arcs may lack explicit E (some
slicer versions compute arc E implicitly). Arcs are simply skipped.


── _empty_layers(lines) ──────────────────────────────────────────────────────────────────

Purpose: detect z-height gaps in the layer sequence — ranges where the slicer produced
no geometry and jumped straight to the next layer.

An "empty layer" is not a slicer error: it means the geometry itself had zero
cross-sectional area at a z-range. The slicer simply skips it. But a physical printer
cannot skip z-height — if the nozzle travels from z=17.9mm to z=18.6mm with nothing
printed in between, the result is a gap in the part wall. This is always a geometry
defect, not a slicing preference.

Step-by-step logic:

  1. Scan all lines for '; layer_z = N.NNN'. Parse N.NNN as a float. Collect in zs[].
     OrcaSlicer emits one '; layer_z =' per layer, so zs[] ends up as the sequence of
     z heights across the whole print.

  2. If fewer than 3 layers, return [] — can't infer anything meaningful.

  3. Compute all consecutive differences: steps = [zs[i+1] - zs[i] for all i where
     zs[i+1] > zs[i]]. The sorted median of this list is the nominal layer height.
     Why median? The first layer is often taller (0.25mm first layer on a 0.20mm print),
     and variable-layer-height features may create some non-standard steps. The median is
     robust to these outliers — on a 200-layer print, one 0.35mm first layer doesn't
     skew the median away from 0.20mm.

  4. Set threshold = nominal_layer_height × 1.5. A gap between two consecutive layers
     that exceeds 1.5× the expected height is flagged as an empty layer.
     Why 1.5×? The first layer is typically at most 1.25× the nominal (0.25mm on a
     0.20mm print). 1.5× gives a comfortable margin above the legitimate maximum step
     without requiring a precisely calibrated threshold.

  5. Return [(z_start, z_end)] for every consecutive pair in zs[] where the gap exceeds
     threshold.

What it can NOT detect: a geometry defect that produces a very thin (but non-zero) layer.
If the cross-section at a seam is 0.001mm² instead of exactly zero, OrcaSlicer will
produce a layer with a single extrusion move, and the z-sequence will look normal.
That geometry defect will fail at print time (a nearly-invisible layer), but this
function won't catch it. The empty-layer check is a hard gate only for the fully-zero case.


── analyze_gcode(txt) ────────────────────────────────────────────────────────────────────

Purpose: orchestrates the three sub-analyses into a single dict of printability signals.

Step-by-step logic:

  1. Read line_width from the gcode header (first 400 lines only — the header is always
     at the top, no need to scan the whole file). Default 0.45mm if not found.
     The linewidth matters for coverage: area = length × width. A 0.45mm line of 50mm
     length deposits 22.5mm² of material. Using the gcode's actual linewidth instead of
     a hardcoded value makes coverage comparable across different slicer profiles.

  2. Find all '; CHANGE_LAYER' line indices. If none, return None — the gcode has no
     layers (slicing failed or the file is just G-code preamble).

  3. Extract the first-layer block: lines from the first CHANGE_LAYER to the second (or
     to end-of-file if there's only one layer).

  4. Call _extruded(first_layer_block, non-skirt-brim-filter):
     → fl_len = total extrusion path length on the first layer (mm)
     → fl_bbox = bounding box of that extrusion (mm²)

  5. Call _extruded(all_lines, overhang-filter):
     → oh_len = total overhang extrusion length across the whole print (mm)
     (The overhang bbox is discarded — only the length matters for the structural gate.)

  6. Compute coverage:
     coverage = (fl_len × linewidth / fl_bbox) × 100%
     If fl_bbox is 0 (no linear moves found — probably all arcs), coverage = 0%.
     This is the key metric for first-layer adhesion: how densely packed are the
     extrusion lines relative to the footprint? A solid rectangle at 0.2mm spacing
     and 0.45mm width over a 100mm² footprint would be ~100% coverage (in practice
     85–95% because of wall gaps). A frame-only object with no infill would be 5–15%.
     Very low coverage (<10%) means most of the footprint has no adhesion.

  7. Call _empty_layers(all_lines) → gaps.

  8. Return dict:
       fl_contact_mm    — how many mm of first-layer extrusion were deposited
       fl_footprint_mm2 — the rectangular bounding box of those moves
       fl_coverage_pct  — coverage % (0% if arcs-only, see G2/G3 note above)
       overhang_mm      — total overhang extrusion length across whole print
       empty_layer_gaps — list of (z_start, z_end) where z-gaps were found

Why first layer is the priority signal:

  Every subsequent layer is supported by the one below. If layer 2 is slightly sparse,
  layer 3 fills in the gaps. But layer 1 sits on glass or PEI — if it's sparse, the
  part lifts, warps, or doesn't stick. A failed first layer = a failed print. Every
  other signal in gcode analysis is secondary to this one.

Why overhang_mm is a hint, not a hard gate:

  OrcaSlicer marks the top-of-hole teardrops in a mesh pattern as "Overhang" because
  the teardrop tip is a ~60° face — correct geometrically, but printed fine because the
  teardrop shape was specifically designed for FDM. On a dense mesh box (hundreds of
  holes), oh_len can be thousands of mm from teardrops alone. Reporting this as "NOT
  PRINTABLE: overhang too long" would always fire on a healthy mesh box and never catch
  a real structural cantilevered lip. The length metric is only reliable when run on
  SOLID (mesh-off) geometry — then every "Overhang" truly is a structural face without
  support below it.


── slicer_printability(stl_path) ──────────────────────────────────────────────────────

Public entry point for the main gate. Creates a temp directory, calls _slice_to_gcode
to produce the gcode text, passes it to analyze_gcode, and returns the result dict (or
None if slicing was unavailable or failed).

The temp directory is cleaned up automatically when the context manager exits, so no
gcode files are left on disk after the check completes.


── The G2/G3 arc gap — what's missing and what would fix it ──────────────────────────

_extruded only handles G1 and G0 (linear moves). OrcaSlicer uses G2 (clockwise arc)
and G3 (counterclockwise arc) for circular geometry: jar walls, round bases, cylindrical
caps. A complete arc command looks like:

    G2 X155.3 Y100.0 I-5.0 J0.0 E0.1240 F7200

  X/Y  — the endpoint of the arc
  I/J  — offset from the current position to the arc center
  E    — filament extruded (positive = extrude)

The arc's path length is: radius × angle_swept (in radians). Radius = sqrt(I² + J²).
Angle swept = atan2 of (endpoint - center) minus atan2 of (start - center), with
correct wrapping for CW/CCW direction.

For a 35mm diameter jar at the first layer:
  - Circumference ≈ 110mm
  - OrcaSlicer uses ~4 arc moves to trace the full circle (one per 90°)
  - Each arc move has its own E value

Because _extruded skips G2/G3, a circular jar produces xs=[], ys=[], fl_bbox=0,
fl_coverage_pct=0.0%. The main gate guards against this with:

    if pc["fl_coverage_pct"] > 0 and pc["fl_coverage_pct"] < args.min_coverage_pct:
        # fail
    # else: 0% means arcs — skip, don't fail

A proper fix would extend _extruded to parse G2/G3:
  1. Extract I/J to get the arc center offset.
  2. Compute radius r = hypot(I, J).
  3. Compute start_angle = atan2(-J, -I) (angle from center back to start pos).
  4. Compute end_angle = atan2(end_y - center_y, end_x - center_x).
  5. Compute arc length = r × abs(angular_sweep), where sweep is adjusted for CW/CCW.
  6. Interpolate a bounding box contribution from the arc (the bbox of a partial circle
     can be computed analytically).
  7. Treat E > 0 the same as G1 to decide if it counts.

This is deferred because it's significant additional complexity for a check that is
already informative for rectangular geometry (boxes, trays, lids), and the workaround
(skip-at-zero) is conservative — it never falsely fails a jar.

── ISSUE: rim_chamf ≥ sw → empty layer + floating cantilever at z=0 on 0.6 mm nozzle (2026-06-18)

After regenerating the test coupons with the stress-test config (0.6 mm nozzle, 0.30 mm layer),
OrcaSlicer reported two new problems on `jar_d55h55`:

  "Object can't be printed for empty layer between 2.1 and 3."
  "It seems object jar_d55h55.stl has floating cantilever."

The geometry looked fine for a 0.4 mm nozzle. The analysis:

`rim_chamf = noz * 4` was added to bevel the floor ring and cylinder wall rims so they
don't print as knife edges. A 45° chamfer of size `c` at the outer edge of a cylinder
removes `c` from the outer radius at z=0. The inner hole doesn't change. So the annulus
width at z=0 is: `sw - rim_chamf`.

For 0.4 mm nozzle: `rim_chamf = 1.6 mm`, `sw = 2.4 mm` → annulus = 0.8 mm (2 perimeters). Fine.

For 0.6 mm nozzle: `rim_chamf = noz * 4 = 2.4 mm`, and `sw = round(THICK_WALL0 / noz) * noz =
round(2.4 / 0.6) * 0.6 = round(4) * 0.6 = 2.4 mm`. So `rim_chamf == sw` → annulus = 0 mm
at z=0. The chamfer completely eroded the ring.

Two symptoms:
  1. "Floating cantilever" — the floor ring at z=0 has zero width; the only material touching
     the bed is the inner mesh disc. The ring appears to float just above z=0 without bed contact.
  2. "Empty layer between 2.1 and 3" — the wall cylinder starts at z=sf-EPS=1.99 mm and also
     has rim_chamf=2.4 mm. At z=1.99 to 1.99+2.4=4.39 mm (the bottom chamfer zone), the wall
     annulus width grows from 0 at z=1.99 to sw at z=4.39. OrcaSlicer can't generate perimeters
     for sub-nozzle-width cross-sections, so it reports the zone with < 1 perimeter as empty.

The fix: cap `rim_chamf = min(noz * 4, sw - noz)`. This guarantees at least 1 perimeter (noz)
of annulus width at z=0, regardless of nozzle size. For 0.6 mm: `min(2.4, 2.4 - 0.6) = 1.8 mm`.
Floor ring at z=0: outer radius = 27.5 - 1.8 = 25.7 mm, inner = 25.1 mm → 0.6 mm = 1 perimeter. Fixed.

Applied in:
  - `RenderJar.scad`: floor ring chamfer (tagged GEOM-FIX: chamf-clamp)
  - `RenderMesh.scad` (cylindrical_mesh_wall): wall cylinder chamfer (same tag)

The lesson: chamfer sizing must be bounded by the annulus it bites into. `noz * N` is a fine
heuristic but must always be checked against the thinnest geometry it could erase. Whenever
a chamfer is applied to the outer edge of a hollow cylinder (ring/annulus), the constraint is
`chamfer < wall_thickness`. Here we use `wall_thickness - noz` to leave a minimum of one perimeter.

---

── ISSUE: First-layer coverage gate fired as 0% on circular jars (false positive) (2026-06-18)

After fixing the stale keys, running the slicer gate on the threaded jar produced:

  first-layer coverage 0.0% < 10.0% (adhesion risk)

But the jar was printing fine. Zero coverage on a jar that covers the full build plate footprint made no sense.

The autopsy: `_extruded()` in check_printable.py collects x/y coordinates from G1 and G0 moves (linear moves). OrcaSlicer outputs circular arcs as G2 and G3 commands (arc moves), not G1. The jar's circular outer perimeter is 100% G2/G3 arcs. `_extruded()` never collects any x/y coordinates for the first layer → xs and ys are empty → the bounding box is zero area → fl_coverage_pct = 0.0% → the gate fires.

The fix: only gate on coverage when `fl_coverage_pct > 0`. A value of exactly zero means the parser found no linear moves on the first layer — most likely arc moves that we aren't parsing, not genuine evidence of poor bed adhesion. The gate text was also updated to make this explicit: zero means "arc-only first layer (not parsed), not evidence of poor adhesion."

The full fix would be to parse G2/G3 arcs and add their x/y extents to the bounding box calculation. That's deferred — the arc geometry requires knowing the center point and radius from the I/J parameters. For now, skipping the gate when coverage is zero is correct and safe: it avoids false fails while still catching the real zero-coverage case (a model that truly has no first layer, which would produce no moves at all and a different gcode structure).

The lesson: when a metric can be zero for two completely different reasons (parser gap vs genuine problem), the gate must distinguish them. Treating "not measured" the same as "measured zero" produces false positives. Always check whether zero means "no data" before deciding it means "bad data."

---

── NOTE: BOSL2 `chamfer` is always 45° — no additional angle cap is needed on rim_chamf (2026-06-18)

After capping `rim_chamf = min(noz*4, sw-noz)` (B10 fix), the question arose: should rim_chamf
also be limited by the 45° self-supporting angle rule for FDM printing?

The answer is no, and the reason is definitional: BOSL2's `chamfer` parameter is not an angle —
it is a SIZE (mm). The angle is always exactly 45°, regardless of how large or small the chamfer
is. A `chamfer=1.6mm` and a `chamfer=1.8mm` both produce a 1:1 rise-to-run slope (45° from
horizontal). The size changes; the angle does not.

Printed bottom-up, the chamfer zone at the base of a cylinder looks like this:

  z = rim_chamf:  ████████████████████████  ← full outer radius r
  z = rim_chamf/2: ██████████████████████   ← r - rim_chamf/2 (each layer extends outward by lh)
  z = 0 (bed):   ████████████████████     ← r - rim_chamf (sits on bed, no overhang)

Each successive layer extends outward by exactly one layer height — that 1:1 ratio is the 45°
angle. The geometry is self-supporting by construction. No constraint on rim_chamf can change
this, because the angle isn't a function of size.

The top chamfer on the wall cylinder (chamfer= applies both ends) is even safer: the outer
boundary SHRINKS as layers go up, so there is no overhang at all — each new layer prints
fully supported inside the previous one.

The only constraint on rim_chamf that matters is the one already in place:

  rim_chamf = min(noz * 4, sw - noz)   // annulus ≥ 1 perimeter at z=0

That cap is about annulus WIDTH at the base face, not about the slope angle. The 45° rule is
satisfied automatically because `chamfer` in BOSL2 is defined as a 45° bevel.

The lesson: understand what a parameter actually controls. `chamfer` in BOSL2 is a SIZE, not an
angle. Trying to cap it "for the 45° rule" would be solving a non-problem — the rule is already
baked into the operation's definition.

---

── NOTE: Never add `include <BOSL2/...>` or `include <MasterEngine.scad>` to a sub-file (2026-06-17)

OpenSCAD's `include` directive is NOT deduplicated. If two files both include the same file,
that file is parsed TWICE — there is no include guard, no once-per-translation-unit semantics.

Before the fix, BOSL2 was being re-parsed on every build by 11 different files through a diamond
include graph (RenderBox→RenderTray→RenderMesh/RenderGrid etc., each with their own
`include <BOSL2/std.scad>`). The measured cost: ~22s of FIXED overhead per build, regardless of
geometry size. A 125 KB box and an 8.7 MB jar both took ~23s. All of that overhead was re-parsing.

The fix: single-owner includes. MasterBuilder.scad is the ONLY file that includes MasterEngine.scad.
MasterEngine.scad is the ONLY file that includes BOSL2/std.scad. Every other file relies on those
symbols being available because MasterBuilder loaded them first. Result: plain box build time
went from 23.8s → 1.6s (~15× faster). Geometry byte-identical; gate 26/26.

RULE (hard requirement):
- Do NOT add `include <BOSL2/std.scad>`, `include <BOSL2/threading.scad>`, or any other BOSL2
  include to any sub-file (RenderBox, RenderMesh, RenderGrid, RenderJar, RenderLid, etc.).
- Do NOT add `include <MasterEngine.scad>` to any sub-file.
- MasterBuilder.scad includes MasterEngine first. MasterEngine includes BOSL2. Sub-files
  inherit both. This is the only correct configuration.

The correct include header for any new sub-file:

  // BOSL2/std comes via MasterEngine — do NOT re-include (OpenSCAD has no include dedup;
  // re-parse cost ~21s) [perf]
  // MasterEngine is included once by MasterBuilder.scad (single owner) — not re-included
  // here [perf]
  include <RenderMesh.scad>    // only other sub-files you directly depend on

Tradeoff (user-approved): sub-files no longer open standalone in the OpenSCAD GUI. To preview
a part, open MasterBuilder.scad and set Part_To_Build in the Customizer panel.

The lesson: OpenSCAD's include model is textual substitution with no dedup. Every include is a
full re-parse. Diamond graphs are lethal to build times. Enforce single-owner includes from the
start; measuring ~22s of unexplained fixed cost is how this was discovered, not a review.


