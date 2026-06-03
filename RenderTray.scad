// ==============================================================================
// FILE: RenderTray.scad
// ARCHITECTURE: Layer 3 (Factory)
// PURPOSE: Hollow open-top tray — floor + four walls with mesh support,
//          per-wall height modification, and corner rounding.
// ==============================================================================
include <BOSL2/std.scad>
include <MasterEngine.scad>
include <RenderMesh.scad>

// core_tray_chassis(data)
// Inner hollow chassis: floor slab + four wall slabs, no corner clipping.
// Used directly by RenderBox (which applies its own bounds after groove cuts).
// All dimensions and safety values derived from data.
module core_tray_chassis(data) {
    w  = m_bw(data);
    l  = m_bl(data);
    h  = m_bh(data);
    sf = m_safe_floor(data);
    sw = m_safe_wall(data);

    wall_h = h - sf;
    targ   = get_val(WALL_TARGET, data, "All Walls");
    mod_p  = m_wall_mod_p(data) / 100;

    h_front = (targ == "Front"  || targ == "All Walls") ? max(0.1, wall_h * mod_p) : wall_h;
    h_back  = (targ == "Back"   || targ == "All Walls") ? max(0.1, wall_h * mod_p) : wall_h;
    h_left  = (targ == "Left"   || targ == "All Walls") ? max(0.1, wall_h * mod_p) : wall_h;
    h_right = (targ == "Right"  || targ == "All Walls") ? max(0.1, wall_h * mod_p) : wall_h;

    union() {
        // Floor
        up(sf / 2)
            framed_mesh(data, w, l, sf, false,
                        get_mesh_cfg(data, HOLE_FLOOR, STRUT_FLOOR));

        // Front wall (−Y face)
        translate([0, -l/2 + sw/2, sf + h_front/2])
            xrot(90)
            framed_mesh(data, w, h_front, sw, false,
                        get_mesh_cfg(data, HOLE_WALL, STRUT_WALL));

        // Back wall (+Y face)
        translate([0, l/2 - sw/2, sf + h_back/2])
            xrot(90)
            framed_mesh(data, w, h_back, sw, false,
                        get_mesh_cfg(data, HOLE_WALL, STRUT_WALL));

        // Left wall (−X face)
        translate([-w/2 + sw/2, 0, sf + h_left/2])
            zrot(90) xrot(90)
            framed_mesh(data, l, h_left, sw, false,
                        get_mesh_cfg(data, HOLE_WALL, STRUT_WALL));

        // Right wall (+X face)
        translate([w/2 - sw/2, 0, sf + h_right/2])
            zrot(90) xrot(90)
            framed_mesh(data, l, h_right, sw, false,
                        get_mesh_cfg(data, HOLE_WALL, STRUT_WALL));
    }
}

module factory_render_tray(data, opts, phys) {
    w = m_bw(data); l = m_bl(data); h = m_bh(data);
    sf = phys[1][1]; sw = phys[0][1];
    cfg_floor = get_mesh_cfg(data, HOLE_FLOOR, STRUT_FLOOR);
    cfg_wall  = get_mesh_cfg(data, HOLE_WALL,  STRUT_WALL);
    echo(str("-> Factory [TRAY] | ", w, "x", l, "x", h,
             " | sf=", sf, " sw=", sw,
             " | floor cfg=", cfg_floor,
             " | wall cfg=",  cfg_wall));
    apply_master_bounds(w, l, h, m_c_rad(data), m_chamf(data))
        core_tray_chassis(data);
}
