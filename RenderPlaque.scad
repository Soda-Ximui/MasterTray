// ==============================================================================
// FILE: RenderPlaque.scad
// ARCHITECTURE: Layer 3 (Factory)
// PURPOSE: Label plaque system for tray / box walls and lids.
//
// PLAQUE_TARGET:
//   "Wall"     — U-Clip + swivel face plate. Two pieces side by side.
//                Clip grips wall edge; plate snaps onto pin and swivels to face user.
//   "Lid"      — Face plate only, flat back. Adhesive-mount on any flat lid surface.
//                Single piece; no clip, no socket, no swivel.
//   "Lid_Peg"  — Face plate with two press-fit pegs on the back.
//                Pegs snap into holes in the lid surface (removable, reusable).
//                Use plaque_get_peg_holes() to punch matching holes in the lid.
//
// CLIP_TYPE (Wall target only):
//   "Vertical"   — grips thin vertical edge of a dropped tray wall.
//                  U opens at −Y; arms bracket both wall faces in X.
//                  Print: upright, no supports.
//   "Horizontal" — straddles horizontal top rim of any wall (tray or box).
//                  U opens toward bed (−Z); arms on bed, clip_top last.
//                  Inner bridge ≈ sw+tol (2–4 mm) — within FDM bridging range.
//                  Print: upright, no supports.
//
// Face plate (all targets):
//   Print: UPRIGHT — stands on p_w × p_t_eff base, p_h tall in Z.
//   All edges chamfered. Label surface for stick-on label or Bambu text modifier.
//   Wall:    C-clip socket on top, axis vertical — prints as C-rings, zero overhang.
//            p_t_eff = max(p_t_nominal, socket_od) — socket base fully backed.
//   Lid:     Plain flat top, thinner (p_t nominal).
//   Lid_Peg: Two pegs on back face, sized to snap-fit tolerance. Thinner (p_t nominal).
//
// Peg mount integration (Lid_Peg) — two-step pattern for meshed lids:
//   1. union()      → plaque_peg_patch(data, phys, lid_depth)  — solid fill at peg sites
//   2. difference() → plaque_get_peg_holes(data, phys)         — punch holes through patch
//   Patch is required because mesh lids have open cells; a hole in empty air grips nothing.
//   Both modules take the same translate() to position the plaque on the lid surface.
//
// All pieces print support-free in their shipped orientations.
// ==============================================================================
// BOSL2/std comes via MasterEngine — do NOT re-include (OpenSCAD has no include dedup; re-parse cost ~21s) [perf]
// MasterEngine is included once by MasterBuilder.scad (single owner) — not re-included here [perf]
include <MasterTolerance.scad>

// ── Private constants ─────────────────────────────────────────────────────────
_PL_CLIP_WALL_N = 4;    // clip / socket wall = N × nozzle (matches proven hinge wall)
_PL_PIN_D       = 4.0;  // pivot pin diameter — matches hinge_d throughout the system
_PL_ARM_D       = 12;   // vertical-clip arm depth (how far arms wrap the wall edge) mm
_PL_GAP         = 4;    // platter separation between pieces mm
_PL_PEG_D       = 4.0;  // lid-mount peg diameter mm — same as pin for tooling consistency
_PL_PEG_H      = 5.0;  // peg protrusion from back face mm

// ── Pivot pin (integral to clip, extends upward) ──────────────────────────────
module _pl_pin(pin_d, pin_h) {
    cyl(d = pin_d, h = pin_h, chamfer2 = pin_d * 0.15, anchor = BOTTOM, $fn = 36);
}

// ── C-clip socket (Wall face plate only) ──────────────────────────────────────
// Axis in Z (vertical). Prints as clean C-rings — zero overhang at any layer.
// C-opening at +X: snap on from the side; gravity cannot pull it off.
// Anchor: BOTTOM — caller places at Z = p_h so it sits above the slab.
module _pl_socket(pin_d, socket_h, tol, noz) {
    clip_wall = noz * _PL_CLIP_WALL_N;
    od  = pin_d + tol * 2 + clip_wall * 2;
    id  = pin_d + tol * 2;
    gap = pin_d * 0.80;  // opening — allows snap-on, friction holds swivel angle

    difference() {
        cyl(d = od, h = socket_h, anchor = BOTTOM, $fn = 36);
        translate([0, 0, -EPS])
            cyl(d = id, h = socket_h + LINE_W, anchor = BOTTOM, $fn = 36);
        // C-opening slab at +X
        translate([od / 4, 0, socket_h / 2])
            cuboid([od / 2 + EPS, gap, socket_h + LINE_W], anchor = CENTER);
    }
}

// ── Vertical U-clip ───────────────────────────────────────────────────────────
// Grips thin vertical edge of a dropped tray wall. U opens at −Y.
// Print: upright, no supports.
module _uclip_vertical(sw, tol, clip_wall, clip_h, pin_d, pin_h, chamf) {
    gap    = sw + tol;
    cw     = gap + clip_wall * 2;
    back_t = clip_wall;
    arm_d  = _PL_ARM_D;

    echo(str("   U-Clip [Vertical] gap=", gap, " cw=", cw, " h=", clip_h));

    union() {
        difference() {
            cuboid([cw, arm_d, clip_h], chamfer = chamf, anchor = BOTTOM);
            // U channel: open at −Y, full height, back_t wall at +Y
            translate([0, -back_t / 2, -EPS])
                cuboid([gap, arm_d - back_t + EPS, clip_h + LINE_W], anchor = BOTTOM);
        }
        translate([0, arm_d / 2 - back_t / 2, clip_h])
            _pl_pin(pin_d, pin_h);
    }
}

// ── Horizontal U-clip ─────────────────────────────────────────────────────────
// Straddles horizontal top rim of any wall (tray or box). U opens toward bed.
// Print: upright, no supports. Inner bridge = sw+tol ≈ 2–4 mm, within FDM range.
module _uclip_horizontal(sw, tol, clip_wall, clip_l, pin_d, pin_h, chamf) {
    gap   = sw + tol;
    arm_t = clip_wall;
    arm_h = _PL_ARM_D;
    ct    = clip_wall;
    cw    = gap + arm_t * 2;

    echo(str("   U-Clip [Horizontal] gap=", gap, " cw=", cw, " arm_h=", arm_h));

    union() {
        difference() {
            cuboid([cw, clip_l, arm_h + ct], chamfer = chamf, anchor = BOTTOM);
            // U gap open at −Z, full Y, ct of solid at top
            down(EPS)
                cuboid([gap, clip_l + EPS, arm_h + EPS], anchor = BOTTOM);
        }
        translate([0, 0, arm_h + ct])
            _pl_pin(pin_d, pin_h);
    }
}

// ── Lid-mount pegs (Lid_Peg variant) ─────────────────────────────────────────
// Two chamfered pegs on back face, spaced ±p_h/4 in Z from centre.
// Snap-fit: peg_d - tol×2 into matching hole. Chamfer tip aids insertion.
// Print: pegs point in −Y (back of upright face plate) — no overhangs.
module _pl_pegs(p_h, peg_tol) {
    peg_d = _PL_PEG_D - peg_tol * 2;  // interference fit on insertion
    spacing = p_h / 4;
    for (sz = [-spacing, spacing])
        translate([0, 0, p_h / 2 + sz])
            rotate([90, 0, 0])  // peg extends in −Y from back face
                cyl(d = peg_d, h = _PL_PEG_H,
                    chamfer2 = peg_d * 0.2, anchor = BOTTOM, $fn = 24);
}

// ── Public: solid patch for Lid_Peg mount ────────────────────────────────────
// Lids may be meshed. A peg hole punched into an open mesh cell has nothing to
// grip. Call plaque_peg_patch() in the lid factory's union() BEFORE the mesh
// subtraction to guarantee solid material at every peg location.
//
// Usage pattern in a lid factory:
//   difference() {
//     union() {
//       apply_master_bounds(...) up(sl/2) framed_mesh(...);  // meshed slab
//       translate([px, py, 0]) plaque_peg_patch(data, phys, sl); // solid patch
//     }
//     translate([px, py, 0]) plaque_get_peg_holes(data, phys);   // hole cutter
//   }
//
// px, py = desired plaque centre on the lid surface (in lid's local XY).
// Patch is a solid cuboid, full lid depth, slightly larger than each hole.
module plaque_peg_patch(data, phys, lid_depth) {
    noz     = phys[3][1];
    p_h     = get_val(PLAQUE_H, data, 40);
    patch_w = _PL_PEG_D + noz * 6;   // generous margin — covers any mesh cell
    spacing = p_h / 4;
    for (sz = [-spacing, spacing])
        translate([0, 0, p_h / 2 + sz])
            cuboid([patch_w, lid_depth + LINE_W, patch_w], anchor = CENTER);
}

// ── Public: hole pattern to punch in a lid for Lid_Peg mount ─────────────────
// Call inside difference() after plaque_peg_patch() has filled the mesh.
// Holes centred at X=0, Z = p_h/2 ± p_h/4. Depth = _PL_PEG_H + EPS.
// Caller translates to desired XYZ position on the lid surface.
module plaque_get_peg_holes(data, phys) {
    p_h     = get_val(PLAQUE_H, data, 40);
    tol     = breathing_room(COMP_CCLIP, data);
    hole_d  = _PL_PEG_D + tol * 2;
    spacing = p_h / 4;
    for (sz = [-spacing, spacing])
        translate([0, 0, p_h / 2 + sz])
            rotate([90, 0, 0])
                cyl(d = hole_d, h = _PL_PEG_H + LINE_W, anchor = BOTTOM, $fn = 24);
}

// ── Face plate (shared by all targets) ───────────────────────────────────────
// Print: UPRIGHT — p_w × p_t_eff base, p_h tall. All edges chamfered.
//   Wall:    socket on top (axis Z); p_t_eff = max(p_t, od) — socket fully backed.
//   Lid:     plain flat top; p_t nominal.
//   Lid_Peg: pegs on back face (−Y); p_t nominal; pegs print in −Y, no overhang.
module _face_plate(p_w, p_h, p_t, pin_d, socket_h, tol, peg_tol, noz, chamf, mode) {
    clip_wall = noz * _PL_CLIP_WALL_N;
    od        = pin_d + tol * 2 + clip_wall * 2;
    p_t_eff   = (mode == "Wall") ? max(p_t, od) : p_t;

    echo(str("   Face Plate ", p_w, "×", p_t_eff, "×", p_h, "H mode=", mode,
             (mode == "Wall") ? str(" socket_od=", od, " socket_h=", socket_h) : ""));

    union() {
        cuboid([p_w, p_t_eff, p_h], chamfer = chamf, anchor = BOTTOM);
        if (mode == "Wall")
            translate([0, 0, p_h])
                _pl_socket(pin_d, socket_h, tol, noz);
        if (mode == "Lid_Peg")
            translate([0, -p_t_eff / 2, 0])
                _pl_pegs(p_h, peg_tol);
    }
}

// ── Factory ───────────────────────────────────────────────────────────────────
module factory_render_plaque(data, opts, phys) {
    sw    = phys[0][1];
    noz   = phys[3][1];
    lh    = m_lh(data);
    chamf = m_chamf(data);

    clip_tol  = get_val(TOL_CLIP,  data, breathing_room(COMP_GLIDE, data));
    pivot_tol = breathing_room(COMP_CCLIP, data);

    target    = get_val(PLAQUE_TARGET, data, "Wall");
    clip_type = get_val(CLIP_TYPE,     data, "Vertical");
    p_h       = get_val(PLAQUE_H,      data, 40);
    p_w       = get_val(PLAQUE_W,      data, 50);
    clip_h    = get_val(CLIP_H,        data, 20);

    clip_wall = noz * _PL_CLIP_WALL_N;
    pin_d     = _PL_PIN_D;
    pin_h     = min(p_h * 0.35, 12);
    socket_h  = min(p_h * 0.35, pin_h + 2);

    // Nominal face plate thickness: ~3mm snapped to layer-height multiples.
    // _face_plate bumps to max(p_t, od) for the Wall variant automatically.
    p_t = lh * max(3, ceil(3.0 / lh));

    echo(str("-> Factory [PLAQUE] | target=", target,
             target == "Wall" ? str(" clip=", clip_type) : "",
             " plate=", p_w, "×", p_h,
             " pin_d=", pin_d, " pin_h=", pin_h));

    peg_tol = breathing_room(COMP_CCLIP, data);  // press-fit peg — same tight-fit class

    if (target == "Lid" || target == "Lid_Peg") {
        // ── Lid variant: face plate only (adhesive or peg-mount) ─────────────
        _face_plate(p_w, p_h, p_t, pin_d, socket_h, pivot_tol, peg_tol, noz, chamf, target);

    } else {
        // ── Wall variant: U-Clip + swivel face plate ──────────────────────────
        clip_gap     = sw + clip_tol;
        clip_outer_w = clip_gap + clip_wall * 2;

        if (clip_type == "Horizontal")
            _uclip_horizontal(sw, clip_tol, clip_wall, clip_h, pin_d, pin_h, chamf);
        else
            _uclip_vertical(sw, clip_tol, clip_wall, clip_h, pin_d, pin_h, chamf);

        translate([clip_outer_w / 2 + p_w / 2 + _PL_GAP, 0, 0])
            _face_plate(p_w, p_h, p_t, pin_d, socket_h, pivot_tol, peg_tol, noz, chamf, "Wall");
    }
}
