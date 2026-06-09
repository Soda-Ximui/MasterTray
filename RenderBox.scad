// ==============================================================================
// FILE: RenderBox.scad
// ARCHITECTURE: Layer 3 (Factory)
// PURPOSE: Rectangular box body — all lid-body variants driven by LID_TYPE in opts.
//
// One factory, one primitive shape. LID_TYPE determines what the body needs:
//   "Snap" / "Slip" — plain chassis, no body modifications
//   "Glide"         — groove channel cut into top + ball-catch dimples
//   "Flip_Single"   — hinge boss on +Y face, axle pin, diamond latch recess on −Y
//   "Flip_Double"   — hinge bosses on both Y faces, two axle pins, two latch recesses
//
// All geometry: core_tray_chassis + lid-specific additions/subtractions.
// No intermediate render_* wrappers — logic lives here, driven by opts.
// ==============================================================================
include <BOSL2/std.scad>
include <MasterEngine.scad>
include <MasterTolerance.scad>
include <RenderTray.scad>

module factory_render_box(data, opts, phys) {
    lid_type   = get_val("LID_TYPE",  opts, "Snap");
    glide_dir  = get_val(GLIDE_DIR,   data, "H");
    glide_snap = get_val(GLIDE_SNAP,  data, "Ball");

    w   = m_bw(data); l = m_bl(data); h = m_bh(data);
    sf  = m_safe_floor(data); sw = m_safe_wall(data);
    sl  = m_safe_lid(data);   noz = m_noz(data);

    echo(str("-> Factory [BOX] | ", w, "x", l, "x", h, " | lid=", lid_type));

    // Compute max internal grid wall height and inject into data.
    // render_internal_grid reads GRID_WALL_H so dividers don't block lid closure.
    is_flip = (lid_type == "Flip_Single" || lid_type == "Flip_Double");
    hinge_d_  = 4.0;
    clip_od_  = hinge_d_ + breathing_room(COMP_CCLIP, data)*2 + noz*8;
    axle_z_   = h - clip_od_ / 2;
    grid_wall_h = is_flip ? axle_z_ : (h - sf - sl);

    // Mandatory solid zone at top of walls — keeps mesh holes out of lid-mechanism area.
    // Overrides strut_wall_perc regardless of user setting. See MasterEnum MESH_TOP_MARGIN.
    lh = m_lh(data);
    top_margin =
        (lid_type == "Slip")   ? 0 :
        (lid_type == "Glide")  ? sl + lh * (ceil(1.0 / lh) + 1) :
        sl + lh * 3;

    data_g = concat([[GRID_WALL_H, grid_wall_h], [MESH_TOP_MARGIN, top_margin]], data);

    if (lid_type == "Slip") {
        // ── Plain box: chassis + corner rounding only ──────────────────────────
        apply_master_bounds(w, l, h, m_c_rad(data), m_chamf(data))
            core_tray_chassis(data_g);

    } else if (lid_type == "Snap") {
        // ── Snap box ───────────────────────────────────────────────────────────
        // External (default): plain chassis — lid bead cams past wall top rim.
        // Rabbet: groove on inner wall face at closed position — positive click stop.
        lid_style  = get_val(LID_STYLE, data, "External");
        if (lid_style == "Rabbet") {
            bead_h = m_lh(data) * max(3, ceil(noz * 2 / m_lh(data)));
            glide_tol = breathing_room(COMP_GLIDE, data);
            // Ring groove on inner wall face: bead snaps into defined closed position.
            // Groove occupies h−2·bead_h to h−bead_h; bead_h wall above traps the bead.
            // Lid bead at sl−2·bead_h → when seated (bottom at h−sl) bead aligns with groove.
            groove_z = h - 2 * bead_h;
            difference() {
                apply_master_bounds(w, l, h, m_c_rad(data), m_chamf(data))
                    core_tray_chassis(data_g);
                up(groove_z)
                    difference() {
                        cuboid([w-sw*2 + bead_h*2 + EPS, l-sw*2 + bead_h*2 + EPS,
                                bead_h + EPS], anchor=BOTTOM);
                        cuboid([w-sw*2 - EPS, l-sw*2 - EPS, bead_h*2], anchor=BOTTOM);
                    }
            }
        } else {
            apply_master_bounds(w, l, h, m_c_rad(data), m_chamf(data))
                core_tray_chassis(data_g);
        }

    } else if (lid_type == "Glide") {
        // ── Glide box: groove channel + ball-catch dimples ─────────────────────
        lid_style  = get_val(LID_STYLE, data, "External");
        glide_tol  = breathing_room(COMP_GLIDE, data);
        ball_d     = glide_ball_d(w, l, sw, noz);
        ball_r     = ball_d / 2;
        ball_protr = glide_ball_protr(ball_r, glide_tol, noz);

        if (lid_style == "Rabbet") {
            // ── Rabbet glide: groove on inner wall face, lid drops inside ──────
            // Groove depth = sw/2 into the wall. Lid top is flush with box rim.
            rabbet_d = sw / 2;
            sl_glide_r = max(sl, ball_d);
            rabbet_h = max(sl_glide_r + glide_tol, ball_d + glide_tol + noz * 4);
            int_w_r  = w - sw*2;
            int_l_r  = l - sw*2;
            // Lid dims — must match RenderLid Rabbet formula
            lid_w_r  = (glide_dir == "H") ? w - sw - glide_tol : l - sw/2;
            lid_l_r  = (glide_dir == "H") ? l - sw/2           : w - sw - glide_tol;
            ball_y   = lid_l_r/2 - ball_r*2.5;
            ball_x_r = lid_w_r/2 + ball_r - ball_protr;
            difference() {
                apply_master_bounds(w, l, h, m_c_rad(data), m_chamf(data))
                    core_tray_chassis(data_g);
                if (glide_dir == "H") {
                    for (sx = [-1, 1])
                        translate([sx * (int_w_r/2 + rabbet_d/2), 0, h - rabbet_h])
                            cuboid([rabbet_d + EPS, int_l_r + EPS, rabbet_h + EPS], anchor=BOTTOM);
                    if (glide_snap == "Ball")
                        for (sx = [-1, 1])
                            translate([sx * ball_x_r, ball_y, h - rabbet_h/2])
                                sphere(d=ball_d + glide_tol);
                } else {
                    for (sy = [-1, 1])
                        translate([0, sy * (int_l_r/2 + rabbet_d/2), h - rabbet_h])
                            cuboid([int_w_r + EPS, rabbet_d + EPS, rabbet_h + EPS], anchor=BOTTOM);
                    if (glide_snap == "Ball")
                        for (sy = [-1, 1])
                            translate([ball_y, sy * ball_x_r, h - rabbet_h/2])
                                sphere(d=ball_d + glide_tol);
                }
            }
        } else {
        // ── External glide: groove on outer wall top ───────────────────────────
        groove_w   = w - sw + 0.6;
        groove_l   = l + EPS;
        sl_glide_  = max(sl, ball_d);
        // groove_h must fit the thickened lid AND leave noz*2 wall above and below
        // the ball dimple so it prints as a full circle, not a broken arc.
        // The ball dimple sphere (diameter = ball_d + glide_tol) needs noz*2 of wall
        // on each Z face to avoid cutting to the groove edge.
        groove_h   = max(sl_glide_ + glide_tol, ball_d + glide_tol + noz * 4);
        // ceil() snaps the 1mm drop up to the nearest full layer boundary.
        // At 0.28mm lh: ceil(1.0/0.28)=4 layers → 1.12mm — groove sits on a clean layer.
        groove_z   = h - sl - m_lh(data) * ceil(1.0 / m_lh(data));
        lid_w      = groove_w - glide_tol;       // must match RenderLid lid_w formula
        lid_l      = l - sw / 2;
        ball_y     = lid_l / 2 - ball_r * 2.5;  // same formula as in RenderLid
        ball_x     = lid_w / 2 + ball_r - ball_protr;  // = groove_w/2 + noz/2

        difference() {
            apply_master_bounds(w, l, h, m_c_rad(data), m_chamf(data))
                core_tray_chassis(data_g);
            // Groove channel for lid to slide into
            up(groove_z)
                cuboid([groove_w, groove_l, groove_h], anchor=BOTTOM);
            // Ball-catch dimples — Z at groove centre so noz*2 wall exists above and below.
            if (glide_snap == "Ball")
                for (sx = [-1, 1])
                    translate([sx * ball_x, ball_y, groove_z + groove_h / 2])
                        sphere(d=ball_d + glide_tol);
            // Thumb notch at −Y groove mouth bottom — fingernail purchase under lid edge.
            // Shifted EPS above groove_z so notch overlaps groove interior (avoids coplanar
            // face with groove cutter bottom — would create non-manifold edges).
            translate([0, -l/2, groove_z + EPS])
                cuboid([groove_w * 0.5, sw + EPS*2, noz * 4 + EPS], anchor=TOP);
        }
        } // end External glide

    } else if (lid_type == "Flip_Single") {
        // ── Single flip-hinge box: hinge boss on +Y, latch recess on −Y ────────
        hinge_d     = 4.0;
        clearance   = breathing_room(COMP_CCLIP, data);
        clasp_depth = engagement_depth(COMP_CLASP, data);
        clip_wall   = noz * 4;
        clip_od     = hinge_d + clearance*2 + clip_wall*2;
        cc_z        = clip_od / 2;
        hinge_y     = clip_od / 2;
        // latch_z: derived from axle height and lid latch geometry so they align.
        // When closed: lid face sits at h − sl − 2·cc_z; latch tip at +clasp_depth above that.
        latch_z     = flip_latch_z(h, cc_z, clasp_depth);
        axle_z     = h - cc_z;
        clip_len   = w - sw*6;
        int_w      = w - sw*2;
        div_t      = get_val(THICK_DIVIDER, data, 1.2);
        // grid column count from layout string (for hinge pillar spacing)
        g_str      = get_val(GRID_LAYOUT, data, "");
        tok_x      = [for (tok = str_split(g_str, " "))
                          if (len(search("x", tok)) > 0 || len(search("X", tok)) > 0) tok];
        cols       = len(tok_x) > 0
                     ? max(1, to_num(get_digits(str_split(tok_x[0], "xX")[0])))
                     : 1;
        skip_p     = get_val(SKIP_PILLARS, data, false);

        // Hard stop: a box too narrow for the hinge C-clip has no functional fallback.
        // Silently rendering it would produce a "Flip_Single" box that cannot flip.
        // The user must increase width or reduce Wall_Loops — there is no graceful degradation.
        assert(clip_len > 0, str(
            "Flip_Single requires w > ", sw*6, "mm. ",
            "Current w=", w, "mm, sw=", sw, "mm. ",
            "Increase part_width or reduce Wall_Loops."));
        union() {
            difference() {
                apply_master_bounds(w, l, h, m_c_rad(data), m_chamf(data))
                    core_tray_chassis(data_g);
                // Hinge bore recess — centred on axle, open at box top for C-clip entry.
                // Axle sits at l/2−hinge_y so the C-clip outer edge is flush with l/2.
                if (clip_len > 0)
                    translate([0, l/2 - hinge_y, axle_z])
                        yrot(90) cyl(d=clip_od + clearance*4, h=clip_len+2, $fn=36);
            }
            // Hinge pillars — fill from l/2−clip_od to l/2, height up to axle crown.
            // This keeps the full hinge assembly within the box's total footprint.
            if (clip_len > 0) {
            // EPS corrections: outer X face would land at ±w/2 (box outer wall) — coplanar.
            // Back Y face would land at l/2 (box outer wall) — coplanar.
            // Width  sw*3 - EPS → outer X face at ±w/2 + EPS/2 (inside wall material). ✓
            // Depth clip_od - EPS → back Y face at l/2 - EPS (inside wall material). ✓
            // Bottom EPS sink: pillar bottom at sf-EPS (not sf) — avoids floor-top coplanar.
            // Height axle_z+cc_z-sf: top at sf-EPS+(axle_z+cc_z-sf) = axle_z+cc_z-EPS = h-EPS.
            // axle_z+cc_z = h exactly, so +EPS on height would bring top to h — coplanar with
            // box top face. Keep height as axle_z+cc_z-sf so top lands at h-EPS. ✓
            translate([-(w-sw*2)/2 + sw/2, l/2 - clip_od, sf - EPS])
                cuboid([sw*3 - EPS, clip_od - EPS, axle_z+cc_z-sf], chamfer=m_chamf(data),
                       edges=TOP, anchor=BOTTOM+FRONT);
            translate([ (w-sw*2)/2 - sw/2, l/2 - clip_od, sf - EPS])
                cuboid([sw*3 - EPS, clip_od - EPS, axle_z+cc_z-sf], chamfer=m_chamf(data),
                       edges=TOP, anchor=BOTTOM+FRONT);
            if (cols > 1 && !skip_p)
                for (i = [1 : cols-1])
                    translate([-int_w/2 + i*(int_w/cols), l/2 - clip_od, sf - EPS])
                        cuboid([div_t, clip_od, axle_z+cc_z-sf], chamfer=m_chamf(data),
                               edges=TOP, anchor=BOTTOM+FRONT);
            // Axle pin — EPS2 so ends at ±(w/2−sw+EPS), past box inner wall face.
            translate([0, l/2 - hinge_y, axle_z])
                yrot(90) cyl(d=hinge_d, h=w - sw*2 + EPS2, chamfer=0.5, $fn=36);
            } // end clip_len > 0 guard
            // Diamond latch recess — cutter matches lid tab shape.
            // Z-tips widened to noz*1.05 to mirror the truncated lid tab (same extrusion width).
            // +EPS on Y so hull root face is EPS inside the wall, not coplanar with wall -Y face.
            translate([0, -l/2 + EPS, latch_z])
                hull() {
                    translate([0,  0,   0.8]) cuboid([w-sw*4, 0.1, noz*1.05], anchor=CENTER);
                    translate([0, -0.8, 0  ]) cuboid([w-sw*4, noz*2, 0.1   ], anchor=CENTER);
                    translate([0,  0,  -0.8]) cuboid([w-sw*4, 0.1, noz*1.05], anchor=CENTER);
                }
        }

    } else if (lid_type == "Flip_Double") {
        // ── Double flip-hinge box: bosses on both Y faces ───────────────────────
        hinge_d     = 4.0;
        clearance   = breathing_room(COMP_CCLIP, data);
        clasp_depth = engagement_depth(COMP_CLASP, data);
        spine_gap   = breathing_room(COMP_SPINE, data);
        clip_wall   = noz * 4;
        clip_od     = hinge_d + clearance*2 + clip_wall*2;
        cc_z        = clip_od / 2;
        hinge_y     = clip_od/2 + spine_gap;
        latch_z     = flip_latch_z(h, cc_z, clasp_depth);
        spine_w    = hinge_y*2 + hinge_d;
        axle_z     = h - cc_z;
        clip_len   = w - sw*6;
        int_w      = w - sw*2;
        div_t      = get_val(THICK_DIVIDER, data, 1.2);
        g_str      = get_val(GRID_LAYOUT, data, "");
        tok_x      = [for (tok = str_split(g_str, " "))
                          if (len(search("x", tok)) > 0 || len(search("X", tok)) > 0) tok];
        cols       = len(tok_x) > 0
                     ? max(1, to_num(get_digits(str_split(tok_x[0], "xX")[0])))
                     : 1;
        skip_p     = get_val(SKIP_PILLARS, data, false);
        spine_fill = get_val("SPINE_FILL", opts, false);

        assert(clip_len > 0, str(
            "Flip_Double requires w > ", sw*6, "mm. ",
            "Current w=", w, "mm, sw=", sw, "mm. ",
            "Increase part_width or reduce Wall_Loops."));

        union() {
            difference() {
                apply_master_bounds(w, l, h, m_c_rad(data), m_chamf(data))
                    core_tray_chassis(data_g);
                // Spine-fill variant: cut individual bore cylinders only.
                // Hull variant: cut the full pill-shaped slab between hinges (original).
                // Individual cuts leave spine material between the two hinges intact;
                // hull removes everything between them (creating the visible open gap).
                if (spine_fill) {
                    for (sy = [-1, 1])
                        translate([0, sy*hinge_y, axle_z])
                            yrot(90) cyl(d=clip_od + clearance*4, h=clip_len+2, $fn=36);
                } else {
                    hull() {
                        translate([0, -hinge_y, axle_z])
                            yrot(90) cyl(d=clip_od + clearance*4, h=clip_len+2, $fn=36);
                        translate([0,  hinge_y, axle_z])
                            yrot(90) cyl(d=clip_od + clearance*4, h=clip_len+2, $fn=36);
                    }
                }
            }
            // Spine pillars (corner supports, both variants)
            // EPS-shrunk width: outer X face would land at ±w/2 (box wall) — coplanar = non-manifold.
            // Bottom EPS sink: pillar bottom at sf-EPS (not sf) — avoids floor-top coplanar.
            // Height axle_z+cc_z-sf: top at h-EPS (not h) — avoids box-top coplanar. ✓
            translate([-(w-sw*2)/2 + sw/2, 0, sf - EPS])
                cuboid([sw*3 - EPS, spine_w, axle_z+cc_z-sf], chamfer=m_chamf(data),
                       edges=TOP, anchor=BOTTOM);
            translate([ (w-sw*2)/2 - sw/2, 0, sf - EPS])
                cuboid([sw*3 - EPS, spine_w, axle_z+cc_z-sf], chamfer=m_chamf(data),
                       edges=TOP, anchor=BOTTOM);
            if (cols > 1 && !skip_p)
                for (i = [1 : cols-1])
                    translate([-int_w/2 + i*(int_w/cols), 0, sf - EPS])
                        cuboid([div_t, spine_w, axle_z+cc_z-sf], chamfer=m_chamf(data),
                               edges=TOP, anchor=BOTTOM);
            // Spine fill — connects the two side pillars across the full spine width.
            // Only for SPINE_FILL variant: individual bore cuts leave the chassis solid
            // between hinges, so this block merges seamlessly with the retained material.
            if (spine_fill && clip_len > 0)
                translate([0, 0, sf - EPS])
                    cuboid([int_w - sw*6, spine_w, axle_z+cc_z-sf],
                           chamfer=m_chamf(data), edges=TOP, anchor=BOTTOM);
            // Two axle pins — EPS2 so ends at ±(w/2−sw+EPS), past box inner wall face.
            translate([0, -hinge_y, axle_z])
                yrot(90) cyl(d=hinge_d, h=w - sw*2 + EPS2, chamfer=0.5, $fn=36);
            translate([0,  hinge_y, axle_z])
                yrot(90) cyl(d=hinge_d, h=w - sw*2 + EPS2, chamfer=0.5, $fn=36);
            // Diamond latch recesses on both Y faces — Z-tips truncated to match lid tab.
            // EPS shrink on Y: hull root face at sy*(l/2−EPS) — inside wall, not coplanar.
            for (sy = [-1, 1])
                translate([0, sy * (l/2 - EPS), latch_z])
                    hull() {
                        translate([0, sy*0,    0.8]) cuboid([w-sw*4, 0.1, noz*1.05], anchor=CENTER);
                        translate([0, sy*0.8,  0  ]) cuboid([w-sw*4, noz*2, 0.1   ], anchor=CENTER);
                        translate([0, sy*0,   -0.8]) cuboid([w-sw*4, 0.1, noz*1.05], anchor=CENTER);
                    }
        }
    }
}

module factory_render_flip_box(data, opts, phys) {
    factory_render_box(data, concat([["LID_TYPE", "Flip_Single"]], opts), phys);
}

module factory_render_double_flip_box(data, opts, phys) {
    factory_render_box(data, concat([["LID_TYPE", "Flip_Double"]], opts), phys);
}
