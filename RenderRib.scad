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

// --- LENGTH CAP ---

// Cap endpoint (bx,by) at max_len mm from (ax,ay). No-op if rib is already shorter.
// Used for anchor-to-wall and angle connections; ignored for anchor-to-anchor.
function _length_cap(ax, ay, bx, by, max_len) =
    let(dx = bx-ax, dy = by-ay, L = norm([dx, dy]))
    (L < 0.001 || max_len >= L) ? [bx, by] :
    [ax + max_len*dx/L, ay + max_len*dy/L];

// --- HUB CLIPPING ---

// Inscribed-circle clip radius for a hub shape.
// C: exact radius = n/2.  S, D: inscribed face distance = n/2.
// T: inradius = n / (2*sqrt(3)).  Nubs (n < sw) return 0 — no clipping.
function _hub_clip_r(shape_str, sw) =
    let(first = shape_str[0],
        n     = to_num(get_digits(shape_str)))
    (n < sw) ? 0 :
    (first == "C") ? n / 2 :
    (first == "S") ? n / 2 :
    (first == "D") ? n / 2 :
    (first == "T") ? n / (2 * sqrt(3)) : 0;

// t at which ray (ax,ay)+(t*dx,t*dy) ENTERS circle (hx,hy,r) from outside.
// Returns undef if no forward intersection strictly in (0, 1).
function _ray_enters_circle_t(ax, ay, dx, dy, hx, hy, r) =
    let(ex = ax-hx, ey = ay-hy,
        A  = dx*dx + dy*dy,
        B  = 2*(ex*dx + ey*dy),
        C  = ex*ex + ey*ey - r*r,
        disc = B*B - 4*A*C)
    (disc < 0 || A < 0.0001) ? undef :
    let(t = (-B - sqrt(disc)) / (2*A))
    (t > 0.001 && t < 0.999) ? t : undef;

// t at which ray EXITS circle — used when start point is inside (source hub).
function _ray_exits_circle_t(ax, ay, dx, dy, hx, hy, r) =
    let(ex = ax-hx, ey = ay-hy,
        A  = dx*dx + dy*dy,
        B  = 2*(ex*dx + ey*dy),
        C  = ex*ex + ey*ey - r*r,
        disc = B*B - 4*A*C)
    (disc < 0 || A < 0.0001) ? undef :
    let(t = (-B + sqrt(disc)) / (2*A))
    (t > 0.001) ? t : undef;

// Earliest t at which rib (ax,ay)→(bx,by) enters any non-source hub.
// Returns undef if no hub is hit before the endpoint.
function _end_clip_t(anchor_defs, from_name, ax, ay, bx, by, int_w, int_l, sw) =
    let(dx = bx-ax, dy = by-ay,
        ts = [for (adef = anchor_defs)
              if (adef[0] != from_name && adef[3] != "")
              let(r  = _hub_clip_r(adef[3], sw),
                  hx = adef[5] ? 0 : _sw_to_mm(adef[1], int_w),
                  hy = adef[5] ? 0 : _sw_to_mm(adef[2], int_l),
                  t  = (r > 0) ? _ray_enters_circle_t(ax, ay, dx, dy, hx, hy, r) : undef)
              if (t != undef) t])
    len(ts) > 0 ? min(ts) : undef;

// t at which rib exits the source anchor's own hub (start offset).
// Returns undef if source has no hub or rib starts outside it.
function _start_clip_t(from_def, ax, ay, bx, by, int_w, int_l, sw) =
    (from_def[3] == "") ? undef :
    let(r = _hub_clip_r(from_def[3], sw))
    (r <= 0) ? undef :
    let(hx = from_def[5] ? 0 : _sw_to_mm(from_def[1], int_w),
        hy = from_def[5] ? 0 : _sw_to_mm(from_def[2], int_l),
        dx = bx-ax, dy = by-ay)
    _ray_exits_circle_t(ax, ay, dx, dy, hx, hy, r);

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
// shape_str: "C<n>" cylinder d=n, "S<n>" square side n,
//            "T<n>" equilateral triangle side n, "D<n>" diamond (square rotated 45°).
// n absent, 0, or n < sw  →  solid decorative nub (NUB_D diameter/side).
// n >= sw                  →  hollow shell, wall thickness = div_t.
// All four shapes follow the same solid/hollow rule.
NUB_D = 2.0;
module _render_hub(shape_str, h, div_t, sw) {
    if (shape_str != "" && h > 0.01) {
        first    = shape_str[0];
        size_val = to_num(get_digits(shape_str));
        is_nub   = (size_val < sw);
        eff      = is_nub ? NUB_D : size_val;
        inner    = eff - div_t * 2;
        hollow   = !is_nub && inner >= div_t;

        if (first == "C")
            if (hollow) difference() {
                cyl(d=eff,   h=h,       anchor=BOTTOM);
                down(EPS) cyl(d=inner, h=h+EPS2, anchor=BOTTOM);
            } else
                cyl(d=eff, h=h, anchor=BOTTOM);

        if (first == "S")
            if (hollow) difference() {
                cuboid([eff,   eff,   h],       anchor=CENTER+BOTTOM);
                down(EPS) cuboid([inner, inner, h+EPS2], anchor=CENTER+BOTTOM);
            } else
                cuboid([eff, eff, h], anchor=CENTER+BOTTOM);

        if (first == "D")
            if (hollow) difference() {
                zrot(45) cuboid([eff,   eff,   h],       anchor=CENTER+BOTTOM);
                down(EPS) zrot(45) cuboid([inner, inner, h+EPS2], anchor=CENTER+BOTTOM);
            } else
                zrot(45) cuboid([eff, eff, h], anchor=CENTER+BOTTOM);

        if (first == "T") {
            ht = eff * sqrt(3) / 2;
            if (hollow) {
                ht_i = inner * sqrt(3) / 2;
                difference() {
                    linear_extrude(h)
                        polygon([[-eff/2, -ht/3],   [eff/2, -ht/3],   [0, 2*ht/3]]);
                    down(EPS) linear_extrude(h+EPS2)
                        polygon([[-inner/2, -ht_i/3], [inner/2, -ht_i/3], [0, 2*ht_i/3]]);
                }
            } else
                linear_extrude(h)
                    polygon([[-eff/2, -ht/3], [eff/2, -ht/3], [0, 2*ht/3]]);
        }
    }
}

// Emit all v2 hub shapes and ribs. Called inside a clipping context.
// Ribs are automatically clipped against all hub shapes:
//   - start offset: rib begins at source hub boundary (not hub centre)
//   - end clip:     rib stops at the boundary of the first hub it would enter
// Clipping uses inscribed-circle approximation for S/D/T, exact for C.
module _franken_v2_geom(anchor_defs, conn_defs, int_w, int_l, default_h, max_h, is_closed, is_jar, int_d, div_t, sw) {
    for (adef = anchor_defs) {
        ax = adef[5] ? 0 : _sw_to_mm(adef[1], int_w);
        ay = adef[5] ? 0 : _sw_to_mm(adef[2], int_l);
        ah = _resolve_height(adef[4], default_h, max_h, is_closed);
        translate([ax, ay, 0]) _render_hub(adef[3], ah, div_t, sw);
    }
    for (cdef = conn_defs) {
        from_def = _find_anchor_def(anchor_defs, cdef[0]);
        if (from_def != undef) {
            ax    = from_def[5] ? 0 : _sw_to_mm(from_def[1], int_w);
            ay    = from_def[5] ? 0 : _sw_to_mm(from_def[2], int_l);
            rib_h = (cdef[2] == "") ? default_h : _resolve_height(cdef[2], default_h, max_h, is_closed);
            to_pt = _resolve_to(cdef[1], ax, ay, anchor_defs, int_w, int_l, is_jar, int_d);
            // Length cap: truncate rib at given mm from anchor (ignored for anchor-to-anchor).
            length_str  = (len(cdef) > 3) ? cdef[3] : "";
            is_a2a      = (_find_anchor_def(anchor_defs, cdef[1]) != undef);
            capped_pt   = (length_str != "" && !is_a2a)
                ? _length_cap(ax, ay, to_pt[0], to_pt[1], to_num(get_digits(length_str)))
                : to_pt;
            bx = capped_pt[0]; by = capped_pt[1];
            // Clip start out of source hub; clip end before entering any other hub.
            st = _start_clip_t(from_def,    ax, ay, bx, by, int_w, int_l, sw);
            et = _end_clip_t(anchor_defs, cdef[0], ax, ay, bx, by, int_w, int_l, sw);
            ax2 = (st != undef) ? ax + st*(bx-ax) : ax;
            ay2 = (st != undef) ? ay + st*(by-ay) : ay;
            bx2 = (et != undef) ? ax + et*(bx-ax) : bx;
            by2 = (et != undef) ? ay + et*(by-ay) : by;
            dx = bx2-ax2; dy = by2-ay2;
            L  = norm([dx, dy]);
            if (L > 0.1)
                translate([(ax2+bx2)/2, (ay2+by2)/2, 0])
                    zrot(atan2(dy, dx))
                    cuboid([L, div_t, rib_h], anchor=CENTER+BOTTOM);
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
                                 is_closed, is_jar, int_d, div_t, sw);
            }
        } else {
            apply_master_bounds(int_w, int_l, int_h, m_c_rad(data)-sw, m_chamf(data)/2)
                _franken_v2_geom(anchor_defs, conn_defs, int_w, int_l, default_h, max_h,
                                 is_closed, is_jar, int_d, div_t, sw);
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