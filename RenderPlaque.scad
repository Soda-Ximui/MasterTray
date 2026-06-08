// ==============================================================================
// FILE: RenderPlaque.scad
// ARCHITECTURE: Layer 3 (Factory)
// PURPOSE: Label plaque system for tray / box walls and lids.
//
// PLAQUE_TARGET:
//   "Wall" — U-Clip + swivel face plate. Emits two pieces side by side.
//            Clip grips the wall edge; face plate snaps onto pivot pin and
//            swivels to face the user regardless of clip orientation.
//   "Lid"  — Face plate only (flat back). Adhesive-mount on any flat lid or
//            box surface. Single piece. No clip, no socket, no swivel.
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
// Face plate (both targets):
//   Print: UPRIGHT — stands on p_w × p_t_eff base, p_h tall in Z.
//   All edges chamfered. Label surface for stick-on label or Bambu text modifier.
//   Wall variant: C-clip socket on top, axis vertical → C-rings, zero overhang.
//   Lid  variant: plain flat top — no socket needed.
//   p_t_eff = max(p_t_nominal, socket_od) so the socket base is fully backed.
//
// All pieces print support-free in their shipped orientations.
// ==============================================================================
include <BOSL2/std.scad>
include <MasterEngine.scad>
include <MasterTolerance.scad>

// ── Private constants ─────────────────────────────────────────────────────────
_PL_CLIP_WALL_N = 4;    // clip / socket wall = N × nozzle (matches proven hinge wall)
_PL_PIN_D       = 4.0;  // pivot pin diameter — matches hinge_d throughout the system
_PL_ARM_D       = 12;   // vertical-clip arm depth (how far arms wrap the wall edge) mm
_PL_GAP         = 4;    // platter separation between pieces mm

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
            cyl(d = id, h = socket_h + EPS2, anchor = BOTTOM, $fn = 36);
        // C-opening slab at +X
        translate([od / 4, 0, socket_h / 2])
            cuboid([od / 2 + EPS, gap, socket_h + EPS2], anchor = CENTER);
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
                cuboid([gap, arm_d - back_t + EPS, clip_h + EPS2], anchor = BOTTOM);
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

// ── Face plate (shared by Wall and Lid targets) ───────────────────────────────
// Print: UPRIGHT — p_w × p_t_eff base, p_h tall. All edges chamfered.
// Wall variant (has_socket=true):  C-clip socket on top, axis in Z.
//   p_t_eff = max(p_t, socket_od) — socket base fully backed, no bridging.
// Lid  variant (has_socket=false): plain flat top, thinner (p_t nominal only).
module _face_plate(p_w, p_h, p_t, pin_d, socket_h, tol, noz, chamf, has_socket) {
    clip_wall = noz * _PL_CLIP_WALL_N;
    od        = pin_d + tol * 2 + clip_wall * 2;
    p_t_eff   = has_socket ? max(p_t, od) : p_t;

    echo(str("   Face Plate ", p_w, "×", p_t_eff, "×", p_h, "H",
             has_socket ? str(" socket_od=", od, " socket_h=", socket_h) : " [Lid/flat]"));

    union() {
        cuboid([p_w, p_t_eff, p_h], chamfer = chamf, anchor = BOTTOM);
        if (has_socket)
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

    if (target == "Lid") {
        // ── Lid variant: face plate only, flat back, adhesive mount ──────────
        _face_plate(p_w, p_h, p_t, pin_d, socket_h, pivot_tol, noz, chamf, false);

    } else {
        // ── Wall variant: U-Clip + swivel face plate ──────────────────────────
        clip_gap     = sw + clip_tol;
        clip_outer_w = clip_gap + clip_wall * 2;

        if (clip_type == "Horizontal")
            _uclip_horizontal(sw, clip_tol, clip_wall, clip_h, pin_d, pin_h, chamf);
        else
            _uclip_vertical(sw, clip_tol, clip_wall, clip_h, pin_d, pin_h, chamf);

        translate([clip_outer_w / 2 + p_w / 2 + _PL_GAP, 0, 0])
            _face_plate(p_w, p_h, p_t, pin_d, socket_h, pivot_tol, noz, chamf, true);
    }
}
