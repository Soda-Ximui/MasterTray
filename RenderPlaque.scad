// ==============================================================================
// FILE: RenderPlaque.scad
// ARCHITECTURE: Layer 3 (Factory)
// PURPOSE: Swivel-face-plate label / text plaque system.
//
// Emits TWO print-ready pieces side by side on the platter:
//   1. U-Clip  — grips tray/box wall edge; carries a vertical pivot pin.
//   2. Face Plate — snaps onto pin via C-clip socket; swivels to face user.
//
// CLIP_TYPE:
//   "Vertical"   — grips the thin vertical edge of a dropped tray wall.
//                  U opens at −Y; arms bracket the wall faces in X.
//                  Print: upright, clip_h in Z, no supports needed.
//   "Horizontal" — straddles the horizontal top rim of any wall.
//                  U opens toward bed (−Z); arms on bed, clip_top printed last.
//                  The 3mm bridge inside the U is well within FDM capability.
//                  Print: right-side up, no supports, no flipping.
//
// PLAQUE_STYLE:
//   "Label"  — blank smooth surface, ready for a stick-on label.
//   "Text"   — text engraved into face, auto-sized to fit width,
//              hard-clipped to plate boundary as last resort.
//
// Swivel: pivot pin on clip is vertical in assembly. Face plate hangs
//   below the pin via a C-clip socket at the plate's top edge. Rotating
//   the plate around the pin (assembly Z = rotation around print Y) sweeps
//   it to face the user regardless of which way the clip is oriented on the wall.
//   Snap on from the +X side; friction holds angle. No explicit detents —
//   the 250° C-clip wrap provides enough friction for a label in normal use.
//
// Socket Z-range note: socket diameter > face plate thickness. Socket center
//   placed at Z = od/2 from bed so the socket bottom sits at Z = 0 (supported
//   by the face plate from the start). Above Z = p_t the socket is already at
//   ~98% of max radius — negligible unsupported overhang (~0.08 mm per layer).
//   Same root cause as B4 (glide ball) — pre-empted here by design.
//
// Print orientations:
//   U-Clip (Vertical):   upright, U opens at −Y face.
//   U-Clip (Horizontal): upright, U opens toward bed (−Z).
//   Face Plate:          face-down (engraved / label surface on bed).
// ==============================================================================
include <BOSL2/std.scad>
include <MasterEngine.scad>
include <MasterTolerance.scad>
include <MasterText.scad>

// ── Private constants ─────────────────────────────────────────────────────────
_PL_CLIP_WALL_N = 4;    // clip / socket wall = N × nozzle (matches proven hinge wall)
_PL_PIN_D       = 4.0;  // pivot pin diameter — matches hinge_d throughout the system
_PL_WRAP_DEG    = 250;  // C-clip socket wrap angle; >180° required for retention
_PL_ARM_D       = 12;   // vertical-clip arm depth (how far arms wrap the wall edge) mm
_PL_GAP         = 4;    // platter separation between clip and face plate mm

// ── Helper: auto-size text to fit available_w ─────────────────────────────────
// Uses the same 0.65 kerning multiplier as get_text_plaque_width.
// Returns the largest size ≤ want_size that fits; floors at min_size.
function _pl_text_size(txt, available_w, want_size, min_size = 3) =
    len(txt) == 0 ? want_size :
    let(fits = want_size * len(txt) * 0.65 <= available_w)
    fits ? want_size
         : max(min_size, available_w / (len(txt) * 0.65));

// ── Pivot pin (integral to clip, extends upward in print and in assembly) ──────
module _pl_pin(pin_d, pin_h) {
    cyl(d = pin_d, h = pin_h, chamfer2 = pin_d * 0.15, anchor = BOTTOM, $fn = 36);
}

// ── C-clip socket (on face plate top edge) ────────────────────────────────────
// Cylinder axis in local Z; caller applies rotate([-90,0,0]) so axis becomes
// world +Y (print). In assembly (face plate vertical) this becomes world +Z.
// C-opening at +X: snap on from the side; gravity cannot pull it off.
module _pl_socket(pin_d, socket_h, tol, noz) {
    clip_wall = noz * _PL_CLIP_WALL_N;
    od = pin_d + tol * 2 + clip_wall * 2;
    id = pin_d + tol * 2;
    gap = pin_d * 0.80;  // opening width — allows snap-on, retains under friction

    difference() {
        cyl(d = od, h = socket_h, anchor = CENTER, $fn = 36);
        // Inner bore — pin + tolerance
        cyl(d = id, h = socket_h + EPS2, anchor = CENTER, $fn = 36);
        // C-opening slab at +X (from centre to +X face)
        // cuboid centred at (od/4, 0, 0) spans X: 0→od/2, Y: ±gap/2
        translate([od / 4, 0, 0])
            cuboid([od / 2 + EPS, gap, socket_h + EPS2], anchor = CENTER);
    }
}

// ── Vertical U-clip ───────────────────────────────────────────────────────────
// Grips the thin vertical edge of a dropped tray wall.
// Print: upright, clip_h in Z, U opening at −Y, no supports.
// Gap (sw + tol) is in X; arms bracket both faces of the wall edge.
// Pin sits on top of the back wall, centred in X.
module _uclip_vertical(sw, tol, clip_wall, clip_h, pin_d, pin_h, chamf) {
    gap    = sw + tol;
    cw     = gap + clip_wall * 2;   // outer clip width in X
    back_t = clip_wall;             // back-wall thickness in Y
    arm_d  = _PL_ARM_D;            // U depth in Y

    echo(str("   U-Clip [Vertical] gap=", gap, " cw=", cw, " h=", clip_h));

    union() {
        difference() {
            cuboid([cw, arm_d, clip_h], chamfer = chamf, edges = "Z", anchor = BOTTOM);
            // U channel: open at −Y, full height, leaving back_t at +Y
            // Cutter centred at Y = −back_t/2, depth = arm_d − back_t
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
// Print: right-side up, U opening toward bed (−Z), clip_top printed last.
//   Arms sit on bed; the gap between arms is open toward bed.
//   The inner bridge (sw + tol ≈ 3 mm) is well within FDM bridging capability.
// Assembly: clip is already in correct orientation — no flipping needed.
//   Clip_top lands on top of wall; arms grip both wall faces; pin points up.
// Gap (sw + tol) is in X; arms extend downward (−Z) from clip_top.
module _uclip_horizontal(sw, tol, clip_wall, clip_l, pin_d, pin_h, chamf) {
    gap   = sw + tol;
    arm_t = clip_wall;              // arm wall thickness in X
    arm_h = _PL_ARM_D;             // arm height in Z
    ct    = clip_wall;              // clip_top thickness in Z
    cw    = gap + arm_t * 2;       // outer clip width in X

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
// Printed face-down (label / engraved surface on bed for best finish).
// C-clip socket at top assembly edge (+Y in print) snaps onto the clip pin.
// Socket axis = Y in print → Z (vertical) in assembly → aligns with pin. ✓
//
// Socket placement (Z-range pre-emption):
//   od (socket outer diameter) > p_t (face plate thickness).
//   Centre at Z = od/2 so socket bottom is at Z = 0 (bed-supported from start).
//   Above Z = p_t the socket is already at ~98% of max radius — trivial overhang.
module _face_plate(p_w, p_h, p_t, txt, want_size, style, pin_d, pin_h, tol, noz, lh, chamf) {
    clip_wall = noz * _PL_CLIP_WALL_N;
    od        = pin_d + tol * 2 + clip_wall * 2;
    socket_h  = min(p_h * 0.35, pin_h + 2);    // engagement height
    margin    = noz * 4;
    avail_w   = p_w - margin * 2;
    eff_size  = _pl_text_size(txt, avail_w, want_size);

    echo(str("   Face Plate ", p_w, "×", p_h, "×", p_t,
             " style=", style, " text_size=", eff_size,
             " socket_od=", od, " socket_h=", socket_h));

    union() {
        // ── Face plate slab ───────────────────────────────────────────────────
        difference() {
            cuboid([p_w, p_h, p_t], chamfer = chamf, edges = "Z", anchor = BOTTOM);
            // Engrave text: cut lh deep from top face (only Text style + non-empty)
            if (style == "Text" && txt != "")
                translate([0, 0, p_t - lh])
                    // Hard clip to plate boundary — last-resort containment
                    intersection() {
                        cuboid([avail_w, p_h - margin * 2, lh + EPS], anchor = BOTTOM);
                        render_embossed_text(txt, eff_size, lh + EPS);
                    }
        }

        // ── C-clip socket ─────────────────────────────────────────────────────
        // Placed at top edge (Y = p_h/2) with cylinder axis in world +Y.
        // Centre in Z at od/2 so bottom of socket is at bed (Z = 0).
        // rotate([-90,0,0]) maps local +Z → world +Y.
        translate([0, p_h / 2, od / 2])
            rotate([-90, 0, 0])
                _pl_socket(pin_d, socket_h, tol, noz);
    }
}

// ── Factory ───────────────────────────────────────────────────────────────────
module factory_render_plaque(data, opts, phys) {
    sw    = phys[0][1];
    noz   = phys[3][1];
    lh    = m_lh(data);
    chamf = m_chamf(data);

    // Wall grip tolerance: sliding/snap fit on wall edge
    clip_tol  = get_val(TOL_CLIP, data, breathing_room(COMP_GLIDE, data));
    // Pivot tolerance: C-clip fit on pin
    pivot_tol = breathing_room(COMP_CCLIP, data);

    clip_type  = get_val(CLIP_TYPE,        data, "Vertical");
    style      = get_val(PLAQUE_STYLE,     data, "Label");
    txt        = get_val(PLAQUE_TEXT,      data, "");
    want_size  = get_val(PLAQUE_TEXT_SIZE, data, 8);
    explicit_w = get_val(PLAQUE_W,         data, 0);
    p_h        = get_val(PLAQUE_H,         data, 35);
    clip_h     = get_val(CLIP_H,           data, 20);

    clip_wall  = noz * _PL_CLIP_WALL_N;
    pin_d      = _PL_PIN_D;
    pin_h      = min(p_h * 0.35, 12);

    // Face plate thickness: ~3mm snapped to layer-height multiples
    p_t = lh * max(3, ceil(3.0 / lh));
    // Face plate width: honour explicit PLAQUE_W or auto-size from text
    p_w = explicit_w > 0 ? explicit_w : get_text_plaque_width(txt, want_size);

    // Clip outer width (used for platter spacing)
    clip_gap    = sw + clip_tol;
    clip_outer_w = clip_gap + clip_wall * 2;

    echo(str("-> Factory [PLAQUE] | clip=", clip_type, " style=", style,
             " text='", txt, "' plate=", p_w, "×", p_h, "×", p_t,
             " pin_d=", pin_d, " pin_h=", pin_h));

    // ── U-Clip at origin ──────────────────────────────────────────────────────
    if (clip_type == "Horizontal")
        _uclip_horizontal(sw, clip_tol, clip_wall, clip_h, pin_d, pin_h, chamf);
    else
        _uclip_vertical(sw, clip_tol, clip_wall, clip_h, pin_d, pin_h, chamf);

    // ── Face plate: shifted +X for platter separation ─────────────────────────
    // Placed face-down (Z = 0 = label/text surface on bed).
    translate([clip_outer_w / 2 + p_w / 2 + _PL_GAP, 0, 0])
        _face_plate(p_w, p_h, p_t, txt, want_size, style,
                    pin_d, pin_h, pivot_tol, noz, lh, chamf);
}
