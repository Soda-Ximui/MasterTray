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
// BOSL2/std comes via MasterEngine — do NOT re-include (OpenSCAD has no include dedup; re-parse cost ~21s) [perf]
// MasterEngine is included once by MasterBuilder.scad (single owner) — not re-included here [perf]
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
                    cuboid([s_w + LINE_W, s_l + LINE_W, h], anchor=BOTTOM);
                    up(-EPS) cuboid([inner_w, inner_l, h + LINE_W], anchor=BOTTOM);
                }
            else
                cuboid([s_w + LINE_W, s_l + LINE_W, h], anchor=BOTTOM);
    }
}

// _render_radial_core — shared radial spoke geometry for jar grids.
// cfg[1][3] = ray height (mm, already resolved), cfg[1][4] = hub height.
// When heights exceed the jar interior they poke above the mouth — intentional
// for open containers used as pencil/utensil holders.
module _render_radial_core(int_h, radius, div_t, cfg) {
    rays    = cfg[1][0];
    c_raw   = cfg[1][1];
    is_perc = cfg[1][2];
    // cfg[1][3] is a list of heights (cycling). cfg[1][4] is hub height (scalar).
    // Single-value list [80] = uniform height. [80,60] = alternating tall/short crown.
    ray_heights = len(cfg[1]) > 3 ? cfg[1][3] : [int_h];
    hub_h       = len(cfg[1]) > 4 ? cfg[1][4] : ray_heights[0];
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
            cyl(d=c_eff, h=hub_h, anchor=BOTTOM);
            down(1) cyl(d=inner, h=hub_h+2, anchor=BOTTOM);
        }
    else
        cyl(d=c_eff, h=hub_h, anchor=BOTTOM);
    if (rays > 0)
        for (i = [0 : rays-1]) {
            h_i = ray_heights[i % len(ray_heights)];
            zrot(i * 360/rays)
                translate([c_eff/2 - EPS, -div_t/2, 0])
                    cuboid([radius - c_eff/2 + EPS, div_t, h_i], anchor=BOTTOM+LEFT);
        }
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
        if (rays > 0 && is_jar) {
            // clip_h: tallest spoke or interior height, whichever is greater.
            ray_heights_bi = len(cfg[1]) > 3 ? cfg[1][3] : [int_h];
            clip_h = max(concat([int_h], ray_heights_bi));
            intersection() {
                cyl(d=int_w, h=clip_h, anchor=BOTTOM);
                _render_radial_core(int_h, int_w / 2, div_t, cfg);
            }
        } else if (is_jar) {
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
// Drop-in sizing depends on dimension_mode:
//   Total  — subtract computed safe-wall/floor from outer dims, add tolerance gap.
//   Usable — LWH are the target interior dims; subtract only the user wall/floor
//            settings (which were added by MasterBuilder to produce raw dims), then
//            subtract the tolerance gap so the grid slides snugly inside.
module render_box_grid_core(data, is_builtin=false) {
    bw  = m_bw(data); bl = m_bl(data); bh = m_bh(data);
    sf  = m_safe_floor(data); sw = m_safe_wall(data);
    div_t    = get_val(THICK_DIVIDER, data, 1.2);
    tol      = is_builtin ? 0 : GRID_DROP_IN_TOL;
    dim_mode = is_builtin ? "Total" : get_val(DIMENSION_MODE, data, "Total");
    tw       = get_val(THICK_WALL,  data, 2.4);
    tf       = get_val(THICK_FLOOR, data, 2.0);
    tl       = get_val(THICK_LID,   data, 2.0);
    int_w   = (dim_mode == "Usable") ? bw - tw*2 - tol : bw - sw*2 - tol;
    int_l   = (dim_mode == "Usable") ? bl - tw*2 - tol : bl - sw*2 - tol;
    int_d   = int_w;   // for jar clipping (jars: int_w == int_l)
    is_jar  = get_val(IS_JAR_GRID, data, false);
    cfg       = get_grid_config(data);
    cols      = cfg[0][0]; rows = cfg[0][1];
    spans     = cfg[2];
    // Base only for drop-in — built-in grids sit on the tray floor already.
    // "No base" still gets one layer of thickness so all ribs weld into a single
    // manifold body — prevents the slicer from splitting disconnected ribs into
    // separate objects when the user does "split to parts".
    has_base  = !is_builtin && cfg[3];
    // EPS-thin skin fuses disconnected ribs into one manifold body in the STL.
    // Sub-layer thickness → slicer discards it silently, nothing prints.
    base_t    = has_base ? cfg[4] : (is_builtin ? 0 : EPS);
    default_h = is_builtin ? get_val(GRID_WALL_H, data, bh - sf)
              : (dim_mode == "Usable") ? bh - tf - tl - tol
              : cfg[5];

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
// Drop-in sizing follows the same dimension_mode logic as render_box_grid_core.
module render_jar_grid_core(data, is_builtin=false) {
    bw  = m_bw(data); bh = m_bh(data);
    sf  = m_safe_floor(data); sw = m_safe_wall(data);
    div_t    = get_val(THICK_DIVIDER, data, 1.2);
    tol      = is_builtin ? 0 : GRID_DROP_IN_TOL;
    dim_mode = is_builtin ? "Total" : get_val(DIMENSION_MODE, data, "Total");
    tw       = get_val(THICK_WALL,  data, 2.4);
    tf       = get_val(THICK_FLOOR, data, 2.0);
    tl       = get_val(THICK_LID,   data, 2.0);
    has_threads = get_val(HAS_THREADS, data, false);
    lip_h = JAR_LIP_HEIGHT;   // centralized in MasterConstants
    lh    = m_lh(data);
    // Drop-in clearance snapped to nearest layer — preserves alignment of int_h.
    drop_in_clr = is_builtin ? 0 : lh * ceil(0.5 / lh);
    int_h_raw = (dim_mode == "Usable")
        ? bh - tf - tl - tol
        : bh - sf - (has_threads ? lip_h + sw*1.5 : 0) - drop_in_clr;
    int_h = round(int_h_raw / lh) * lh;   // force layer alignment on the result
    int_d = (dim_mode == "Usable") ? bw - tw*2 - tol : bw - sw*2 - tol;
    cfg      = get_grid_config(data);
    // Base only for drop-in jar grids. "No base" still gets one layer so all
    // radial spokes weld into a single manifold body in the slicer.
    has_base = !is_builtin && cfg[3];
    base_t   = has_base ? cfg[4] : (is_builtin ? 0 : EPS);
    ray_heights_di = len(cfg[1]) > 3 ? cfg[1][3] : [int_h];
    clip_h = max(concat([int_h], ray_heights_di));
    union() {
        if (has_base) cyl(d=int_d, h=base_t, anchor=BOTTOM);
        up(base_t)
            intersection() {
                cyl(d=int_d, h=clip_h, anchor=BOTTOM);
                _render_radial_core(int_h, int_d/2, div_t, cfg);
            }
    }
}

// factory_render_grid — drop-in grid factory (called from manifest).
// Standalone printable piece — outer dims shrunk by GRID_DROP_IN_TOL.
// IS_JAR_GRID in opts → rectangular grid clipped to jar cylinder.
// When GRID_MOD_HINTS is true, emits thin marker discs above shaped hub tops so
// the slicer "split to objects" workflow can select them as modifier volumes.
// Discs are topologically disconnected (float at hub_h + EPS) so they don't fuse.
module factory_render_grid(data, opts, phys) {
    g_str    = get_val(GRID_LAYOUT, data, "");
    rays     = parse_radial_rays(g_str);
    is_jar   = get_val(IS_JAR_GRID, opts, false);
    mod_hint = get_val(GRID_MOD_HINTS, data, true);
    // Inject IS_JAR_GRID and TYPE so render_box_grid_core + _resolve_height see correct type.
    // TYPE=BOX_GRID / JAR_GRID → is_closed=false → poke-through heights NOT clamped to max_h.
    d = is_jar
        ? concat([[IS_JAR_GRID, true], [TYPE, JAR_GRID]], data)
        : concat([[TYPE, BOX_GRID]], data);
    echo(str("-> Factory [GRID] | layout='", g_str, "' rays=", rays, " jar=", is_jar));
    if (rays > 0 && !is_jar)
        echo(str("WARNING: layout '", g_str, "' contains radial tokens (R/C) but this is",
                 " not a jar grid — radial dividers ignored. Add IS_JAR_GRID flag or",
                 " remove R/C tokens for box/tray grids."));
    // Hints_Only (modifier export): emit just the marker discs, no grid body.
    // Guarded with is_undef so the module is robust if the flag isn't defined.
    hints_only = is_undef(Hints_Only) ? false : Hints_Only;
    sf = m_safe_floor(d);
    up(sf) {
        if (hints_only) {
            _render_grid_mod_hints(d, sf);   // modifier-volume discs only
        } else {
            if (rays > 0 && is_jar)
                render_jar_grid_core(d, false);
            else
                render_box_grid_core(d, false);
            cfg = get_grid_config(d);
            up(cfg[4]) render_franken_ribs(d);
            if (mod_hint) _render_grid_mod_hints(d, sf);
        }
    }
}

// _render_grid_mod_hints — thin marker discs floating just above shaped hub tops.
// Co-located in the same STL as the grid; topologically disconnected so the slicer
// can "split to objects" and select them as modifier volumes.
// Discs mark XY footprint and height of each circular hub (C/S/D/T shapes only).
module _render_grid_mod_hints(data, sf) {
    sw      = m_safe_wall(data);
    bw      = m_bw(data); bl = m_bl(data); bh = m_bh(data);
    tol     = GRID_DROP_IN_TOL;
    dim_mode = get_val(DIMENSION_MODE, data, "Total");
    tw      = get_val(THICK_WALL, data, 2.4);
    tf      = get_val(THICK_FLOOR, data, 2.0);
    tl      = get_val(THICK_LID,   data, 2.0);
    int_w   = (dim_mode == "Usable") ? bw - tw*2 - tol : bw - sw*2 - tol;
    int_l   = (dim_mode == "Usable") ? bl - tw*2 - tol : bl - sw*2 - tol;
    int_h   = (dim_mode == "Usable") ? bh - tf - tl - tol : bh - sf;

    g_str  = get_val(GRID_LAYOUT, data, "");
    a_raw  = parse_anchor_tokens(g_str);
    a_defs = [for (ac = a_raw) parse_anchor_def(ac)];

    for (adef = a_defs) {
        shape_str  = adef[3];
        height_str = adef[4];
        is_center  = adef[5];
        clip_r = _hub_clip_r(shape_str, sw);
        if (clip_r > 0) {
            hub_h = _resolve_height(height_str, int_h, int_h, false);
            ax = is_center ? 0 : _anchor_center_mm(adef[1], adef[6], int_w);
            ay = is_center ? 0 : _anchor_center_mm(adef[2], adef[7], int_l);
            // Disc floats at hub_h + EPS: separate shell from hub top face → slicer splits cleanly
            translate([ax, ay, hub_h + EPS])
                cyl(d=clip_r*2 + sw, h=sw*2, anchor=BOTTOM);
        }
    }
}
