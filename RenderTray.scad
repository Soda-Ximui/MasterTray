// ==============================================================================
// FILE: RenderTray.scad
// ARCHITECTURE: Layer 2.1 (Domain Module)
// ==============================================================================
include <RenderGrid.scad>
module core_tray_chassis(data) {
    bw = m_bw(data);
    bl = m_bl(data); bh = m_bh(data); sf = m_safe_floor(data); sw = m_safe_wall(data); actual_wall_h = bh - sf;
    targ = get_val(WALL_TARGET, data, "All Walls"); mod_p = m_wall_mod_p(data) / 100;
    h_front = (targ == "Front" || targ == "All Walls") ? max(0.1, actual_wall_h * mod_p) : actual_wall_h;
    h_back  = (targ == "Back" || targ == "All Walls") ? max(0.1, actual_wall_h * mod_p) : actual_wall_h;
    h_left  = (targ == "Left" || targ == "All Walls") ? max(0.1, actual_wall_h * mod_p) : actual_wall_h;
    h_right = (targ == "Right" || targ == "All Walls") ? max(0.1, actual_wall_h * mod_p) : actual_wall_h;
    union() {
        up(sf / 2) framed_mesh(data, bw, bl, sf, false, get_mesh_cfg(data, HOLE_FLOOR, STRUT_FLOOR));
        translate([0, -bl / 2 + sw / 2, (sf + h_front / 2)]) xrot(90) framed_mesh(data, bw, h_front, sw, false, get_mesh_cfg(data, HOLE_WALL, STRUT_WALL));
        translate([0, bl / 2 - sw / 2, (sf + h_back / 2)]) xrot(90) framed_mesh(data, bw, h_back, sw, false, get_mesh_cfg(data, HOLE_WALL, STRUT_WALL));
        translate([-bw / 2 + sw / 2, 0, (sf + h_left / 2)]) zrot(90) xrot(90) framed_mesh(data, bl, h_left, sw, false, get_mesh_cfg(data, HOLE_WALL, STRUT_WALL));
        translate([bw / 2 - sw / 2, 0, (sf + h_right / 2)]) zrot(90) xrot(90) framed_mesh(data, bl, h_right, sw, false, get_mesh_cfg(data, HOLE_WALL, STRUT_WALL));
        render_internal_grid(data); 
    }
}

module render_tray_simple(data) { apply_master_bounds(m_bw(data), m_bl(data), m_bh(data), m_c_rad(data), m_chamf(data)) { core_tray_chassis(data);
} }

module render_tray_stack_nest(data) {
    bw = m_bw(data); bl = m_bl(data); sw = m_safe_wall(data);
    union() {
        render_tray_simple(data);
        down(2) apply_master_bounds(bw-sw*2, bl-sw*2, 2, m_c_rad(data)-sw, m_chamf(data)) cuboid([bw, bl, 2.1], anchor=BOTTOM);
    }
}

module render_tray_stack_peg(data) { 
    bw = m_bw(data); bl = m_bl(data); bh = m_bh(data); sw = m_safe_wall(data);
    socket_d = 8.0; boss_d = socket_d + sw*2; cx = bw/2 - sw - boss_d/2 + 0.1;
    cy = bl/2 - sw - boss_d/2 + 0.1; 
    max_total_z = bh + 2.1;
    safe_top_depth = min(12.0, max(3.0, (max_total_z / 2) - 1)); safe_bot_depth = min(12.0, max(3.0, (max_total_z / 2) - 1));
    difference() {
        union() { 
            render_tray_simple(data);
            down(2) apply_master_bounds(bw-sw*2, bl-sw*2, 2, m_c_rad(data)-sw, m_chamf(data)) cuboid([bw, bl, 2.1], anchor=BOTTOM); 
            for(x=[-1,1]) for(y=[-1,1]) translate([x*cx, y*cy, -2]) cyl(d=boss_d, h=bh + 2, anchor=BOTTOM);
        }
        for(x=[-1,1]) for(y=[-1,1]) {
            translate([x*cx, y*cy, bh + 0.1]) cyl(d=socket_d, h=safe_top_depth + 0.1, anchor=TOP);
            translate([x*cx, y*cy, -2.1]) cyl(d=socket_d, h=safe_bot_depth + 0.1, anchor=BOTTOM);
        }
    }
}

module render_peg(data) {
    p_len = get_val(PEG_HEIGHT, data, 80);
    tol = get_val(TOL_CLIP, data, 0.1); p_dia = 8.0 - (tol * 2); 
    difference() { yrot(90) cyl(d=p_dia, h=p_len, chamfer=0.5, anchor=CENTER);
    down(p_dia/2) cuboid([p_len + 2, p_dia + 2, 1], anchor=BOTTOM); }
}