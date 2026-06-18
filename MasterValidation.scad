// ==============================================================================
// FILE: MasterValidation.scad
// ARCHITECTURE: Layer 1.1.5 (Input Validation & Warnings)
// PURPOSE: Pre-build validation to catch user errors early
// ==============================================================================

// MasterEngine is included once by MasterBuilder.scad (single owner) — not re-included here [perf]
include <MasterConstants.scad>
include <GridLayout.scad>

// === DATA FORMAT VALIDATION ===
// Validates that part data follows the required array-of-arrays format

function validate_part_structure(data) =
  let (
    is_array = is_list(data),
    has_type = is_array && len([for (kv = data) if (kv[0] == TYPE) kv]) > 0
  ) (is_array && has_type) ? true : false;

// === DIMENSION VALIDATION ===
// Warns about dimensions that are too small or too large for FDM printing

function validate_dimensions(data) =
  let (w = m_bw(data), l = m_bl(data), h = m_bh(data)) (w < 10) ? echo(str("⚠ WARNING: Width ", w, "mm < 10mm minimum"))
  : (l < 10) ? echo(str("⚠ WARNING: Length ", l, "mm < 10mm minimum"))
  : (h < 5) ? echo(str("⚠ WARNING: Height ", h, "mm < 5mm minimum"))
  : (w > 250) ? echo(str("⚠ WARNING: Width ", w, "mm > 250mm build plate"))
  : (l > 250) ? echo(str("⚠ WARNING: Length ", l, "mm > 250mm build plate"))
  : data;

// === THICKNESS VALIDATION ===
// Warns about wall/floor/lid thicknesses that are dangerously thick or thin

function validate_thicknesses(data) =
  let (
    wall = get_val(THICK_WALL, data, THICK_WALL0),
    floor = get_val(THICK_FLOOR, data, THICK_FLOOR0),
    lid = get_val(THICK_LID, data, THICK_LID0),
    noz = m_noz(data)
  ) (wall < noz) ? echo(str("⚠ WARNING: Wall ", wall, "mm < nozzle ", noz, "mm"))
  : (floor < noz) ? echo(str("⚠ WARNING: Floor ", floor, "mm < nozzle ", noz, "mm"))
  : (lid < noz) ? echo(str("⚠ WARNING: Lid ", lid, "mm < nozzle ", noz, "mm"))
  : (wall > 10) ? echo(str("⚠ WARNING: Wall ", wall, "mm is extremely thick (material waste)"))
  : data;

// === GRID LAYOUT VALIDATION ===
// Warns about invalid grid specifications

function validate_grid_layout(data) =
  let (
    g_str = get_val(GRID_LAYOUT, data, ""),
    valid = is_valid_grid_layout(g_str)
  ) (!valid && g_str != "") ? echo(str("⚠ WARNING: Invalid grid layout '", g_str, "'"))
  : data;

// === GRID CELL SIZE VALIDATION ===
// Warns when grid cells are too small for reliable printing

function validate_grid_cell_size(data) =
  let (
    type = get_val(TYPE, data, BOX),
    g_str = get_val(GRID_LAYOUT, data, ""),
    w = m_bw(data),
    l = m_bl(data),
    sw = m_safe_wall(data)
  ) (g_str == "") ? data
  : (type == BOX || type == TRAY_SIMPLE || type == FLIP_BOX) ?
    let (
      cart = parse_cartesian(g_str),
      cols = cart[0],
      rows = cart[1],
      cell_w = (w - sw * 2) / cols,
      cell_l = (l - sw * 2) / rows
    ) (cell_w < 5 || cell_l < 5) ? echo(str("⚠ WARNING: Grid cells too small (", cell_w, "×", cell_l, "mm). Min 5×5mm recommended.")) : data
  : data;

// === MESH HOLE SIZE VALIDATION ===
// Warns about mesh hole sizes that are too large or too small

function validate_mesh_holes(data) =
  let (
    hole_wall = get_val(HOLE_WALL, data, 1.6),
    hole_floor = get_val(HOLE_FLOOR, data, 1.6),
    hole_lid = get_val(HOLE_LID, data, 1.6),
    noz = m_noz(data),
    min_spacing = MIN_HOLE_SPACING
  ) (hole_wall > 5) ? echo(str("⚠ WARNING: Wall mesh hole ", hole_wall, "mm is very large (bridges/sag risk)"))
  : (hole_wall < 0.5) ? echo(str("⚠ WARNING: Wall mesh hole ", hole_wall, "mm is very small (may not print)"))
  : (hole_floor > 5) ? echo(str("⚠ WARNING: Floor mesh hole ", hole_floor, "mm is very large"))
  : (hole_floor < 0.5) ? echo(str("⚠ WARNING: Floor mesh hole ", hole_floor, "mm is very small"))
  : data;

// === STRUT PERCENTAGE VALIDATION ===
// Warns about strut percentages that result in very weak structures

function validate_strut_percentages(data) =
  let (
    strut_wall = get_val(STRUT_WALL, data, STRUT_WALL0),
    strut_floor = get_val(STRUT_FLOOR, data, STRUT_FLOOR0),
    strut_lid = get_val(STRUT_LID, data, STRUT_LID0)
  ) (strut_wall < 10) ? echo(str("⚠ WARNING: Wall strut ", strut_wall, "% is very weak"))
  : (strut_floor < 5) ? echo(str("⚠ WARNING: Floor strut ", strut_floor, "% may collapse under weight"))
  : (strut_lid < 5) ? echo(str("⚠ WARNING: Lid strut ", strut_lid, "% may sag"))
  : (strut_wall > 95) ? echo(str("⚠ WARNING: Wall strut ", strut_wall, "% is nearly solid (material waste)"))
  : data;

// === COMPREHENSIVE VALIDATION PIPELINE ===
// Run all validators in sequence

function validate_all(data) =
  validate_part_structure(data) ?
    validate_dimensions(
      validate_thicknesses(
        validate_grid_layout(
          validate_grid_cell_size(
            validate_mesh_holes(
              validate_strut_percentages(data)
            )
          )
        )
      )
    )
  : data;

// === AUDIT LOG ===
// v1.0: Initial validation suite
//       Warnings output to OpenSCAD console during render preview
//       Silent failures (returns data unmodified) to maintain backwards compatibility
