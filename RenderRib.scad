// ==============================================================================
// FILE: RenderRib.scad [v1.5]
// ARCHITECTURE: Layer 2.2 (FrankenTray Vector Generator)
// PURPOSE: Dedicated geometry builder for radial/vector-based Rib topologies.
// ==============================================================================

include <BOSL2/std.scad>
include <GridLayout.scad>
include <MasterBug.scad>
include <MasterUtility.scad> 

module render_franken_ribs(data) {
    g_str = get_val(GRID_LAYOUT, data, "");
    cfg = parse_franken_config(g_str);
    
    if (cfg != undef) {
        log_franken_state(cfg, g_str);
        
        rays = cfg[0];
        hub_d = cfg[1];
        anchor = cfg[2];
        ribs = cfg[3];
        
        bh = m_bh(data);
        sf = m_safe_floor(data);
        sw = m_safe_wall(data);
        sl = m_safe_lid(data);
        div_t = get_val(THICK_DIVIDER, data, 1.2);
        
        type = get_val(TYPE, data, BOX);
        is_closed = (type == BOX || type == FLIP_BOX || type == JAR_LID || type == DOUBLE_FLIP_BOX || type == DESICCANT_BOX);
        is_jar = (type == JAR || type == JAR_LID || type == JAR_GRID || type == PLAQUE_JAR);
        
        int_w = m_bw(data) - sw*2 - 0.4;
        int_l = m_bl(data) - sw*2 - 0.4;
        int_h = bh - sf - (is_closed ? sl : 0);
        
        ox = anchor[0];
        oy = anchor[1];

        if (is_jar) {
            intersection() {
                cyl(d=int_w, h=int_h, anchor=BOTTOM);
                translate([ox, oy, 0]) {
                    if (hub_d > 0) cyl(d=hub_d, h=int_h, anchor=BOTTOM);
                    if (len(ribs) > 0) {
                        for(i = [0 : len(ribs)-1]) {
                            traj = ribs[i][0]; beh = ribs[i][1];
                            theta = get_rib_angle(traj, int_w, int_l, ox, oy);
                            L = get_rib_length(theta, beh, traj, ox, oy, int_w, int_l, is_jar);
                            zrot(theta) cuboid([L, div_t, int_h], anchor=BOTTOM+LEFT);
                        }
                    }
                }
            }
        } else {
            apply_master_bounds(int_w, int_l, int_h, m_c_rad(data)-sw, m_chamf(data)/2) {
                translate([ox, oy, 0]) {
                    if (hub_d > 0) cyl(d=hub_d, h=int_h, anchor=BOTTOM);
                    if (len(ribs) > 0) {
                        for(i = [0 : len(ribs)-1]) {
                            traj = ribs[i][0]; beh = ribs[i][1];
                            theta = get_rib_angle(traj, int_w, int_l, ox, oy);
                            L = get_rib_length(theta, beh, traj, ox, oy, int_w, int_l, is_jar);
                            zrot(theta) cuboid([L, div_t, int_h], anchor=BOTTOM+LEFT);
                        }
                    }
                }
            }
        }
    }
}