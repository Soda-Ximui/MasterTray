// ==============================================================================
// FILE: RenderGrid.scad
// ARCHITECTURE: Layer 3 (Factory)
// PURPOSE: Cartesian and radial grid dividers — built-in (fused to chassis) and
//          drop-in (standalone printable piece with tolerance gap).
//
// BUILT-IN GRID:
//   render_internal_grid called from core_tray_chassis when HAS_BUILTIN_GRID=true.
//   GRID_WALL_H injected by factory_render_box — caps divider height so lid closes.
//     Flip lids → capped at axle_z    Plain box → full interior height
//
// DROP-IN GRID:
//   factory_render_grid called from manifest. Outer dims shrunk by GRID_DROP_IN_TOL.
//   Optional base plate (GRID_HAS_BASE).
//
// LAYOUT STRING: "CxR [S row/col/colSpan/rowSpan/wall_h] [Ra] [Cb]"
//   3x7            — 3 rows × 7 columns
//   S1/1/2/3/150%  — span at (row1,col1): 2 cols wide, 3 rows tall, wall=150% of default
//   S1/1/2/3/25    — same span, wall=25mm absolute
//   R6 C20%        — 6 radial spokes, centre hub = 20% of diameter
// ==============================================================================
include <BOSL2/std.scad>
include <MasterEngine.scad>
include <GridLayout.scad>
include <RenderRib.scad>

GRID_DROP_IN_TOL = 0.4; // clearance so drop-in slides inside the container

// render_cartesian_walls — shared by built-in and drop-in cartesian grids.
// Renders column dividers, row dividers, and span cuboids at their respective heights.
module render_cartesian_walls(cols, rows, spans, int_w, int_l, default_h, div_t) {
    cw = (int_w - div_t * (cols - 1)) / cols;
    cl = (int_l - div_t * (rows - 1)) / rows;
    // Column dividers
    if (cols > 1)
        for (i = [1 : cols-1])
            translate([-int_w/2 + i*(cw + div_t) - div_t/2, 0, default_h/2])
                cuboid([div_t, int_l, default_h], anchor=CENTER);
    // Row dividers
    if (rows > 1)
        for (i = [1 : rows-1])
            translate([0, int_l/2 - i*(cl + div_t) + div_t/2, default_h/2])
                cuboid([int_w, div_t, default_h], anchor=CENTER);
    // Spans: taller border walls around merged cell area.
    // Format from parse_single_span: [row_start, col_start, row_span, col_span, h, ...]
    // X axis = column direction (width), Y axis = row direction (length).
    // h clamped to default_h — factory may inject a tighter GRID_WALL_H after parse_spans.
    for (s = spans) {
        start_row = s[0]; start_col = s[1]; row_span = s[2]; col_span = s[3];
        h = span_h_clamped(s[4], default_h);
        s_w = cw * col_span + div_t * (col_span - 1);   // X extent = col_span cells
        s_l = cl * row_span + div_t * (row_span - 1);   // Y extent = row_span cells
        pos_x = -int_w/2 + (start_col - 1) * (cw + div_t) + s_w/2;
        pos_y =  int_l/2 - (start_row - 1) * (cl + div_t) - s_l/2;
        inner_w = s_w - div_t * 2;
        inner_l = s_l - div_t * 2;
        // Outer box extended by EPS on all sides to overlap adjacent regular dividers.
        // Without this, the span outer faces are exactly flush with neighbouring divider
        // faces → coincident geometry → Z-fighting (green preview artefact).
        translate([pos_x, pos_y, 0])
            if (inner_w > 0 && inner_l > 0)
                difference() {
                    cuboid([s_w + EPS2, s_l + EPS2, h], anchor=BOTTOM);
                    up(-EPS) cuboid([inner_w, inner_l, h + EPS2], anchor=BOTTOM);
                }
            else
                cuboid([s_w + EPS2, s_l + EPS2, h], anchor=BOTTOM);
    }
}

// _render_radial_core — shared radial spoke geometry for jar grids.
module _render_radial_core(int_h, radius, div_t, cfg) {
    rays    = cfg[1][0];
    c_raw   = cfg[1][1];
    is_perc = cfg[1][2];
    // Convert C percentage to actual diameter; absolute values used as-is.
    c_dia   = is_perc ? radius * 2 * (c_raw / 100) : c_raw;
    inner   = c_dia - div_t * 2;
    // Thresholds scale with nozzle so the hub is always structurally sound.
    // min_hollow: inner hole must span at least 6 extrusion passes — below this it's
    //   so small the slicer will fill it solid anyway, creating a stress-riser void.
    // min_solid:  if forced solid, ensure 10 passes across the full diameter.
    min_hollow = nozzle_d * 6;
    min_solid  = nozzle_d * 10;
    c_eff   = (inner >= min_hollow) ? c_dia : max(min_solid, c_dia);
    if (inner >= min_hollow)
        difference() {
            cyl(d=c_eff, h=int_h, anchor=BOTTOM);
            down(1) cyl(d=inner, h=int_h+2, anchor=BOTTOM);
        }
    else
        cyl(d=c_eff, h=int_h, anchor=BOTTOM);
    if (rays > 0)
        for (i = [0 : rays-1])
            zrot(i * 360/rays)
                translate([c_eff/2 - EPS, -div_t/2, 0])
                    cuboid([radius - c_eff/2 + EPS, div_t, int_h], anchor=BOTTOM+LEFT);
}

// render_internal_grid — called from core_tray_chassis (box) or factory_render_jar.
// GRID_WALL_H was injected upstream — caps divider height for lid closure.
// IS_JAR_GRID in data → clips cartesian walls to circular boundary.
module render_internal_grid(data) {
    if (get_val(HAS_BUILTIN_GRID, data, false)) {
    sf    = m_safe_floor(data);
    sw    = m_safe_wall(data);
    bh    = m_bh(data);
    bw    = m_bw(data);
    int_h = get_val(GRID_WALL_H, data, bh - sf);
    div_t = get_val(THICK_DIVIDER, data, 1.2);
    int_w = bw - sw * 2;
    int_l = m_bl(data) - sw * 2;
    is_jar = get_val(IS_JAR_GRID, data, false);
    cfg   = get_grid_config(data);
    cols  = cfg[0][0]; rows = cfg[0][1];
    spans = cfg[2];
    rays  = cfg[1][0];
    if (rays > 0 && !is_jar)
        echo(str("WARNING: layout contains radial tokens but IS_JAR_GRID is false",
                 " — radial dividers ignored for this container type."));
    up(sf) {
        if (rays > 0 && is_jar)
            _render_radial_core(int_h, int_w / 2, div_t, cfg);
        else if (is_jar) {
            // Rectangular grid clipped to jar cylinder
            intersection() {
                cyl(d=int_w, h=int_h, anchor=BOTTOM);
                render_cartesian_walls(cols, rows, spans, int_w, int_l, int_h, div_t);
            }
        } else if (cols > 1 || rows > 1 || len(spans) > 0)
            render_cartesian_walls(cols, rows, spans, int_w, int_l, int_h, div_t);
        render_franken_ribs(data);
    }
    } // end HAS_BUILTIN_GRID guard
}

// render_box_grid_core — cartesian grid body, box or clipped-to-jar.
// When IS_JAR_GRID=true in data, the grid is intersected with the jar cylinder.
module render_box_grid_core(data, is_builtin=false) {
    bw  = m_bw(data); bl = m_bl(data); bh = m_bh(data);
    sf  = m_safe_floor(data); sw = m_safe_wall(data);
    div_t   = get_val(THICK_DIVIDER, data, 1.2);
    tol     = is_builtin ? 0 : GRID_DROP_IN_TOL;
    int_w   = bw - sw*2 - tol;
    int_l   = bl - sw*2 - tol;
    int_d   = bw - sw*2 - tol;   // for jar clipping
    is_jar  = get_val(IS_JAR_GRID, data, false);
    cfg       = get_grid_config(data);
    cols      = cfg[0][0]; rows = cfg[0][1];
    spans     = cfg[2];
    // Base only for drop-in — built-in grids sit on the tray floor already
    has_base  = !is_builtin && cfg[3];
    base_t    = has_base ? cfg[4] : 0;
    default_h = is_builtin ? get_val(GRID_WALL_H, data, bh - sf) : cfg[5];

    if (is_jar) {
        // Jar: clip rectangular walls to the circular container boundary
        intersection() {
            cyl(d=int_d, h=default_h + base_t, anchor=BOTTOM);
            union() {
                if (has_base) cuboid([int_d, int_d, base_t], anchor=BOTTOM);
                up(base_t)
                    if (cols > 1 || rows > 1 || len(spans) > 0)
                        render_cartesian_walls(cols, rows, spans, int_w, int_l, default_h, div_t);
            }
        }
    } else {
        // Box: standard bounded rectangular walls
        apply_master_bounds(int_w, int_l, default_h + base_t,
                            m_c_rad(data) - sw, m_chamf(data) / 2) {
            if (has_base) cuboid([int_w, int_l, base_t], anchor=BOTTOM);
            up(base_t)
                if (cols > 1 || rows > 1 || len(spans) > 0)
                    render_cartesian_walls(cols, rows, spans, int_w, int_l, default_h, div_t);
        }
    }
}

// render_jar_grid_core — radial drop-in grid body for jars.
module render_jar_grid_core(data, is_builtin=false) {
    bw  = m_bw(data); bh = m_bh(data);
    sf  = m_safe_floor(data); sw = m_safe_wall(data);
    div_t = get_val(THICK_DIVIDER, data, 1.2);
    tol   = is_builtin ? 0 : GRID_DROP_IN_TOL;
    has_threads = get_val(HAS_THREADS, data, false);
    lip_h = JAR_LIP_HEIGHT;   // centralized in MasterConstants
    lh    = m_lh(data);
    // Drop-in clearance snapped to nearest layer — preserves alignment of int_h.
    drop_in_clr = is_builtin ? 0 : lh * ceil(0.5 / lh);
    int_h_raw = bh - sf - (has_threads ? lip_h + sw*1.5 : 0) - drop_in_clr;
    int_h = round(int_h_raw / lh) * lh;   // force layer alignment on the result
    int_d = bw - sw*2 - tol;
    cfg      = get_grid_config(data);
    // Base only for drop-in jar grids
    has_base = !is_builtin && cfg[3];
    base_t   = has_base ? cfg[4] : 0;
    union() {
        if (has_base) cyl(d=int_d, h=base_t, anchor=BOTTOM);
        up(base_t)
            intersection() {
                cyl(d=int_d, h=int_h, anchor=BOTTOM);
                _render_radial_core(int_h, int_d/2, div_t, cfg);
            }
    }
}

// factory_render_grid — drop-in grid factory (called from manifest).
// Standalone printable piece — outer dims shrunk by GRID_DROP_IN_TOL.
// IS_JAR_GRID in opts → rectangular grid clipped to jar cylinder.
module factory_render_grid(data, opts, phys) {
    g_str  = get_val(GRID_LAYOUT, data, "");
    rays   = parse_radial_rays(g_str);
    is_jar = get_val(IS_JAR_GRID, opts, false);
    // Inject IS_JAR_GRID into data so render_box_grid_core can read it
    d = is_jar ? concat([[IS_JAR_GRID, true]], data) : data;
    echo(str("-> Factory [GRID] | layout='", g_str, "' rays=", rays, " jar=", is_jar));
    if (rays > 0 && !is_jar)
        echo(str("WARNING: layout '", g_str, "' contains radial tokens (R/C) but this is",
                 " not a jar grid — radial dividers ignored. Add IS_JAR_GRID flag or",
                 " remove R/C tokens for box/tray grids."));
    up(m_safe_floor(d)) {
        if (rays > 0 && is_jar)
            render_jar_grid_core(d, false);
        else
            render_box_grid_core(d, false);
        cfg = get_grid_config(d);
        up(cfg[4]) render_franken_ribs(d);
    }
}
