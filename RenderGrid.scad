// ==============================================================================
// FILE: RenderGrid.scad [v3.3]
// ARCHITECTURE: Layer 2.1 (Domain Module)
// PURPOSE: Context-Aware Grid Generation (Cartesian, Radial, and Vector Overlays)
// ==============================================================================

include <BOSL2/std.scad>
include <GridLayout.scad>
include <RenderRib.scad> 

module render_internal_grid(data) {
    debug_grid_parser(data);
    
    if (get_val(HAS_BUILTIN_GRID, data, false)) {
        type = get_val(TYPE, data, BOX);
        cfg = get_grid_config(data);
        rays = cfg[1][0]; 
        
        if (type == JAR) {
            if (rays > 0) { render_jar_grid_core(data, true); } 
            else { render_box_grid_core(data, true); }
        } else {
            render_box_grid_core(data, true);
        }
        render_franken_ribs(data);
    }
}

module render_box_grid(data) {
    render_box_grid_core(data, false);
    cfg = get_grid_config(data);
    up(cfg[4]) render_franken_ribs(data); 
}

module render_jar_grid(data) {
    render_jar_grid_core(data, false);
    cfg = get_grid_config(data);
    up(cfg[4]) render_franken_ribs(data); 
}

module render_cartesian_walls(cols, rows, spans, int_w, int_l, default_h, div_t) {
    cw = (int_w - (div_t * (cols - 1))) / cols;
    cl = (int_l - (div_t * (rows - 1))) / rows;
    
    if (cols > 1) {
        for(i=[1:cols-1]) {
            translate([-int_w/2 + i*(cw + div_t) - div_t/2, 0, default_h/2])
                cuboid([div_t, int_l, default_h], anchor=CENTER);
        }
    }
    if (rows > 1) {
        for(i=[1:rows-1]) {
            translate([0, int_l/2 - i*(cl + div_t) + div_t/2, default_h/2])
                cuboid([int_w, div_t, default_h], anchor=CENTER);
        }
    }
    if (len(spans) > 0) {
        for (s = spans) {
            start_c = s[0]; start_r = s[1]; span_c = s[2]; span_r = s[3]; h = s[4];
            s_w = (cw * span_c) + (div_t * (span_c - 1));
            s_l = (cl * span_r) + (div_t * (span_r - 1));
            pos_x = -int_w/2 + (start_c - 1)*(cw + div_t) + s_w/2;
            pos_y = int_l/2 - (start_r - 1)*(cl + div_t) - s_l/2;
            translate([pos_x, pos_y, h/2])
                cuboid([s_w, s_l, h], anchor=CENTER);
        }
    }
}

module render_box_grid_core(data, is_builtin=false) {
    bw = m_bw(data); bl = m_bl(data); bh = m_bh(data); sf = m_safe_floor(data); sw = m_safe_wall(data);
    div_t = get_val(THICK_DIVIDER, data, 1.2);
    int_w = bw - sw*2 - (is_builtin ? 0 : 0.4); 
    int_l = bl - sw*2 - (is_builtin ? 0 : 0.4); 
    
    cfg = get_grid_config(data);
    cols = cfg[0][0]; 
    rows = cfg[0][1]; 
    spans = cfg[2]; 
    has_base = cfg[3]; 
    base_t = cfg[4]; 
    default_h = cfg[5];
    
    union() {
        apply_master_bounds(int_w, int_l, default_h + base_t, m_c_rad(data)-sw, m_chamf(data)/2) {
            if (has_base) cuboid([int_w, int_l, base_t], anchor=BOTTOM);
            up(base_t) {
                if (cols > 1 || rows > 1 || len(spans) > 0) {
                    render_cartesian_walls(cols, rows, spans, int_w, int_l, default_h, div_t);
                }
            }
        }
    }
}

module render_jar_grid_core(data, is_builtin=false) {
    bw = m_bw(data); bh = m_bh(data); sf = m_safe_floor(data); sw = m_safe_wall(data); 
    div_t = get_val(THICK_DIVIDER, data, 1.2);
    int_h = bh - sf - (get_val(HAS_THREADS, data, false) ? 8.0 + sw*1.5 : 0) - 0.5;
    int_d = bw - sw*2 - (is_builtin ? 0 : 0.4); 
    
    cfg = get_grid_config(data);
    rays = cfg[1][0]; 
    c_dia = cfg[1][1]; 
    has_base = cfg[3]; 
    base_t = cfg[4];
    
    union() {
        if (has_base) cyl(d=int_d, h=base_t, anchor=BOTTOM);
        up(base_t) {
            intersection() {
                cyl(d=int_d, h=int_h, anchor=BOTTOM);
                union() {
                    if (c_dia > 0) { cyl(d=c_dia, h=int_h, anchor=BOTTOM); }
                    if (rays > 0) {
                        for(i=[0:rays-1]) {
                            zrot(i * (360/rays)) translate([0, -div_t/2, 0]) 
                                cuboid([int_d/2, div_t, int_h], anchor=BOTTOM+LEFT);
                        }
                    }
                }
            }
        }
    }
}