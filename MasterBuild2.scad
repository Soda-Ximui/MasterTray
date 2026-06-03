// ==============================================================================
// FILE: MasterBuilder.scad
// ARCHITECTURE: Layer 4 (User Interface & Main Entry Point)
// PURPOSE: Customizer-friendly UI + build dispatcher for MasterTray system
// ==============================================================================
//
// THE MASTERBUILDER IS THE USER-FACING INTERFACE TO THE ENTIRE SYSTEM.
// It bridges human-friendly parameters (width, length, height) to the
// internal factory system that generates 3D geometry.
//
// FLOW:
//   1. User adjusts parameters in Customizer or this script
//   2. Parameters are packaged into ui_payload array
//   3. compile_manifest(Part_To_Build, ui_payload) determines what to render
//   4. build_part() dispatches to appropriate factory functions
//   5. Each factory renders its geometry (tray, jar, lid, grid)
//   6. Union of all parts = final printable geometry
//
// CUSTOMIZER INTERFACE CONVENTION:
//   /* [Section Name] */ - Groups parameters in the Customizer UI
//   Variable_Name = default_value; // [option1, option2, option3]
//   The double-slash comment creates dropdown menus in Customizer
//
// ==============================================================================

// ==============================================================================
// SECTION 1: PRINTER / MATERIAL SETTINGS
// ==============================================================================
// These parameters define YOUR PRINTER and filament characteristics.
// Critical for calculating safe thickness multiples.
// Change these to match your specific hardware.

/* [Printer / Slicer Settings] */

/// Nozzle_Diameter [mm]: The size of your printer's extrusion nozzle
/// Common sizes: 0.4 (standard), 0.6 (faster), 0.2 (detail), 0.8 (draft)
/// IMPORTANCE: All wall thicknesses align to multiples of this value
/// Formula: wall_thickness ≈ nozzle_diameter × number_of_loops
Nozzle_Diameter = 0.4;

/// Wall_Loops: Number of perimeter passes the slicer will execute
/// This is typically controlled in your slicer settings (Prusaslicer: "Perimeters")
/// Used here to calculate minimum safe wall thickness
/// Formula: minimum_wall = nozzle_diameter × wall_loops
Wall_Loops = 2;

/// Layer_Height [mm]: The Z-height of each layer from your slicer
/// Common settings: 0.12 (detailed), 0.20 (standard), 0.28 (fast)
/// IMPORTANCE: All floor/lid heights align to multiples of this value
/// Reason: Prevents slicer "micro-stepping" (tiny Z-movements between layers)
///         which causes warping and poor surface finish
Layer_Height = 0.20;

/// Filament_Type: The material you're printing with
/// Options: "PLA", "PETG" (recommended), "TPU" (flexible), "ABS"
/// Used for tolerance lookups (different materials shrink differently)
Filament_Type = "PETG"; // ["PLA", "PETG", "TPU", "ABS"]

// ==============================================================================
// SECTION 2: PART SELECTION AND DESIGN
// ==============================================================================
// Choose WHAT you're building and its basic dimensions.

/* [Part Selection] */

/// Part_To_Build: Which part type to generate
/// - "Box": Simple rectangular container with optional grid dividers
/// - "Threaded Jar": Cylindrical jar with screw-on threaded lid
/// - "Flip Box": Box with hinged flip lid (snap-fit assembly)
/// - "Double Flip Box": Box with hinged lids on both Y faces
/// - "Simple Tray": Open-top storage tray (like a toolbox without walls)
Part_To_Build = "Threaded Jar"; // ["Box", "Threaded Jar", "Flip Box", "Double Flip Box", "Simple Tray"]

/* [Dimensions] */

/// part_width [mm]: X-axis dimension (left-right when looking at front)
/// Typical range: 20-200mm for most containers
/// Constraints: Must be >= 20mm (minimum for wall + interior space)
part_width = 100;

/// part_length [mm]: Y-axis dimension (front-back)
/// Typical range: 20-200mm
part_length = 50;

/// part_height [mm]: Z-axis dimension (up-down), total container height
/// Typical range: 10-150mm
/// Note: If you build a JAR, this controls the jar's overall height
part_height = 20;

/// dimension_mode: Whether dimensions are TOTAL or USABLE interior space
/// - "Total": Dimensions given are the OUTSIDE of the container
/// - "Usable": Dimensions are the INTERIOR space (walls added on top)
/// Use "Total" if you're converting from box dimensions
/// Use "Usable" if you're thinking about storage capacity
dimension_mode = "Total"; // ["Total", "Usable"]

// ==============================================================================
// SECTION 3: VISUAL / MATERIAL PROPERTIES
// ==============================================================================
// Control how walls, floors, and lids look and feel.

/* [Mesh Pattern] */

/// mesh_pattern: Hole pattern for mesh surfaces (if enabled)
/// - "Teardrop": Tadpole-shaped holes (printing optimized, minimal bridging)
/// - "Honeycomb": Hexagonal cells (strong, efficient use of material)
/// - "Circle": Simple round holes (easy to understand, moderate strength)
/// - "Square": Square grid pattern (mathematical, uniform stress distribution)
/// - "Slotted": Rectangular slots (good for liquid drainage)
/// - "Diamond": Rotated squares (45° pattern, interesting aesthetics)
mesh_pattern = "Teardrop"; // ["Teardrop", "Honeycomb", "Circle", "Square", "Slotted", "Diamond"]

/// mesh_hole_size [mm]: Diameter of holes in the mesh (if pattern enabled)
/// 0.0 = No mesh (solid walls/floors/lids)
/// 1.0-3.0 = Small detail (lightweight)
/// 3.0-6.0 = Medium drainage (typical containers)
/// 6.0+ = Large opening (perforated storage)
/// CONSTRAINT: Holes must be larger than nozzle diameter (≥0.4mm)
mesh_hole_size = 0.0;

/// strut_wall_perc [%]: Material density of wall mesh
/// 100% = solid walls
/// 50% = half solid, half perforated (lighter weight)
/// 20% = mostly holes with fine struts (minimal material, lightweight)
strut_wall_perc = 100; // [10:10:100]

/// strut_floor_perc [%]: Material density of floor mesh
/// 100% = solid floor (waterproof, strong)
/// 50% = half mesh (drains liquids, lighter)
/// Typical: 100% for storage, 50% for strainers
strut_floor_perc = 100; // [10:10:100]

/// strut_lid_perc [%]: Material density of lid mesh
/// 100% = solid lid (waterproof protection)
/// 50% = ventilated lid (reduces plastic, allows air circulation)
strut_lid_perc = 100; // [10:10:100]

// ==============================================================================
// SECTION 4: GRID SYSTEM (INTERNAL DIVIDERS)
// ==============================================================================
// Customize the internal wall/shelf structure.

/* [Grid System] */

/// grid_type: Are dividers built-in or drop-in?
/// - "Built-in": Dividers molded as part of the container (permanent, strong)
/// - "Drop-in": Dividers are separate (reusable, removable)
grid_type = "Built-in"; // ["Built-in", "Drop-in"]

/// grid_layout: ASCII-like specification for divider arrangement
/// Syntax: "[Cols]x[Rows] [Span definitions] [Radial specs]"
/// Examples:
///   "3x3"                     = 3×3 grid of equal cells
///   "2x4 S1/1/2/2/50%"        = 2×4 grid, custom span at row 1 col 1
///   "R6 C20%"                 = 6-ray radial pattern (jars), 20% of diameter
/// For simple grids, just use "[Cols]x[Rows]"
grid_layout = "7x5 S2/2/2/3/150% S5/1/1/2/80 R3 C15%";

/// grid_has_base: Add a support plate under the grid?
/// true = Grid sits on a 2-3mm thick floor (distributes weight)
/// false = Grid is cut out directly into container floor (saves material)
grid_has_base = true;

// ==============================================================================
// SECTION 5: ENGINEERING / MATERIAL THICKNESS
// ==============================================================================
// Fine-tune wall/floor/lid thickness for strength and weight.
// Note: These are TARGET values. Actual thicknesses may be adjusted
// to align with nozzle diameter (see MasterEngine.scad TIER 5 for details).

/* [Engineering] */

/// floor_thickness [mm]: Bottom surface thickness
/// Typical: 1.5-3.0mm for normal containers
/// Higher = more rigid, heavier
/// Lower = lighter, but may sag if unsupported (especially for wide bases)
/// CONSTRAINT: Will be rounded to nearest multiple of layer_height
floor_thickness = 2.0;

/// lid_thickness [mm]: Top/lid thickness
/// Typical: 2.0-3.0mm (slightly thicker than floor for structural strength)
/// Higher = more durable, protects contents better
/// CONSTRAINT: Will be rounded to nearest multiple of layer_height
lid_thickness = 2.0;

/// wall_thickness [mm]: Side wall thickness
/// Typical: 2.0-2.4mm for standard containers
/// 1.6mm = Thin, lightweight (small decorative boxes)
/// 2.4mm = Standard (most containers)
/// 3.2mm = Thick, very strong (heavy-duty storage)
/// CONSTRAINT: Will be rounded to nearest multiple of nozzle_diameter
wall_thickness = 2.4;

/// divider_thickness [mm]: Internal shelf/grid wall thickness
/// Typical: 1.0-1.5mm (can be thinner than outer walls, interior stress is lower)
/// Thinner = saves material, faster print
/// Thicker = more rigid shelves (matters for large grids)
divider_thickness = 1.2;

/// thread_pitch [mm]: Thread spacing for threaded jars
/// Typical: 2.0mm (M8-equivalent, compatible with standard lids)
/// Higher pitch = coarser threads (fewer turns to open/close, faster assembly)
/// Lower pitch = finer threads (more turns, smoother operation)
/// ONLY USED if Part_To_Build = "Threaded Jar"
thread_pitch = 2.0;

// ==============================================================================
// SECTION 6: INTERNAL SYSTEM REQUIRES - DO NOT MODIFY
// ==============================================================================
// These includes load the core engine and render factories.
// Order matters! Dependencies must be loaded before dependent modules.

/// MasterEngine.scad: Core parameter getters and FDM safety validators
/// Contains: m_bw(), m_bl(), m_bh(), m_safe_wall(), m_safe_floor(), etc.
include <MasterEngine.scad>

/// MasterManifest.scad: Build type dispatcher
/// Contains: compile_manifest() which determines what parts to render based on Part_To_Build
include <MasterManifest.scad>

// ============================================================================
// SECTION 7: FACTORY IMPORTS
// ============================================================================
// include (not use) so factory module definitions are available in this scope.
// None of these files have top-level executable geometry, so include is safe.

/// RenderTray.scad: Factory for simple tray geometries
include <RenderTray.scad>

/// RenderPeg.scad: Factory for stacking pegs/connectors
include <RenderPeg.scad>

/// RenderJar.scad: Factory for cylindrical jar bodies with optional threading
include <RenderJar.scad>

/// RenderLid.scad: Factory for various lid types (screw, hinged, sliding)
include <RenderLid.scad>

/// RenderGrid.scad: Factory for internal divider grids
include <RenderGrid.scad>

/// RenderBox.scad: Factory for rectangular boxes and flip-lid boxes
include <RenderBox.scad>

/// RenderPlaque.scad: Factory for labeled specification plaques
include <RenderPlaque.scad>

// ==============================================================================
// SECTION 8: BUILD CONFIGURATION - PACKAGE UI PARAMETERS
// ==============================================================================
// This array contains all the user-facing parameters above in a machine-readable
// format that the engine can process. It's like the "payload" sent to a factory.
//
// FORMAT: [["KEY_NAME", value], ["KEY_NAME", value], ...]
// The engine uses get_val(key, payload, fallback) to extract values safely.
//
// WHY THIS STRUCTURE?
//   - Single data source of truth (one ui_payload array)
//   - Easy to pass to functions without parameter explosion
//   - Safe: if key is missing, functions return sensible defaults
//   - Extensible: add new parameters without changing function signatures

ui_payload = [
  ["WIDTH", part_width],
  ["LENGTH", part_length],
  ["HEIGHT", part_height],
  ["PATTERN", mesh_pattern],
  ["NOZZLE_DIAMETER", Nozzle_Diameter],
  ["WALL_LOOPS", Wall_Loops],
  ["LAYER_HEIGHT", Layer_Height],
  ["FILAMENT_TYPE", Filament_Type],
  ["GRID_LAYOUT", grid_layout],
  ["GRID_HAS_BASE", grid_has_base],
  ["GRID_TYPE", grid_type],
  ["THICK_FLOOR", floor_thickness],
  ["THICK_LID", lid_thickness],
  ["THICK_WALL", wall_thickness],
  ["THICK_DIVIDER", divider_thickness],
  ["THREAD_PITCH", thread_pitch],
];

// ==============================================================================
// SECTION 9: FACTORY DISPATCHER - MAIN EXECUTION
// ==============================================================================

/// build_part(name, data)
/// MAIN ORCHESTRATOR: Converts build intent into rendered geometry.
///
/// LOGIC:
///   1. compile_manifest(name, data) examines Part_To_Build and returns a list of
///      required sub-parts (e.g., "Box" → ["TRAY", ...])
///   2. Loop through each part in the manifest
///   3. Dispatch each part to its corresponding factory function
///      - factory_render_tray() for tray bodies
///      - factory_render_jar() for cylindrical jars
///      - factory_render_lid() for lid geometries
///      - factory_render_grid() for internal dividers
///   4. All parts union together into the final printable shape
///
/// The beauty of this design: To support a new part type, just:
///   - Add a new case in the if/else chain
///   - Define a new factory function in the corresponding Render*.scad file
///   - Add the part to compile_manifest() in MasterManifest.scad
///
module build_part(name, data) {
  // Compile the manifest: determines what parts are needed for this design
  manifest = compile_manifest(name, data);

  // Status message (appears in OpenSCAD console)
  echo("=== STARTING FACTORY PIPELINE ===");
  echo(str("Building: ", name));
  echo(str("Component count: ", len(manifest)));

  // Loop through each component in the manifest
  for (i = [0:len(manifest) - 1]) {
    item = manifest[i];

    // Extract component information
    type = item[0];           // Part type: "TRAY", "JAR", "LID", "GRID", etc.
    data_payload = item[1];   // Configuration data for this component
    options = item[2];        // Specific options for this component type
    physics = item[3];        // Pre-calculated safety values (wall, floor thickness, etc.)

    // Dispatch to appropriate factory based on type
    if (type == "TRAY") {
      echo(str("  Rendering: TRAY"));
      factory_render_tray(data_payload, options, physics);
    }
    else if (type == "BOX") {
      echo(str("  Rendering: BOX"));
      factory_render_box(data_payload, options, physics);
    }
    else if (type == "FLIP_BOX") {
      echo(str("  Rendering: FLIP_BOX"));
      factory_render_flip_box(data_payload, options, physics);
    }
    else if (type == "DOUBLE_FLIP_BOX") {
      echo(str("  Rendering: DOUBLE_FLIP_BOX"));
      factory_render_double_flip_box(data_payload, options, physics);
    }
    else if (type == "JAR") {
      echo(str("  Rendering: JAR"));
      factory_render_jar(data_payload, options, physics);
    }
    else if (type == "LID") {
      echo(str("  Rendering: LID"));
      factory_render_lid(data_payload, options, physics);
    }
    else if (type == "GRID") {
      echo(str("  Rendering: GRID"));
      factory_render_grid(data_payload, options, physics);
    }
    else if (type == "PLAQUE") {
      echo(str("  Rendering: PLAQUE"));
      factory_render_plaque(data_payload, options, physics);
    }
    else {
      echo(str("  WARNING: Unknown component type: ", type));
    }
  }

  echo("=== FACTORY PIPELINE COMPLETE ===");
  echo(str("Render time: Check OpenSCAD status bar for total computation time"));
}

// ==============================================================================
// SECTION 10: MAIN EXECUTION - EXECUTE THE BUILD
// ==============================================================================
// This is the actual line that triggers rendering when the script runs.
// Customizer calls this automatically when you change parameters.

build_part(Part_To_Build, ui_payload);
