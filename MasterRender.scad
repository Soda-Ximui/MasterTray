// ==============================================================================
// FILE: MasterRender.scad [v3.7]
// ARCHITECTURE: Layer 2 (The Render Pipeline & Geometry Modules)
// ==============================================================================

include <MasterUtility.scad> 

function apply_inductions(data) = let(type = get_val(TYPE, data, BOX), ui_pat = get_val(PATTERN, data, TEARDROP)) ((type == DESICCANT_BOX || type == DESICCANT_LID) && ui_pat != NONE) ? concat([[PATTERN, SLOTTED]], data) : data;
function enforce_safety(data) = concat([ [THICK_WALL, m_safe_wall(data)], [THICK_FLOOR, m_safe_floor(data)] ], data);
function process_part(part_data) = enforce_safety(apply_inductions(part_data));

module apply_master_bounds(w, l, h, r, c) { c_r = max(0.1, min(r, (w/2) - 0.1, (l/2) - 0.1)); intersection() { children(); cuboid([w,l,h*3], rounding=c_r, edges="Z", anchor=BOTTOM); } }
module native_teardrop(d) { union() { circle(d=d); polygon([[-d/2, 0], [d/2, 0], [0, d/2 * 1.5]]); } }

module framed_mesh(data, w, l, h, is_cyl=false, cfg=undef) {
    noz = m_noz(data); pat = get_val(PATTERN, data, PATTERN0); min_sp = 1.2;
    if (cfg == undef) { linear_extrude(height=h, center=true) { if (is_cyl) circle(d=w); else rect([w, l]); } } 
    else { hole = cfg[0]; solid = cfg[1]; step = get_grid_step(hole, min_sp, noz); nx = get_n_steps(w, solid, step); ny = get_n_steps(l, solid, step); pad = is_cyl ? 0 : (noz * 3) * 1.5; 
        linear_extrude(height=h, center=true) { difference() { if (is_cyl) circle(d=w); else rect([w, l]); intersection() { if (is_cyl) circle(d=get_mesh_dim(w, solid)); else rect([max(0.1, get_mesh_dim(w, solid)-pad), max(0.1, get_mesh_dim(l, solid)-pad)]); if (pat == HONEYCOMB) { grid_copies(spacing=[step, step * sin(60)], n=[nx, ny], stagger=true) circle(d=hole / sin(60), $fn=6); } else if (pat == TEARDROP) { grid_copies(spacing=step, n=[nx, ny]) native_teardrop(hole); } else if (pat == SLOTTED) { grid_copies(spacing=[step*1.5, step], n=[nx, ny]) rect([hole * 2, hole], rounding=hole*0.2); } else if (pat == CIRCLE) { grid_copies(spacing=step, n=[nx, ny]) circle(d=hole); } else if (pat == SQUARE) { grid_copies(spacing=step, n=[nx, ny]) rect([hole, hole]); } else if (pat == DIAMOND) { grid_copies(spacing=step, n=[nx, ny]) rotate(45) rect([hole, hole]); } } } } }
}

module cylindrical_mesh_wall(data, d, h, wall_t, cfg=undef) {
    pat = get_val(PATTERN, data, PATTERN0); min_sp = 1.2; noz = m_noz(data);
    if (cfg == undef) { difference() { cyl(d=d, h=h, anchor=BOTTOM); down(1) cyl(d=d - wall_t * 2, h=h + 2, anchor=BOTTOM); } } 
    else { hole = cfg[0]; solid = cfg[1]; h_active = h * (1 - (solid / 100)); step = get_grid_step(hole, min_sp, noz); nz = max(1, floor(h_active / step)); na = max(3, floor((PI * d) / step)); a_step = 360 / na; z_step = h_active / nz;
        difference() { difference() { cyl(d=d, h=h, anchor=BOTTOM); down(1) cyl(d=d - wall_t * 2, h=h + 2, anchor=BOTTOM); } for (i = [0 : nz - 1]) { for (j = [0 : na - 1]) { z_pos = (h - h_active) / 2 + (i + 0.5) * z_step; zrot(j * a_step) translate([d / 2, 0, z_pos]) { yrot(90) { if (pat == HONEYCOMB) { cyl(d=hole / sin(60), h=wall_t * 4, $fn=6); } else if (pat == TEARDROP) { linear_extrude(wall_t * 4, center=true) native_teardrop(hole); } else if (pat == SLOTTED) { cuboid([hole*2, hole, wall_t * 4]); } else if (pat == CIRCLE) { cyl(d=hole, h=wall_t * 4); } else if (pat == SQUARE) { cuboid([hole, hole, wall_t * 4]); } else if (pat == DIAMOND) { zrot(45) cuboid([hole, hole, wall_t * 4]); } } } } } }
    }
}

module render_internal_grid(data) {
    if (get_val(HAS_BUILTIN_GRID, data, false)) {
        type = get_val(TYPE, data, BOX); bw = m_bw(data); bl = m_bl(data); bh = m_bh(data); sf = m_safe_floor(data); sw = m_safe_wall(data); div_t = get_val(THICK_DIVIDER, data, 1.2);
        g_str = get_val(GRID_LAYOUT, data, ""); tokens = str_split(g_str, " ");
        
        if (type == JAR) {
            lip_h = 8.0; has_threads = get_val(HAS_THREADS, data, false);
            int_h = has_threads ? bh - sf - lip_h - sw*1.5 : bh - sf; int_d = bw - sw*2;
            tok_r = [for (tok=tokens) if (tok[0]=="R" || tok[0]=="r") tok]; rays = len(tok_r)>0 ? (len(get_digits(tok_r[0]))>0 ? to_num(get_digits(tok_r[0])) : 4) : 0; 
            tok_c = [for (tok=tokens) if (tok[0]=="C" || tok[0]=="c") tok]; has_c = len(tok_c)>0; c_dia = has_c ? (len(get_digits(tok_c[0]))>0 ? to_num(get_digits(tok_c[0])) : 10.0) : 6.0; 
            up(sf) {
                inner_dia = c_dia - (div_t * 2); c_eff = (inner_dia >= 1.5) ? c_dia : max(4.0, c_dia); 
                if (inner_dia >= 1.5) { difference() { cyl(d=c_eff, h=int_h, anchor=BOTTOM); down(1) cyl(d=inner_dia, h=int_h+2, anchor=BOTTOM); } } else { cyl(d=c_eff, h=int_h, anchor=BOTTOM); }
                if (rays > 0) { for(i=[0:rays-1]) zrot(i * 360/rays) translate([c_eff/2 - 0.1, -div_t/2, 0]) cuboid([int_d/2 - c_eff/2 + 0.1, div_t, int_h], anchor=BOTTOM+LEFT); }
            }
        } else {
            int_w = bw - sw*2; int_l = bl - sw*2; int_h = bh - sf;
            tok_x = [for (tok=tokens) if (len(search("x", tok))>0 || len(search("X", tok))>0) tok];
            if (len(tok_x) > 0) {
                dims = str_split(tok_x[0], "xX"); cols = max(1, to_num(get_digits(dims[0]))); rows = max(1, to_num(get_digits(dims[1])));
                up(sf) {
                    // [V3.7 FIX] Changed center=true to anchor=CENTER for BOSL2 cuboid compatibility
                    for(i=[1:cols-1]) translate([-int_w/2 + i*(int_w/cols), 0, int_h/2]) cuboid([div_t, int_l, int_h], anchor=CENTER);
                    for(j=[1:rows-1]) translate([0, -int_l/2 + j*(int_l/rows), int_h/2]) cuboid([int_w, div_t, int_h], anchor=CENTER);
                }
            }
        }
    }
}

module render_box_grid(data) {
    bw = m_bw(data); bl = m_bl(data); bh = m_bh(data); sf = m_safe_floor(data); sw = m_safe_wall(data); div_t = get_val(THICK_DIVIDER, data, 1.2);
    int_w = bw - sw*2 - 0.4; int_l = bl - sw*2 - 0.4; int_h = bh - sf - 0.5;   
    g_str = get_val(GRID_LAYOUT, data, ""); tokens = str_split(g_str, " ");
    tok_x = [for (tok=tokens) if (len(search("x", tok))>0 || len(search("X", tok))>0) tok][0]; dims = str_split(tok_x, "xX");
    cols = max(1, to_num(get_digits(dims[0]))); rows = max(1, to_num(get_digits(dims[1])));
    has_base = get_val(GRID_HAS_BASE, data, false); base_t = has_base ? m_lh(data)*4 : 0; 
    apply_master_bounds(int_w, int_l, int_h, m_c_rad(data)-sw, m_chamf(data)/2) { 
        if (has_base) cuboid([int_w, int_l, base_t], anchor=BOTTOM);
        up(base_t) {
            // [V3.7 FIX] Changed center=true to anchor=CENTER for BOSL2 cuboid compatibility
            for(i=[1:cols-1]) translate([-int_w/2 + i*(int_w/cols), 0, int_h/2]) cuboid([div_t, int_l, int_h], anchor=CENTER);
            for(j=[1:rows-1]) translate([0, -int_l/2 + j*(int_l/rows), int_h/2]) cuboid([int_w, div_t, int_h], anchor=CENTER);
        }
    }
}

module render_jar_grid(data) {
    bw = m_bw(data); bh = m_bh(data); sf = m_safe_floor(data); sw = m_safe_wall(data); div_t = get_val(THICK_DIVIDER, data, 1.2);
    has_threads = get_val(HAS_THREADS, data, false); lip_h = 8.0; int_h = has_threads ? bh - sf - lip_h - sw*1.5 - 0.5 : bh - sf - 0.5; int_d = bw - sw*2 - 0.4; 
    g_str = get_val(GRID_LAYOUT, data, ""); tokens = str_split(g_str, " ");
    tok_r = [for (tok=tokens) if (tok[0]=="R" || tok[0]=="r") tok]; rays = len(tok_r)>0 ? (len(get_digits(tok_r[0]))>0 ? to_num(get_digits(tok_r[0])) : 4) : 0; 
    tok_c = [for (tok=tokens) if (tok[0]=="C" || tok[0]=="c") tok]; has_c = len(tok_c)>0; c_dia = has_c ? (len(get_digits(tok_c[0]))>0 ? to_num(get_digits(tok_c[0])) : 10.0) : 6.0; 
    has_base = get_val(GRID_HAS_BASE, data, false); base_t = has_base ? m_lh(data)*4 : 0;
    union() {
        if (has_base) cyl(d=int_d, h=base_t, anchor=BOTTOM);
        up(base_t) {
            inner_dia = c_dia - (div_t * 2); c_eff = (inner_dia >= 1.5) ? c_dia : max(4.0, c_dia);
            if (inner_dia >= 1.5) { difference() { cyl(d=c_eff, h=int_h, anchor=BOTTOM); down(1) cyl(d=inner_dia, h=int_h+2, anchor=BOTTOM); } } else { cyl(d=c_eff, h=int_h, anchor=BOTTOM); }
            if (rays > 0) { for(i=[0:rays-1]) zrot(i * 360/rays) translate([c_eff/2 - 0.1, -div_t/2, 0]) cuboid([int_d/2 - c_eff/2 + 0.1, div_t, int_h], anchor=BOTTOM+LEFT); }
        }
    }
}

module core_tray_chassis(data) {
    bw = m_bw(data); bl = m_bl(data); bh = m_bh(data); sf = m_safe_floor(data); sw = m_safe_wall(data); actual_wall_h = bh - sf; 
    targ = get_val(WALL_TARGET, data, "All Walls"); mod_p = m_wall_mod_p(data) / 100;
    h_front = (targ == "Front" || targ == "All Walls") ? max(0.1, actual_wall_h * mod_p) : actual_wall_h; h_back  = (targ == "Back" || targ == "All Walls") ? max(0.1, actual_wall_h * mod_p) : actual_wall_h;
    h_left  = (targ == "Left" || targ == "All Walls") ? max(0.1, actual_wall_h * mod_p) : actual_wall_h; h_right = (targ == "Right" || targ == "All Walls") ? max(0.1, actual_wall_h * mod_p) : actual_wall_h;
    union() {
        up(sf / 2) framed_mesh(data, bw, bl, sf, false, get_mesh_cfg(data, HOLE_FLOOR, STRUT_FLOOR));
        translate([0, -bl / 2 + sw / 2, (sf + h_front / 2)]) xrot(90) framed_mesh(data, bw, h_front, sw, false, get_mesh_cfg(data, HOLE_WALL, STRUT_WALL)); 
        translate([0, bl / 2 - sw / 2, (sf + h_back / 2)]) xrot(90) framed_mesh(data, bw, h_back, sw, false, get_mesh_cfg(data, HOLE_WALL, STRUT_WALL)); 
        translate([-bw / 2 + sw / 2, 0, (sf + h_left / 2)]) zrot(90) xrot(90) framed_mesh(data, bl, h_left, sw, false, get_mesh_cfg(data, HOLE_WALL, STRUT_WALL)); 
        translate([bw / 2 - sw / 2, 0, (sf + h_right / 2)]) zrot(90) xrot(90) framed_mesh(data, bl, h_right, sw, false, get_mesh_cfg(data, HOLE_WALL, STRUT_WALL)); 
        render_internal_grid(data); 
    }
}

module render_box(data) { 
    sw = m_safe_wall(data); apply_master_bounds(m_bw(data), m_bl(data), m_bh(data), m_c_rad(data), m_chamf(data)) { 
        difference() { core_tray_chassis(data); if (get_val(NEEDS_GROOVE, data, false)) { up(m_bh(data) - m_safe_lid(data) - 1.0) cuboid([m_bw(data) - sw + 0.1, m_bl(data) + 0.1, m_safe_lid(data) + 0.4], anchor=BOTTOM); } }
    } 
}

module render_flip_box(data) {
    bw = m_bw(data); bl = m_bl(data); bh = m_bh(data); sw = m_safe_wall(data); sl = m_safe_lid(data); hinge_d = 4.0;
    union() {
        render_box(data); 
        translate([-(bw - sw*2)/2 + sw/2, bl/2 - 0.5, bh - 1]) cuboid([sw*3, hinge_d + 1, sl + 1], anchor=BOTTOM+FRONT);
        translate([(bw - sw*2)/2 - sw/2, bl/2 - 0.5, bh - 1]) cuboid([sw*3, hinge_d + 1, sl + 1], anchor=BOTTOM+FRONT);
        translate([0, bl/2 + hinge_d/2, bh + sl]) { yrot(90) cyl(d=hinge_d, h=bw - sw*2, chamfer=0.5, $fn=36); }
        translate([0, -bl/2, bh - 3]) cuboid([bw - sw*2, 1.5, 1.5], rounding=0.5, edges="X", anchor=BACK);
    }
}

module render_double_flip_box(data) {
    bw = m_bw(data); bl = m_bl(data); bh = m_bh(data); sw = m_safe_wall(data); sl = m_safe_lid(data); hinge_d = 4.0;
    hinge_offset = 3 + sw; 
    union() {
        render_box(data);
        translate([0, 0, bh - hinge_d]) cuboid([bw - sw*2, hinge_offset*2, hinge_d], anchor=BOTTOM);
        translate([-(bw - sw*2)/2 + sw/2, 0, bh - 1]) cuboid([sw*3, hinge_offset*2, sl + 1], anchor=BOTTOM);
        translate([(bw - sw*2)/2 - sw/2, 0, bh - 1]) cuboid([sw*3, hinge_offset*2, sl + 1], anchor=BOTTOM);
        translate([0, -hinge_offset, bh + sl]) yrot(90) cyl(d=hinge_d, h=bw - sw*2, chamfer=0.5, $fn=36);
        translate([0, hinge_offset, bh + sl]) yrot(90) cyl(d=hinge_d, h=bw - sw*2, chamfer=0.5, $fn=36);
        translate([0, -bl/2, bh - 3]) cuboid([bw - sw*2, 1.5, 1.5], rounding=0.5, edges="X", anchor=BACK);
        translate([0, bl/2, bh - 3]) cuboid([bw - sw*2, 1.5, 1.5], rounding=0.5, edges="X", anchor=FRONT);
    }
}

module render_flip_lid(data) {
    bw = m_bw(data); bl = m_bl(data); sl = m_safe_lid(data); sw = m_safe_wall(data); hinge_d = 4.0; clearance = 0.2;
    lid_w = bw; lid_l = bl; clip_len = lid_w - sw*6;
    txt = get_val(PLAQUE_TEXT, data, ""); txt_size = get_val(PLAQUE_TEXT_SIZE, data, 8);
    difference() {
        union() {
            apply_master_bounds(lid_w, lid_l, sl, m_c_rad(data), m_chamf(data)) { up(sl / 2) framed_mesh(data, lid_w, lid_l, sl, false, get_mesh_cfg(data, HOLE_LID, STRUT_LID, true)); }
            translate([0, lid_l/2 + hinge_d/2, sl]) { 
                difference() { 
                    yrot(90) cyl(d=hinge_d + sw*2.5, h=clip_len, chamfer=0.5, $fn=36); 
                    yrot(90) cyl(d=hinge_d + clearance*2, h=clip_len + 2, $fn=36); 
                    translate([0, hinge_d/2, 0]) cuboid([clip_len + 2, hinge_d, hinge_d*0.8], anchor=CENTER); 
                } 
                translate([0, -hinge_d/4, 0]) cuboid([clip_len, hinge_d/2 + 0.1, sl], anchor=CENTER);
            }
            translate([0, -lid_l/2 + sw, sl]) { difference() { cuboid([lid_w - sw*2, sw + 1.5, 4], anchor=BOTTOM+FRONT); up(1.5) cuboid([lid_w, 2, 1.5], rounding=0.5, edges="X", anchor=FRONT); } }
        }
        if (txt != "") { translate([0, 0, sl - 0.4]) linear_extrude(1) text(txt, size=txt_size, font="Arial Black", halign="center", valign="center"); }
    }
}

module render_tray_simple(data) { apply_master_bounds(m_bw(data), m_bl(data), m_bh(data), m_c_rad(data), m_chamf(data)) { core_tray_chassis(data); } }

module render_tray_stack(data) { 
    bw = m_bw(data); bl = m_bl(data); bh = m_bh(data); sw = m_safe_wall(data); sf = m_safe_floor(data);
    socket_d = 8.0; 
    boss_d = socket_d + sw*2; 
    
    cx = bw/2 - sw - boss_d/2 + 0.1; 
    cy = bl/2 - sw - boss_d/2 + 0.1;
    
    socket_depth = 12.0; 
    
    difference() {
        union() { 
            render_tray_simple(data); 
            down(2) apply_master_bounds(bw-sw*2, bl-sw*2, 2, m_c_rad(data)-sw, m_chamf(data)) cuboid([bw, bl, 2.1], anchor=BOTTOM); 
            for(x=[-1,1]) for(y=[-1,1]) translate([x*cx, y*cy, -2]) cyl(d=boss_d, h=bh + 2, anchor=BOTTOM);
        }
        for(x=[-1,1]) for(y=[-1,1]) {
            translate([x*cx, y*cy, bh + 0.1]) cyl(d=socket_d, h=socket_depth, anchor=TOP);
            translate([x*cx, y*cy, -2.1]) cyl(d=socket_d, h=socket_depth, anchor=BOTTOM);
        }
    }
}

module render_peg(data) {
    p_len = get_val(PEG_HEIGHT, data, 80); tol = get_val(TOL_CLIP, data, 0.1); p_dia = 8.0 - (tol * 2); 
    difference() { yrot(90) cyl(d=p_dia, h=p_len, chamfer=0.5, anchor=CENTER); down(p_dia/2) cuboid([p_len + 2, p_dia + 2, 1], anchor=BOTTOM); }
}

module render_lid(data) { bw = m_bw(data); bl = m_bl(data); sl = m_safe_lid(data); sw = m_safe_wall(data); lid_w = bw - sw - 0.6; lid_l = bl - sw / 2 - 0.6; apply_master_bounds(lid_w, lid_l, sl, m_c_rad(data), m_chamf(data)) { up(sl / 2) framed_mesh(data, lid_w, lid_l, sl, false, get_mesh_cfg(data, HOLE_LID, STRUT_LID, true)); } }
module render_lid_glide(data) { bw = m_bw(data); bl = m_bl(data); sl = m_safe_lid(data); sw = m_safe_wall(data); lid_w = bw - sw + 0.2; lid_l = bl - sw / 2; apply_master_bounds(lid_w, lid_l, sl, m_c_rad(data), m_chamf(data)) { up(sl / 2) framed_mesh(data, lid_w, lid_l, sl, false, get_mesh_cfg(data, HOLE_LID, STRUT_LID, true)); } }
module render_jar(data) { has_threads = get_val(HAS_THREADS, data, false); bw = m_bw(data); sf = m_safe_floor(data); sw = m_safe_wall(data); lip_h = 8.0; actual_wall_h = m_bh(data) - sf; cyl_wall_h = max(0.1, has_threads ? (actual_wall_h - lip_h - sw * 1.5) : actual_wall_h); neck_od = bw - sw * 2 - 0.6; neck_id = neck_od - sw * 2; union() { up(sf / 2) framed_mesh(data, bw, bw, sf, true, get_mesh_cfg(data, HOLE_FLOOR, STRUT_FLOOR)); up(sf) cylindrical_mesh_wall(data, bw, cyl_wall_h, sw, get_mesh_cfg(data, HOLE_WALL, STRUT_WALL)); render_internal_grid(data); if (has_threads) { up(sf + cyl_wall_h) { difference() { cyl(d1=bw, d2=neck_od, h=sw * 1.5, anchor=BOTTOM); down(1) cyl(d=neck_id, h=sw * 1.5 + 2, anchor=BOTTOM); } } up(sf + cyl_wall_h + sw * 1.5) { difference() { threaded_rod(d=neck_od, l=lip_h, pitch=get_val(THREAD_PITCH, data, 2.0), internal=false, anchor=BOTTOM, $fn=30); down(1) cyl(d=neck_id, h=lip_h + 2, anchor=BOTTOM); } } } } }
module render_jar_lid(data) { bw = m_bw(data); sw = m_safe_wall(data); sl = m_safe_lid(data); lip_h = 8.0; cap_h = max(0.1, lip_h + sw * 1.5); neck_od = bw - sw * 2 - 0.6; difference() { union() { up(cap_h + sl / 2) framed_mesh(data, bw, bw, sl, true, get_mesh_cfg(data, HOLE_LID, STRUT_LID, true)); cyl(d=bw, h=cap_h, chamfer2=m_chamf(data), anchor=BOTTOM); } up(-0.1) threaded_rod(d=neck_od + 0.8, l=cap_h + 1, pitch=get_val(THREAD_PITCH, data, 2.0), internal=false, anchor=BOTTOM, $fn=30); } }
module render_plaque(data) { txt = get_val(PLAQUE_TEXT, data, ""); txt_size = get_val(PLAQUE_TEXT_SIZE, data, 8); p_w = get_val(WIDTH, data, max(25, txt_size * len(txt) * 0.65)); difference() { cuboid([p_w, 20, 1.0], rounding=1.5, edges="Z", anchor=BOTTOM); up(0.4) linear_extrude(1) text(txt, size=txt_size, font="Arial Black", halign="center", valign="center"); } }

module build_part(data) {
    generate_preflight_report(data);
    type = get_val(TYPE, data, BOX);
    if (type == BOX || type == DESICCANT_BOX) render_box(data);
    else if (type == TRAY_SIMPLE) render_tray_simple(data);
    else if (type == TRAY_STACK) render_tray_stack(data);
    else if (type == PEG) render_peg(data);
    else if (type == FLIP_BOX) render_flip_box(data);
    else if (type == DOUBLE_FLIP_BOX) render_double_flip_box(data);
    else if (type == FLIP_LID) render_flip_lid(data);
    else if (type == LID || type == DESICCANT_LID) render_lid(data);
    else if (type == LID_GLIDE) render_lid_glide(data);
    else if (type == PLAQUE) render_plaque(data);
    else if (type == JAR) render_jar(data); 
    else if (type == JAR_LID) render_jar_lid(data);
    else if (type == BOX_GRID) render_box_grid(data);
    else if (type == JAR_GRID) render_jar_grid(data);
}

module build_platter(manifest) { for (i = [0 : len(manifest) - 1]) { pos = get_xy(manifest, i); translate([pos[0], pos[1], 0]) build_part(manifest[i]); } }