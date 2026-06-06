// ==============================================================================
// FILE: MasterBuilder.scad
// ARCHITECTURE: Layer 4 (User Interface & Main Entry Point)
// PURPOSE: Customizer-friendly UI + build dispatcher for MasterTray system
// ==============================================================================
/* [Printer / Slicer Setting] */
Nozzle_Diameter    = 0.4;  // [0.2, 0.4, 0.6, 0.8]
Wall_Loops         = 2;    // [1 : 1 : 10]
Layer_Height       = 0.28; // [0.12, 0.16, 0.20, 0.24, 0.28]
// Mesh hole corner rounding as a fraction of hole diameter (0.05=near-sharp, 0.45=near-circle).
// Raise to reduce print-head deceleration at hole corners; lower for crisper square shapes.
// Only affects square/slotted holes larger than ~2.1mm — below that the Arachne floor
// (one extrusion width) always wins and this knob has no effect.
Corner_Round_Ratio = 0.20; // [0.05:0.05:0.45]

// 1.05 = Bambu Studio default extrusion width (105% of nozzle diameter)
// e.g. 0.4mm nozzle → 0.42mm actual line width → slider snaps in 0.42mm steps
//STEP_X = Nozzle_Diameter * 1.05;
//STEP_Y = STEP_X;
//STEP_Z = Layer_Height;

/* [Build Selection] */
Part_To_Build = "Jar with Lid"; // ["Box", "Standalone Box", "Flip Box", "Double Flip Box", "1-Day AM/PM Box", "1-Day 2-Compartment (Single Lid)", "7-Day Pill Box", "14-Day AM/PM Box", "Pillbox Set (Double Lid)", "Pillbox Set (Single Lid)", "Pillbox Full Set", "Lid", "Simple Tray", "Nesting Tray (Short)", "Modular Peg Tray (Long)", "Standalone Box Grid", "Standalone Jar Grid", "Open Jar", "Threaded Jar", "Jar with Lid", "S4 Jar", "Spool Jar", "S4 Wedge", "S4 Set", "Plaque", "Grid Test"]
jar_shape = "Circle"; // ["Circle", "Quad", "Hexa", "Octa", "Dodeca"]


/* [Dimensions: W x L x H] */
part_width = 30; // [10 : 0.42 : 300]
part_length = 40; // [10 : 0.42 : 300]
part_height = 20; // [5 : 0.28 : 300]
dimension_mode = "Total"; // Total", "Usable"]


/* [Mesh Aesthetics] */
mesh_pattern = "Teardrop"; // ["Honeycomb", "Teardrop", "Slotted", "Circle", "Square", "Diamond", "None"]
mesh_hole_size = 0.0; // [0.0 : 0.1 : 5.0]
// Minimum gap between hole edges (mm). Default 0.8 = 2 wall loops × 0.4mm nozzle.
// Raise to thicken struts; lower for more open mesh. Physics floor always applies.
// If you change Nozzle_Diameter, update this accordingly (Wall_Loops × Nozzle_Diameter).
mesh_hole_spacing = 0.8; // [0.1 : 0.1 : 5.0]
strut_wall_perc = 100; // [0 : 5 : 100]
strut_floor_perc = 100; // [0 : 5 : 100]
strut_lid_perc = 100; // [0 : 5 : 100]

/* [Lid Options] */
lid_glide_direction = "H"; // ["H", "V"]
lid_glide_snap = "Ball"; // ["Ball", "Tab"]

/* [Wall Modifications] */
modify_wall = "None"; // ["None", "Dropped", "50%", "25%"]
target_wall = "All Walls"; // ["All Walls", "Front", "Back", "Left", "Right"]

/* [Grid System] */
grid_type = "Built-in"; // ["Built-in", "Drop-in", "None"]
grid_layout = "7x5 S2/2/2/3/150% S5/1/1/2/80 R3 C15%";
grid_has_base = false;

/* [Plaque / Labels] */
plaque_style = "None"; // ["None", "Embedded", "Standalone"]
plaque_text = "";
plaque_text_size = 6; // [4:1:20]

/* [Core Engineering (R&D Exposed)] */
floor_thickness = 2.0;
lid_thickness = 2.0;   
wall_thickness = 2.4;  
divider_thickness = 1.2; 
min_solid_edge_for_lid = 10;
peg_thickness_multiplier = 2.0; 
platter_gap = 15; 
thread_pitch = 2.0; 
/* [High-Peg Mod] */
stackable_peg_height = 80; // [20 : 10 : 200]

/* [Advanced - Material & Tolerances] */
Filament_Type = "PETG"; // ["PLA", "PETG", "TPU", "ABS"]
Mechanical_Fit = "Standard"; // ["Tighter", "Tight", "Standard", "Loose", "Looser"]

/* [Advanced - Geometry Overrides] */
// 0 = auto-computed from printer settings. Non-zero = explicit override.
corner_radius       = 0.0; // [0 : 0.1 : 10.0]
chamfer_size        = 0.0; // [0 : 0.1 : 3.0]
peg_socket_diameter = 8.0; // [4 : 0.5 : 16.0]
nesting_ledge_depth = 2.0; // [1 : 0.5 : 8.0]
peg_protrusion      = 0.0; // [0 : 0.5 : 20.0] — builtin peg height above tray, 0=auto

/* [Advanced - Debug] */
// Human-readable report to the console (View → Console after F5).
debug_report = false;
// Pipe-delimited payload for Perl + Template Toolkit report generation.
debug_payload = false;

/* [Advanced - Boolean Epsilon] */
// How far difference() cutters extend past the face they pierce (default 0.1mm).
// Prevents Z-fighting in F5 preview and non-manifold edges on export.
// Raise toward 0.2–0.3 if you see flickering cut faces. See LESSONS.md §EPS.
bool_overlap_eps = 0.1; // [0.01 : 0.01 : 0.5]

include <MasterManifest.scad>
include <MasterDebug.scad>

include <RenderTray.scad>
include <RenderPeg.scad>
include <RenderJar.scad>
include <RenderLid.scad>
include <RenderGrid.scad>
include <RenderBox.scad>
include <RenderPlaque.scad>

// Override MasterEngine defaults with Customizer values (must follow all includes).
EPS  = bool_overlap_eps;
EPS2 = EPS * 2;

// --- AUTO-MATH ENGINE ---
raw_w = (dimension_mode == "Usable") ? part_width + (wall_thickness * 2) : part_width;
raw_l = (dimension_mode == "Usable") ? part_length + (wall_thickness * 2) : part_length;
raw_h = (dimension_mode == "Usable") ? part_height + floor_thickness + lid_thickness : part_height;

ui_payload = [
    [BUILDER_VERSION,    "v4.26"], 
    ["FILAMENT_TYPE",    Filament_Type], 
    ["FIT_PROFILE",      Mechanical_Fit],
    [DIMENSION_MODE,     dimension_mode], 
    [WIDTH,              raw_w], 
    [LENGTH,             raw_l], 
    [HEIGHT,             raw_h],
    [PEG_HEIGHT,         stackable_peg_height], 
    [LAYER_HEIGHT,       Layer_Height], 
    [WALL_LOOPS,         Wall_Loops], 
    [NOZZLE_DIAMETER,    Nozzle_Diameter],
    [PATTERN,            mesh_pattern], 
    [HOLE_WALL,          mesh_hole_size],
    [HOLE_FLOOR,         mesh_hole_size],
    [HOLE_LID,           mesh_hole_size],
    [HOLE_SPACING,       mesh_hole_spacing],
    [STRUT_WALL,         strut_wall_perc], 
    [STRUT_FLOOR,        strut_floor_perc], 
    [STRUT_LID,          strut_lid_perc],
    [WALL_MODIFY,        modify_wall], 
    [WALL_TARGET,        target_wall], 
    [GRID_LAYOUT,        grid_layout], 
    [GRID_TYPE,          grid_type], 
    [GRID_HAS_BASE,      grid_has_base], 
    [HAS_BUILTIN_GRID,   (grid_type == "Built-in")],
    [PLAQUE_STYLE,       plaque_style], 
    [PLAQUE_TEXT,        plaque_text], 
    [PLAQUE_TEXT_SIZE,   plaque_text_size],
    [THICK_FLOOR,        floor_thickness], 
    [THICK_LID,          lid_thickness], 
    [THICK_WALL,         wall_thickness], 
    [THICK_DIVIDER,      divider_thickness],
    [LID_MIN_SOLID,      min_solid_edge_for_lid], 
    [THICK_PEG_MULT,     peg_thickness_multiplier], 
    [PLATTER_GAP,        platter_gap], 
    [THREAD_PITCH,       thread_pitch],
    [JAR_SHAPE,          jar_shape],
    [GLIDE_DIR,          lid_glide_direction],
    [GLIDE_SNAP,         lid_glide_snap],
    [CHAMFER_SIZE,       chamfer_size],
    [CORNER_RADIUS,      corner_radius],
    [PEG_SOCKET_D,       peg_socket_diameter],
    [LEDGE_DEPTH,        nesting_ledge_depth],
    [PEG_PROTRUSION,     peg_protrusion]
];

// --- FACTORY DISPATCHER ---
module build_part(name, data) {
    manifest = compile_manifest(name, data);
    echo(str("Building: ", name, " (", len(manifest), " components)"));
    for (i = [0 : len(manifest) - 1]) {
        item    = manifest[i];
        type    = item[0];
        payload = item[1];
        options = item[2];
        physics = item[3];
        pos     = get_xy(manifest, i);
        translate([pos[0], pos[1], 0]) {
            if      (type == "TRAY")             { factory_render_tray(payload, options, physics); }
            else if (type == "BOX")              { factory_render_box(payload, options, physics); }
            else if (type == "FLIP_BOX")         { factory_render_flip_box(payload, options, physics); }
            else if (type == "DOUBLE_FLIP_BOX")  { factory_render_double_flip_box(payload, options, physics); }
            else if (type == "JAR")              { factory_render_jar(payload, options, physics); }
            else if (type == "LID")              { factory_render_lid(payload, options, physics); }
            else if (type == "GRID")             { factory_render_grid(payload, options, physics); }
            else if (type == "PEG")              { factory_render_peg(payload, options, physics); }
            else if (type == "PLAQUE")           { factory_render_plaque(payload, options, physics); }
            else { echo(str("WARNING: Unknown component type: ", type)); }
        }
    }
}

// --- FINAL EXECUTION ---
if (debug_report)  dump_build_options(Part_To_Build,  ui_payload);
if (debug_payload) dump_build_payload(Part_To_Build, ui_payload);
build_part(Part_To_Build, ui_payload);