// ==============================================================================
// FILE: GridLayout.scad [v2.2]
// ARCHITECTURE: Layer 1.3 (Grid Layout Parsing & Validation)
// PURPOSE: Context-aware parsing for Cartesian, Radial, and Custom Spans
// ==============================================================================

include <BOSL2/std.scad>
include <MasterEnum.scad>
include <MasterEngine.scad>

// --- CORE PARSER UTILITIES ---
function get_grid_tokens(g_str) = [for (t = str_split(g_str, " ")) if (t != "") t];

// --- CARTESIAN PARSER ---
function parse_cartesian(g_str) =
    let(tokens = get_grid_tokens(g_str),
        tok_x = [for (tok = tokens) if (len(search("x", tok)) > 0 || len(search("X", tok)) > 0) tok])
    (len(tok_x) == 0) ? [1, 1] :
    let(dims = str_split(tok_x[0], ["x", "X"]),
        cols = max(1, to_num(get_digits(dims[0]))),
        rows = max(1, to_num(get_digits(dims[1]))))
    [cols, rows];

function has_cartesian(g_str) = 
    let(tok_x = [for (t = get_grid_tokens(g_str)) if (len(search("x", t)) > 0 || len(search("X", t)) > 0) t])
    len(tok_x) > 0;

// --- RADIAL PARSER (JAR ONLY) ---
function parse_radial(g_str) =
    let(tokens = get_grid_tokens(g_str),
        tok_r = [for (t = tokens) if (t[0] == "R" || t[0] == "r") t],
        tok_c = [for (t = tokens) if (t[0] == "C" || t[0] == "c") t],
        
        rays = len(tok_r) > 0 ? max(0, to_num(get_digits(tok_r[0]))) : 0,
        c_val = len(tok_c) > 0 ? to_num(get_digits(tok_c[0])) : 6.0,
        is_perc = len(tok_c) > 0 && tok_c[0][len(tok_c[0])-1] == "%")
    [rays, c_val, is_perc];

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
        
        is_closed = (type == BOX || type == FLIP_BOX || type == JAR_LID || type == DOUBLE_FLIP_BOX || type == DESICCANT_BOX),
        
        max_internal_h = bh - sf - (is_closed ? sl : 0),
        default_h = max_internal_h,
        
        cart_dims = parse_cartesian(g_str),
        rad_dims = parse_radial(g_str),
        spans = parse_spans(g_str, default_h, max_internal_h, is_closed)
    )
    [cart_dims, rad_dims, spans, has_base, base_t, default_h];

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