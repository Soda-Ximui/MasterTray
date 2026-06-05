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

    // Ball catch shared dims (Snap + Glide Ball modes).
    // Scales with box footprint so large lids get proportionally stronger retention.
    // Capped at sw*2 so the ball never exceeds the groove wall depth.
    ball_d    = glide_ball_d(w, l, sw, noz);
    ball_r    = ball_d / 2;
    ball_protr = glide_ball_protr(ball_r, breathing_room(COMP_GLIDE, data), noz);

    if (lid_type == "Snap") {
        // Press-fit inside the box walls.
        // Retention bead on two X sides (at lid top) clicks under box wall rim.
        clearance = breathing_room(COMP_GLIDE, data);
        lid_w = w - sw * 2 - clearance;
        lid_l = l - sw * 2 - clearance;
        // Round up to nearest layer boundary, minimum 3 layers.
        // noz*2 = 0.8mm at 0.4mm nozzle = 2.857 layers — fractional, weak retention.
        // 3 layers at 0.28mm lh = 0.84mm — clean boundary, reliable PETG click-force.
        bead_h = m_lh(data) * max(3, ceil(noz * 2 / m_lh(data)));
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
            // C-clip hinge on +Y face — suppressed if lid is too narrow for mechanism
            if (clip_len > 0) {
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
            }
            // Diamond latch tab on −Y face (clicks into box latch recess)
            translate([0, -lid_l/2 - 1.1, sl/2])
                cuboid([lid_w - sw*4, 2.2, sl], anchor=CENTER);
            translate([0, -lid_l/2 - 2.2, sl + clasp_depth/2])
                cuboid([lid_w - sw*4, 1.6, clasp_depth], anchor=CENTER);
            // Diamond tip — the snap click point.
            // Z-tips truncated to noz*1.05 (Arachne flat-top, no pressure pinch).
            // Z-offsets snapped to layer boundaries via layer_snap() — no micro-stepping.
            // Engagement Y-cuboid widened to noz*2 — was 0.1mm (sub-nozzle, unprintable).
            lz = layer_snap(0.8, m_lh(data));
            translate([0, -lid_l/2 - 1.5, sl + clasp_depth])
                hull() {
                    translate([0, 0,   -lz]) cuboid([lid_w-sw*4, 0.1,   noz*1.05], anchor=CENTER);
                    translate([0, 0.9,   0]) cuboid([lid_w-sw*4, noz*2, 0.1     ], anchor=CENTER);
                    translate([0, 0,    lz]) cuboid([lid_w-sw*4, 0.1,   noz*1.05], anchor=CENTER);
                }
        }

    } else if (lid_type == "Screw") {
        // cap_h: minimum thread engagement height only.
        // BEFORE: lip_h = JAR_LIP_HEIGHT; cap_h = max(0.1, lip_h + sw * 1.5);
        //   = 8.0 + 3.6 = 11.6mm — this is the JAR NECK height, not lid height.
        //   sw*1.5 taper allowance lives on the jar body; the lid doesn't need it.
        //   Total lid was sl+11.6 = 13.6mm. See BUGS.md B2.
        // FIX: 3 full thread turns = minimum reliable grip at any pitch.
        //   sw*2 floor ensures at least 2 full wall passes on the cap cylinder.
        cap_h   = max(m_thread_pitch(data) * 3, sw * 2);
        neck_od = w - sw * 2 - 0.6;
        // Face-down: flat top on bed, interior thread on vertical walls.
        difference() {
            union() {
                up(sl / 2) framed_mesh(data, w, w, sl, true,
                                        get_mesh_cfg(data, HOLE_LID, STRUT_LID, true));
                up(sl) cyl(d=w, h=cap_h, chamfer2=noz*4, anchor=BOTTOM);
            }
            // EPS pullback: cutter starts one boolean-epsilon below lid surface so the
            // thread is cleanly subtracted without a zero-thickness manifold edge.
            up(sl - EPS) threaded_rod(d=neck_od + 0.8, l=cap_h+1,
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
