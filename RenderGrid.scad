// ==============================================================================
// FILE: RenderGrid.scad
// ARCHITECTURE: Layer 2.1 (Domain Module)
// ==============================================================================

module render_internal_grid(data) {
    if (get_val(HAS_BUILTIN_GRID, data, false)) {
        type = get_val(TYPE, data, BOX);
        bw = m_bw(data); bl = m_bl(data); bh = m_bh(data); sf = m_safe_floor(data); sw = m_safe_wall(data); div_t = get_val(THICK_DIVIDER, data, 1.2);
        g_str = get_val(GRID_LAYOUT, data, ""); tokens = str_split(g_str, " ");
        if (type == JAR) {
            lip_h = 8.0;
            has_threads = get_val(HAS_THREADS, data, false);
            int_h = has_threads ? bh - sf - lip_h - sw*1.5 : bh - sf;
            int_d = bw - sw*2;
            tok_r = [for (tok=tokens) if (tok[0]=="R" || tok[0]=="r") tok]; rays = len(tok_r)>0 ?
            (len(get_digits(tok_r[0]))>0 ? to_num(get_digits(tok_r[0])) : 4) : 0; 
            tok_c = [for (tok=tokens) if (tok[0]=="C" || tok[0]=="c") tok]; has_c = len(tok_c)>0;
            c_dia = has_c ? (len(get_digits(tok_c[0]))>0 ? to_num(get_digits(tok_c[0])) : 10.0) : 6.0;
            up(sf) {
                inner_dia = c_dia - (div_t * 2);
                c_eff = (inner_dia >= 1.5) ? c_dia : max(4.0, c_dia); 
                if (inner_dia >= 1.5) { difference() { cyl(d=c_eff, h=int_h, anchor=BOTTOM);
                down(1) cyl(d=inner_dia, h=int_h+2, anchor=BOTTOM); } } else { cyl(d=c_eff, h=int_h, anchor=BOTTOM);
                }
                if (rays > 0) { for(i=[0:rays-1]) zrot(i * 360/rays) translate([c_eff/2 - 0.1, -div_t/2, 0]) cuboid([int_d/2 - c_eff/2 + 0.1, div_t, int_h], anchor=BOTTOM+LEFT);
                }
            }
        } else {
            int_w = bw - sw*2;
            int_l = bl - sw*2; int_h = bh - sf;
            tok_x = [for (tok=tokens) if (len(search("x", tok))>0 || len(search("X", tok))>0) tok];
            if (len(tok_x) > 0) {
                dims = str_split(tok_x[0], "xX");
                cols = max(1, to_num(get_digits(dims[0]))); rows = max(1, to_num(get_digits(dims[1])));
                up(sf) {
                    for(i=[1:cols-1]) translate([-int_w/2 + i*(int_w/cols), 0, int_h/2]) cuboid([div_t, int_l, int_h], anchor=CENTER);
                    for(j=[1:rows-1]) translate([0, -int_l/2 + j*(int_l/rows), int_h/2]) cuboid([int_w, div_t, int_h], anchor=CENTER);
                }
            }
        }
    }
}

module render_box_grid(data) {
    bw = m_bw(data);
    bl = m_bl(data); bh = m_bh(data); sf = m_safe_floor(data); sw = m_safe_wall(data); div_t = get_val(THICK_DIVIDER, data, 1.2);
    int_w = bw - sw*2 - 0.4; int_l = bl - sw*2 - 0.4;
    int_h = bh - sf - 0.5;   
    g_str = get_val(GRID_LAYOUT, data, ""); tokens = str_split(g_str, " ");
    tok_x = [for (tok=tokens) if (len(search("x", tok))>0 || len(search("X", tok))>0) tok][0]; dims = str_split(tok_x, "xX");
    cols = max(1, to_num(get_digits(dims[0])));
    rows = max(1, to_num(get_digits(dims[1])));
    has_base = get_val(GRID_HAS_BASE, data, false); base_t = has_base ? m_lh(data)*4 : 0;
    apply_master_bounds(int_w, int_l, int_h, m_c_rad(data)-sw, m_chamf(data)/2) { 
        if (has_base) cuboid([int_w, int_l, base_t], anchor=BOTTOM);
        up(base_t) {
            for(i=[1:cols-1]) translate([-int_w/2 + i*(int_w/cols), 0, int_h/2]) cuboid([div_t, int_l, int_h], anchor=CENTER);
            for(j=[1:rows-1]) translate([0, -int_l/2 + j*(int_l/rows), int_h/2]) cuboid([int_w, div_t, int_h], anchor=CENTER);
        }
    }
}

module render_jar_grid(data) {
    bw = m_bw(data); bh = m_bh(data); sf = m_safe_floor(data);
    sw = m_safe_wall(data); div_t = get_val(THICK_DIVIDER, data, 1.2);
    has_threads = get_val(HAS_THREADS, data, false); lip_h = 8.0; int_h = has_threads ?
    bh - sf - lip_h - sw*1.5 - 0.5 : bh - sf - 0.5;
    int_d = bw - sw*2 - 0.4; 
    g_str = get_val(GRID_LAYOUT, data, ""); tokens = str_split(g_str, " ");
    tok_r = [for (tok=tokens) if (tok[0]=="R" || tok[0]=="r") tok]; rays = len(tok_r)>0 ? (len(get_digits(tok_r[0]))>0 ? to_num(get_digits(tok_r[0])) : 4) : 0;
    tok_c = [for (tok=tokens) if (tok[0]=="C" || tok[0]=="c") tok]; has_c = len(tok_c)>0; c_dia = has_c ?
    (len(get_digits(tok_c[0]))>0 ? to_num(get_digits(tok_c[0])) : 10.0) : 6.0; 
    has_base = get_val(GRID_HAS_BASE, data, false); base_t = has_base ? m_lh(data)*4 : 0;
    union() {
        if (has_base) cyl(d=int_d, h=base_t, anchor=BOTTOM);
        up(base_t) {
            inner_dia = c_dia - (div_t * 2);
            c_eff = (inner_dia >= 1.5) ? c_dia : max(4.0, c_dia);
            if (inner_dia >= 1.5) { difference() { cyl(d=c_eff, h=int_h, anchor=BOTTOM);
            down(1) cyl(d=inner_dia, h=int_h+2, anchor=BOTTOM); } } else { cyl(d=c_eff, h=int_h, anchor=BOTTOM);
            }
            if (rays > 0) { for(i=[0:rays-1]) zrot(i * 360/rays) translate([c_eff/2 - 0.1, -div_t/2, 0]) cuboid([int_d/2 - c_eff/2 + 0.1, div_t, int_h], anchor=BOTTOM+LEFT);
            }
        }
    }
}