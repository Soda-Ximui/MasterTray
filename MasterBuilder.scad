// ==============================================================================
// FILE: MasterBuilder.scad [v4.26]
// ARCHITECTURE: Layer 3 (The UI & Controller)
// ==============================================================================

/* [Build Selection] */
Part_To_Build = "1-Day 2-Compartment (Single Lid)"; // ["Box", "Standalone Box", "Flip Box", "1-Day AM/PM Box", "1-Day 2-Compartment (Single Lid)", "7-Day Pill Box", "14-Day AM/PM Box", "Lid", "Simple Tray", "Nesting Tray (Short)", "Modular Peg Tray (Long)", "Standalone Box Grid", "Standalone Jar Grid", "Open Jar", "Threaded Jar", "Jar with Lid", "S4 Center Jar", "S4 Wedge Box", "S4 Set", "Plaque"]

/* [Total Outer Dimensions] */
dimension_mode = "Total"; // ["Total", "Usable"]
part_width = 30; // [10 : 1 : 300]
part_length = 40; // [10 : 1 : 300]
part_height = 20; // [5 : 1 : 300]

/* [High-Peg Mod] */
stackable_peg_height = 80; // [20 : 10 : 200]

/* [Printer / Slicer Setting] */
Layer_Height = 0.28; // [0.12, 0.16, 0.20, 0.24, 0.28]
Wall_Loops = 2; // [1 : 1 : 10]
Nozzle_Diameter = 0.4; // [0.2, 0.4, 0.6, 0.8]

/* [Advanced - Material & Tolerances] */
Filament_Type = "PETG"; // ["PLA", "PETG", "TPU", "ABS"]
Mechanical_Fit = "Standard"; // ["Tighter", "Tight", "Standard", "Loose", "Looser"]

/* [Mesh Aesthetics] */
mesh_pattern = "Teardrop"; // ["Honeycomb", "Teardrop", "Slotted", "Circle", "Square", "Diamond", "None"]
mesh_hole_size = 0.0; // [0.0 : 0.1 : 5.0]
strut_wall_perc = 100; // [0 : 5 : 100]
strut_floor_perc = 100; // [0 : 5 : 100]
strut_lid_perc = 100; // [0 : 5 : 100]

/* [Wall Modifications] */
modify_wall = "None"; // ["None", "Dropped", "50%", "25%"]
target_wall = "All Walls"; // ["All Walls", "Front", "Back", "Left", "Right"]

/* [Grid System] */
grid_type = "Built-in"; // ["Built-in", "Drop-in", "None"]
grid_layout = "7x2"; 
grid_has_base = true;

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

include <MasterManifest.scad>

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
    [THREAD_PITCH,       thread_pitch]
];

// --- FINAL EXECUTION ---
final_build_queue = compile_manifest(Part_To_Build, ui_payload);
build_platter(final_build_queue);