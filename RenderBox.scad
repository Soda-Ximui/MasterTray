// ==============================================================================
// FILE: RenderBox.scad [v4.26]
// ARCHITECTURE: Layer 2.1 (Domain Module)
// ==============================================================================

include <MasterTolerance.scad> 

module render_box(data) { 
    sw = m_safe_wall(data);
    glide_tol = breathing_room(COMP_GLIDE, data); // INJECT PHYSICS
    
    apply_master_bounds(m_bw(data), m_bl(data), m_bh(data), m_c_rad(data), m_chamf(data)) { 
        difference() { 
            core_tray_chassis(data); 
            if (get_val(NEEDS_GROOVE, data, false)) { 
                up(m_bh(data) - m_safe_lid(data) - 1.0) 
                cuboid([m_bw(data) - sw + 0.6, m_bl(data) + 0.1, m_safe_lid(data) + glide_tol], anchor=BOTTOM);
            } 
        }
    } 
}

module render_flip_box(data) {
    bw = m_bw(data); bl = m_bl(data); bh = m_bh(data); sw = m_safe_wall(data); sl = m_safe_lid(data); noz = m_noz(data); sf = m_safe_floor(data);
    
    hinge_d = 4.0; 
    clearance = breathing_room(COMP_CCLIP, data); // DYNAMIC TOLERANCE
    
    clip_wall = noz * 4;
    clip_outer_d = hinge_d + (clearance*2) + (clip_wall*2);
    cc_z = clip_outer_d / 2;
    hinge_y_offset = clip_outer_d / 2;
    axle_z = bh - cc_z; clip_len = bw - sw*6;
    
    int_w = bw - sw*2; div_t = get_val(THICK_DIVIDER, data, 1.2);
    g_str = get_val(GRID_LAYOUT, data, ""); tokens = str_split(g_str, " ");
    tok_x = [for (tok=tokens) if (len(search("x", tok))>0 || len(search("X", tok))>0) tok];
    cols = len(tok_x) > 0 ? max(1, to_num(get_digits(str_split(tok_x[0], "xX")[0]))) : 1;
    skip_pillars = get_val(SKIP_PILLARS, data, false);
    
    union() {
        difference() {
            render_box(data);
            translate([0, bl/2 + hinge_y_offset, axle_z]) yrot(90) cyl(d=clip_outer_d + clearance*4, h=clip_len + 2, $fn=36);
        }
        translate([-(bw - sw*2)/2 + sw/2, bl/2 - 0.5, sf]) cuboid([sw*3, hinge_y_offset + 1, axle_z + cc_z - sf], anchor=BOTTOM+FRONT);
        translate([(bw - sw*2)/2 - sw/2, bl/2 - 0.5, sf]) cuboid([sw*3, hinge_y_offset + 1, axle_z + cc_z - sf], anchor=BOTTOM+FRONT);
        
        if (cols > 1 && !skip_pillars) {
            for(i=[1:cols-1]) translate([-int_w/2 + i*(int_w/cols), bl/2 - 0.5, sf]) cuboid([div_t, hinge_y_offset + 1, axle_z + cc_z - sf], anchor=BOTTOM+FRONT);
        }
        
        translate([0, bl/2 + hinge_y_offset, axle_z]) { yrot(90) cyl(d=hinge_d, h=bw - sw*2, chamfer=0.5, $fn=36); }
        
        translate([0, -bl/2, bh - 4.0]) {
            hull() {
                translate([0, 0, 0.8]) cuboid([bw - sw*4, 0.1, 0.1], anchor=CENTER); 
                translate([0, -0.8, 0]) cuboid([bw - sw*4, 0.1, 0.1], anchor=CENTER); 
                translate([0, 0, -0.8]) cuboid([bw - sw*4, 0.1, 0.1], anchor=CENTER); 
            }
        }
    }
}

module render_double_flip_box(data) {
    bw = m_bw(data); bl = m_bl(data); bh = m_bh(data); sw = m_safe_wall(data); sl = m_safe_lid(data); noz = m_noz(data); sf = m_safe_floor(data);
    
    hinge_d = 4.0; 
    clearance = breathing_room(COMP_CCLIP, data); // DYNAMIC TOLERANCE
    spine_gap = breathing_room(COMP_SPINE, data); // DYNAMIC TOLERANCE
    
    clip_wall = noz * 4; clip_outer_d = hinge_d + (clearance*2) + (clip_wall*2);
    cc_z = clip_outer_d / 2; 
    hinge_y_offset = (clip_outer_d / 2) + spine_gap;
    
    spine_w = hinge_y_offset * 2 + hinge_d; axle_z = bh - cc_z; clip_len = bw - sw*6;
    
    int_w = bw - sw*2; div_t = get_val(THICK_DIVIDER, data, 1.2);
    g_str = get_val(GRID_LAYOUT, data, ""); tokens = str_split(g_str, " ");
    tok_x = [for (tok=tokens) if (len(search("x", tok))>0 || len(search("X", tok))>0) tok];
    cols = len(tok_x) > 0 ? max(1, to_num(get_digits(str_split(tok_x[0], "xX")[0]))) : 1;
    skip_pillars = get_val(SKIP_PILLARS, data, false);
    
    union() {
        difference() {
            render_box(data);
            hull() {
                translate([0, -hinge_y_offset, axle_z]) yrot(90) cyl(d=clip_outer_d + clearance*4, h=clip_len + 2, $fn=36);
                translate([0, hinge_y_offset, axle_z]) yrot(90) cyl(d=clip_outer_d + clearance*4, h=clip_len + 2, $fn=36);
            }
        }
        
        translate([-(bw - sw*2)/2 + sw/2, 0, sf]) cuboid([sw*3, spine_w, axle_z + cc_z - sf], anchor=BOTTOM);
        translate([(bw - sw*2)/2 - sw/2, 0, sf]) cuboid([sw*3, spine_w, axle_z + cc_z - sf], anchor=BOTTOM);
        
        if (cols > 1 && !skip_pillars) {
            for(i=[1:cols-1]) translate([-int_w/2 + i*(int_w/cols), 0, sf]) cuboid([div_t, spine_w, axle_z + cc_z - sf], anchor=BOTTOM);
        }
        
        translate([0, -hinge_y_offset, axle_z]) yrot(90) cyl(d=hinge_d, h=bw - sw*2, chamfer=0.5, $fn=36);
        translate([0, hinge_y_offset, axle_z]) yrot(90) cyl(d=hinge_d, h=bw - sw*2, chamfer=0.5, $fn=36);
        
        translate([0, -bl/2, bh - 4.0]) {
            hull() {
                translate([0, 0, 0.8]) cuboid([bw - sw*4, 0.1, 0.1], anchor=CENTER); 
                translate([0, -0.8, 0]) cuboid([bw - sw*4, 0.1, 0.1], anchor=CENTER); 
                translate([0, 0, -0.8]) cuboid([bw - sw*4, 0.1, 0.1], anchor=CENTER); 
            }
        }
        translate([0, bl/2, bh - 4.0]) {
            hull() {
                translate([0, 0, 0.8]) cuboid([bw - sw*4, 0.1, 0.1], anchor=CENTER); 
                translate([0, 0.8, 0]) cuboid([bw - sw*4, 0.1, 0.1], anchor=CENTER); 
                translate([0, 0, -0.8]) cuboid([bw - sw*4, 0.1, 0.1], anchor=CENTER); 
            }
        }
    }
}