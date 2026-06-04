// ==============================================================================
// FILE: RenderBox.scad
// ARCHITECTURE: Layer 3 (Factory)
// PURPOSE: Render factories for rectangular box and flip-lid geometries.
// ==============================================================================

include <MasterEngine.scad>
include <MasterTolerance.scad>
include <RenderTray.scad>

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

// ==============================================================================
// FACTORY INTERFACE (Layer 3)
// These wrappers adapt the domain render modules to the factory_render_*(data, opts, phys)
// signature used by MasterBuilder's dispatcher, running data through process_part first.
// ==============================================================================

module factory_render_box(data, opts, phys) {
    lid_type   = get_val("LID_TYPE",  opts, "Snap");
    glide_dir  = get_val(GLIDE_DIR,   data, "H");
    glide_snap = get_val(GLIDE_SNAP,  data, "Ball");
    needs_groove = (lid_type == "Glide");

    // Inject NEEDS_GROOVE so render_box cuts the glide channel.
    d = needs_groove ? concat([[NEEDS_GROOVE, true]], data) : data;

    if (glide_snap == "Ball" && needs_groove) {
        // Add ball-catch dimples in the groove walls to match the lid ball bumps.
        sw        = m_safe_wall(d);
        sl        = m_safe_lid(d);
        bh        = m_bh(d);
        bw        = m_bw(d);
        bl        = m_bl(d);
        glide_tol = breathing_room(COMP_GLIDE, d);
        noz       = m_noz(d);
        ball_d    = max(2.0, noz * 5);
        ball_r    = ball_d / 2;
        // Match lid: ball_y = lid_l/2 - ball_r*2.5 from lid centre
        // lid_l = bl - sw/2; lid centre at y=0; ball at y = lid_l/2 - ball_r*2.5
        lid_l     = bl - sw / 2;
        ball_y    = lid_l / 2 - ball_r * 2.5;
        // Ball sits at the groove X wall. Dimple = sphere slightly larger than ball.
        groove_x  = (bw - sw + 0.6) / 2;
        difference() {
            render_box(process_part(d));
            for (sx = [-1, 1])
                translate([sx * groove_x, ball_y, bh - sl/2])
                    sphere(d=ball_d + glide_tol);
        }
    } else {
        render_box(process_part(d));
    }
}

module factory_render_flip_box(data, opts, phys) {
    render_flip_box(process_part(data));
}

module factory_render_double_flip_box(data, opts, phys) {
    render_double_flip_box(process_part(data));
}