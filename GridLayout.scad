// ==============================================================================
// FILE: GridLayout.scad
// ARCHITECTURE: Layer 1.3 (Grid Layout Parsing & Validation)
// PURPOSE: Context-aware parsing for Cartesian, Radial, and Custom Spans
// ==============================================================================

include <BOSL2/std.scad>
include <MasterEnum.scad>
include <MasterEngine.scad>

// --- CORE PARSER UTILITIES ---
function get_grid_tokens(g_str) = [for (t = str_split(g_str, " ")) if (t != "") t];

// --- CARTESIAN PARSER ---
// Handles both "3x2" (concatenated) and "3 x 2" (spaced) forms.
function parse_cartesian(g_str) =
    let(tokens = get_grid_tokens(g_str),
        // Find index of first token containing x/X
        xi_list = [for (i = [0:len(tokens)-1])
                    if (len(search("x", tokens[i])) > 0 || len(search("X", tokens[i])) > 0) i],
        xi  = len(xi_list) > 0 ? xi_list[0] : -1,
        tok = xi >= 0 ? tokens[xi] : "")
    (xi < 0) ? [1, 1] :
    (len(tok) > 1) ?
        // Concatenated form "3x2": split on x/X
        let(dims = str_split(tok, ["x", "X"]),
            cols = max(1, to_num(get_digits(dims[0]))),
            rows = max(1, to_num(get_digits(dims[1]))))
        [cols, rows] :
        // Standalone "x"/"X": adjacent tokens hold the dimensions
        let(cols = (xi > 0)               ? max(1, to_num(get_digits(tokens[xi-1]))) : 1,
            rows = (xi < len(tokens) - 1) ? max(1, to_num(get_digits(tokens[xi+1]))) : 1)
        [cols, rows];

function has_cartesian(g_str) =
    let(tok_x = [for (t = get_grid_tokens(g_str)) if (len(search("x", t)) > 0 || len(search("X", t)) > 0) t])
    len(tok_x) > 0;

// --- RADIAL PARSER (JAR ONLY) ---
// Syntax: R<rays>[/H[%]]  C<diameter>[%][/H[%]]
//   R4        — 4 spokes, height = jar interior (default)
//   R4/150%   — 4 spokes, height = 150% of interior → pokes above jar mouth
//   R4/80     — 4 spokes, 80mm absolute height
//   C20%/120% — hub = 20% of diameter, height = 120% of interior
// Heights are resolved to mm in get_grid_config (needs effective_max_h).
// Returns raw parsed values: [rays, c_val, c_is_perc, r_h_val, r_h_is_perc, c_h_val, c_h_is_perc]
//   r_h_val / c_h_val = undef → use default height (flush with jar mouth)
function parse_radial(g_str) =
    let(
        tokens      = get_grid_tokens(g_str),
        tok_r       = [for (t = tokens) if (t[0] == "R" || t[0] == "r") t],
        tok_c       = [for (t = tokens) if (t[0] == "C" || t[0] == "c") t],

        // Normalise token: replace "/" with "," so str_split(",") works uniformly
        // (same technique used by parse_single_span for "S" tokens).
        r_norm      = len(tok_r) > 0
                        ? str_join([for (i=[0:len(tok_r[0])-1]) tok_r[0][i]=="/" ? "," : tok_r[0][i]], "")
                        : "",
        r_parts      = str_split(r_norm, ","),
        rays         = len(r_parts) > 0 ? max(0, to_num(get_digits(r_parts[0]))) : 0,
        // Height parts: everything after the ray count (r_parts[1], r_parts[2], …).
        // Single value R4/80 → [80]. Cycling list R4/80,60 → [80,60]. None → undef.
        r_h_parts    = len(r_parts) > 1 ? [for (i = [1:len(r_parts)-1]) r_parts[i]] : undef,
        r_h_is_percs = r_h_parts != undef ? [for (p = r_h_parts) p[len(p)-1] == "%"] : undef,
        r_h_vals     = r_h_parts != undef ? [for (p = r_h_parts) to_num(get_digits(p))] : undef,

        c_norm      = len(tok_c) > 0
                        ? str_join([for (i=[0:len(tok_c[0])-1]) tok_c[0][i]=="/" ? "," : tok_c[0][i]], "")
                        : "",
        c_parts     = str_split(c_norm, ","),
        c_base      = len(c_parts) > 0 ? c_parts[0] : "",
        c_val       = len(c_base) > 0 ? to_num(get_digits(c_base)) : 6.0,
        c_is_perc   = len(c_base) > 0 && c_base[len(c_base)-1] == "%",
        c_h_str     = len(c_parts) > 1 ? c_parts[1] : undef,
        c_h_is_perc = (c_h_str != undef) && c_h_str[len(c_h_str)-1] == "%",
        c_h_val     = (c_h_str != undef) ? to_num(get_digits(c_h_str)) : undef
    )
    [rays, c_val, c_is_perc, r_h_vals, r_h_is_percs, c_h_val, c_h_is_perc];

function has_radial(g_str) = 
    let(rad = parse_radial(g_str)) 
    (rad[0] > 0 || rad[1] > 0);

// --- CUSTOM SPAN PARSER ---
function parse_spans(g_str, default_h, max_h, is_closed) =
    let(tokens = get_grid_tokens(g_str),
        span_tokens = [for (t = tokens) if (t[0] == "S" || t[0] == "s") t])
    [for (st = span_tokens) parse_single_span(st, default_h, max_h, is_closed)];

function parse_single_span(span_str, default_h, max_h, is_closed) =
    let(
        norm_str = str_join([for (i=[0:len(span_str)-1]) span_str[i] == "/" ? "," : span_str[i]], ""),
        parts = str_split(norm_str, ","),
        
        r  = len(parts) > 0 ? max(1, to_num(get_digits(parts[0]))) : 1,
        c  = len(parts) > 1 ? max(1, to_num(get_digits(parts[1]))) : 1,
        rs = len(parts) > 2 ? max(1, to_num(get_digits(parts[2]))) : 1,
        cs = len(parts) > 3 ? max(1, to_num(get_digits(parts[3]))) : 1,
        
        raw_h_str = len(parts) > 4 ? parts[4] : "",
        is_h_perc = len(raw_h_str) > 0 && raw_h_str[len(raw_h_str)-1] == "%",
        h_val = len(raw_h_str) > 0 ? to_num(get_digits(raw_h_str)) : 100,
        
        req_h = len(raw_h_str) == 0 ? default_h : 
                is_h_perc ? (default_h * (h_val / 100)) : h_val,
                
        final_h = is_closed ? min(req_h, max_h) : req_h
    )
    [r, c, rs, cs, final_h, req_h, is_closed];

// --- MASTER ROUTER CONFIGURATION ---
function get_grid_config(data) =
    let(
        type = get_val(TYPE, data, BOX),
        g_str = get_val(GRID_LAYOUT, data, ""),
        
        has_base = get_val(GRID_HAS_BASE, data, false),
        base_t = has_base ? m_lh(data) * 4 : 0,
        
        bh = m_bh(data),
        sf = m_safe_floor(data),
        sl = m_safe_lid(data),
        
        // TYPE defaults to BOX when not set (jars don't inject it), so we also
        // check IS_JAR_GRID to distinguish jar context from a true box.
        is_jar    = get_val(IS_JAR_GRID, data, false),
        is_closed = !is_jar && (type == BOX || type == FLIP_BOX || type == JAR_LID || type == DOUBLE_FLIP_BOX || type == DESICCANT_BOX),

        max_internal_h = bh - sf - (is_closed ? sl : 0),
        // GRID_WALL_H injected by factories (e.g. factory_render_jar for neck clearance,
        // factory_render_box for flip-lid axle clearance). When present it is the true
        // ceiling — use it as both the default height and the clamp for spans.
        grid_wall_h_cap = get_val(GRID_WALL_H, data, 0),
        effective_max_h = (grid_wall_h_cap > 0) ? grid_wall_h_cap : max_internal_h,
        default_h = effective_max_h,

        cart_dims   = parse_cartesian(g_str),
        rad_dims    = parse_radial(g_str),
        spans       = parse_spans(g_str, default_h, effective_max_h, is_closed || grid_wall_h_cap > 0),

        // Resolve optional poke-through heights from R/H[,H2,…] and C/H tokens.
        // undef → flush with jar mouth (effective_max_h). % → relative to that.
        // Clamp when: box-type closed container, OR threaded jar (neck blocks poke-through).
        // Open jars: poke-through allowed — pencil/utensil holder use case.
        //
        // ray_heights is always a list, even for a single value.
        // Cycling: _render_radial_core uses heights[i % len(heights)] per spoke.
        jar_threaded = is_jar && get_val(HAS_THREADS, data, false),
        clamp_height = is_closed || jar_threaded,
        r_h_vals_raw = rad_dims[3],
        r_h_percs    = rad_dims[4],
        // Resolve each height value in the list to mm; fall back to effective_max_h if undef.
        r_h_mm_list  = (r_h_vals_raw == undef) ? [effective_max_h] :
          [for (i = [0:len(r_h_vals_raw)-1])
            r_h_percs[i] ? (effective_max_h * r_h_vals_raw[i] / 100) : r_h_vals_raw[i]],
        ray_heights  = [for (h = r_h_mm_list) clamp_height ? min(h, effective_max_h) : h],
        // Hub height: single value, defaults to max of ray heights when not specified.
        c_h_mm  = (rad_dims[5] == undef) ? max(ray_heights) :
                   rad_dims[6] ? (effective_max_h * rad_dims[5] / 100) : rad_dims[5],
        hub_h   = clamp_height ? min(c_h_mm, effective_max_h) : c_h_mm,

        // cfg[1] = [rays, c_val, c_is_perc, ray_heights (list), hub_h_mm (scalar)]
        // Indices 0-2 unchanged — existing callers unaffected.
        rad_cfg = [rad_dims[0], rad_dims[1], rad_dims[2], ray_heights, hub_h]
    )
    [cart_dims, rad_cfg, spans, has_base, base_t, default_h];

// --- DEBUGGER ---
module debug_grid_parser(data) {
    cfg = get_grid_config(data);
    spans = cfg[2];
    
    echo(" ");
    echo("=== 🐛 GRID PARSER DIAGNOSTICS ===");
    echo(str("1. Raw Input:   '", get_val(GRID_LAYOUT, data, ""), "'"));
    echo(str("2. Cartesian:   Cols: ", cfg[0][0], " | Rows: ", cfg[0][1]));
    echo(str("3. Radial:      Rays: ", cfg[1][0], " | Center: ", cfg[1][1]));
    echo(str("4. Spans Found: ", len(spans)));
    
    if (len(spans) > 0) {
        for (i = [0 : len(spans) - 1]) {
            s = spans[i];
            clamp_note = (s[4] < s[5] && s[6]) ? str(" (⚠️ CLAMPED from ", s[5], " due to lid)") : "";
            echo(str("   -> Span ", i+1, ": [Row ", s[0], ", Col ", s[1], "] | Span: ", s[2], "x", s[3], " | Calc Height: ", s[4], clamp_note));
        }
    }
    
    echo(str("5. Base Height: ", cfg[5], "mm"));
    echo(str("6. Has Base:    ", cfg[3], " | Thickness: ", cfg[4], "mm"));
    echo("==================================");
    echo(" ");
}

// --- GRID STRING VALIDATION ---
// Token classifiers used by is_valid_grid_layout and MasterValidation.
function is_cartesian_token(tok) = len(search("x", tok)) > 0 || len(search("X", tok)) > 0;
function is_radial_token(tok)    = len(tok) > 0 && (tok[0] == "R" || tok[0] == "r");
function is_center_token(tok)    = len(tok) > 0 && (tok[0] == "C" || tok[0] == "c");
function is_span_token(tok)      = len(tok) > 0 && (tok[0] == "S" || tok[0] == "s");
// Standalone digit token — appears when user writes "3 x 2" (spaced cartesian form).
function is_digit_token(tok)     = len(tok) > 0 && ord(tok[0]) >= 48 && ord(tok[0]) <= 57;

function is_valid_grid_layout(g_str) =
  (g_str == "") ? true :
  has_franken_v2(g_str) ? true :   // v2 syntax — skip space-token validation
  let (tokens = [for (t = get_grid_tokens(g_str)) t])
  (len(tokens) == 0) ? false :
  len([for (t = tokens) if (
    is_cartesian_token(t) || is_radial_token(t) ||
    is_center_token(t)    || is_span_token(t)   || is_digit_token(t)
  ) t]) == len(tokens);

// Flat accessors for callers that only need one value from parse_radial.
function parse_radial_rays(g_str)      = parse_radial(g_str)[0];
function parse_center_diameter(g_str)  =
  let (r = parse_radial(g_str)) r[2] ? (r[1] / 100) : r[1];

// Legacy compat wrappers (kept for any old callers).
function get_cartesian_dims_legacy(g_str)  = parse_cartesian(g_str);
function get_radial_rays_legacy(g_str)     = parse_radial_rays(g_str);
function get_center_diameter_legacy(g_str) = parse_center_diameter(g_str);

// --- FRANKENTRAY DIAGNOSTICS ---
module log_franken_state(cfg, g_str) {
    if (cfg != undef) {
        echo(" ");
        echo("=== FRANKENTRAY FLIGHT RECORDER ===");
        echo(str("Raw_Input: '", g_str, "'"));
        echo(str("Base Config: Rays: ", cfg[0], " | Hub Dia: ", cfg[1]));
        echo(str("Global Anchor Offset: [", cfg[2][0], ", ", cfg[2][1], "]"));
        echo("--- RIB TOPOLOGY ARRAY ---");
        if (len(cfg[3]) > 0) {
            for (i = [0 : len(cfg[3])-1])
                echo(str("  Rib ", i+1, ": [", cfg[3][i][0], "] --> [", cfg[3][i][1], "]"));
        } else {
            echo("  (No vector ribs compiled)");
        }
        echo("====================================");
        echo(" ");
    }
}

// --- FRANKEN-PARSE (VECTOR/RIB TOPOLOGY) ---
function parse_rib_node(token) =
    let(
        parts = str_split(token, "-"),
        beh_str = len(parts) > 1 ? parts[len(parts)-1] : "T",
        cut_len = len(parts) > 1 ? len(beh_str) + 1 : 0,
        traj_str = len(parts) > 1 ? substr(token, 0, len(token) - cut_len) : token
    )
    [traj_str, beh_str];

function parse_offset(o_str) =
    let(
        clean_str = substr(o_str, 1),
        parts = str_split(clean_str, ","),
        x_val = to_num(get_digits(parts[0])) * (len(search("-", parts[0])) > 0 ? -1 : 1),
        y_val = len(parts) > 1 ? to_num(get_digits(parts[1])) * (len(search("-", parts[1])) > 0 ? -1 : 1) : 0
    )
    [x_val, y_val];

function parse_franken_config(g_str) =
    let(
        tokens = get_grid_tokens(g_str),
        p_tok = [for (t = tokens) if (t[0] == "P" && len(search("/", t)) > 0) t],
        o_tok = [for (t = tokens) if (t[0] == "O") t],
        rib_toks = [for (t = tokens) if (t[0] != "P" && t[0] != "O" && len(search("-", t)) > 0) t]
    )
    (len(p_tok) == 0) ? undef :
    let(
        hub_data = str_split(p_tok[0], "/"),
        rays = to_num(get_digits(hub_data[0])),
        hub_d = len(hub_data) > 1 ? to_num(get_digits(hub_data[1])) : 10,
        offset = len(o_tok) > 0 ? parse_offset(o_tok[0]) : [0, 0],
        ribs = [for (rt = rib_toks) parse_rib_node(rt)]
    )
    [rays, hub_d, offset, ribs];

// ==============================================================================
// FRANKENTRAY V2 PARSER
// Syntax:  A(name, x%, y% [, shape] [, height])   — anchor definition
//          [from, to [, height]]                    — connection
// All whitespace is stripped before tokenising — humans may format freely.
// ==============================================================================

// Strip all whitespace from string (space and tab).
function strip_ws(s) =
    str_join([for (i = [0:len(s)-1]) if (s[i] != " " && s[i] != "\t") s[i]], "");

// Find the first occurrence of character ch in s at or after index start.
// Returns len(s) when not found.
function _next_char(s, start, ch) =
    (start >= len(s)) ? len(s) :
    (s[start] == ch)  ? start  :
    _next_char(s, start+1, ch);

// Returns list of raw content strings inside A(...) tokens.
function parse_anchor_tokens(raw) =
    let(s = strip_ws(raw), n = len(s))
    [for (i = [0:n-2])
        if (s[i] == "A" && s[i+1] == "(")
        let(close = _next_char(s, i+2, ")"))
        if (close < n)
        substr(s, i+2, close - i - 2)
    ];

// Returns list of raw content strings inside [...] tokens.
function parse_connection_tokens(raw) =
    let(s = strip_ws(raw), n = len(s))
    [for (i = [0:n-1])
        if (s[i] == "[")
        let(close = _next_char(s, i+1, "]"))
        if (close < n)
        substr(s, i+1, close - i - 1)
    ];

// True if token is a hub shape specifier: C<n>, S<n>, or T<n> (len > 1).
function _is_shape_tok(s) =
    len(s) > 1 && (s[0] == "C" || s[0] == "S" || s[0] == "T");

// True if token is a height value: ends with % OR first char is ASCII digit 0-9.
function _is_height_tok(s) =
    len(s) > 0 && (s[len(s)-1] == "%" || (ord(s[0]) >= 48 && ord(s[0]) <= 57));

// Parse anchor content string: "name,x,y[,shape][,height]" or "name,C[,shape][,height]"
// Coordinates are mm from the SW (bottom-left) interior corner.
// C means tray centre (resolved in the renderer — no mm value needed).
// Returns [name, x_mm_sw, y_mm_sw, shape_str, height_str, is_center]
function parse_anchor_def(content) =
    let(
        parts     = str_split(content, ","),
        np        = len(parts),
        name      = (np > 0) ? parts[0] : "",
        is_center = (np > 1) && (parts[1] == "C"),
        x_mm      = is_center ? 0 : ((np > 1) ? to_num(get_digits(parts[1])) : 0),
        y_mm      = is_center ? 0 : ((np > 2) ? to_num(get_digits(parts[2])) : 0),
        // Optional fields start after position args
        opt_start = is_center ? 2 : 3,
        opt0      = (np > opt_start)   ? parts[opt_start]   : "",
        opt1      = (np > opt_start+1) ? parts[opt_start+1] : "",
        // opt0 is shape if it starts with C/S/T and len>1; otherwise it may be height
        shape_str  = _is_shape_tok(opt0) ? opt0 : "",
        height_str = _is_shape_tok(opt0) ? opt1 :
                     (_is_height_tok(opt0) ? opt0 : "")
    )
    [name, x_mm, y_mm, shape_str, height_str, is_center];

// Parse connection content string: "from,to[,height]"
// Returns [from_name, to_str, height_str]
function parse_connection_def(content) =
    let(parts = str_split(content, ","), np = len(parts))
    [
        (np > 0) ? parts[0] : "",
        (np > 1) ? parts[1] : "",
        (np > 2) ? parts[2] : ""
    ];

// True if to_str is a cardinal/intercardinal wall name.
function _is_wall_name(s) =
    s == "N" || s == "S" || s == "E" || s == "W" ||
    s == "NE" || s == "NW" || s == "SE" || s == "SW";

// True if to_str is a numeric angle (starts with ASCII digit 0-9).
function _to_is_angle(s) = len(s) > 0 && ord(s[0]) >= 48 && ord(s[0]) <= 57;

// True if g_str contains v2 FrankenTray anchor syntax.
function has_franken_v2(g_str) =
    let(s = strip_ws(g_str), n = len(s))
    len([for (i = [0:n-2]) if (s[i] == "A" && s[i+1] == "(") i]) > 0;

// Parse all v2 tokens from g_str.
// Returns [anchor_defs, connection_defs]
//   anchor_defs:     [[name, x_pct, y_pct, shape_str, height_str], ...]
//   connection_defs: [[from_name, to_str, height_str], ...]
function parse_franken_v2(g_str) =
    let(
        a_raw = parse_anchor_tokens(g_str),
        c_raw = parse_connection_tokens(g_str)
    )
    [
        [for (ac = a_raw) parse_anchor_def(ac)],
        [for (cc = c_raw) parse_connection_def(cc)]
    ];