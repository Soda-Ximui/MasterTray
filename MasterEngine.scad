// ==============================================================================
// FILE: MasterEngine.scad
// ARCHITECTURE: Layer 1.0 (Core Processing Engine)
// PURPOSE: Universal parameter getters, thickness calculators, and validation
// ==============================================================================
// This is the HEART of the MasterTray system. Every render function, builder,
// and processor depends on these getter functions to extract parameters from
// the configuration data structure and apply FDM-specific safety rules.
//
// DESIGN PATTERN: All public functions follow naming convention:
//   m_XXX(data) = "Master getter for XXX"
//   Returns calculated/validated value for feature XXX
//
// ==============================================================================

// MasterEngine is the single canonical owner of the BOSL2 includes. Every other
// file in the system includes MasterEngine, so it gets BOSL2 transitively — it
// must NOT `include <BOSL2/std.scad>` itself.
//
// WHY THIS MATTERS [perf, 2026-06-17]: OpenSCAD's `include` does NOT deduplicate.
// Each textual `include <BOSL2/std.scad>` re-parses the whole BOSL2 library. The
// Render files used to include BOSL2 directly AND via MasterEngine AND via each
// other (RenderBox→RenderTray→…), so BOSL2 was re-parsed dozens of times through
// the diamond-shaped include graph — ~21s of pure parse overhead on EVERY build,
// regardless of geometry (measured: a 125 KB box and an 8.7 MB jar both took ~23s).
// Removing the redundant direct includes leaves BOSL2 parsed via this file only.
// Do not add `include <BOSL2/...>` anywhere that already includes MasterEngine.
include <BOSL2/std.scad>
include <BOSL2/threading.scad>
include <MasterEnum.scad>
include <MasterConstants.scad>

// --- RENDERING QUALITY SETTINGS ---
// Use $fs (max chord length) + $fa (max angle) instead of a fixed $fn so that
// every circle gets exactly as many facets as the nozzle can resolve — no more,
// no less.  A 10 mm circle at 0.4 mm nozzle needs ~78 facets; an 80 mm circle
// needs ~628.  A global $fn=128 is too coarse for large circles and wasteful for
// small ones.  Hard-coded $fn overrides (6 = hexagon holes, 30 = threads,
// 36 = hinge/clip cylinders) intentionally win over these defaults.
//
// nozzle_d must be set by MasterBuilder before this file is included so that
// $fs matches the actual printer.  Falls back to NOZZLE_DIAMETER0 (0.4 mm).
nozzle_d           = is_undef(Nozzle_Diameter)    ? 0.4                  : Nozzle_Diameter;
line_width         = nozzle_d * EXTRUSION_WIDTH_MULT;                   // one extrusion width (0.42mm at 0.4mm nozzle)
corner_round_ratio = is_undef(Corner_Round_Ratio) ? RECT_HOLE_ROUND_RATIO : Corner_Round_Ratio;
$fn = $preview ? 24 : 0;          // 0 = let $fs/$fa control facet count
$fs = $preview ? 2  : nozzle_d;   // max chord length per facet
$fa = $preview ? 10 : 1;          // max degrees per facet (secondary guard)

// ==============================================================================
// SECTION 1: DEFAULT CONSTANTS
// ==============================================================================
// These are the fallback values used when a parameter isn't specified.
// Centralized here so they can be tweaked globally.

WIDTH0 = 50;                    // Default container width (mm)
LENGTH0 = 50;                   // Default container length (mm)
HEIGHT0 = 50;                   // Default container height (mm)
LAYER_HEIGHT0 = 0.20;           // Default slicer layer height (mm)
WALL_LOOPS0 = 3;                // Default perimeter passes
NOZZLE_DIAMETER0 = 0.4;         // Default nozzle size (mm)

HINGE_WIDTH_PERCENT0 = 0.6;     // Default flip-lid C-clip hinge length, as a fraction of part width
MIN_HINGE_WIDTH0 = 16;          // Default minimum flip-lid C-clip hinge length (mm)

MIN_HOLE_SPACING0 = 1.2;        // Default mesh hole min spacing (mm)
PATTERN0 = TEARDROP;            // Default mesh pattern
STRUT_WALL0 = 25;               // Default wall mesh density (%)
STRUT_FLOOR0 = 25;              // Default floor mesh density (%)
STRUT_LID0 = 25;                // Default lid mesh density (%)

PLAQUE_STYLE0 = "None";         // Default spec tag style
PLAQUE_TEXT0 = "";              // Default spec tag text
PLAQUE_TEXT_SIZE0 = 8;          // Default text size
WALL_MODIFY0 = "None";          // Default wall modification
WALL_TARGET0 = "All Walls";     // Default wall target

THICK_FLOOR0 = 2.0;             // Default floor thickness (mm)
THICK_LID0 = 2.0;               // Default lid thickness (mm)
THICK_WALL0 = 2.4;              // Default wall thickness (mm)
THICK_DIVIDER0 = 1.2;           // Default divider thickness (mm)
LID_MIN_SOLID0 = 10;            // Default min solid lid area (%)
TOL_SNAP_GAP0 = 0.1;            // Default snap clearance (mm)
TOL_CLIP0 = 0.1;                // Default clip tolerance (mm)

// Boolean operation epsilon — prevents Z-fighting and non-manifold edges in preview.
// EPS  = single-sided cutter overlap. 0.01mm = 10 microns — below any FDM resolution,
//        dimensionally invisible, sits in the floating-point Goldilocks zone for CGAL.
// LINE_W = double-sided cutter overlap = one nozzle line width. Overridden in
//        MasterBuilder to Nozzle_Diameter so it scales with printer settings.
EPS  = 0.01;
LINE_W = 0.4;   // default: one line width at 0.4mm nozzle; overridden in MasterBuilder

PLATTER_GAP0 = 15;              // Default part spacing on bed (mm)
THREAD_PITCH0 = 2.0;            // Default thread pitch (mm)
MAX_BUILD_PLATE_WIDTH0 = 250;   // Default print bed width (mm)
GRID_LAYOUT0 = "";              // Default grid specification
GRID_HAS_BASE0 = false;         // Default grid base

// ==============================================================================
// ENVIRONMENT CONSTRUCTOR
// ==============================================================================
// make_env(...) is the single authoritative way to construct the ui_payload data
// array passed through the entire render pipeline.
//
// WHY: the previous approach was a 55-entry [[KEY, value], ...] literal built
// directly in MasterBuilder.scad.  A typo in a VALUE was silent; a typo in a KEY
// string was only caught by STRICT_KEYS (undefined constant → undef → fallback).
// With named parameters, a typo in a parameter name produces an OpenSCAD
// "unknown parameter" warning at parse time — caught before any geometry runs.
//
// HOW TO OVERRIDE downstream: concat([[KEY, new_val]], data) still works exactly
// as before.  Only the *construction site* (MasterBuilder.scad) changes.
//
// Parameter names use snake_case and map 1-to-1 to the KEY constants in
// MasterEnum.scad.  Defaults come from the *0 constants defined above.
//
// ADDING A KEY: add the parameter here, a matching constant in MasterEnum.scad,
// and the [KEY, param] pair to the return array.  Then pass the Customizer
// variable in MasterBuilder.scad.  Three files, three co-located changes.

function make_env(
    // Identity
    builder_version   = "v4.26",
    // Printer / slicer
    filament_type     = "PLA",
    fit_profile       = "Standard",
    layer_height      = LAYER_HEIGHT0,
    wall_loops        = WALL_LOOPS0,
    nozzle_diameter   = NOZZLE_DIAMETER0,
    // Dimensions
    dimension_mode    = "Total",
    width             = WIDTH0,
    length            = LENGTH0,
    height            = HEIGHT0,
    // Mesh
    pattern           = PATTERN0,
    hole_wall         = 0,
    hole_floor        = 0,
    hole_lid          = 0,
    hole_spacing      = MIN_HOLE_SPACING0,
    strut_wall        = STRUT_WALL0,
    strut_floor       = STRUT_FLOOR0,
    strut_lid         = STRUT_LID0,
    // Geometry overrides
    chamfer_size      = 0.4,
    corner_radius     = 0.0,
    // Thicknesses
    thick_floor       = THICK_FLOOR0,
    thick_lid         = THICK_LID0,
    thick_wall        = THICK_WALL0,
    thick_divider     = THICK_DIVIDER0,
    thick_peg_mult    = 2.0,
    // Stacking
    peg_height        = 80,
    peg_socket_d      = 8.0,
    ledge_depth       = 2.0,
    peg_protrusion    = 0.0,
    // Layout / platter
    platter_gap       = PLATTER_GAP0,
    grid_layout       = GRID_LAYOUT0,
    grid_mod_hints    = true,
    // Lid type selection (Box intent)
    snap_external     = false,
    snap_internal     = false,
    glide_external    = false,
    glide_internal    = false,
    build_flip_single = false,
    build_flip_double = false,
    glide_dir         = "H",
    glide_snap        = "Ball",
    // Lid type selection (Container Lid / standalone intent)
    lid_type_sel      = "Flip_Single",
    lid_style         = "External",
    // Simple Tray stacking variants
    stack_nesting     = true,
    stack_peg         = true,
    // Jar
    jar_shape         = "Circle",
    jar_with_lid      = false,
    thread_pitch      = THREAD_PITCH0,
    // Plaque / label
    plaque_target     = "Wall",
    clip_type         = "Vertical",
    plaque_w          = 50,
    plaque_h          = 40,
    clip_h            = 20,
    // Pillbox
    pillbox_days      = 7,
    // Wall modifications
    wall_modify       = WALL_MODIFY0,
    wall_target       = WALL_TARGET0
) = [
    [BUILDER_VERSION,   builder_version],
    [FILAMENT_TYPE,     filament_type],
    [FIT_PROFILE,       fit_profile],
    [LAYER_HEIGHT,      layer_height],
    [WALL_LOOPS,        wall_loops],
    [NOZZLE_DIAMETER,   nozzle_diameter],
    [DIMENSION_MODE,    dimension_mode],
    [WIDTH,             width],
    [LENGTH,            length],
    [HEIGHT,            height],
    [PATTERN,           pattern],
    [HOLE_WALL,         hole_wall],
    [HOLE_FLOOR,        hole_floor],
    [HOLE_LID,          hole_lid],
    [HOLE_SPACING,      hole_spacing],
    [STRUT_WALL,        strut_wall],
    [STRUT_FLOOR,       strut_floor],
    [STRUT_LID,         strut_lid],
    [CHAMFER_SIZE,      chamfer_size],
    [CORNER_RADIUS,     corner_radius],
    [THICK_FLOOR,       thick_floor],
    [THICK_LID,         thick_lid],
    [THICK_WALL,        thick_wall],
    [THICK_DIVIDER,     thick_divider],
    [THICK_PEG_MULT,    thick_peg_mult],
    [PEG_HEIGHT,        peg_height],
    [PEG_SOCKET_D,      peg_socket_d],
    [LEDGE_DEPTH,       ledge_depth],
    [PEG_PROTRUSION,    peg_protrusion],
    [PLATTER_GAP,       platter_gap],
    [GRID_LAYOUT,       grid_layout],
    [GRID_MOD_HINTS,    grid_mod_hints],
    [SNAP_EXTERNAL,     snap_external],
    [SNAP_INTERNAL,     snap_internal],
    [GLIDE_EXTERNAL,    glide_external],
    [GLIDE_INTERNAL,    glide_internal],
    [BUILD_FLIP_SINGLE, build_flip_single],
    [BUILD_FLIP_DOUBLE, build_flip_double],
    [GLIDE_DIR,         glide_dir],
    [GLIDE_SNAP,        glide_snap],
    [LID_TYPE_SEL,      lid_type_sel],
    [LID_STYLE,         lid_style],
    [STACK_NESTING,     stack_nesting],
    [STACK_PEG,         stack_peg],
    [JAR_SHAPE,         jar_shape],
    [JAR_WITH_LID,      jar_with_lid],
    [THREAD_PITCH,      thread_pitch],
    [PLAQUE_TARGET,     plaque_target],
    [CLIP_TYPE,         clip_type],
    [PLAQUE_W,          plaque_w],
    [PLAQUE_H,          plaque_h],
    [CLIP_H,            clip_h],
    [PILLBOX_DAYS,      pillbox_days],
    [WALL_MODIFY,       wall_modify],
    [WALL_TARGET,       wall_target]
];

// ==============================================================================
// TIER 0: PRIMITIVE GETTERS (Extract raw values from data array)
// ==============================================================================

/// get_val(key, data, fallback)
/// Universal parameter extractor using array search.
/// The data array is structured as: [["KEY1", val1], ["KEY2", val2], ...]
/// This function searches for the key and returns its value, or fallback if not found.
// STRICT_KEYS: when true (-D STRICT_KEYS=true), get_val asserts the key constant
// is actually defined. A typo'd KEY constant (e.g. get_val(WIDHT, ...)) evaluates
// to undef in OpenSCAD and would otherwise silently return the fallback. Off by
// default so production builds are unaffected; turn on in the test gate / CI.
STRICT_KEYS = false;
function get_val(key, data, fallback) =
  assert(!STRICT_KEYS || !is_undef(key),
         "get_val: key constant is undef — likely a typo in a KEY name")
  let (idx = search([key], data)[0])
  (idx == []) ? fallback : data[idx][1];

/// make_part(type, local_data)
/// Helper to create a new part specification with a given type.
/// Concatenates the TYPE key-value with additional data.
function make_part(type, local_data=[]) =
  concat([[TYPE, type]], local_data);

/// get_footprint(data)
/// Returns [width, length] footprint of the container.
/// For jars: footprint is square (width = length)
/// For boxes/trays: footprint is rectangular (width × length)
function get_footprint(data) =
    let(type = get_val(TYPE, data, BOX),
        w = max(10, get_val(WIDTH, data, WIDTH0)),
        l = max(10, get_val(LENGTH, data, LENGTH0)))
    (type == JAR || type == JAR_LID || type == JAR_GRID || type == PLAQUE_JAR)
      ? [w, w]              // Jar: square footprint
      : [w, l];             // Box/Tray: rectangular footprint

// --- Dimension Getters with Bounds Checking ---
// These extract raw dimension values and apply minimum bounds to prevent
// invalid geometry (containers can't be smaller than walls allow).

/// m_bw(data): Master Builder Width
/// Returns the WIDTH parameter with minimum bound of 10mm.
function m_bw(data) = max(10, get_val(WIDTH, data, WIDTH0));

/// m_bl(data): Master Builder Length
/// Returns the LENGTH parameter with minimum bound of 10mm.
function m_bl(data) = max(10, get_val(LENGTH, data, LENGTH0));

/// m_bh(data): Master Builder Height
/// Returns the HEIGHT parameter with minimum bound of 5mm.
function m_bh(data) = max(5, get_val(HEIGHT, data, HEIGHT0));

// --- Hardware Specification Getters ---
// These extract printer/filament specifications needed for safety calculations.

/// m_noz(data): Master Nozzle diameter
/// Returns the nozzle diameter in millimeters (typical: 0.4, 0.6, 0.8)
function m_noz(data) = get_val(NOZZLE_DIAMETER, data, NOZZLE_DIAMETER0);

/// m_lh(data): Master Layer Height
/// Handles both numeric and string values.
/// Converts string descriptions like "Detailed (0.12mm)" to numeric values.
/// Returns the slicer layer height in millimeters.
function m_lh(data) =
  let (s = get_val(LAYER_HEIGHT, data, 0.20))
  (is_num(s)) ? s : ((s=="Detailed (0.12mm)") ? 0.12 : 0.20);

/// m_wloops(data): Master Wall Loops
/// Returns the number of perimeter passes, with fallback for string values.
function m_wloops(data) =
  let (w = get_val(WALL_LOOPS, data, 3))
  (is_num(w)) ? w : 3;

// ==============================================================================
// TIER 1: UTILITY FUNCTIONS (String parsing and numeric helpers)
// ==============================================================================

/// get_digits(s): Extract all digit characters from a string
/// Returns array of integers extracted from the string (0-9 only).
/// Used for parsing parameter strings like "50%" or "Detailed (0.12mm)"
function get_digits(s) =
  [for (i = [0 : len(s)-1])
    let (o = ord(s[i]))
    if (o >= 48 && o <= 57)  // ASCII 48-57 = '0'-'9'
      o - 48
  ];

/// to_num(d): Convert array of digits to a number
/// Handles 1, 2, or 3-digit numbers correctly.
/// Examples: [5] → 5, [2,3] → 23, [1,2,3] → 123
function to_num(d) =
  (len(d)==0) ? 0 :
  (len(d)==1) ? d[0] :
  (len(d)==2) ? d[0]*10 + d[1] :
  (len(d)==3) ? d[0]*100 + d[1]*10 + d[2] :
  0;

// ==============================================================================
// TIER 2: MESH & GRID CONFIGURATION (Pattern and density calculations)
// ==============================================================================

/// get_mesh_cfg(data, h_key, s_key)
/// Returns [hole, strut] for a mesh surface, or undef when no mesh should be cut.
///
/// hole  — hole diameter (mm); controls hole size, together with spacing sets density
/// strut — solid border surrounding the mesh region as % of the surface
///         (NOT the strut between holes — that is set by hole size + spacing)
///
/// WHY NO needs_margin: the minimum solid edge at the jar neck / box lip is provided
/// by the physical container geometry unconditionally. Enforcing it again as a mesh
/// border double-counts the constraint and silently overrides the user's strut%.
function get_mesh_cfg(data, h_key, s_key) =
  let(pat = get_val(PATTERN, data, PATTERN0))
  (pat == NONE) ? undef :
  let(hole = get_val(h_key, data, 1.6))
  (hole <= 0.05) ? undef :
  let(strut = get_val(s_key, data, 25))
  (strut >= 99) ? undef :
  [hole, strut];

/// get_grid_step(hole, min_sp, noz): step = hole diameter + strut width
///
/// Strut width (innermost → outermost):
///   max(noz*2, hole*STRUT_HOLE_RATIO) — raw strut: min 2 nozzle widths, or 25% of
///                              hole diameter for large holes (struts stay proportional)
///   round(.../noz) * noz    — snap to nearest nozzle-width multiple so the slicer
///                              lays complete extrusion passes (no partial lines)
///   max(noz, ...)           — floor at 1 nozzle width if rounding went down
///   max(min_sp, ...)        — caller's minimum wins if larger (physics/user override)
///
/// Result: step is always a whole-nozzle multiple, never thinner than the physics floor.
function get_grid_step(hole, min_sp, noz) =
  hole + max(min_sp, max(noz, round(max(noz * 2, hole * STRUT_HOLE_RATIO) / noz) * noz));

/// get_mesh_dim(dim, strut): Inner mesh region size after subtracting solid border.
/// strut% is the solid border as a fraction of the total surface.
/// e.g. 100mm surface, strut=20% → 10mm solid on each side → 80mm mesh region.
/// Density (holes/mm²) is set by hole size + spacing and is independent of strut%.
function get_mesh_dim(dim, perc) = max(0.1, dim * (1 - (perc / 100)));

/// get_n_steps(dim, perc, step): Calculate number of mesh pattern repetitions
/// Used to tile hole patterns across a surface.
function get_n_steps(dim, perc, step) = ceil((get_mesh_dim(dim, perc)) / step) + 2;

// ==============================================================================
// TIER 3: PLATTER PACKING (Multi-part layout on print bed)
// ==============================================================================

/// get_xy(manifest, target_idx, ...)
/// Recursive function that calculates XY position of a part in a platter layout.
/// Implements row-wrapping when parts exceed build plate width.
/// Returns [center_x, center_y] for the target part.
function get_xy(manifest, target_idx, curr_idx=0, edge_x=0, edge_y=0, row_max_y=0) =
    let(
        data = manifest[curr_idx],
        footprint = get_footprint(data),
        w = footprint[0],
        l = footprint[1],

        gap = get_val(PLATTER_GAP, data, PLATTER_GAP0),
        wrap = (edge_x > 0) && ((edge_x + w) > MAX_BUILD_PLATE_WIDTH0),

        actual_edge_x = wrap ? 0 : edge_x,
        actual_edge_y = wrap ? edge_y + row_max_y : edge_y,

        center_x = actual_edge_x + (w / 2),
        center_y = actual_edge_y + (l / 2),

        next_edge_x = actual_edge_x + w + gap,
        next_row_max = wrap ? l + gap : max(row_max_y, l + gap)
    )
    (curr_idx == target_idx)
      ? [center_x, center_y]
      : get_xy(manifest, target_idx, curr_idx + 1, next_edge_x, actual_edge_y, next_row_max);

// ==============================================================================
// TIER 4: COMPOSITE GETTERS (Combine multiple sources for final values)
// ==============================================================================

/// m_type(data): Master Part Type
/// Returns the build type (BOX, JAR, FLIP_BOX, TRAY, PLAQUE, etc.)
function m_type(data) = get_val(TYPE, data, BOX);

/// m_grid_layout(data): Master Grid Layout String
/// Returns the raw grid specification string for parsing by GridLayout.scad
function m_grid_layout(data) = get_val(GRID_LAYOUT, data, GRID_LAYOUT0);

/// m_grid_has_base(data): Master Grid Base Toggle
/// Returns whether the grid includes a support base (true/false)
function m_grid_has_base(data) = get_val(GRID_HAS_BASE, data, GRID_HAS_BASE0);

/// m_mesh_pattern(data): Master Mesh Pattern
/// Returns pattern type for mesh generation: TEARDROP, HONEYCOMB, CIRCLE, etc.
function m_mesh_pattern(data) = get_val(PATTERN, data, PATTERN0);

/// m_thread_pitch(data): Master Thread Pitch
/// Returns pitch for M8-equivalent threaded jars (typical: 2.0mm)
function m_thread_pitch(data) = get_val(THREAD_PITCH, data, THREAD_PITCH0);

/// m_fil(data): Master Filament Type
/// Returns filament material name (e.g., "PLA", "PETG", "TPU")
function m_fil(data) = get_val(FILAMENT_TYPE, data, "PLA");

// ==============================================================================
// TIER 5: SAFETY VALIDATORS (FDM-specific thickness calculations)
// ==============================================================================
// These functions apply FDM-specific constraints to ensure successful prints.
// Canonical home for all FDM safety constraints.

/// m_safe_floor(data): Safe Floor Thickness
/// Ensures floor is aligned to layer height to prevent slicer micro-stepping.
///
/// CONSTRAINT 1: Round to nearest multiple of layer height
///   REASON: Micro-stepping = slicer inserts tiny Z-movements between layers
///           causing surface roughness, layer adhesion stress, and warping
///   EXAMPLE: 2.0mm floor on 0.20mm layer height
///            Safe:   round(2.0 / 0.20) * 0.20 = 2.0mm (exactly 10 layers)
///            Unsafe: 2.0mm / 0.20 = 10.0 (micro-steps occur)
///
/// CONSTRAINT 2: Cap at 35% of total height
///   REASON: Prevents accidentally creating solid bricks for small trays
///           Example: 10mm tall container shouldn't have 3.5mm floor
// [GEOM-FIX: under-thin floor] Floor is bumped to a structural minimum (>= MIN_FLOOR_MM and
// >= MIN_FLOOR_LAYERS layers) if the user spec is thinner — was floored at one layer, which
// won't hold contents. Structural min is clamped to the MAX_FLOOR cap so a short box isn't
// over-bumped. Only ever raises a too-thin value; the 2.0mm default is unaffected.
function m_safe_floor(data) =
  let(lh = m_lh(data),
      cap = m_bh(data) * (MAX_FLOOR_THICKNESS_PCT / 100),
      struct = min(cap, max(MIN_FLOOR_MM, MIN_FLOOR_LAYERS * lh)))
  max(
    struct,
    round(min(get_val(THICK_FLOOR, data, THICK_FLOOR0), cap) / lh) * lh
  );

/// m_safe_lid(data): Safe Lid Thickness
/// Same logic as m_safe_floor—rounds to layer height multiples.
/// Lids need alignment to prevent warping when they're large and flat.
// [GEOM-FIX: under-thin lid] Same structural-minimum bump as m_safe_floor — a 1-layer lid
// flexes/cracks and can't seat a closing mechanism. Clamped to MAX_LID cap; only raises.
function m_safe_lid(data) =
  let(lh = m_lh(data),
      cap = m_bh(data) * (MAX_LID_THICKNESS_PCT / 100),
      struct = min(cap, max(MIN_LID_MM, MIN_LID_LAYERS * lh)))
  max(
    struct,
    round(min(get_val(THICK_LID, data, THICK_LID0), cap) / lh) * lh
  );

/// m_safe_wall(data): Safe Wall Thickness
/// Ensures wall thickness snaps to exact multiples of nozzle diameter.
///
/// CONSTRAINT 1: Round to nearest multiple of nozzle diameter
///   REASON: FDM extrusion is delivered in discrete threads of plastic.
///           If wall = 2.3mm but nozzle = 0.4mm, slicer generates:
///             5 passes @ 0.4mm = 2.0mm (undersize, weak)
///             6 passes @ 0.4mm = 2.4mm (oversize, may hit geometry)
///           Force walls to exact multiples (2.0mm or 2.4mm) to eliminate ambiguity
///   EXAMPLE: 0.4mm nozzle → valid walls: 0.4, 0.8, 1.2, 1.6, 2.0, 2.4, 2.8, 3.2mm
///
/// CONSTRAINT 2: Minimum = nozzle × wall_loops
///   REASON: Physical minimum for structural integrity
///           3 perimeters × 0.4mm nozzle = minimum 1.2mm wall
///
/// CONSTRAINT 3: Cap at 45% of smallest XY dimension
///   REASON: Prevents excessively thick walls that waste material and print time
// [GEOM-FIX: under-thin wall] Minimum is now max(wall_loops, MIN_WALL_LOOPS) perimeters, so a
// user setting Wall_Loops=1 still gets a structurally-sound 2-perimeter wall. For loops>=2 and
// the default thick_wall this is unchanged. Only ever raises a too-thin value.
function m_safe_wall(data) =
  let(noz = m_noz(data))
  max(
    noz * max(m_wloops(data), MIN_WALL_LOOPS),  // structural floor: >= MIN_WALL_LOOPS perimeters
    round(
      min(
        get_val(THICK_WALL, data, THICK_WALL0),
        min(m_bw(data), m_bl(data)) * (MAX_WALL_THICKNESS_PCT / 100)
      ) / noz
    ) * noz
  );

/// m_c_rad(data): Master Corner Radius
/// Derives safe inner bounding box corner radius from wall thickness.
///
/// ENGINEERING REASON:
///   - BOSL2's cuboid(..., rounding=r) applies radius to OUTER edges
///   - If inner radius drops below wall thickness, internal geometry inverts
///     and creates non-manifold geometry that fails in slicers
///   - Formula: wall_thickness + (nozzle × wall_loops) / 2 - 0.5mm margin
///   - 0.5mm margin prevents edge cases where rounding is exactly at boundary
function m_c_rad(data) =
  let(v = get_val(CORNER_RADIUS, data, 0))
  v > 0 ? v : m_safe_wall(data) + ((m_noz(data) * m_wloops(data)) / 2) - 0.5;

/// m_chamf(data): Master Chamfer Distance
/// Calculates maximum safe chamfer before FDM bridging failures.
///
/// CONSTRAINT: Capped at nozzle_diameter × 2.5
/// ENGINEERING REASON:
///   - FDM critical overhang angle: 45° (empirically determined)
///   - Beyond 2.5× nozzle diameter, chamfers create unsupported bridges
///   - Example: 0.4mm nozzle → max chamfer 1.0mm (0.4 × 2.5)
///   - Excessive chamfers (e.g., 3mm) cause slicer to generate bridges
///     that collapse during printing or cool incorrectly
function m_chamf(data) =
  let(v = get_val(CHAMFER_SIZE, data, 0))
  v > 0 ? v : m_noz(data) * MAX_CHAMFER_MULT;

/// m_wall_mod_p(data): Wall Modification Percentage
/// Parses the WALL_MODIFY string into a 0–100 numeric multiplier.
/// Input formats: "None" → 100, "Dropped" → 0, "50%" → 50
function m_wall_mod_p(data) =
  let (s = str(get_val(WALL_MODIFY, data, WALL_MODIFY0)))
  (s == "None")    ? 100 :
  (s == "Dropped") ? 0   :
  let (n = get_digits(s))
  (len(n) == 1) ? n[0] :
  (len(n) == 2) ? n[0] * 10 + n[1] :
  (len(n) == 3) ? n[0] * 100 + n[1] * 10 + n[2] :
  100;

// ==============================================================================
// TIER 6: PLATTER PACKING
// ==============================================================================

// Returns [w, l] footprint for a manifest item. Jars are always square (w×w).
function get_footprint(item) =
  let(type = item[0],
      data = item[1],
      w = m_bw(data),
      l = m_bl(data))
  (type == "JAR" || type == "JAR_LID" || type == "JAR_GRID") ? [w, w] : [w, l];

// Shelf-packing: walks the manifest accumulating X/Y positions, returns [cx, cy]
// for the part at target_idx. Wraps to a new row when exceeding bed width.
function get_xy(manifest, target_idx, curr_idx=0, edge_x=0, edge_y=0, row_max_y=0) =
  let(
    fp      = get_footprint(manifest[curr_idx]),
    w       = fp[0],
    l       = fp[1],
    gap     = get_val(PLATTER_GAP, manifest[curr_idx][1], PLATTER_GAP0),
    wrap    = (edge_x > 0) && ((edge_x + w) > MAX_BUILD_PLATE_WIDTH0),
    ex      = wrap ? 0           : edge_x,
    ey      = wrap ? edge_y + row_max_y : edge_y,
    cx      = ex + w / 2,
    cy      = ey + l / 2,
    next_x  = ex + w + gap,
    next_y  = wrap ? l + gap : max(row_max_y, l + gap)
  )
  (curr_idx == target_idx)
    ? [cx, cy]
    : get_xy(manifest, target_idx, curr_idx + 1, next_x, ey, next_y);

// ==============================================================================
// TIER 6b: GEOMETRY CONSTRAINTS
// Named functions for all derived geometry limits. Centralised here so that
// render modules and MasterDebug use the same formula, and the formula is
// findable by name rather than buried inline.
// ==============================================================================

/// layer_snap(z, lh): round z to the nearest layer-height multiple.
/// Use on any Z position or height that will be printed as a surface.
/// Fractional-layer Z forces the slicer to insert micro-moves between layers,
/// causing surface roughness and reduced inter-layer adhesion.
function layer_snap(z, lh) = round(z / lh) * lh;

/// Glide lid — ball catch diameter scaled with box footprint.
/// Glide ball diameter — scales with box footprint, capped at 1.5× wall thickness.
/// Boss pads (RenderBox) provide structural backing so the old groove-wall-penetration
/// cap (wall_cap) is no longer needed — it was limiting ball_d to 0.8mm (2 nozzle
/// widths), which produced zero-protrusion sockets that couldn't snap shut.
/// Minimum noz*5 (2mm at 0.4mm nozzle) — smallest sphere with a printable socket ring.
/// Scale 0.04: 2mm at 50mm footprint, 4mm at 100mm — proportional retention force.
function glide_ball_d(w, l, sw, noz) =
    max(noz * 5, min(sw * 1.5, max(w, l) * 0.04));

/// Glide lid — how deeply the ball center is recessed into the lid face.
/// Positions ball center at noz/2 past the groove wall — gentle cam entry
/// that allows insertion while providing positive snap retention.
function glide_ball_protr(ball_r, glide_tol, noz) =
    ball_r - (glide_tol + noz) / 2;

/// Flip lid — Z height of the diamond latch recess on the box front face.
/// Derived from axle height and lid latch geometry so tip aligns when closed.
/// When closed: lid face at h − sl − 2·cc_z; latch tip at +clasp_depth above that.
function flip_latch_z(h, cc_z, clasp_depth) =
    h - 2 * cc_z + clasp_depth;

/// Flip lid — length of the C-clip hinge / connecting block along the wall.
/// HINGE_WIDTH_PERCENT0 of the part width, floored at MIN_HINGE_WIDTH0 so small
/// parts still get a hinge wide enough to be structurally sound, and capped at
/// part_w - sw*6 so it never collides with the side walls.
function flip_hinge_len(part_w, sw) =
    min(part_w - sw * 6, max(part_w * HINGE_WIDTH_PERCENT0, MIN_HINGE_WIDTH0));

/// Grid span — clamp span wall height to the container's permitted maximum.
/// Prevents spans from exceeding flip-lid axle clearance or jar neck clearance.
function span_h_clamped(req_h, max_h) = min(req_h, max_h);

// ==============================================================================
// TIER 7: GEOMETRY UTILITIES
// ==============================================================================

/// apply_master_bounds(w, l, h, r, c)
/// Clips child geometry to a rounded-corner, chamfered-top bounding box.
///
/// Two-pass intersection:
///   Pass 1 — rounds the four vertical (Z) corner edges.
///             h*3 oversize avoids inadvertently clipping tall children.
///   Pass 2 — chamfers the top AND bottom horizontal edges at exactly h.
///             TOP  chamfer: rounds the rim so it doesn't cut fingers.
///             BOTTOM chamfer: gives first-layer squish a lead-in ramp,
///             eliminating elephant foot at the base perimeter.
///             XY is oversized by EPS so it doesn't disturb the corner rounding.
///
/// Result: vertical corners rounded, top and bottom rims chamfered, sides untouched.
/// The `c` parameter was previously accepted but silently ignored — this wires it up.
module apply_master_bounds(w, l, h, r, c) {
  c_r = max(0.1, min(r, (w / 2) - 0.1, (l / 2) - 0.1));
  intersection() {
    intersection() {
      children();
      cuboid([w, l, h * 3], rounding=c_r, edges="Z", anchor=BOTTOM);
    }
    cuboid([w + EPS, l + EPS, h], chamfer=max(0, c), edges=TOP+BOTTOM, anchor=BOTTOM);
  }
}

// ==============================================================================
// TIER 7: DATA PIPELINE (Pre-processing before factory dispatch)
// ==============================================================================

/// apply_inductions(data)
/// Automatic overrides based on part type before geometry is built.
/// Currently: forces SLOTTED pattern on desiccant types (required for airflow).
function apply_inductions(data) =
  let (type = get_val(TYPE, data, BOX),
       ui_pat = get_val(PATTERN, data, TEARDROP))
  ((type == DESICCANT_BOX || type == DESICCANT_LID) && ui_pat != NONE)
    ? concat([[PATTERN, SLOTTED]], data)
    : data;

/// enforce_safety(data)
/// Prepends computed FDM-safe thicknesses so they override raw UI values.
/// Prepending exploits get_val's first-match semantics for immutable override.
function enforce_safety(data) =
  concat([[THICK_WALL, m_safe_wall(data)], [THICK_FLOOR, m_safe_floor(data)]], data);

/// process_part(part_data)
/// Standard pre-processing pipeline: inductions then safety enforcement.
/// Every factory should call this on its data before extracting dimensions.
function process_part(part_data) = enforce_safety(apply_inductions(part_data));
