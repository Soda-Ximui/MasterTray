// ==============================================================================
// FILE: RenderPlaque.scad
// ARCHITECTURE: Layer 3 (Factory)
// PURPOSE: Swivel label-plaque system for tray / box walls.
//
// Emits TWO print-ready pieces side by side on the platter:
//   1. U-Clip  — grips tray/box wall edge; carries a vertical pivot pin.
//   2. Face Plate — snaps onto pin via C-clip socket; swivels to face user.
//
// CLIP_TYPE:
//   "Vertical"   — grips the thin vertical edge of a dropped tray wall.
//                  U opens at −Y; arms bracket the wall faces in X.
//                  Print: upright, no supports.
//   "Horizontal" — straddles the horizontal top rim of any wall.
//                  U opens toward bed (−Z); arms on bed, clip_top printed last.
//                  3mm inner bridge — well within FDM bridging capability.
//                  Print: upright, no supports.
//
// Face plate: label surface only (stick-on label or Bambu Studio text modifier).
//   Print: UPRIGHT — face plate stands on its bottom edge (p_w × p_t base).
//   Socket cylinder axis is vertical (Z), prints as clean C-rings, zero overhang.
//   Snap on from the +X side; 250° wrap provides friction to hold swivel angle.
//
// All three pieces print support-free in their shipped orientations.
// ==============================================================================
include <BOSL2/std.scad>
include <MasterEngine.scad>
include <MasterTolerance.scad>

// ── Private constants ─────────────────────────────────────────────────────────
_PL_CLIP_WALL_N = 4;    // clip / socket wall = N × nozzle (matches proven hinge wall)
_PL_PIN_D       = 4.0;  // pivot pin diameter — matches hinge_d throughout the system
_PL_ARM_D       = 12;   // vertical-clip arm depth (how far arms wrap the wall edge) mm
_PL_GAP         = 4;    // platter separation between clip and face plate mm

// ── Pivot pin (integral to clip, extends upward in print and in assembly) ──────
module _pl_pin(pin_d, pin_h) {
    cyl(d = pin_d, h = pin_h, chamfer2 = pin_d * 0.15, anchor = BOTTOM, $fn = 36);
}

// ── C-clip socket (on face plate top edge) ────────────────────────────────────
// Axis in world Z (vertical). Face plate prints upright → socket axis stays
// vertical → prints as clean C-rings at each layer, zero overhang.
// C-opening at +X: snap on from the side; gravity cannot pull it off.
// Anchor: BOTTOM — caller places at (0, 0, p_h) to sit above the slab.
module _pl_socket(pin_d, socket_h, tol, noz) {
    clip_wall = noz * _PL_CLIP_WALL_N;
    od = pin_d + tol * 2 + clip_wall * 2;
    id = pin_d + tol * 2;
    gap = pin_d * 0.80;  // opening width — allows snap-on, retains under friction

    difference() {
        cyl(d = od, h = socket_h, anchor = BOTTOM, $fn = 36);
        // Inner bore
        translate([0, 0, -EPS])
            cyl(d = id, h = socket_h + EPS2, anchor = BOTTOM, $fn = 36);
        // C-opening at +X
        translate([od / 4, 0, socket_h / 2])
            cuboid([od / 2 + EPS, gap, socket_h + EPS2], anchor = CENTER);
    }
}

// ── Vertical U-clip ───────────────────────────────────────────────────────────
// Grips the thin vertical edge of a dropped tray wall.
// Print: upright, clip_h in Z, U opening at −Y, no supports.
module _uclip_vertical(sw, tol, clip_wall, clip_h, pin_d, pin_h, chamf) {
    gap    = sw + tol;
    cw     = gap + clip_wall * 2;
    back_t = clip_wall;
    arm_d  = _PL_ARM_D;

    echo(str("   U-Clip [Vertical] gap=", gap, " cw=", cw, " h=", clip_h));

    union() {
        difference() {
            cuboid([cw, arm_d, clip_h], chamfer = chamf, edges = "Z", anchor = BOTTOM);
            // U channel: open at −Y, full height, back_t at +Y
            translate([0, -back_t / 2, -EPS])
                cuboid([gap, arm_d - back_t + EPS, clip_h + EPS2], anchor = BOTTOM);
        }
        // Pin on top of back wall
        translate([0, arm_d / 2 - back_t / 2, clip_h])
            _pl_pin(pin_d, pin_h);
    }
}

// ── Horizontal U-clip ─────────────────────────────────────────────────────────
// Straddles the horizontal top rim of any wall.
// Print: upright, U opens toward bed (−Z), clip_top printed last, no supports.
module _uclip_horizontal(sw, tol, clip_wall, clip_l, pin_d, pin_h, chamf) {
    gap   = sw + tol;
    arm_t = clip_wall;
    arm_h = _PL_ARM_D;
    ct    = clip_wall;
    cw    = gap + arm_t * 2;

    echo(str("   U-Clip [Horizontal] gap=", gap, " cw=", cw, " arm_h=", arm_h));

    union() {
        difference() {
            cuboid([cw, clip_l, arm_h + ct], chamfer = chamf, edges = "Z", anchor = BOTTOM);
            // U gap: open at bottom (−Z), full Y, leaving ct at top
            down(EPS)
                cuboid([gap, clip_l + EPS, arm_h + EPS], anchor = BOTTOM);
        }
        // Pin on top of clip_top
        translate([0, 0, arm_h + ct])
            _pl_pin(pin_d, pin_h);
    }
}

// ── Face plate ────────────────────────────────────────────────────────────────
// Print: UPRIGHT — stands on p_w × p_t base, p_h tall in Z.
// Socket sits on top (Z = p_h), axis vertical → prints as C-rings, no overhang.
// Blank surface for stick-on label or Bambu Studio text modifier.
// Slab thickness p_t bumped to max(p_t, od) so the socket is fully backed —
// no bridging at the socket base, clean first layer across the full od width.
module _face_plate(p_w, p_h, p_t, pin_d, socket_h, tol, noz, chamf) {
    clip_wall = noz * _PL_CLIP_WALL_N;
    od        = pin_d + tol * 2 + clip_wall * 2;
    // Embed the socket: face plate must be at least as thick as the socket diameter.
    p_t_eff   = max(p_t, od);

    echo(str("   Face Plate ", p_w, "×", p_t_eff, "×", p_h, "H",
             " socket_od=", od, " socket_h=", socket_h));

    union() {
        // Slab: p_w wide, p_t_eff thick (≥ od), p_h tall
        cuboid([p_w, p_t_eff, p_h], chamfer = chamf, edges = "Z", anchor = BOTTOM);
        // Socket on top — axis in Z, C-opening at +X, fully supported at base
        translate([0, 0, p_h])
            _pl_socket(pin_d, socket_h, tol, noz);
    }
}

// ── Factory ───────────────────────────────────────────────────────────────────
module factory_render_plaque(data, opts, phys) {
    sw    = phys[0][1];
    noz   = phys[3][1];
    lh    = m_lh(data);
    chamf = m_chamf(data);

    // Wall grip tolerance: sliding fit on wall edge
    clip_tol  = get_val(TOL_CLIP, data, breathing_room(COMP_GLIDE, data));
    // Pivot tolerance: C-clip fit on pin
    pivot_tol = breathing_room(COMP_CCLIP, data);

    clip_type = get_val(CLIP_TYPE, data, "Vertical");
    p_h       = get_val(PLAQUE_H,  data, 40);
    p_w       = get_val(PLAQUE_W,  data, 50);
    clip_h    = get_val(CLIP_H,    data, 20);

    clip_wall = noz * _PL_CLIP_WALL_N;
    pin_d     = _PL_PIN_D;
    pin_h     = min(p_h * 0.35, 12);
    socket_h  = min(p_h * 0.35, pin_h + 2);

    // Face plate thickness: ~3mm snapped to layer-height multiples
    p_t = lh * max(3, ceil(3.0 / lh));

    // Clip outer width (used for platter spacing)
    clip_gap     = sw + clip_tol;
    clip_outer_w = clip_gap + clip_wall * 2;

    echo(str("-> Factory [PLAQUE] | clip=", clip_type,
             " plate=", p_w, "×", p_t, "×", p_h, "H",
             " pin_d=", pin_d, " pin_h=", pin_h));

    // ── U-Clip at origin ──────────────────────────────────────────────────────
    if (clip_type == "Horizontal")
        _uclip_horizontal(sw, clip_tol, clip_wall, clip_h, pin_d, pin_h, chamf);
    else
        _uclip_vertical(sw, clip_tol, clip_wall, clip_h, pin_d, pin_h, chamf);

    // ── Face plate: shifted +X for platter separation ─────────────────────────
    translate([clip_outer_w / 2 + p_w / 2 + _PL_GAP, 0, 0])
        _face_plate(p_w, p_h, p_t, pin_d, socket_h, pivot_tol, noz, chamf);
}
