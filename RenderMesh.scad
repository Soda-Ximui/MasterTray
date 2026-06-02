// ==============================================================================
// FILE: RenderMesh.scad
// ARCHITECTURE: Layer 2.1 (Domain Module)
// ==============================================================================

module framed_mesh(data, w, l, h, is_cyl=false, cfg=undef) {
    noz = m_noz(data);
    pat = get_val(PATTERN, data, PATTERN0); min_sp = 1.2;
    if (cfg == undef) { 
        linear_extrude(height=h, center=true) { 
            if (is_cyl) circle(d=w);
            else rect([w, l]); 
        } 
    } else { 
        hole = cfg[0];
        solid = cfg[1]; step = get_grid_step(hole, min_sp, noz); 
        nx = get_n_steps(w, solid, step); ny = get_n_steps(l, solid, step);
        pad = is_cyl ? 0 : (noz * 3) * 1.5;
        linear_extrude(height=h, center=true) { 
            difference() { 
                if (is_cyl) circle(d=w);
                else rect([w, l]); 
                intersection() { 
                    if (is_cyl) circle(d=get_mesh_dim(w, solid));
                    else rect([max(0.1, get_mesh_dim(w, solid)-pad), max(0.1, get_mesh_dim(l, solid)-pad)]); 
                    
                    render_rectangular_pattern(pat, hole, step, nx, ny);
                } 
            } 
        } 
    }
}

module cylindrical_mesh_wall(data, d, h, wall_t, cfg=undef) {
    pat = get_val(PATTERN, data, PATTERN0);
    min_sp = 1.2; noz = m_noz(data);
    if (cfg == undef) { 
        difference() { 
            cyl(d=d, h=h, anchor=BOTTOM);
            down(1) cyl(d=d - wall_t * 2, h=h + 2, anchor=BOTTOM);
        } 
    } else { 
        hole = cfg[0];
        solid = cfg[1]; h_active = h * (1 - (solid / 100)); 
        step = get_grid_step(hole, min_sp, noz);
        nz = max(1, floor(h_active / step)); 
        na = max(3, floor((PI * d) / step)); a_step = 360 / na;
        z_step = h_active / nz;
        difference() { 
            difference() { 
                cyl(d=d, h=h, anchor=BOTTOM);
                down(1) cyl(d=d - wall_t * 2, h=h + 2, anchor=BOTTOM);
            } 
            for (i = [0 : nz - 1]) { 
                for (j = [0 : na - 1]) { 
                    z_pos = (h - h_active) / 2 + (i + 0.5) * z_step;
                    zrot(j * a_step) translate([d / 2, 0, z_pos]) { 
                        yrot(90) { 
                            render_cylindrical_pattern(pat, hole, wall_t);
                        } 
                    } 
                } 
            } 
        }
    }
}