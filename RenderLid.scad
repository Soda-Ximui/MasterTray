// ==============================================================================
// FILE: RenderLid.scad [v4.17]
// ARCHITECTURE: Layer 2.1 (Domain Module)
// ==============================================================================

module render_lid(data) { bw = m_bw(data); bl = m_bl(data);
    sl = m_safe_lid(data); sw = m_safe_wall(data); lid_w = bw - sw - 0.6;
    lid_l = bl - sw / 2 - 0.6; apply_master_bounds(lid_w, lid_l, sl, m_c_rad(data), m_chamf(data)) { up(sl / 2) framed_mesh(data, lid_w, lid_l, sl, false, get_mesh_cfg(data, HOLE_LID, STRUT_LID, true));
    } }

module render_lid_glide(data) { bw = m_bw(data); bl = m_bl(data); sl = m_safe_lid(data); sw = m_safe_wall(data);
    lid_w = bw - sw + 0.2; lid_l = bl - sw / 2;
    apply_master_bounds(lid_w, lid_l, sl, m_c_rad(data), m_chamf(data)) { up(sl / 2) framed_mesh(data, lid_w, lid_l, sl, false, get_mesh_cfg(data, HOLE_LID, STRUT_LID, true));
    } }

module render_flip_lid(data) {
    bw = m_bw(data); bl = m_bl(data); sl = m_safe_lid(data); sw = m_safe_wall(data);
    noz = m_noz(data);
    hinge_d = 4.0; clearance = 0.2; clip_wall = noz * 4;
    clip_outer_d = hinge_d + (clearance*2) + (clip_wall*2);
    cc_z = clip_outer_d / 2; hinge_y_offset = clip_outer_d / 2;
    
    lid_w = bw;
    lid_l = bl; clip_len = lid_w - sw*6;
    
    clip_z = sl + cc_z;
    
    union() {
        apply_master_bounds(lid_w, lid_l, sl, m_c_rad(data), m_chamf(data)) { 
            up(sl / 2) framed_mesh(data, lid_w, lid_l, sl, false, get_mesh_cfg(data, HOLE_LID, STRUT_LID, true));
        }
        
        translate([0, lid_l/2 + hinge_y_offset, clip_z]) { 
            difference() { 
                union() {
                    // [v4.17] Flat-Belly C-Clip
                    // Slices 0.6mm off the top and bottom to create a perfect FDM bridging surface 
                    // allowing the lid to be printed face down entirely without slicer supports.
                    intersection() {
                        yrot(90) cyl(d=clip_outer_d, h=clip_len, chamfer=0.5, $fn=36);
                        cuboid([clip_len + 2, clip_outer_d, clip_outer_d - 1.2], anchor=CENTER);
                    }
                    
                    translate([0, -hinge_y_offset/2, -(clip_z - sl)/2 - 0.5]) 
                        cuboid([clip_len, hinge_y_offset + 1.0, (clip_z - sl) + 1.0], anchor=CENTER);
                }
                
                yrot(90) cyl(d=hinge_d + clearance*2, h=clip_len + 2, $fn=36); 
                
                translate([0, 0, clip_outer_d/2])
                    cuboid([clip_len + 2, hinge_d * 0.8, clip_outer_d], anchor=CENTER);
            } 
        }
            
        translate([0, -lid_l/2 - 1.1, sl/2]) cuboid([lid_w - sw*4, 2.2, sl], anchor=CENTER);
        
        translate([0, -lid_l/2 - 2.2, sl + 2.0]) cuboid([lid_w - sw*4, 1.6, 6.0], anchor=CENTER);
        
        translate([0, -lid_l/2 - 1.5, sl + 3.8]) {
            hull() {
                translate([0, 0, -0.8]) cuboid([lid_w - sw*4, 0.1, 0.1], anchor=CENTER); 
                translate([0, 0.9, 0]) cuboid([lid_w - sw*4, 0.1, 0.1], anchor=CENTER); 
                translate([0, 0, 0.8]) cuboid([lid_w - sw*4, 0.1, 0.1], anchor=CENTER); 
            }
        }
    }
}