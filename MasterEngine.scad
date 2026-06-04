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

include <BOSL2/std.scad>
include <BOSL2/threading.scad>
include <MasterEnum.scad>
include <MasterConstants.scad>

// --- RENDERING QUALITY SETTINGS ---
// $fn: Fragment count controls smoothness of curves
//   - Preview mode: 32 segments (fast screen refresh)
//   - Render mode: 128 segments (export-quality STL smoothness)
$fn = $preview ? 24 : 128;

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

PLATTER_GAP0 = 15;              // Default part spacing on bed (mm)
THREAD_PITCH0 = 2.0;            // Default thread pitch (mm)
MAX_BUILD_PLATE_WIDTH0 = 250;   // Default print bed width (mm)
GRID_LAYOUT0 = "";              // Default grid specification
GRID_HAS_BASE0 = false;         // Default grid base

// ==============================================================================
// TIER 0: PRIMITIVE GETTERS (Extract raw values from data array)
// ==============================================================================

/// get_val(key, data, fallback)
/// Universal parameter extractor using array search.
/// The data array is structured as: [["KEY1", val1], ["KEY2", val2], ...]
/// This function searches for the key and returns its value, or fallback if not found.
function get_val(key, data, fallback) =
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

/// get_mesh_cfg(data, h_key, s_key, needs_margin)
/// Returns mesh configuration [hole_size, strut_percentage] for a surface.
/// If conditions are met (no pattern, holes too small, etc.), returns undef.
/// This prevents invalid mesh geometries from being generated.
function get_mesh_cfg(data, h_key, s_key, needs_margin=false) =
  let(
    pat = get_val(PATTERN, data, PATTERN0),
    hole = get_val(h_key, data, 1.6),
    strut = get_val(s_key, data, 25),
    req_s = (200 * get_val(LID_MIN_SOLID, data, LID_MIN_SOLID0))
            / min(m_bw(data), m_bl(data)),
    final_s = needs_margin
              ? max(strut, req_s)
              : strut
  )
  ((pat == NONE || hole <= 0.05 || final_s >= 99) ? undef : [hole, final_s]);

/// get_grid_step(hole, min_sp, noz): Calculate spacing between mesh holes
/// Ensures minimum spacing is maintained and aligns to nozzle multiples.
function get_grid_step(hole, min_sp, noz) =
  hole + max(min_sp, max(noz, round(max(noz * 2, hole * 0.25) / noz) * noz));

/// get_mesh_dim(dim, perc): Calculate effective mesh dimension from percentage
/// If surface is 100mm and 80% solid, remaining mesh area is 20mm across.
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
function m_safe_floor(data) =
  max(
    m_lh(data),
    round(
      min(
        get_val(THICK_FLOOR, data, THICK_FLOOR0),
        m_bh(data) * (MAX_FLOOR_THICKNESS_PCT / 100)
      ) / m_lh(data)
    ) * m_lh(data)
  );

/// m_safe_lid(data): Safe Lid Thickness
/// Same logic as m_safe_floor—rounds to layer height multiples.
/// Lids need alignment to prevent warping when they're large and flat.
function m_safe_lid(data) =
  max(
    m_lh(data),
    round(
      min(
        get_val(THICK_LID, data, THICK_LID0),
        m_bh(data) * (MAX_LID_THICKNESS_PCT / 100)
      ) / m_lh(data)
    ) * m_lh(data)
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
function m_safe_wall(data) =
  max(
    m_noz(data) * m_wloops(data),  // Minimum: nozzle_diameter × wall_loops
    round(
      min(
        get_val(THICK_WALL, data, THICK_WALL0),
        min(m_bw(data), m_bl(data)) * (MAX_WALL_THICKNESS_PCT / 100)
      ) / m_noz(data)
    ) * m_noz(data)
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
  m_safe_wall(data) + ((m_noz(data) * m_wloops(data)) / 2) - 0.5;

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
  m_noz(data) * MAX_CHAMFER_MULT;

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
// TIER 6: GEOMETRY UTILITIES
// ==============================================================================

/// apply_master_bounds(w, l, h, r, c)
/// Clips child geometry to a rounded-corner bounding box using intersection.
/// Ensures no geometry escapes the outer container walls.
/// The h*3 oversize prevents the clip from cutting the top of tall objects.
module apply_master_bounds(w, l, h, r, c) {
  c_r = max(0.1, min(r, (w / 2) - 0.1, (l / 2) - 0.1));
  intersection() {
    children();
    cuboid([w, l, h * 3], rounding=c_r, edges="Z", anchor=BOTTOM);
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
