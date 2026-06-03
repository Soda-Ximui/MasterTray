// ==============================================================================
// FILE: RenderLid.scad
// ARCHITECTURE: Layer 3 (Factory)
// PURPOSE: Render factory for various lid types (screw, glide, flip, slip)
// ==============================================================================

include <BOSL2/std.scad>
include <MasterEngine.scad>
include <MasterTolerance.scad>
include <RenderMesh.scad>

module factory_render_lid(data, opts, phys) {
    w = m_bw(data); bl = m_bl(data); sl = m_safe_lid(data); 
    sw = phys[0][1]; noz = phys[3][1]; 
    lid_type = get_val("LID_TYPE", opts, "Slip"); 
    
    echo(str("-> Factory [LID]  | Type: ", lid_type));
    
    if (lid_type == "Glide") {
        glide_tol = breathing_room("COMP_GLIDE", data); 
        lid_w = (w - sw + 0.6) - glide_tol; lid_l = bl - sw / 2;
        apply_master_bounds(lid_w, lid_l, sl, m_c_rad(data), m_chamf(data)) { 
            up(sl / 2) framed_mesh(data, lid_w, lid_l, sl, false, get_mesh_cfg(data, "HOLE_LID", "STRUT_LID", true));
        } 
    } else if (lid_type == "Flip_Single") {
        hinge_d = 4.0; clearance = breathing_room("COMP_CCLIP", data); 
        flat_belly = engagement_depth("COMP_BELLY", data); clasp_depth = engagement_depth("COMP_CLASP", data); 
        clip_wall = noz * 4; clip_outer_d = hinge_d + (clearance*2) + (clip_wall*2);
        cc_z = clip_outer_d / 2; hinge_y_offset = clip_outer_d / 2;
        lid_w = w; lid_l = bl; clip_len = lid_w - sw*6; clip_z = sl + cc_z;
        
        union() {
            apply_master_bounds(lid_w, lid_l, sl, m_c_rad(data), m_chamf(data)) { 
                up(sl / 2) framed_mesh(data, lid_w, lid_l, sl, false, get_mesh_cfg(data, "HOLE_LID", "STRUT_LID", true));
            }
            translate([0, lid_l/2 + hinge_y_offset, clip_z]) { 
                difference() { 
                    union() {
                        intersection() {
                            yrot(90) cyl(d=clip_outer_d, h=clip_len, chamfer=0.5);
                            cuboid([clip_len + 2, clip_outer_d, clip_outer_d - (flat_belly * 2)], anchor=CENTER);
                        }
                        translate([0, -hinge_y_offset/2, -(clip_z - sl)/2 - 0.5]) 
                            cuboid([clip_len, hinge_y_offset + 1.0, (clip_z - sl) + 1.0], anchor=CENTER);
                    }
                    yrot(90) cyl(d=hinge_d + clearance*2, h=clip_len + 2); 
                    translate([0, 0, clip_outer_d/2]) cuboid([clip_len + 2, hinge_d * 0.8, clip_outer_d], anchor=CENTER);
                } 
            }
            translate([0, -lid_l/2 - 1.1, sl/2]) cuboid([lid_w - sw*4, 2.2, sl], anchor=CENTER);
            translate([0, -lid_l/2 - 2.2, sl + (clasp_depth / 2)]) cuboid([lid_w - sw*4, 1.6, clasp_depth], anchor=CENTER);
        }
    } else if (lid_type == "Screw") {
        lip_h = 8.0; cap_h = max(0.1, lip_h + sw * 1.5); neck_od = w - sw * 2 - 0.6; 
        difference() { 
            union() { 
                up(cap_h + sl / 2) framed_mesh(data, w, w, sl, true, get_mesh_cfg(data, "HOLE_LID", "STRUT_LID", true));
                cyl(d=w, h=cap_h, chamfer2=m_chamf(data), anchor=BOTTOM); 
            } 
            up(-0.1) threaded_rod(d=neck_od + 0.8, l=cap_h + 1, pitch=m_thread_pitch(data), internal=false, anchor=BOTTOM, $fn=30);
        }
    } else {
        lid_w = w - sw - 0.6; lid_l = bl - sw / 2 - 0.6; 
        apply_master_bounds(lid_w, lid_l, sl, m_c_rad(data), m_chamf(data)) { 
            up(sl / 2) framed_mesh(data, lid_w, lid_l, sl, false, get_mesh_cfg(data, "HOLE_LID", "STRUT_LID", true));
        } 
    }
}