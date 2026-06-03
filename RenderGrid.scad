// ==============================================================================
// FILE: RenderGrid.scad
// ARCHITECTURE: Layer 2.1 (Domain Module)
// PURPOSE: Context-Aware Grid Generation (Decoupled Cartesian/Radial)
// ==============================================================================

include <BOSL2/std.scad>
include <GridLayout.scad>

module render_internal_grid(data) {
    debug_grid_parser(data);
    if (get_val(HAS_BUILTIN_GRID, data, false)) {
        type = get_val(TYPE, data, BOX);
        cfg = get_grid_config(data);
        rays = cfg[1][0]; 
        
        if (type == JAR) {
            // Prevent builtin fusion: prioritize radial, fallback to circular cartesian
            if (rays > 0) { render_jar_grid_core(data, true); } 
            else { render_box_grid_core(data, true); }
        } else {
            render_box_grid_core(data, true);
        }
    }
}

module render_box_grid(data) {
    render_box_grid_core(data, false);
}

module render_jar_grid(data) {
    render_jar_grid_core(data, false);
}

// --- HELPER: ABSTRACT CARTESIAN WALLS ---
// Generates raw rectangular walls and spans; parent modules handle the clipping
module render_cartesian_walls(cols, rows, spans, int_w, int_l, default_h, div_t) {
    difference() {
        union() {
            for(i=[1:cols-1]) translate([-int_w/2 + i*(int_w/cols), 0, default_h/2]) 
                cuboid([div_t, int_l, default_h], anchor=CENTER);
            for(j=[1:rows-1]) translate([0, -int_l/2 + j*(int_l/rows), default_h/2]) 
                cuboid([int_w, div_t, default_h], anchor=CENTER);
        }
        for(s = spans) {
            cell_w = int_w / cols; cell_l = int_l / rows;
            start_x = -int_w/2 + (s[1]-1)*cell_w; start_y = int_l/2 - (s[0]-1)*cell_l;
            cavity_w = (cell_w * s[3]) - div_t - 0.1; cavity_l = (cell_l * s[2]) - div_t - 0.1;
            translate([start_x + (cell_w*s[3])/2, start_y - (cell_l*s[2])/2, default_h/2])
                cuboid([cavity_w, cavity_l, default_h + 2], anchor=CENTER);
        }
    }
    
    for(s = spans) {
        h_val = s[4];
        extra_h = h_val - default_h;
        if (extra_h > 0.01) {
            cell_w = int_w / cols; cell_l = int_l / rows;
            start_x = -int_w/2 + (s[1]-1)*cell_w; start_y = int_l/2 - (s[0]-1)*cell_l;
            z_pos = default_h + (extra_h / 2);
            eps = 0.1; // Manifold fusion epsilon
            
            if (s[0] > 1) translate([start_x + (cell_w*s[3])/2, start_y, z_pos]) 
                cuboid([(cell_w * s[3]) + eps, div_t, extra_h], anchor=CENTER);
            if (s[0] + s[2] - 1 < rows) translate([start_x + (cell_w*s[3])/2, start_y - (cell_l*s[2]), z_pos]) 
                cuboid([(cell_w * s[3]) + eps, div_t, extra_h], anchor=CENTER);
            if (s[1] > 1) translate([start_x, start_y - (cell_l*s[2])/2, z_pos]) 
                cuboid([div_t, (cell_l * s[2]) + eps, extra_h], anchor=CENTER);
            if (s[1] + s[3] - 1 < cols) translate([start_x + (cell_w*s[3]), start_y - (cell_l*s[2])/2, z_pos]) 
                cuboid([div_t, (cell_l * s[2]) + eps, extra_h], anchor=CENTER);
        }
    }
}

// --- CORE GENERATORS ---

module render_box_grid_core(data, is_builtin=false) {
    type = get_val(TYPE, data, BOX);
    bw = m_bw(data); bl = m_bl(data); 
    sf = m_safe_floor(data); sw = m_safe_wall(data); 
    div_t = get_val(THICK_DIVIDER, data, 1.2);
    
    cfg = get_grid_config(data);
    cols = cfg[0][0]; rows = cfg[0][1];
    spans = cfg[2];       
    has_base = cfg[3];    
    base_t = cfg[4];      
    default_h = cfg[5];   
    
    int_w = bw - sw*2 - (is_builtin ? 0 : 0.4); 
    int_l = bl - sw*2 - (is_builtin ? 0 : 0.4);
    int_d = bw - sw*2 - (is_builtin ? 0 : 0.4); // Diameter for Jars
    
    if (type == JAR) {
        // JAR CONTEXT: Cookie-cut the cartesian grid into a circle
        union() {
            if (has_base) cyl(d=int_d, h=base_t, anchor=BOTTOM);
            up(base_t) {
                if (cols > 1 || rows > 1 || len(spans) > 0) {
                    intersection() {
                        cyl(d=int_d, h=default_h*5, anchor=BOTTOM);
                        render_cartesian_walls(cols, rows, spans, int_d, int_d, default_h, div_t);
                    }
                }
            }
        }
    } else {
        // STANDARD CONTEXT: Box Bounds
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
            inner_dia = c_dia - (div_t * 2); c_eff = (inner_dia >= 1.5) ? c_dia : max(4.0, c_dia);
            if (inner_dia >= 1.5) { difference() { cyl(d=c_eff, h=int_h, anchor=BOTTOM);
            down(1) cyl(d=inner_dia, h=int_h+2, anchor=BOTTOM); } } else { cyl(d=c_eff, h=int_h, anchor=BOTTOM); }
            
            if (rays > 0) { 
                for(i=[0:rays-1]) zrot(i * 360/rays) translate([c_eff/2 - 0.1, -div_t/2, 0]) 
                cuboid([int_d/2 - c_eff/2 + 0.1, div_t, int_h], anchor=BOTTOM+LEFT); 
            }
        }
    }
}