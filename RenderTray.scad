// ==============================================================================
// FILE: RenderTray.scad
// ARCHITECTURE: Layer 3 (Factory)
// PURPOSE: Open-top tray — plain, or stackable via Peg / Builtin / Snap modes.
//
// STACK_MODE opts:
//   "Peg"     — corner bosses + top sockets + bottom sockets. 4 standalone PEG
//               renders are kicked off separately by the manifest.
//   "Builtin" — corner bosses + built-in pegs protruding from top + bottom sockets.
//               No separate peg pieces. Pegs go into bottom sockets of tray above.
//   "Snap"    — nesting ledge below floor + snap bead at ledge bottom edge.
//               Press-fit click. Recommended filament: PETG (flex without breaking).
//
// Boss/socket constants (all modes that use corner hardware):
//   socket_d = 8mm  — peg/socket diameter
//   boss_d   = socket_d + sw*2  — outer boss cylinder diameter
//   Boss sits at each corner, inset from outer wall, runs full tray height.
// ==============================================================================
// BOSL2/std comes via MasterEngine — do NOT re-include (OpenSCAD has no include dedup; re-parse cost ~21s) [perf]
// MasterEngine is included once by MasterBuilder.scad (single owner) — not re-included here [perf]
include <RenderMesh.scad>
include <RenderGrid.scad>

// render_wall_face — wall mesh slab with mandatory solid top margin.
// Replaces a bare framed_mesh call for walls: splits into meshed lower band
// and solid upper band so lid-mechanism zones are always hole-free.
// face_w: span of wall face (container width or length).
// face_h: height of wall face.
// wall_t: wall thickness.
// Called after xrot(90)/zrot(90) already applied by the parent translate.
module render_wall_face(data, face_w, face_h, wall_t) {
    top_margin = get_val(MESH_TOP_MARGIN, data, 0);
    mesh_cfg   = get_mesh_cfg(data, HOLE_WALL, STRUT_WALL);
    h_mesh = max(0, face_h - top_margin);
    // Lower meshed band — extended by EPS into the solid band above (mirrors the
    // floor/wall EPS overlap in core_tray_chassis) so the meshed band's hole-pattern
    // border vertices don't land exactly coplanar with the solid band's bottom face,
    // which produced 4-face-sharing NM edges along the whole top-margin seam.
    if (h_mesh > 0)
        translate([0, -face_h/2 + (h_mesh+EPS)/2, 0])
            framed_mesh(data, face_w, h_mesh+EPS, wall_t, false, mesh_cfg);
    // Upper solid band — always solid regardless of strut_wall_perc
    if (top_margin > 0 && top_margin <= face_h)
        translate([0, face_h/2 - top_margin/2, 0])
            framed_mesh(data, face_w, top_margin, wall_t, false);
}

// core_tray_chassis — hollow floor + four walls. No corner clipping.
// Called by factory_render_tray and by RenderBox (which applies its own bounds).
module core_tray_chassis(data) {
    w  = m_bw(data); l  = m_bl(data); h  = m_bh(data);
    sf = m_safe_floor(data); sw = m_safe_wall(data);
    wall_h = h - sf;
    targ  = get_val(WALL_TARGET, data, "All Walls");
    mod_p = m_wall_mod_p(data) / 100;
    h_front = (targ == "Front"  || targ == "All Walls") ? max(0.1, wall_h * mod_p) : wall_h;
    h_back  = (targ == "Back"   || targ == "All Walls") ? max(0.1, wall_h * mod_p) : wall_h;
    h_left  = (targ == "Left"   || targ == "All Walls") ? max(0.1, wall_h * mod_p) : wall_h;
    h_right = (targ == "Right"  || targ == "All Walls") ? max(0.1, wall_h * mod_p) : wall_h;
    union() {
        up((sf + EPS) / 2)
            framed_mesh(data, w, l, sf + EPS, false, get_mesh_cfg(data, HOLE_FLOOR, STRUT_FLOOR));
        translate([0, -l/2 + sw/2, sf + h_front/2])
            xrot(90) render_wall_face(data, w, h_front, sw);
        translate([0,  l/2 - sw/2, sf + h_back/2])
            xrot(90) render_wall_face(data, w, h_back,  sw);
        translate([-w/2 + sw/2, 0, sf + h_left/2])
            zrot(90) xrot(90) render_wall_face(data, l, h_left,  sw);
        translate([ w/2 - sw/2, 0, sf + h_right/2])
            zrot(90) xrot(90) render_wall_face(data, l, h_right, sw);
        // Built-in grid — fused to chassis, height capped by GRID_WALL_H in data
        render_internal_grid(data);
    }
}

module factory_render_tray(data, opts, phys) {
    w  = m_bw(data); l  = m_bl(data); h  = m_bh(data);
    sf = phys[1][1]; sw = phys[0][1];
    clearance  = get_val("CLEARANCE", phys, 0.2);
    stackable  = get_val(STACKABLE,   opts, false);
    stack_mode = get_val(STACK_MODE,  opts, "Peg");

    cfg_floor = get_mesh_cfg(data, HOLE_FLOOR, STRUT_FLOOR);
    cfg_wall  = get_mesh_cfg(data, HOLE_WALL,  STRUT_WALL);
    echo(str("-> Factory [TRAY] | ", w, "x", l, "x", h,
             " | sf=", sf, " sw=", sw,
             " | stackable=", stackable,
             " | floor cfg=", cfg_floor, " wall cfg=", cfg_wall));

    // --- Boss/socket shared dimensions (Peg + Builtin modes) ---
    socket_d   = get_val(PEG_SOCKET_D,   data, 8.0);
    ledge_h    = get_val(LEDGE_DEPTH,    data, 2.0);
    boss_d     = socket_d + sw * 2;
    cx         = w/2 - sw - boss_d/2 + EPS;
    cy         = l/2 - sw - boss_d/2 + EPS;
    sock_depth = min(12.0, max(3.0, (h + ledge_h) / 2 - 1));
    peg_d      = socket_d - clearance * 2;
    peg_protr  = let(v = get_val(PEG_PROTRUSION, data, 0))
                 v > 0 ? v : max(6.0, sock_depth * 0.75);

    if (!stackable) {
        // --- Plain tray ---
        apply_master_bounds(w, l, h, m_c_rad(data), m_chamf(data))
            core_tray_chassis(data);

    } else if (stack_mode == "Peg" || stack_mode == "Builtin") {
        // --- Peg / Builtin: corner bosses + sockets ---
        // Bosses run from ledge_h below floor to top of tray, at all 4 corners.
        // Top sockets (Peg mode): accept standalone peg rods from above.
        // Built-in pegs (Builtin mode): protrude upward, go into tray above's bottom sockets.
        // Bottom sockets (both modes): accept pegs from tray below.
        difference() {
            union() {
                apply_master_bounds(w, l, h, m_c_rad(data), m_chamf(data))
                    core_tray_chassis(data);
                // Nesting ledge — smaller than outer wall so it fits inside the tray below.
                // chamfer1 on bottom edge (faces down, first contact when inserting).
                down(ledge_h)
                    apply_master_bounds(w - sw*2, l - sw*2, ledge_h,
                                        m_c_rad(data) - sw, m_chamf(data))
                    cuboid([w, l, ledge_h + EPS], anchor=BOTTOM,
                           chamfer=m_chamf(data), edges=BOTTOM);
                // 4 corner bosses — chamfer2 on top for clean edge
                for (x=[-1,1]) for (y=[-1,1])
                    translate([x*cx, y*cy, -ledge_h])
                        cyl(d=boss_d, h=h + ledge_h, anchor=BOTTOM,
                            chamfer2=m_chamf(data));
                // Builtin mode: add protruding pegs from top corners
                if (stack_mode == "Builtin")
                    for (x=[-1,1]) for (y=[-1,1])
                        translate([x*cx, y*cy, h])
                            cyl(d=peg_d, h=peg_protr, chamfer2=m_chamf(data), anchor=BOTTOM);
            }
            // Top sockets (Peg mode only — Builtin has pegs instead)
            if (stack_mode == "Peg")
                for (x=[-1,1]) for (y=[-1,1])
                    translate([x*cx, y*cy, h + EPS])
                        cyl(d=socket_d, h=sock_depth + EPS, anchor=TOP);
            // Bottom sockets (both modes — accept pegs from tray below)
            for (x=[-1,1]) for (y=[-1,1])
                translate([x*cx, y*cy, -ledge_h - EPS])
                    cyl(d=socket_d, h=sock_depth + EPS, anchor=BOTTOM);
        }

    } else if (stack_mode == "Snap") {
        // --- Snap: nesting ledge + snap bead at ledge bottom edge ---
        // The ledge fits inside the tray below. The bead (diamond cross-section,
        // all faces ≤45°) cams past the lower tray's inner wall and retains.
        // Recommended: PETG — flexes enough for click, won't snap like PLA.
        bead_r = m_noz(data);
        union() {
            apply_master_bounds(w, l, h, m_c_rad(data), m_chamf(data))
                core_tray_chassis(data);
            // Nesting ledge — bottom edge chamfered to guide insertion into tray below
            down(ledge_h)
                apply_master_bounds(w - sw*2, l - sw*2, ledge_h,
                                    m_c_rad(data) - sw, m_chamf(data))
                cuboid([w, l, ledge_h + EPS], anchor=BOTTOM,
                       chamfer=m_chamf(data), edges=BOTTOM);
            // Snap bead — diamond cross-section ring at bottom of ledge.
            // All faces at 45°: support-free in print orientation.
            down(ledge_h)
                difference() {
                    apply_master_bounds(w - sw*2, l - sw*2, bead_r * 2,
                                        m_c_rad(data) - sw, 0)
                        cuboid([w - sw*2 + bead_r*2, l - sw*2 + bead_r*2, bead_r*2],
                               anchor=BOTTOM);
                    // Hollow out interior — leaves only the outer bead ring
                    cuboid([w - sw*2 - bead_r*2, l - sw*2 - bead_r*2, bead_r*4],
                           anchor=BOTTOM);
                    // 45° chamfers top and bottom for diamond profile
                    up(bead_r) rotate_extrude()
                        translate([max(w,l)/2, 0, 0])
                        rotate(45) square(bead_r * sqrt(2), center=true);
                }
        }
    }
}
