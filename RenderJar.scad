// ==============================================================================
// FILE: RenderJar.scad
// ARCHITECTURE: Layer 2.1 (Domain Module)
// ==============================================================================

module render_jar(data) { has_threads = get_val(HAS_THREADS, data, false); bw = m_bw(data); sf = m_safe_floor(data); sw = m_safe_wall(data);
    lip_h = 8.0; actual_wall_h = m_bh(data) - sf; cyl_wall_h = max(0.1, has_threads ? (actual_wall_h - lip_h - sw * 1.5) : actual_wall_h);
    neck_od = bw - sw * 2 - 0.6; neck_id = neck_od - sw * 2;
    union() { up(sf / 2) framed_mesh(data, bw, bw, sf, true, get_mesh_cfg(data, HOLE_FLOOR, STRUT_FLOOR));
    up(sf) cylindrical_mesh_wall(data, bw, cyl_wall_h, sw, get_mesh_cfg(data, HOLE_WALL, STRUT_WALL)); render_internal_grid(data); if (has_threads) { up(sf + cyl_wall_h) { difference() { cyl(d1=bw, d2=neck_od, h=sw * 1.5, anchor=BOTTOM);
    down(1) cyl(d=neck_id, h=sw * 1.5 + 2, anchor=BOTTOM); } } up(sf + cyl_wall_h + sw * 1.5) { difference() { threaded_rod(d=neck_od, l=lip_h, pitch=get_val(THREAD_PITCH, data, 2.0), internal=false, anchor=BOTTOM, $fn=30);
    down(1) cyl(d=neck_id, h=lip_h + 2, anchor=BOTTOM); } } } } }

module render_jar_lid(data) { bw = m_bw(data); sw = m_safe_wall(data);
    sl = m_safe_lid(data); lip_h = 8.0; cap_h = max(0.1, lip_h + sw * 1.5);
    neck_od = bw - sw * 2 - 0.6; difference() { union() { up(cap_h + sl / 2) framed_mesh(data, bw, bw, sl, true, get_mesh_cfg(data, HOLE_LID, STRUT_LID, true));
    cyl(d=bw, h=cap_h, chamfer2=m_chamf(data), anchor=BOTTOM); } up(-0.1) threaded_rod(d=neck_od + 0.8, l=cap_h + 1, pitch=get_val(THREAD_PITCH, data, 2.0), internal=false, anchor=BOTTOM, $fn=30);
    } }