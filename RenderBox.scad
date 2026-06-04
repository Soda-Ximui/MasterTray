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
    data_g = concat([[GRID_WALL_H, grid_wall_h]], data);

    if (lid_type == "Snap" || lid_type == "Slip") {
        // ── Plain box: chassis + corner rounding only ──────────────────────────
        apply_master_bounds(w, l, h, m_c_rad(data), m_chamf(data))
            core_tray_chassis(data_g);

    } else if (lid_type == "Glide") {
        // ── Glide box: groove channel + ball-catch dimples ─────────────────────
        glide_tol  = breathing_room(COMP_GLIDE, data);
        groove_w   = w - sw + 0.6;
        groove_l   = l + EPS;
        groove_h   = sl + glide_tol;
        // ceil() snaps the 1mm drop up to the nearest full layer boundary.
        // At 0.28mm lh: ceil(1.0/0.28)=4 layers → 1.12mm — groove sits on a clean layer.
        groove_z   = h - sl - m_lh(data) * ceil(1.0 / m_lh(data));
        // Ball dimple geometry — must match lid ball bumps exactly.
        // ball_protr: how deeply the ball center is recessed into the lid face.
        // Formula ensures ball center sits noz/2 past the groove wall — gentle cam entry.
        ball_d     = glide_ball_d(w, l, sw, noz);
        ball_r     = ball_d / 2;
        ball_protr = glide_ball_protr(ball_r, glide_tol, noz);
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
            // Ball-catch dimples — X matches lid ball center; Z matches groove centre
            if (glide_snap == "Ball")
                for (sx = [-1, 1])
                    translate([sx * ball_x, ball_y, groove_z + groove_h / 2])
                        sphere(d=ball_d + glide_tol);
        }

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
                // Hinge bore recess on +Y face — only cut when hinge will exist
                if (clip_len > 0)
                    translate([0, l/2 + hinge_y, axle_z])
                        yrot(90) cyl(d=clip_od + clearance*4, h=clip_len+2, $fn=36);
            }
            // Hinge pillars, axle pin — suppressed if box too narrow for mechanism
            if (clip_len > 0) {
            translate([-(w-sw*2)/2 + sw/2, l/2 - 0.5, sf])
                cuboid([sw*3, hinge_y+1, axle_z+cc_z-sf], chamfer=m_chamf(data),
                       edges=TOP, anchor=BOTTOM+FRONT);
            translate([ (w-sw*2)/2 - sw/2, l/2 - 0.5, sf])
                cuboid([sw*3, hinge_y+1, axle_z+cc_z-sf], chamfer=m_chamf(data),
                       edges=TOP, anchor=BOTTOM+FRONT);
            if (cols > 1 && !skip_p)
                for (i = [1 : cols-1])
                    translate([-int_w/2 + i*(int_w/cols), l/2 - 0.5, sf])
                        cuboid([div_t, hinge_y+1, axle_z+cc_z-sf], chamfer=m_chamf(data),
                               edges=TOP, anchor=BOTTOM+FRONT);
            // Axle pin
            translate([0, l/2 + hinge_y, axle_z])
                yrot(90) cyl(d=hinge_d, h=w - sw*2, chamfer=0.5, $fn=36);
            } // end clip_len > 0 guard
            // Diamond latch recess — cutter matches lid tab shape.
            // Z-tips widened to noz*1.05 to mirror the truncated lid tab (same extrusion width).
            translate([0, -l/2, latch_z])
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

        assert(clip_len > 0, str(
            "Flip_Double requires w > ", sw*6, "mm. ",
            "Current w=", w, "mm, sw=", sw, "mm. ",
            "Increase part_width or reduce Wall_Loops."));

        union() {
            difference() {
                apply_master_bounds(w, l, h, m_c_rad(data), m_chamf(data))
                    core_tray_chassis(data_g);
                // Hinge bore recesses on both Y faces
                hull() {
                    translate([0, -hinge_y, axle_z])
                        yrot(90) cyl(d=clip_od + clearance*4, h=clip_len+2, $fn=36);
                    translate([0,  hinge_y, axle_z])
                        yrot(90) cyl(d=clip_od + clearance*4, h=clip_len+2, $fn=36);
                }
            }
            // Spine pillars (centre, supports both hinges)
            translate([-(w-sw*2)/2 + sw/2, 0, sf])
                cuboid([sw*3, spine_w, axle_z+cc_z-sf], chamfer=m_chamf(data),
                       edges=TOP, anchor=BOTTOM);
            translate([ (w-sw*2)/2 - sw/2, 0, sf])
                cuboid([sw*3, spine_w, axle_z+cc_z-sf], chamfer=m_chamf(data),
                       edges=TOP, anchor=BOTTOM);
            if (cols > 1 && !skip_p)
                for (i = [1 : cols-1])
                    translate([-int_w/2 + i*(int_w/cols), 0, sf])
                        cuboid([div_t, spine_w, axle_z+cc_z-sf], chamfer=m_chamf(data),
                               edges=TOP, anchor=BOTTOM);
            // Two axle pins
            translate([0, -hinge_y, axle_z])
                yrot(90) cyl(d=hinge_d, h=w - sw*2, chamfer=0.5, $fn=36);
            translate([0,  hinge_y, axle_z])
                yrot(90) cyl(d=hinge_d, h=w - sw*2, chamfer=0.5, $fn=36);
            // Diamond latch recesses on both Y faces — Z-tips truncated to match lid tab.
            for (sy = [-1, 1])
                translate([0, sy * l/2, latch_z])
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
