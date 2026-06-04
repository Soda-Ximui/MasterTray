// ==============================================================================
// FILE: RenderLid.scad
// ARCHITECTURE: Layer 3 (Factory)
// PURPOSE: All lid types — Snap, Glide (H/V, Ball/Tab), Flip_Single, Screw.
//
// All lids printed face-down (flat visible surface on bed) for best finish.
//
// LID_TYPE dispatch:
//   "Snap"        — press-on lid that friction-fits inside the box walls.
//                   Retention bead on two X sides clicks under the box wall top rim.
//   "Glide"       — slides into grooves. GLIDE_DIR: "H" (Y-axis) | "V" (X-axis).
//                   GLIDE_SNAP: "Ball" (default, two side dimples) | "Tab" (front snap).
//   "Flip_Single" — C-clip hinge on +Y face, diamond latch on −Y face.
//   "Screw"       — internally threaded cap for jars (face-down: flat top on bed).
//   default/Slip  — plain press-fit slab, no retention.
// ==============================================================================
include <BOSL2/std.scad>
include <MasterEngine.scad>
include <MasterTolerance.scad>
include <RenderMesh.scad>

module factory_render_lid(data, opts, phys) {
    w  = m_bw(data); l = m_bl(data); sl = m_safe_lid(data);
    sw = phys[0][1]; noz = phys[3][1];
    lid_type  = get_val("LID_TYPE",  opts, "Slip");
    glide_dir = get_val(GLIDE_DIR,   data, "H");
    glide_snap = get_val(GLIDE_SNAP, data, "Ball");

    echo(str("-> Factory [LID] | type=", lid_type, " glide_dir=", glide_dir, " snap=", glide_snap));

    // Ball catch shared dims (Snap + Glide Ball modes)
    ball_d    = max(2.0, noz * 5);
    ball_r    = ball_d / 2;
    ball_protr = max(0.3, breathing_room(COMP_GLIDE, data) * 0.6);

    if (lid_type == "Snap") {
        // Press-fit inside the box walls.
        // Retention bead on two X sides (at lid top) clicks under box wall rim.
        clearance = breathing_room(COMP_GLIDE, data);
        lid_w = w - sw * 2 - clearance;
        lid_l = l - sw * 2 - clearance;
        bead_h = noz * 2;
        union() {
            apply_master_bounds(lid_w, lid_l, sl, m_c_rad(data), m_chamf(data))
                up(sl / 2) framed_mesh(data, lid_w, lid_l, sl, false,
                                        get_mesh_cfg(data, HOLE_LID, STRUT_LID, true));
            // Retention beads on X sides — click under box wall top rim
            for (sx = [-1, 1])
                translate([sx * (lid_w/2 - sw/2), 0, sl])
                    cuboid([sw, lid_l - sw*2, bead_h], chamfer=bead_h/2,
                           edges="ALL", anchor=BOTTOM);
        }

    } else if (lid_type == "Glide") {
        glide_tol = breathing_room(COMP_GLIDE, data);
        // H: lid slides along Y (front-to-back). Grooves in X walls.
        // V: lid slides along X (side-to-side). Grooves in Y walls.
        lid_w = (glide_dir == "H") ? (w - sw + 0.6) - glide_tol : l - sw / 2;
        lid_l = (glide_dir == "H") ? l - sw / 2                  : (w - sw + 0.6) - glide_tol;

        // Ball positions: near the closed end (far end when inserted)
        ball_y = lid_l / 2 - ball_r * 2.5;

        union() {
            apply_master_bounds(lid_w, lid_l, sl, m_c_rad(data), m_chamf(data))
                up(sl / 2) framed_mesh(data, lid_w, lid_l, sl, false,
                                        get_mesh_cfg(data, HOLE_LID, STRUT_LID, true));

            if (glide_snap == "Ball") {
                // Two sphere bumps on X sides near the closed end.
                // They ride in the groove and click into matching dimples in the box.
                for (sx = [-1, 1])
                    translate([sx * (lid_w/2 + ball_r - ball_protr), ball_y, sl/2])
                        sphere(d=ball_d);
            } else {
                // Tab snap: small flexible tab at the open end (−Y face)
                tab_h = sl * 0.6;
                tab_d = noz * 3;
                translate([0, -lid_l/2, tab_h/2])
                    cuboid([lid_w * 0.4, tab_d, tab_h], chamfer=tab_d/2,
                           edges="FRONT", anchor=CENTER);
            }
        }

    } else if (lid_type == "Flip_Single") {
        hinge_d    = 4.0;
        clearance  = breathing_room(COMP_CCLIP, data);
        flat_belly = engagement_depth(COMP_BELLY, data);
        clasp_depth = engagement_depth(COMP_CLASP, data);
        clip_wall  = noz * 4;
        clip_outer_d = hinge_d + clearance*2 + clip_wall*2;
        cc_z       = clip_outer_d / 2;
        hinge_y_off = clip_outer_d / 2;
        lid_w = w; lid_l = l; clip_len = lid_w - sw*6; clip_z = sl + cc_z;
        union() {
            apply_master_bounds(lid_w, lid_l, sl, m_c_rad(data), m_chamf(data))
                up(sl / 2) framed_mesh(data, lid_w, lid_l, sl, false,
                                        get_mesh_cfg(data, HOLE_LID, STRUT_LID, true));
            // C-clip hinge on +Y face
            translate([0, lid_l/2 + hinge_y_off, clip_z])
                difference() {
                    union() {
                        intersection() {
                            yrot(90) cyl(d=clip_outer_d, h=clip_len, chamfer=0.5, $fn=36);
                            cuboid([clip_len+2, clip_outer_d,
                                    clip_outer_d - flat_belly*2], anchor=CENTER);
                        }
                        translate([0, -hinge_y_off/2, -(clip_z-sl)/2 - 0.5])
                            cuboid([clip_len, hinge_y_off+1.0, (clip_z-sl)+1.0], anchor=CENTER);
                    }
                    yrot(90) cyl(d=hinge_d + clearance*2, h=clip_len+2, $fn=36);
                    translate([0, 0, clip_outer_d/2])
                        cuboid([clip_len+2, hinge_d*0.8, clip_outer_d], anchor=CENTER);
                }
            // Diamond latch tab on −Y face (clicks into box latch recess)
            translate([0, -lid_l/2 - 1.1, sl/2])
                cuboid([lid_w - sw*4, 2.2, sl], anchor=CENTER);
            translate([0, -lid_l/2 - 2.2, sl + clasp_depth/2])
                cuboid([lid_w - sw*4, 1.6, clasp_depth], anchor=CENTER);
            // Diamond tip — the snap click point
            translate([0, -lid_l/2 - 1.5, sl + clasp_depth])
                hull() {
                    translate([0, 0,  -0.8]) cuboid([lid_w-sw*4, 0.1, 0.1], anchor=CENTER);
                    translate([0, 0.9, 0  ]) cuboid([lid_w-sw*4, 0.1, 0.1], anchor=CENTER);
                    translate([0, 0,   0.8]) cuboid([lid_w-sw*4, 0.1, 0.1], anchor=CENTER);
                }
        }

    } else if (lid_type == "Screw") {
        lip_h   = 8.0; cap_h = max(0.1, lip_h + sw * 1.5);
        neck_od = w - sw * 2 - 0.6;
        // Face-down: flat top on bed, interior thread on vertical walls.
        difference() {
            union() {
                up(sl / 2) framed_mesh(data, w, w, sl, true,
                                        get_mesh_cfg(data, HOLE_LID, STRUT_LID, true));
                up(sl) cyl(d=w, h=cap_h, anchor=BOTTOM);
            }
            up(sl - 0.1) threaded_rod(d=neck_od + 0.8, l=cap_h+1,
                                       pitch=m_thread_pitch(data),
                                       internal=false, anchor=BOTTOM, $fn=30);
        }

    } else {
        // Slip — plain press-fit slab, no retention mechanism.
        lid_w = w - sw - 0.6; lid_l = l - sw / 2 - 0.6;
        apply_master_bounds(lid_w, lid_l, sl, m_c_rad(data), m_chamf(data))
            up(sl / 2) framed_mesh(data, lid_w, lid_l, sl, false,
                                    get_mesh_cfg(data, HOLE_LID, STRUT_LID, true));
    }
}
