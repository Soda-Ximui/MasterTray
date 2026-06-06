// ==============================================================================
// FILE: RenderRib.scad
// ARCHITECTURE: Layer 2.2 (FrankenTray Vector Generator)
// PURPOSE: Dedicated geometry builder for radial/vector-based Rib topologies.
//          v1: P/O/rib token syntax (legacy). v2: A(...)/[...] anchor syntax.
// ==============================================================================

include <BOSL2/std.scad>
include <GridLayout.scad>
include <MasterUtility.scad>

// --- FRANKENTRAY V2 HELPERS ---

// Convert a mm-from-SW-corner coordinate to OpenSCAD centred mm.
// Anchors use SW as origin; OpenSCAD uses the tray centre as origin.
// C (centre) anchors skip this — the renderer uses 0 directly.
function _sw_to_mm(x_mm_sw, dim) = x_mm_sw - dim/2;

// Resolve a height string to mm.
// "" → default_h; "80%" → 80 % of max_h; "60" → 60 mm absolute.
// Clamps to max_h for closed containers.
function _resolve_height(height_str, default_h, max_h, is_closed) =
    let(h = (height_str == "") ? default_h :
            (height_str[len(height_str)-1] == "%")
                ? max_h * to_num(get_digits(height_str)) / 100
                : to_num(get_digits(height_str)))
    is_closed ? min(h, max_h) : h;

// Find anchor definition by name. Returns the first matching entry or undef.
function _find_anchor_def(anchor_defs, name) =
    let(m = [for (a = anchor_defs) if (a[0] == name) a])
    (len(m) > 0) ? m[0] : undef;

// Compute wall endpoint in centred mm coords for cardinal/intercardinal wall names.
function _wall_endpoint(wall, ax, ay, int_w, int_l) =
    (wall == "N")  ? [ax,        int_l/2] :
    (wall == "S")  ? [ax,       -int_l/2] :
    (wall == "E")  ? [int_w/2,   ay]      :
    (wall == "W")  ? [-int_w/2,  ay]      :
    (wall == "NE") ? [int_w/2,  int_l/2]  :
    (wall == "NW") ? [-int_w/2, int_l/2]  :
    (wall == "SE") ? [int_w/2, -int_l/2]  :
    (wall == "SW") ? [-int_w/2,-int_l/2]  :
    [ax, ay];

// Ray-cast from (ax,ay) at angle theta_deg (0=E, 90=N) to rectangular boundary.
function _angle_endpoint_rect(theta_deg, ax, ay, int_w, int_l) =
    let(
        cx = cos(theta_deg), cy = sin(theta_deg),
        hw = int_w/2,        hl = int_l/2,
        t_e = (cx >  0.0001) ? ( hw - ax) / cx : 1e9,
        t_w = (cx < -0.0001) ? (-hw - ax) / cx : 1e9,
        t_n = (cy >  0.0001) ? ( hl - ay) / cy : 1e9,
        t_s = (cy < -0.0001) ? (-hl - ay) / cy : 1e9,
        t   = min(t_e, t_w, t_n, t_s)
    )
    [ax + t*cx, ay + t*cy];

// Ray-cast from (ax,ay) at theta_deg to cylindrical boundary (diameter int_d).
// Solves t²+ 2Bt + C = 0 (A=1 since |cos,sin|=1); takes positive root.
function _angle_endpoint_cyl(theta_deg, ax, ay, int_d) =
    let(
        r  = int_d/2,
        cx = cos(theta_deg), cy = sin(theta_deg),
        B  = ax*cx + ay*cy,
        C  = ax*ax + ay*ay - r*r,
        disc = B*B - C,
        t  = (disc <= 0) ? 0 : (-B + sqrt(disc))
    )
    [ax + t*cx, ay + t*cy];

// Resolve the 'to' field of a connection to [x_mm, y_mm] centred coords.
function _resolve_to(to_str, ax, ay, anchor_defs, int_w, int_l, is_jar, int_d) =
    _is_wall_name(to_str)
        ? _wall_endpoint(to_str, ax, ay, int_w, int_l) :
    _to_is_angle(to_str)
        ? (is_jar
            ? _angle_endpoint_cyl (to_num(get_digits(to_str)), ax, ay, int_d)
            : _angle_endpoint_rect(to_num(get_digits(to_str)), ax, ay, int_w, int_l)) :
    let(adef = _find_anchor_def(anchor_defs, to_str))
    (adef != undef) ? (adef[5] ? [0, 0]
                                : [_sw_to_mm(adef[1], int_w), _sw_to_mm(adef[2], int_l)]) :
    [ax, ay];

// Render hub shape at current position (caller must translate).
// shape_str: "" = none, "C<n>" = cylinder d=2n, "S<n>" = square side n,
//            "T<n>" = equilateral triangle side n, "D<n>" = diamond (square rotated 45°).
// n absent, 0, or below NUB_D → decorative nub (NUB_D solid cylinder).
NUB_D = 2.0;  // minimum printable hub diameter (mm)
module _render_hub(shape_str, h) {
    if (shape_str != "" && h > 0.01) {
        first    = shape_str[0];
        size_val = to_num(get_digits(shape_str));
        is_nub   = (size_val < NUB_D);
        eff      = is_nub ? NUB_D : size_val;
        if (first == "C") {
            d     = is_nub ? NUB_D : eff;
            inner = d - nozzle_d * 4;   // wall = 2 extrusion passes each side
            if (!is_nub && inner >= nozzle_d * 6)
                difference() {
                    cyl(d=d,     h=h,       anchor=BOTTOM);
                    down(EPS) cyl(d=inner, h=h+EPS2, anchor=BOTTOM);
                }
            else
                cyl(d=d, h=h, anchor=BOTTOM);
        }
        if (first == "S") cuboid([eff, eff, h], anchor=CENTER+BOTTOM);
        if (first == "D") zrot(45) cuboid([eff, eff, h], anchor=CENTER+BOTTOM);
        if (first == "T") {
            // Equilateral triangle prism, point facing +Y
            ht = eff * sqrt(3) / 2;
            linear_extrude(h)
                polygon([[-eff/2, -ht/3], [eff/2, -ht/3], [0, 2*ht/3]]);
        }
    }
}

// Emit all v2 hub shapes and ribs. Called inside a clipping context.
module _franken_v2_geom(anchor_defs, conn_defs, int_w, int_l, default_h, max_h, is_closed, is_jar, int_d, div_t) {
    for (adef = anchor_defs) {
        ax = adef[5] ? 0 : _sw_to_mm(adef[1], int_w);
        ay = adef[5] ? 0 : _sw_to_mm(adef[2], int_l);
        ah = _resolve_height(adef[4], default_h, max_h, is_closed);
        translate([ax, ay, 0]) _render_hub(adef[3], ah);
    }
    for (cdef = conn_defs) {
        from_def = _find_anchor_def(anchor_defs, cdef[0]);
        if (from_def != undef) {
            ax      = from_def[5] ? 0 : _sw_to_mm(from_def[1], int_w);
            ay      = from_def[5] ? 0 : _sw_to_mm(from_def[2], int_l);
            // Ribs default to max internal height — shape_height on the anchor
            // only controls the hub prism, not the ribs leaving it.
            rib_h   = (cdef[2] == "") ? default_h : _resolve_height(cdef[2], default_h, max_h, is_closed);
            to_pt   = _resolve_to(cdef[1], ax, ay, anchor_defs, int_w, int_l, is_jar, int_d);
            bx = to_pt[0];  by = to_pt[1];
            dx = bx - ax;   dy = by - ay;
            L  = norm([dx, dy]);
            if (L > 0.1) {
                translate([(ax+bx)/2, (ay+by)/2, 0])
                    zrot(atan2(dy, dx))
                    cuboid([L, div_t, rib_h], anchor=CENTER+BOTTOM);
            }
        }
    }
}

// --- MAIN ENTRY POINT ---

module render_franken_ribs(data) {
    g_str = get_val(GRID_LAYOUT, data, "");

    if (has_franken_v2(g_str)) {
        // ── v2 path: A(...) anchor + [...] connection syntax ──────────────
        v2          = parse_franken_v2(g_str);
        anchor_defs = v2[0];
        conn_defs   = v2[1];

        bh    = m_bh(data);
        sf    = m_safe_floor(data);
        sw    = m_safe_wall(data);
        sl    = m_safe_lid(data);
        div_t = get_val(THICK_DIVIDER, data, 1.2);

        type      = get_val(TYPE, data, BOX);
        is_closed = (type == BOX || type == FLIP_BOX || type == JAR_LID ||
                     type == DOUBLE_FLIP_BOX || type == DESICCANT_BOX);
        is_jar    = (type == JAR || type == JAR_LID || type == JAR_GRID || type == PLAQUE_JAR);

        int_w     = m_bw(data) - sw*2 - 0.4;
        int_l     = m_bl(data) - sw*2 - 0.4;
        int_d     = int_w;   // jars are circular; int_w == int_l == diameter
        int_h     = bh - sf - (is_closed ? sl : 0);
        max_h     = int_h;
        default_h = max_h;

        if (is_jar) {
            intersection() {
                cyl(d=int_d, h=int_h, anchor=BOTTOM);
                _franken_v2_geom(anchor_defs, conn_defs, int_w, int_l, default_h, max_h,
                                 is_closed, is_jar, int_d, div_t);
            }
        } else {
            apply_master_bounds(int_w, int_l, int_h, m_c_rad(data)-sw, m_chamf(data)/2)
                _franken_v2_geom(anchor_defs, conn_defs, int_w, int_l, default_h, max_h,
                                 is_closed, is_jar, int_d, div_t);
        }

    } else {
        // ── v1 path: legacy P/O/rib token syntax ─────────────────────────
        cfg = parse_franken_config(g_str);

        if (cfg != undef) {
            log_franken_state(cfg, g_str);

            rays   = cfg[0];
            hub_d  = cfg[1];
            anchor = cfg[2];
            ribs   = cfg[3];

            bh    = m_bh(data);
            sf    = m_safe_floor(data);
            sw    = m_safe_wall(data);
            sl    = m_safe_lid(data);
            div_t = get_val(THICK_DIVIDER, data, 1.2);

            type      = get_val(TYPE, data, BOX);
            is_closed = (type == BOX || type == FLIP_BOX || type == JAR_LID ||
                         type == DOUBLE_FLIP_BOX || type == DESICCANT_BOX);
            is_jar    = (type == JAR || type == JAR_LID || type == JAR_GRID || type == PLAQUE_JAR);

            int_w = m_bw(data) - sw*2 - 0.4;
            int_l = m_bl(data) - sw*2 - 0.4;
            int_h = bh - sf - (is_closed ? sl : 0);

            ox = anchor[0];
            oy = anchor[1];

            if (is_jar) {
                intersection() {
                    cyl(d=int_w, h=int_h, anchor=BOTTOM);
                    translate([ox, oy, 0]) {
                        if (hub_d > 0) cyl(d=hub_d, h=int_h, anchor=BOTTOM);
                        if (len(ribs) > 0) for (i = [0:len(ribs)-1]) {
                            traj = ribs[i][0]; beh = ribs[i][1];
                            theta = get_rib_angle(traj, int_w, int_l, ox, oy);
                            L = get_rib_length(theta, beh, traj, ox, oy, int_w, int_l, is_jar);
                            zrot(theta) cuboid([L, div_t, int_h], anchor=BOTTOM+LEFT);
                        }
                    }
                }
            } else {
                apply_master_bounds(int_w, int_l, int_h, m_c_rad(data)-sw, m_chamf(data)/2) {
                    translate([ox, oy, 0]) {
                        if (hub_d > 0) cyl(d=hub_d, h=int_h, anchor=BOTTOM);
                        if (len(ribs) > 0) for (i = [0:len(ribs)-1]) {
                            traj = ribs[i][0]; beh = ribs[i][1];
                            theta = get_rib_angle(traj, int_w, int_l, ox, oy);
                            L = get_rib_length(theta, beh, traj, ox, oy, int_w, int_l, is_jar);
                            zrot(theta) cuboid([L, div_t, int_h], anchor=BOTTOM+LEFT);
                        }
                    }
                }
            }
        }
    }
}