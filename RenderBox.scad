// ==============================================================================
// FILE: RenderBox.scad
// ARCHITECTURE: Layer 3 (Factory)
// PURPOSE: Rectangular box body — all lid-body variants driven by LID_TYPE in opts.
//
// One factory, one primitive shape. LID_TYPE determines what the body needs:
//   "Snap"  — plain chassis + thumb notch on −Y wall for over-cap lid removal
//   "Slide" — open-top groove channels on ±X interior wall tops; back wall is the stop
//   "Slip"  — plain chassis, no body modifications
//   "Glide" — groove channel cut into top + ball-catch dimples
//   "Flip_Single"   — hinge boss on +Y face, axle pin, diamond latch recess on −Y
//   "Flip_Double"   — hinge bosses on both Y faces, two axle pins, two latch recesses
//
// All geometry: core_tray_chassis + lid-specific additions/subtractions.
// No intermediate render_* wrappers — logic lives here, driven by opts.
// ==============================================================================
// BOSL2/std comes via MasterEngine — do NOT re-include (OpenSCAD has no include dedup; re-parse cost ~21s) [perf]
// MasterEngine is included once by MasterBuilder.scad (single owner) — not re-included here [perf]
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
        // ── Over-cap box: plain chassis + thumb notch ──────────────────────────
        // No groove needed. The over-cap lid skirt wraps the exterior walls;
        // friction holds it. Thumb notch on −Y wall lets a fingernail push the
        // lid upward for removal.
        notch_w = min(w * 0.4, 30.0);
        notch_h = max(noz * 8, 4.0);
        chamf   = m_chamf(data);
        difference() {
            apply_master_bounds(w, l, h, m_c_rad(data), chamf)
                core_tray_chassis(data_g);
            translate([0, -l/2, h - notch_h])
                cuboid([notch_w, sw + EPS * 2, notch_h + EPS], anchor=BOTTOM);
        }

    } else if (lid_type == "Slide") {
        // ── Matchbox slide box: open-top groove channels on ±X interior wall tops ──
        // No ceiling = zero bridging. Lid rails ride in the groove; front face has
        // two small exit slots; back wall is the natural stop.
        glide_tol  = breathing_room(COMP_GLIDE, data);
        rail_w     = noz * 3;              // groove depth into ±X wall (from interior face)
        groove_dep = sl + glide_tol;       // groove Z height: lid thickness + clearance
        chamf      = m_chamf(data);
        difference() {
            apply_master_bounds(w, l, h, m_c_rad(data), chamf)
                core_tray_chassis(data_g);
            // Groove slots on ±X interior wall tops, open to the top and exiting through
            // the −Y (front) face. Runs from front outer face to back wall interior.
            // Y center = −sw/2, length = l − sw covers [−l/2 … l/2−sw].
            for (sx = [-1, 1])
                translate([sx * (w/2 - sw + rail_w/2), -sw/2, h - groove_dep])
                    cuboid([rail_w + EPS, l - sw + EPS, groove_dep + EPS], anchor=BOTTOM);
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
            // sw*3 inset from end: keeps socket well clear of the corner where the
            // Y-wall leaves no backing material. Must match ball_y in RenderLid Rabbet.
            ball_y   = lid_l_r/2 - sw*3;
            // noz inset: moves socket away from thin rabbet wall so sphere leaves more
            // material on the outer side; must match the ball offset in RenderLid.
            ball_x_r = lid_w_r/2 + ball_r - ball_protr - noz;
            // boss_d / boss_th: pad ring on the rabbet wall face around each socket.
            // Nested difference lets us union the boss after the rabbet cut so it
            // protrudes into the rabbet channel and thickens the socket ledge.
            // boss_d / boss_th: pad ring on the rabbet wall face around each socket.
            // boss_th = ball_d + noz*4 — boss is deep enough that the sphere cutter
            // leaves at least noz*2 of structural ring on the groove-wall side.
            boss_d  = ball_d * 2 + noz * 4;
            boss_th = ball_d + noz * 4;
            difference() {
                union() {
                    difference() {
                        apply_master_bounds(w, l, h, m_c_rad(data), m_chamf(data))
                            core_tray_chassis(data_g);
                        if (glide_dir == "H")
                            for (sx = [-1, 1])
                                // int_l_r + sw: extends slot through the −Y wall face so
                                // the lid can enter from that side. +Y end stays closed (stop wall).
                                translate([sx * (int_w_r/2 + rabbet_d/2), -sw/2, h - rabbet_h])
                                    cuboid([rabbet_d + EPS, int_l_r + sw + EPS, rabbet_h + EPS], anchor=BOTTOM);
                        else
                            for (sy = [-1, 1])
                                translate([0, sy * (int_l_r/2 + rabbet_d/2), h - rabbet_h])
                                    cuboid([int_w_r + EPS, rabbet_d + EPS, rabbet_h + EPS], anchor=BOTTOM);
                    }
                    if (glide_snap == "Ball") {
                        if (glide_dir == "H")
                            for (sx = [-1, 1])
                                translate([sx * ball_x_r, ball_y, h - rabbet_h/2])
                                    yrot(90) cyl(d=boss_d, h=boss_th, $fn=36);
                        else
                            for (sy = [-1, 1])
                                translate([ball_y, sy * ball_x_r, h - rabbet_h/2])
                                    xrot(90) cyl(d=boss_d, h=boss_th, $fn=36);
                    }
                }
                if (glide_snap == "Ball") {
                    if (glide_dir == "H")
                        for (sx = [-1, 1])
                            translate([sx * ball_x_r, ball_y, h - rabbet_h/2])
                                sphere(d=ball_d + glide_tol, $fn=24);
                    else
                        for (sy = [-1, 1])
                            translate([ball_y, sy * ball_x_r, h - rabbet_h/2])
                                sphere(d=ball_d + glide_tol, $fn=24);
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
        // groove_z: top of groove is (h - sl - lh*ceil(1/lh)), leaving that margin of solid
        // wall above the groove. groove_z is the BOTTOM; groove_h extends it upward from there.
        // ceil() snaps to the nearest layer boundary so the groove top lands on a clean layer.
        groove_z   = h - sl - m_lh(data) * ceil(1.0 / m_lh(data)) - groove_h;
        lid_w      = groove_w - glide_tol;       // must match RenderLid lid_w formula
        lid_l      = l - sw / 2;
        ball_y     = lid_l / 2 - ball_r * 2.5;  // same formula as in RenderLid
        // noz inset: moves socket inward so sphere leaves more material in the groove wall;
        // must stay in sync with the matching offset in RenderLid External ball position.
        ball_x     = lid_w / 2 + ball_r - ball_protr - noz;
        // Boss pad — extra disk of material around each socket on the groove wall face.
        // Nested difference: boss is unioned after groove cut so it protrudes into the
        // groove space and gives the socket ring structural wall thickness.
        // boss_th = ball_d + noz*4 — deep enough that the sphere leaves noz*2 ring material.
        // [GEOM-FIX: ball-snap boss disconnect — KNOWN, NOT fixed] With Glide_Snap="Ball"
        // the dimple (sphere, r≈ball_r+glide_tol/2) is centred at the groove edge and cuts
        // inward, leaving only (lip − ~1.08mm) of wall behind it to bond the boss to. The
        // box splits into separate components (Slide+Ball = 4, and ~10 non-manifold edges).
        // Lip-widening was DISPROVEN: a CGAL-bondable ~1.5mm would need lip >2.6mm > the
        // 2.4mm wall. Real fix = smaller/shallower detent or relocating it off the thin
        // wall (mechanism redesign + print). WORKAROUND/STANDARD: Glide_Snap="Tab" (no boss
        // → clean 2 components). See docs/HANDOFF.md #5.
        boss_d  = ball_d * 2 + noz * 4;
        boss_th = ball_d + noz * 4;

        difference() {
            union() {
                difference() {
                    apply_master_bounds(w, l, h, m_c_rad(data), m_chamf(data))
                        core_tray_chassis(data_g);
                    up(groove_z) {
                        cuboid([groove_w, groove_l, groove_h], anchor=BOTTOM);
                        // 45° self-supporting ceiling ramp over each side-wall lip.
                        // The lip (depth ≈ (sw+0.6)/2) overhangs the channel; its flat
                        // underside prints on air. This raises the ceiling toward the
                        // interior at 45° so it self-supports. Full channel height is kept
                        // at the lid edge (~groove_w/2), so lid fit is unchanged — the ramp
                        // only adds void inward, away from the lid. Applied only when a full
                        // 45° ramp fits under the rim (else left flat — no regression). [printability]
                        gx   = groove_w / 2;
                        lip  = (sw + 0.6) / 2;
                        roof = h - (groove_z + groove_h);   // solid wall above the groove
                        // [GEOM-FIX: slide chamfer non-manifold] The ramp's base edge was
                        // coplanar with the groove cuboid's top (z=groove_h) — a coincident
                        // edge that left 2 non-manifold edges at 0.6mm nozzle / 0.30mm layer
                        // (caught by validSTL, not the component-count gate). Dropping the
                        // base by EPS makes the ramp OVERLAP the cuboid so the union merges
                        // cleanly (the EPS-overlap rule). [manifold]
                        if (lip <= roof - m_lh(data))
                            for (sx = [-1, 1])
                                rotate([90, 0, 0])
                                    linear_extrude(height = groove_l, center = true)
                                        polygon([[sx * (gx - lip), groove_h - EPS],
                                                 [sx *  gx,         groove_h - EPS],
                                                 [sx * (gx - lip), groove_h + lip]]);
                    }
                }
                if (glide_snap == "Ball")
                    for (sx = [-1, 1])
                        translate([sx * ball_x, ball_y, groove_z + groove_h / 2])
                            yrot(90) cyl(d=boss_d, h=boss_th, $fn=36);
            }
            // Ball-catch dimples — Z at groove centre so noz*2 wall exists above and below.
            if (glide_snap == "Ball")
                for (sx = [-1, 1])
                    translate([sx * ball_x, ball_y, groove_z + groove_h / 2])
                        sphere(d=ball_d + glide_tol, $fn=24);
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
        clip_len   = flip_hinge_len(w, sw);
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
                // B6 fix: bore radius scaled to 1.5x clip_od (was clip_od + flat 3.0mm).
                // A flat addition doesn't keep pace with clip_od, which itself grows
                // with nozzle diameter (clip_wall = noz*4) — at noz=0.6 the flat
                // +3.0mm left the bore's chord at the box-top edge falling just short
                // of the back wall's outer face, leaving an uncut sliver that blocked
                // the C-clip cylinder ("thin line on top, the cylinder won't go
                // through"). Scaling with clip_od keeps a positive breach margin at
                // any nozzle size. The lid's connecting block (RenderLid.scad ~170)
                // extends slightly past the C-clip's outline, so this margin also
                // keeps it clear of the back wall as the lid rotates.
                if (clip_len > 0)
                    translate([0, l/2 - hinge_y, axle_z])
                        yrot(90) cyl(d=clip_od*1.5 + clearance*4, h=clip_len+2, $fn=36);
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
            // Axle pin — LINE_W so ends at ±(w/2−sw+EPS), past box inner wall face.
            translate([0, l/2 - hinge_y, axle_z])
                yrot(90) cyl(d=hinge_d, h=w - sw*2 + LINE_W, chamfer=0.5, $fn=36);
            } // end clip_len > 0 guard
            // Diamond latch recess — cutter matches lid tab shape.
            // Z-tips widened to noz*1.05 to mirror the truncated lid tab (same extrusion width).
            // +EPS on Y so hull root face is EPS inside the wall, not coplanar with wall -Y face.
            // B5 fix: bulge at +0.8 (local +Y = into the wall, toward box interior, from
            // the origin at -l/2+EPS) so this cutter actually carves a pocket into the
            // wall. The lid's diamond tip protrudes +Y (toward the wall) to seat in it.
            translate([0, -l/2 + EPS, latch_z])
                hull() {
                    translate([0, 0,   0.8]) cuboid([w-sw*4, 0.1, noz*1.05], anchor=CENTER);
                    translate([0, 0.8, 0  ]) cuboid([w-sw*4, noz*2, 0.1   ], anchor=CENTER);
                    translate([0, 0,  -0.8]) cuboid([w-sw*4, 0.1, noz*1.05], anchor=CENTER);
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
        // hinge_y*2 + hinge_d puts the pillar ±Y faces exactly tangent to the axle cylinders
        // (cylinder radius = hinge_d/2, axle at ±hinge_y → tangent at ±(hinge_y+hinge_d/2)).
        // Curved-surface tangent against flat face → CGAL degenerate edge (§11f pattern).
        // +EPS*2: pillar ±Y faces extend EPS past the tangent points, breaking the contact.
        spine_w    = hinge_y*2 + hinge_d + EPS*2;
        axle_z     = h - cc_z;
        clip_len   = flip_hinge_len(w, sw);
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
                // B6 fix: bore radius scaled to 1.5x clip_od (was clip_od + flat
                // clearance*4, no extra margin) — see Flip_Single's bore cutter above
                // for why a flat margin fails to breach the wall at larger nozzle
                // sizes ("thin line on top, the cylinder won't go through").
                if (spine_fill) {
                    for (sy = [-1, 1])
                        translate([0, sy*hinge_y, axle_z])
                            yrot(90) cyl(d=clip_od*1.5 + clearance*4, h=clip_len+2, $fn=36);
                } else {
                    hull() {
                        translate([0, -hinge_y, axle_z])
                            yrot(90) cyl(d=clip_od*1.5 + clearance*4, h=clip_len+2, $fn=36);
                        translate([0,  hinge_y, axle_z])
                            yrot(90) cyl(d=clip_od*1.5 + clearance*4, h=clip_len+2, $fn=36);
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
            // Two axle pins — LINE_W so ends at ±(w/2−sw+EPS), past box inner wall face.
            translate([0, -hinge_y, axle_z])
                yrot(90) cyl(d=hinge_d, h=w - sw*2 + LINE_W, chamfer=0.5, $fn=36);
            translate([0,  hinge_y, axle_z])
                yrot(90) cyl(d=hinge_d, h=w - sw*2 + LINE_W, chamfer=0.5, $fn=36);
            // Diamond latch recesses on both Y faces — Z-tips truncated to match lid tab.
            // EPS shrink on Y: hull root face at sy*(l/2−EPS) — inside wall, not coplanar.
            // B5 fix: bulge at -sy*0.8 so the cutter goes into the wall (toward box
            // centre) regardless of which Y wall it's on, matching the Single-flip fix.
            for (sy = [-1, 1])
                translate([0, sy * (l/2 - EPS), latch_z])
                    hull() {
                        translate([0, sy*0,     0.8]) cuboid([w-sw*4, 0.1, noz*1.05], anchor=CENTER);
                        translate([0, -sy*0.8,  0  ]) cuboid([w-sw*4, noz*2, 0.1   ], anchor=CENTER);
                        translate([0, sy*0,    -0.8]) cuboid([w-sw*4, 0.1, noz*1.05], anchor=CENTER);
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
