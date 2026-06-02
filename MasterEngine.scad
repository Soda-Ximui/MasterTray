// ==============================================================================
// FILE: MasterEngine.scad [v4.11]
// ARCHITECTURE: Layer 1 (The Math Kernel & Data Router)
// ==============================================================================

include <BOSL2/std.scad>
include <BOSL2/threading.scad>
include <MasterEnum.scad>
include <MasterConstants.scad>

WIDTH0=50; LENGTH0=50; HEIGHT0=50; LAYER_HEIGHT0=0.20; WALL_LOOPS0=3; NOZZLE_DIAMETER0=0.4;
MIN_HOLE_SPACING0=1.2; PATTERN0=TEARDROP; STRUT_WALL0=25; STRUT_FLOOR0=25; STRUT_LID0=25;
PLAQUE_STYLE0="None"; PLAQUE_TEXT0=""; PLAQUE_TEXT_SIZE0=8; WALL_MODIFY0="None"; WALL_TARGET0="All Walls";
THICK_FLOOR0=2.0; THICK_LID0=2.0; THICK_WALL0=2.4; THICK_DIVIDER0=1.2; LID_MIN_SOLID0=10; TOL_SNAP_GAP0=0.1; TOL_CLIP0=0.1;
PLATTER_GAP0=15; THREAD_PITCH0=2.0; MAX_BUILD_PLATE_WIDTH0=250; GRID_LAYOUT0=""; GRID_HAS_BASE0=false;

function make_part(type, local_data=[]) = concat([[TYPE, type]], local_data);
function get_val(key, data, fallback) = let (idx = search([key], data)[0]) (idx == []) ? fallback : data[idx][1];
function get_footprint(data) =
    let(type = get_val(TYPE, data, BOX), w = max(10, get_val(WIDTH, data, WIDTH0)), l = max(10, get_val(LENGTH, data, LENGTH0)))
    (type == JAR || type == JAR_LID || type == JAR_GRID || type == PLAQUE_JAR) ? [w, w] : [w, l];

function get_xy(manifest, target_idx, curr_idx=0, edge_x=0, edge_y=0, row_max_y=0) =
    let(
        data = manifest[curr_idx], footprint = get_footprint(data), w = footprint[0], l = footprint[1],
        wrap = (edge_x > 0) && ((edge_x + w) > MAX_BUILD_PLATE_WIDTH0),
        actual_edge_x = wrap ? 0 : edge_x, actual_edge_y = wrap ? edge_y + row_max_y : edge_y,
        center_x = actual_edge_x + (w / 2), center_y = actual_edge_y + (l / 2),
        next_edge_x = actual_edge_x + w + PLATTER_GAP0, next_row_max = wrap ? l + PLATTER_GAP0 : max(row_max_y, l + PLATTER_GAP0)
    )
    (curr_idx == target_idx) ? [center_x, center_y] : get_xy(manifest, target_idx, curr_idx + 1, next_edge_x, actual_edge_y, next_row_max);

function m_bw(data) = max(10, get_val(WIDTH, data, WIDTH0));
function m_bl(data) = max(10, get_val(LENGTH, data, LENGTH0));
function m_bh(data) = max(5, get_val(HEIGHT, data, HEIGHT0)); 
function m_noz(data) = get_val(NOZZLE_DIAMETER, data, NOZZLE_DIAMETER0);

// [v4.11] Updated to parse raw numbers from Customizer, falling back to legacy string values
function m_lh(data) = let(s = get_val(LAYER_HEIGHT, data, 0.20)) (is_num(s)) ? s : ((s=="Detailed (0.12mm)")?0.12:0.20); 
function m_wloops(data) = let(w = get_val(WALL_LOOPS, data, 3)) (is_num(w)) ? w : 3;

function get_digits(s) = [ for (i = [0 : len(s)-1]) let(o = ord(s[i])) if (o >= 48 && o <= 57) o - 48 ];
function to_num(d) = len(d)==0 ? 0 : len(d)==1 ? d[0] : len(d)==2 ? d[0]*10 + d[1] : len(d)==3 ? d[0]*100 + d[1]*10 + d[2] : 0;

function get_mesh_cfg(data, h_key, s_key, needs_margin=false) = 
    let(pat = get_val(PATTERN, data, PATTERN0), hole = get_val(h_key, data, 1.6), strut = get_val(s_key, data, 25), req_s = (200 * get_val(LID_MIN_SOLID, data, LID_MIN_SOLID0)) / min(m_bw(data), m_bl(data)), final_s = needs_margin ? max(max(2, strut), req_s) : max(2, strut)) 
    ((pat == NONE || hole <= 0.05 || final_s >= 99) ? undef : [hole, final_s]);

function get_grid_step(hole, min_sp, noz) = hole + max(min_sp, max(noz, round(max(noz * 2, hole * 0.25) / noz) * noz));
function get_mesh_dim(dim, perc) = max(0.1, dim * (1 - (perc / 100)));
function get_n_steps(dim, perc, step) = ceil((get_mesh_dim(dim, perc)) / step) + 2;