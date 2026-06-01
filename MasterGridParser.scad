// ==============================================================================
// FILE: MasterGridParser.scad [v1.0]
// ARCHITECTURE: Layer 1.3 (Grid Layout Parsing & Validation)
// PURPOSE: Unified parser for grid layout strings with error handling
// ==============================================================================

include <MasterEnum.scad>
include <MasterEngine.scad>

// === GRID LAYOUT FORMAT SPECIFICATION ===
// Grid layouts are space-separated tokens:
//   Cartesian (Rectangular): "7x2"       (7 columns, 2 rows)
//   Radial (Jar):            "R3 C8"     (3 rays, 8mm center diameter)
//   Mixed:                   "7x2 R3"    (rectangular with radial variant)
//
// Examples:
//   "7x2"       → Box with 7 columns × 2 rows
//   "R3 C10"    → Jar with 3-ray spider, 10mm center hub
//   "C0 R2"     → Jar with NO center hub, 2-ray divider
//   ""          → No grid (empty string is valid)

// --- VALIDATOR: Check if string is a valid grid layout ---
// Returns: true if valid, false otherwise
function is_valid_grid_layout(g_str) =
    let(tokens = str_split(g_str, " "))
    (g_str == "") ? true :  // Empty string is valid (no grid)
    (len(tokens) == 0) ? false :
    (len([for (t = tokens) 
          if (is_cartesian_token(t) || is_radial_token(t) || is_center_token(t)) 
          t]) == len(tokens));  // All tokens must be valid

function is_cartesian_token(tok) =
    len(search("x", tok)) > 0 || len(search("X", tok)) > 0;

function is_radial_token(tok) =
    len(tok) > 0 && (tok[0] == "R" || tok[0] == "r");

function is_center_token(tok) =
    len(tok) > 0 && (tok[0] == "C" || tok[0] == "c");

// --- PARSER: Extract cartesian grid dimensions ---
// Input: grid string like "7x2"
// Output: [cols, rows] or undef if not found
function parse_cartesian(g_str) =
    let(tokens = str_split(g_str, " "),
        cart_tokens = [for (t = tokens) if (is_cartesian_token(t)) t])
    (len(cart_tokens) == 0) ? undef :
    let(dims = str_split(cart_tokens[0], "xX"),
        cols = max(1, to_num(get_digits(dims[0]))),
        rows = (len(dims) > 1) ? max(1, to_num(get_digits(dims[1]))) : 1)
    [cols, rows];

// --- PARSER: Extract radial grid (rays) ---
// Input: grid string like "R3" (3 rays) or "R0" (no rays)
// Output: ray_count (0-based) or undef if not found
function parse_radial_rays(g_str) =
    let(tokens = str_split(g_str, " "),
        ray_tokens = [for (t = tokens) if (is_radial_token(t)) t])
    (len(ray_tokens) == 0) ? undef :
    max(0, to_num(get_digits(ray_tokens[0])));

// --- PARSER: Extract radial grid (center hub diameter) ---
// Input: grid string like "C10" (10mm) or "C0" (no hub)
// Output: diameter in mm, or undef if not found
function parse_center_diameter(g_str) =
    let(tokens = str_split(g_str, " "),
        center_tokens = [for (t = tokens) if (is_center_token(t)) t])
    (len(center_tokens) == 0) ? undef :
    let(d_val = to_num(get_digits(center_tokens[0])))
    (d_val > 0) ? d_val : 0;

// === LEGACY COMPATIBILITY LAYER ===
// These functions replicate old inline parsing logic for drop-in compatibility
// Once all code migrates to new parser, these can be deprecated

function get_cartesian_dims_legacy(g_str) =
    let(tokens = str_split(g_str, " "),
        tok_x = [for (tok = tokens) if (len(search("x", tok)) > 0 || len(search("X", tok)) > 0) tok])
    (len(tok_x) == 0) ? [1, 1] :
    let(dims = str_split(tok_x[0], "xX"),
        cols = max(1, to_num(get_digits(dims[0]))),
        rows = max(1, to_num(get_digits(dims[1]))))
    [cols, rows];

function get_radial_rays_legacy(g_str) =
    let(tokens = str_split(g_str, " "),
        tok_r = [for (tok = tokens) if (tok[0] == "R" || tok[0] == "r") tok])
    (len(tok_r) == 0) ? 0 :
    (len(get_digits(tok_r[0])) > 0) ? to_num(get_digits(tok_r[0])) : 4;

function get_center_diameter_legacy(g_str) =
    let(tokens = str_split(g_str, " "),
        tok_c = [for (tok = tokens) if (tok[0] == "C" || tok[0] == "c") tok])
    (len(tok_c) == 0) ? 6.0 :
    (len(get_digits(tok_c[0])) > 0) ? to_num(get_digits(tok_c[0])) : 10.0;

// === TEST SUITE ===
// Uncomment to debug parser in console

// echo("=== GRID PARSER TEST SUITE ===");
// echo(str("Test 1 - Cartesian '7x2': ", parse_cartesian("7x2")));
// echo(str("Test 2 - Radial 'R3 C10': ", parse_radial_rays("R3 C10"), " rays, ", parse_center_diameter("R3 C10"), "mm hub"));
// echo(str("Test 3 - Empty string valid: ", is_valid_grid_layout("")));
// echo(str("Test 4 - Invalid 'ABC': ", is_valid_grid_layout("ABC")));
// echo(str("Test 5 - Legacy compat '7x2': ", get_cartesian_dims_legacy("7x2")));
