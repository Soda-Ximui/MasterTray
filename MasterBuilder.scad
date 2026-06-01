// ==============================================================================
// FILE: MasterBuilder.scad [v4.10]
// ARCHITECTURE: Layer 3 (The UI & Controller)
// DEPENDENCIES: MasterEnum v4.5, MasterUtility v4.8, MasterRender v4.9.1, MasterEngine v4.10
// ==============================================================================

/* [Build Selection] */
Part_To_Build = "14-Day AM/PM Box"; // ["Box", "Standalone Box", "Flip Box", "7-Day Pill Box", "14-Day AM/PM Box", "Lid", "Simple Tray", "Nesting Tray (Short)", "Modular Peg Tray (Long)", "Standalone Box Grid", "Standalone Jar Grid", "Open Jar", "Threaded Jar", "Jar with Lid", "S4 Center Jar", "S4 Wedge Box", "S4 Set", "Plaque"]

/* [Dimensions] */
dimension_mode = "Total"; // ["Total", "Usable"]
part_width = 30;  // [10 : 1 : 250]
part_length = 40; // [10 : 1 : 250]
part_height = 30; // [5 : 1 : 250]

/* [High-Peg Mod] */
stackable_peg_height = 80; // [20 : 10 : 200]

/* [Printer / Slicer Setting] */
Layer_Height = "Standard (0.20mm)"; 
Wall_Loops = "Standard (3 loops)"; 
Nozzle_Diameter = 0.4; 

/* [Mesh Aesthetics] */
mesh_pattern = "Teardrop"; // ["Honeycomb", "Teardrop", "Slotted", "Circle", "Square", "Diamond", "None"]
mesh_hole_size = 0.0; // [0.0 : 0.1 : 5.0]
strut_wall_perc = 100;  // [0 : 5 : 100]
strut_floor_perc = 100; // [0 : 5 : 100]
strut_lid_perc = 100;   // [0 : 5 : 100]

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
snap_tolerance_gap = 0.1; 
clip_tolerance = 0.1; 
platter_gap = 15; 
thread_pitch = 2.0; 

include <MasterRender.scad>

actual_w = (dimension_mode == "Usable") ? part_width + (wall_thickness * 2) : part_width;
actual_l = (dimension_mode == "Usable") ? part_length + (wall_thickness * 2) : part_length;
actual_h = (dimension_mode == "Usable") ? part_height + floor_thickness + lid_thickness : part_height;

ui_payload = [
    [BUILDER_VERSION,    "v4.10"], // [V4.10] Modular refactoring: MasterConstants, MasterGridParser, MasterValidation, MasterMeshPatterns
    [DIMENSION_MODE,     dimension_mode], 
    [WIDTH,              actual_w], 
    [LENGTH,             actual_l], 
    [HEIGHT,             actual_h],
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
    [TOL_SNAP_GAP,       snap_tolerance_gap], 
    [TOL_CLIP,           clip_tolerance],
    [PLATTER_GAP,        platter_gap], 
    [THREAD_PITCH,       thread_pitch]
];

function make_assembly(intents, global_payload, idx=0) = (idx >= len(intents)) ? [] : concat(get_raw_queue(intents[idx], global_payload), make_assembly(intents, global_payload, idx + 1));

function get_raw_queue(intent, global_payload) =
    (intent == "Box") ? [ make_part(TRAY_STACK_NEST, global_payload), make_part(LID, global_payload) ] :
    (intent == "Standalone Box") ? [ make_part(BOX, concat([[WALL_MODIFY, "Dropped"], [WALL_TARGET, "Front"], [NEEDS_GROOVE, true]], global_payload)), make_part(LID_GLIDE, global_payload) ] :
    (intent == "Flip Box") ? [ make_part(FLIP_BOX, global_payload), make_part(FLIP_LID, global_payload) ] :
    (intent == "7-Day Pill Box") ? concat([ make_part(FLIP_BOX, concat([[WIDTH, actual_w * 7], [GRID_LAYOUT, "7x1"]], global_payload)) ], [ for (i=[0:6]) make_part(FLIP_LID, concat([[WIDTH, actual_w - 0.6], [PLAQUE_TEXT, ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"][i]]], global_payload)) ]) :
    (intent == "14-Day AM/PM Box") ? concat([ make_part(DOUBLE_FLIP_BOX, concat([[WIDTH, actual_w * 7], [LENGTH, actual_l * 2 + 10], [GRID_LAYOUT, "7x2"]], global_payload)) ], [ for (i=[0:6]) make_part(FLIP_LID, concat([[WIDTH, actual_w - 0.6], [LENGTH, actual_l], [PLAQUE_TEXT, str(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"][i], " AM")]], global_payload)) ], [ for (i=[0:6]) make_part(FLIP_LID, concat([[WIDTH, actual_w - 0.6], [LENGTH, actual_l], [PLAQUE_TEXT, str(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"][i], " PM")]], global_payload)) ]) :
    (intent == "Nesting Tray (Short)") ? [ make_part(TRAY_STACK_NEST, global_payload) ] : 
    (intent == "Modular Peg Tray (Long)") ? [ make_part(TRAY_STACK_PEG, global_payload), make_part(PEG, global_payload), make_part(PEG, global_payload), make_part(PEG, global_payload), make_part(PEG, global_payload) ] :
    (intent == "Standalone Box Grid") ? [ make_part(BOX_GRID, global_payload) ] :
    (intent == "Standalone Jar Grid") ? [ make_part(JAR_GRID, global_payload) ] :
    (intent == "Lid") ? [ make_part(LID, global_payload) ] : 
    (intent == "Simple Tray") ? [ make_part(TRAY_SIMPLE, global_payload) ] : 
    (intent == "Plaque") ? [ make_part(PLAQUE, global_payload) ] :
    (intent == "Open Jar") ? [ make_part(JAR, concat([[WIDTH, actual_l], [HAS_THREADS, false]], global_payload)), make_part(JAR, concat([[WIDTH, actual_w], [HAS_THREADS, false]], global_payload)) ] :
    (intent == "Threaded Jar") ? [ make_part(JAR, concat([[HAS_THREADS, true]], global_payload)) ] :
    (intent == "Jar with Lid") ? [ make_part(JAR, concat([[HAS_THREADS, true]], global_payload)), make_part(JAR_LID, global_payload) ] :
    (intent == "S4 Center Jar") ? [ make_part(JAR, concat([[HAS_THREADS, true]], global_payload)), make_part(JAR_LID, global_payload) ] :
    (intent == "S4 Wedge Box") ? [ make_part(BOX, concat([[HEIGHT, 90]], global_payload)), make_part(LID, global_payload) ] :
    (intent == "S4 Set") ? make_assembly(["S4 Center Jar", "S4 Wedge Box"], global_payload) : [ make_part(BOX, global_payload) ];

function auto_spawn_grids(raw_queue, global_payload) =
    let( g_str = get_val(GRID_LAYOUT, global_payload, ""), is_drop_in = get_val(GRID_TYPE, global_payload, "Built-in") == "Drop-in", tokens = str_split(g_str, " "), has_cart = len([for (tok=tokens) if (len(search("x", tok))>0 || len(search("X", tok))>0) tok]) > 0, has_rad = len([for (tok=tokens) if (tok[0]=="R" || tok[0]=="r") tok]) > 0 )
    [ for (part = raw_queue) let(t = get_val(TYPE, part, BOX)) for (out = (((t == BOX || t == TRAY_SIMPLE || t == TRAY_STACK_NEST || t == TRAY_STACK_PEG || t == FLIP_BOX || t == DOUBLE_FLIP_BOX) && has_cart && is_drop_in) ? [part, make_part(BOX_GRID, global_payload)] : (t == JAR && has_rad && is_drop_in) ? [part, make_part(JAR_GRID, global_payload)] : [part]) ) out ];

// [V4.9.1] Unconditionally append a single SPEC_TAG to the end of the final build queue array
function compile_manifest(intent, global_payload) = 
    let(raw_q = get_raw_queue(intent, global_payload), grid_q = auto_spawn_grids(raw_q, global_payload)) 
    concat([ for (part = grid_q) process_part(part) ], [ process_part(make_part(SPEC_TAG, global_payload)) ]);

final_build_queue = compile_manifest(Part_To_Build, ui_payload);
build_platter(final_build_queue);