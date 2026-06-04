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
include <BOSL2/std.scad>
include <MasterEngine.scad>
include <RenderMesh.scad>

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
        up(sf / 2)
            framed_mesh(data, w, l, sf, false, get_mesh_cfg(data, HOLE_FLOOR, STRUT_FLOOR));
        translate([0, -l/2 + sw/2, sf + h_front/2])
            xrot(90) framed_mesh(data, w, h_front, sw, false, get_mesh_cfg(data, HOLE_WALL, STRUT_WALL));
        translate([0,  l/2 - sw/2, sf + h_back/2])
            xrot(90) framed_mesh(data, w, h_back,  sw, false, get_mesh_cfg(data, HOLE_WALL, STRUT_WALL));
        translate([-w/2 + sw/2, 0, sf + h_left/2])
            zrot(90) xrot(90) framed_mesh(data, l, h_left,  sw, false, get_mesh_cfg(data, HOLE_WALL, STRUT_WALL));
        translate([ w/2 - sw/2, 0, sf + h_right/2])
            zrot(90) xrot(90) framed_mesh(data, l, h_right, sw, false, get_mesh_cfg(data, HOLE_WALL, STRUT_WALL));
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
    cx         = w/2 - sw - boss_d/2 + 0.1;
    cy         = l/2 - sw - boss_d/2 + 0.1;
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
                    cuboid([w, l, ledge_h + 0.1], anchor=BOTTOM,
                           chamfer1=m_chamf(data));
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
                    translate([x*cx, y*cy, h + 0.1])
                        cyl(d=socket_d, h=sock_depth + 0.1, anchor=TOP);
            // Bottom sockets (both modes — accept pegs from tray below)
            for (x=[-1,1]) for (y=[-1,1])
                translate([x*cx, y*cy, -ledge_h - 0.1])
                    cyl(d=socket_d, h=sock_depth + 0.1, anchor=BOTTOM);
        }

    } else if (stack_mode == "Snap") {
        // --- Snap: nesting ledge + snap bead at ledge bottom edge ---
        // The ledge fits inside the tray below. The bead (diamond cross-section,
        // all faces ≤45°) cams past the lower tray's inner wall and retains.
        // Recommended: PETG — flexes enough for click, won't snap like PLA.
        bead_r = nozzle_d = m_noz(data);
        union() {
            apply_master_bounds(w, l, h, m_c_rad(data), m_chamf(data))
                core_tray_chassis(data);
            // Nesting ledge
            down(ledge_h)
                apply_master_bounds(w - sw*2, l - sw*2, ledge_h,
                                    m_c_rad(data) - sw, m_chamf(data))
                cuboid([w, l, ledge_h + 0.1], anchor=BOTTOM);
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
