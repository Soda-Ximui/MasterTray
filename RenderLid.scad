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
    filament  = get_val("FILAMENT_TYPE", data, "PETG");

    echo(str("-> Factory [LID] | type=", lid_type, " glide_dir=", glide_dir, " snap=", glide_snap));

    // Ball catch shared dims (Snap + Glide Ball modes).
    // Scales with box footprint so large lids get proportionally stronger retention.
    // Capped at sw*2 so the ball never exceeds the groove wall depth.
    ball_d    = glide_ball_d(w, l, sw, noz);
    ball_r    = ball_d / 2;
    ball_protr = glide_ball_protr(ball_r, breathing_room(COMP_GLIDE, data), noz);

    if (lid_type == "Snap") {
        // Press-fit inside the box walls.
        // Retention bead on two X sides clicks under box wall rim (External) or
        // into inner-wall groove (Rabbet).
        clearance = breathing_room(COMP_GLIDE, data);
        lid_style = get_val(LID_STYLE, data, "External");
        lid_w = w - sw * 2 - clearance;
        lid_l = l - sw * 2 - clearance;
        // Round up to nearest layer boundary, minimum 3 layers.
        // noz*2 = 0.8mm at 0.4mm nozzle = 2.857 layers — fractional, weak retention.
        // 3 layers at 0.28mm lh = 0.84mm — clean boundary, reliable PETG click-force.
        bead_h = m_lh(data) * max(3, ceil(noz * 2 / m_lh(data)));
        // snap_protr: how far bead outer face extends past box interior wall.
        // clearance/2 closes the lid_w gap so bead starts at interior face,
        // then protrudes noz further — enough for tactile click without over-stressing wall.
        snap_protr = noz;
        // External: bead bottom placed below apply_master_bounds TOP chamfer zone.
        // apply_master_bounds clips with chamfer=m_chamf on TOP+BOTTOM; chamfer zone depth
        // = m_chamf(data) from the lid top face. bead_z = sl - EPS would land inside that zone,
        // causing complex geometry interactions between chamfered lid top and chamfered bead bottom.
        // Fix: lower by m_chamf so bead root starts on the clean flat portion of the lid body.
        // Bead height increases by m_chamf to keep bead-top protrusion unchanged.
        // Rabbet: bead at sl−2·bead_h — aligns with groove at h−2·bead_h when seated.
        chamf = m_chamf(data);
        bead_z = (lid_style == "Rabbet") ? sl - 2 * bead_h - EPS : sl - chamf - EPS;
        bead_h_ext = (lid_style == "Rabbet") ? bead_h + EPS : bead_h + chamf + EPS;
        union() {
            apply_master_bounds(lid_w, lid_l, sl, m_c_rad(data), chamf)
                up(sl / 2) framed_mesh(data, lid_w, lid_l, sl, false,
                                        get_mesh_cfg(data, HOLE_LID, STRUT_LID));
            // Retention beads on X sides.
            // chamfer=bead_h/2 with height bead_h+EPS leaves only EPS of flat face — degenerate.
            // bead_chamf computed to leave exactly m_lh of flat section (one clean print layer).
            // Base overlaps into lid body — bead root sits on clean flat lid surface below chamfer zone.
            bead_chamf = (bead_h_ext - m_lh(data)) / 2;
            for (sx = [-1, 1])
                translate([sx * (lid_w/2 + clearance/2 + snap_protr - sw/2), 0, bead_z])
                    cuboid([sw, lid_l - sw*2, bead_h_ext], chamfer=bead_chamf,
                           edges="ALL", anchor=BOTTOM);
        }

    } else if (lid_type == "Glide") {
        glide_tol  = breathing_room(COMP_GLIDE, data);
        lid_style  = get_val(LID_STYLE, data, "External");

        // Lid must be at least as thick as the ball diameter so the ball is fully
        // embedded — no floating shell, no rib patch needed.
        sl_glide = max(sl, ball_d);

        // Rabbet: lid steps into inner-wall groove — slightly narrower than External.
        // External: lid rides in outer-wall groove — slightly wider than interior.
        // Must match box groove formulas in RenderBox exactly.
        rabbet_d = sw / 2;
        lid_w = (lid_style == "Rabbet")
            ? ((glide_dir == "H") ? w - sw - glide_tol      : l - sw / 2)
            : ((glide_dir == "H") ? (w - sw + 0.6) - glide_tol : l - sw / 2);
        lid_l = (lid_style == "Rabbet")
            ? ((glide_dir == "H") ? l - sw / 2      : w - sw - glide_tol)
            : ((glide_dir == "H") ? l - sw / 2      : (w - sw + 0.6) - glide_tol);

        ball_y = lid_l / 2 - ball_r * 2.5;

        union() {
            apply_master_bounds(lid_w, lid_l, sl_glide, m_c_rad(data), m_chamf(data))
                up(sl_glide / 2) framed_mesh(data, lid_w, lid_l, sl_glide, false,
                                        get_mesh_cfg(data, HOLE_LID, STRUT_LID));

            if (glide_snap == "Ball") {
                for (sx = [-1, 1])
                    // Ball center at sl_glide/2 — fully within lid body (ball_r ≤ sl_glide/2).
                    translate([sx * (lid_w/2 + ball_r - ball_protr), ball_y, sl_glide/2])
                        sphere(d=ball_d);
            } else {
                tab_h = sl_glide * 0.6;
                tab_d = noz * 3;
                translate([0, -lid_l/2, tab_h/2])
                    cuboid([lid_w * 0.4, tab_d, tab_h], chamfer=tab_d/2,
                           edges=FRONT, anchor=CENTER);
            }
            // Pull tab on −Y face (trailing end when inserted): grip point to slide lid out.
            // Height spans full lid thickness; depth = noz*4 past lid face.
            pull_tab_d = noz * 4;
            pull_tab_h = sl_glide * 0.7;
            // Sunk EPS below Z=0 so bottom face doesn't share the lid face plane (non-manifold).
            // +EPS toward lid body so the +Y face overlaps lid body by EPS — breaks Y coplanarity.
            translate([0, -lid_l/2 - pull_tab_d/2 + EPS, -EPS])
                cuboid([lid_w * 0.45, pull_tab_d, pull_tab_h + EPS],
                       chamfer=pull_tab_d/2, edges=[FRONT+LEFT, FRONT+RIGHT, BOTTOM+FRONT],
                       anchor=BOTTOM);
        }

    } else if (lid_type == "Flip_Single") {
        hinge_d    = 4.0;
        clearance  = breathing_room(COMP_CCLIP, data);
        flat_belly = engagement_depth(COMP_BELLY, data);
        clasp_depth = engagement_depth(COMP_CLASP, data);
        clip_wall  = noz * 4;
        clip_outer_d = hinge_d + clearance*2 + clip_wall*2;
        // C-opening gap: PLA is brittle — wider gap means less arm flex required.
        // PETG: 80% of axle d = 0.4mm flex per arm (validated). PLA: 90% = 0.2mm flex.
        clip_gap = (filament == "PLA") ? hinge_d * 0.90 : hinge_d * 0.80;
        cc_z       = clip_outer_d / 2;
        hinge_y_off = clip_outer_d / 2;
        // lid_l: body only — C-clip adds clip_outer_d on the +Y side, so the total
        // assembly is exactly l (user's specified dimension, not l + clip_outer_d).
        lid_w = w; lid_l = l - clip_outer_d; clip_len = lid_w - sw*6; clip_z = sl + cc_z;
        union() {
            // Flip lid body: minimum noz chamfer on all edges regardless of global chamfer_size=0.
            apply_master_bounds(lid_w, lid_l, sl, m_c_rad(data), max(noz, m_chamf(data)))
                up(sl / 2) framed_mesh(data, lid_w, lid_l, sl, false,
                                        get_mesh_cfg(data, HOLE_LID, STRUT_LID));
            // C-clip hinge on +Y face — suppressed if lid is too narrow for mechanism
            if (clip_len > 0) {
                translate([0, lid_l/2 + hinge_y_off, clip_z])
                    difference() {
                        union() {
                            intersection() {
                                yrot(90) cyl(d=clip_outer_d, h=clip_len, chamfer=noz*3, $fn=36);
                                cuboid([clip_len+2, clip_outer_d,
                                        clip_outer_d - flat_belly*2], anchor=CENTER);
                            }
                            // X span = clip_len − EPS so block ends are EPS/2 inside the
                            // cylinder ends (both are clip_len/2 without this) — coplanar X faces
                            // in union() produce non-manifold edges along the shared boundary.
                            translate([0, -hinge_y_off/2, -(clip_z-sl)/2 - 0.5])
                                cuboid([clip_len - EPS, hinge_y_off+1.0, (clip_z-sl)+1.0],
                                       chamfer=1.0, edges=[TOP+FRONT, TOP+BACK], anchor=CENTER);
                        }
                        yrot(90) cyl(d=hinge_d + clearance*2, h=clip_len+2, $fn=36);
                        // C-opening faces DOWN (−Z) so arms point toward lid body.
                        // Printed face-down: arc is at top of print, fully self-supporting.
                        // Pin enters from below as the lid is pressed onto the box hinge.
                        // Cutter top extends EPS past connection-block top (both land at local z=0).
                        // Without EPS2: cutter face coplanar with block face → non-manifold edges.
                        translate([0, 0, -clip_outer_d/2])
                            cuboid([clip_len+2, clip_gap, clip_outer_d + EPS2], anchor=CENTER);
                    }
            }
            // Diamond latch arm — one solid block from lid face to clasp top.
            // Sunk EPS below Z=0 so the bottom face doesn't share the lid face plane (non-manifold).
            translate([0, -lid_l/2 - 1.1 + EPS, -EPS])
                cuboid([lid_w - sw*4, 2.2, sl + clasp_depth + EPS], anchor=BOTTOM);
            // Diamond tip — the snap click point.
            // Z-tips truncated to noz*1.05 (Arachne flat-top, no pressure pinch).
            // Z-offsets snapped to layer boundaries via layer_snap() — no micro-stepping.
            // Engagement Y-cuboid widened to noz*2 — was 0.1mm (sub-nozzle, unprintable).
            lz = layer_snap(0.8, m_lh(data));
            // +EPS on hull cuboid X: latch arm and hull share the same X width (lid_w−sw*4).
            // In the Z overlap zone their ±X faces are coplanar → non-manifold edges.
            // Widening hull by EPS makes the latch arm X faces interior to the hull volume.
            translate([0, -lid_l/2 - 1.5, sl + clasp_depth])
                hull() {
                    translate([0, 0,   -lz]) cuboid([lid_w-sw*4+EPS, 0.1,   noz*1.05], anchor=CENTER);
                    translate([0, 0.9,   0]) cuboid([lid_w-sw*4+EPS, noz*2, 0.1     ], anchor=CENTER);
                    translate([0, 0,    lz]) cuboid([lid_w-sw*4+EPS, 0.1,   noz*1.05], anchor=CENTER);
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
        // needs_margin=false: retention is in the threaded cylinder, not the flat face.
        // Snap/Glide/Flip use needs_margin=true because their mechanisms live on the border.
        difference() {
            union() {
                up(sl / 2) framed_mesh(data, w, w, sl, true,
                                        get_mesh_cfg(data, HOLE_LID, STRUT_LID));
                // EPS sink: cylinder bottom would land at Z=sl — coplanar with lid plate top.
                up(sl - EPS) cyl(d=w, h=cap_h + EPS, chamfer2=noz*4, anchor=BOTTOM);
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
                                    get_mesh_cfg(data, HOLE_LID, STRUT_LID));
    }

}
