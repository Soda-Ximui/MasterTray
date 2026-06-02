// ==============================================================================
// FILE: MasterBuilder.scad [v4.16]
// ARCHITECTURE: Layer 3 (The UI & Controller)
// DEPENDENCIES: MasterEnum v4.6, MasterUtility v4.9, MasterRender v4.12.0, MasterEngine v4.10
// ==============================================================================

/* [Build Selection] */
Part_To_Build = "1-Day AM/PM Box"; // ["Box", "Standalone Box", "Flip Box", "1-Day AM/PM Box", "1-Day 2-Compartment (Single Lid)", "7-Day Pill Box", "14-Day AM/PM Box", "Lid", "Simple Tray", "Nesting Tray (Short)", "Modular Peg Tray (Long)", "Standalone Box Grid", "Standalone Jar Grid", "Open Jar", "Threaded Jar", "Jar with Lid", "S4 Center Jar", "S4 Wedge Box", "S4 Set", "Plaque"]

/* [Dimensions] */
dimension_mode = "Total"; // ["Total", "Usable"]
part_width = 30; // [10 : 1 : 250]
part_length = 40; // [10 : 1 : 250]
part_height = 20; // [5 : 1 : 250]

/* [High-Peg Mod] */
stackable_peg_height = 80; // [20 : 10 : 200]

/* [Printer / Slicer Setting] */
Layer_Height = "Standard (0.20mm)"; 
Wall_Loops = "Standard (3 loops)";
Nozzle_Diameter = 0.4; 

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
snap_tolerance_gap = 0.1;
clip_tolerance = 0.1; 
platter_gap = 15; 
thread_pitch = 2.0; 

include <MasterRender.scad>

actual_w = (dimension_mode == "Usable") ? part_width + (wall_thickness * 2) : part_width;
actual_l = (dimension_mode == "Usable") ? part_length + (wall_thickness * 2) : part_length;
actual_h = (dimension_mode == "Usable") ? part_height + floor_thickness + lid_thickness : part_height;

// [v4.16] Added +0.5mm clearance so double lids don't grind in the center
clip_outer_d_est = 4.0 + (clip_tolerance * 2) + (Nozzle_Diameter * 4 * 2);
hinge_y_off = (clip_outer_d_est / 2) + 0.5; 
double_box_length = actual_l * 2 + (hinge_y_off * 2);

ui_payload = [
    [BUILDER_VERSION,    "v4.16"], // [v4.16] Fixed double box lid overrun & spine clearance grind
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
    (intent == "Box") ?
    [ make_part(TRAY_STACK_NEST, global_payload), make_part(LID, global_payload) ] :
    (intent == "Standalone Box") ?
    [ make_part(BOX, concat([[WALL_MODIFY, "Dropped"], [WALL_TARGET, "Front"], [NEEDS_GROOVE, true]], global_payload)), make_part(LID_GLIDE, global_payload) ] :
    (intent == "Flip Box") ?
    [ make_part(FLIP_BOX, global_payload), make_part(FLIP_LID, global_payload) ] :
    (intent == "1-Day AM/PM Box") ?
    // [v4.16] Passed (actual_l - hinge_y_off) to mathematically prevent the lid overrun
    concat([ make_part(DOUBLE_FLIP_BOX, concat([[WIDTH, actual_w], [LENGTH, double_box_length], [GRID_LAYOUT, "1x2"]], global_payload)) ], [ make_part(FLIP_LID, concat([[WIDTH, actual_w - 0.6], [LENGTH, actual_l - hinge_y_off], [PLAQUE_TEXT, "AM"]], global_payload)) ], [ make_part(FLIP_LID, concat([[WIDTH, actual_w - 0.6], [LENGTH, actual_l - hinge_y_off], [PLAQUE_TEXT, "PM"]], global_payload)) ]) :
    (intent == "1-Day 2-Compartment (Single Lid)") ?
    [ make_part(FLIP_BOX, concat([[WIDTH, actual_w * 2], [GRID_LAYOUT, "2x1"], [SKIP_PILLARS, true]], global_payload)), make_part(FLIP_LID, concat([[WIDTH, actual_w * 2 - 0.6], [PLAQUE_TEXT, "AM / PM"]], global_payload)) ] :
    (intent == "7-Day Pill Box") ?
    concat([ make_part(FLIP_BOX, concat([[WIDTH, actual_w * 7], [GRID_LAYOUT, "7x1"]], global_payload)) ], [ for (i=[0:6]) make_part(FLIP_LID, concat([[WIDTH, actual_w - 0.6], [PLAQUE_TEXT, ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"][i]]], global_payload)) ]) :
    (intent == "14-Day AM/PM Box") ?
    // [v4.16] Passed (actual_l - hinge_y_off) to mathematically prevent the lid overrun
    concat([ make_part(DOUBLE_FLIP_BOX, concat([[WIDTH, actual_w * 7], [LENGTH, double_box_length], [GRID_LAYOUT, "7x2"]], global_payload)) ], [ for (i=[0:6]) make_part(FLIP_LID, concat([[WIDTH, actual_w - 0.6], [LENGTH, actual_l - hinge_y_off], [PLAQUE_TEXT, str(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"][i], " AM")]], global_payload)) ], [ for (i=[0:6]) make_part(FLIP_LID, concat([[WIDTH, actual_w - 0.6], [LENGTH, actual_l - hinge_y_off], [PLAQUE_TEXT, str(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"][i], " PM")]], global_payload)) ]) :
    (intent == "Nesting Tray (Short)") ?
    [ make_part(TRAY_STACK_NEST, global_payload) ] : 
    (intent == "Modular Peg Tray (Long)") ?
    [ make_part(TRAY_STACK_PEG, global_payload), make_part(PEG, global_payload), make_part(PEG, global_payload), make_part(PEG, global_payload), make_part(PEG, global_payload) ] :
    (intent == "Standalone Box Grid") ?
    [ make_part(BOX_GRID, global_payload) ] :
    (intent == "Standalone Jar Grid") ?
    [ make_part(JAR_GRID, global_payload) ] :
    (intent == "Lid") ?
    [ make_part(LID, global_payload) ] : 
    (intent == "Simple Tray") ?
    [ make_part(TRAY_SIMPLE, global_payload) ] : 
    (intent == "Plaque") ?
    [ make_part(PLAQUE, global_payload) ] :
    (intent == "Open Jar") ?
    [ make_part(JAR, concat([[WIDTH, actual_l], [HAS_THREADS, false]], global_payload)), make_part(JAR, concat([[WIDTH, actual_w], [HAS_THREADS, false]], global_payload)) ] :
    (intent == "Threaded Jar") ?
    [ make_part(JAR, concat([[HAS_THREADS, true]], global_payload)) ] :
    (intent == "Jar with Lid") ?
    [ make_part(JAR, concat([[HAS_THREADS, true]], global_payload)), make_part(JAR_LID, global_payload) ] :
    (intent == "S4 Center Jar") ?
    [ make_part(JAR, concat([[HAS_THREADS, true]], global_payload)), make_part(JAR_LID, global_payload) ] :
    (intent == "S4 Wedge Box") ?
    [ make_part(BOX, concat([[HEIGHT, 90]], global_payload)), make_part(LID, global_payload) ] :
    (intent == "S4 Set") ?
    make_assembly(["S4 Center Jar", "S4 Wedge Box"], global_payload) : [ make_part(BOX, global_payload) ];

function auto_spawn_grids(raw_queue, global_payload) =
    let( g_str = get_val(GRID_LAYOUT, global_payload, ""), is_drop_in = get_val(GRID_TYPE, global_payload, "Built-in") == "Drop-in", tokens = str_split(g_str, " "), has_cart = len([for (tok=tokens) if (len(search("x", tok))>0 || len(search("X", tok))>0) tok]) > 0, has_rad = len([for (tok=tokens) if (tok[0]=="R" || tok[0]=="r") tok]) > 0 )
    [ for (part = raw_queue) let(t = get_val(TYPE, part, BOX)) for (out = (((t == BOX || t == TRAY_SIMPLE || t == TRAY_STACK_NEST || t == TRAY_STACK_PEG || t == FLIP_BOX || t == DOUBLE_FLIP_BOX) && has_cart && is_drop_in) ? [part, make_part(BOX_GRID, global_payload)] : (t == JAR && has_rad && is_drop_in) ? [part, make_part(JAR_GRID, global_payload)] : [part]) ) out ];

function compile_manifest(intent, global_payload) = 
    let(raw_q = get_raw_queue(intent, global_payload), grid_q = auto_spawn_grids(raw_q, global_payload)) 
    [ for (part = grid_q) process_part(part) ];

module build_part(data) {
    generate_preflight_report(data); type = get_val(TYPE, data, BOX);
    if (type == BOX || type == DESICCANT_BOX) render_box(data); 
    else if (type == TRAY_SIMPLE) render_tray_simple(data);
    else if (type == TRAY_STACK_NEST) render_tray_stack_nest(data); 
    else if (type == TRAY_STACK_PEG) render_tray_stack_peg(data); 
    else if (type == PEG) render_peg(data);
    else if (type == FLIP_BOX) render_flip_box(data); 
    else if (type == DOUBLE_FLIP_BOX) render_double_flip_box(data); 
    else if (type == FLIP_LID) render_flip_lid(data);
    else if (type == LID || type == DESICCANT_LID) render_lid(data); 
    else if (type == LID_GLIDE) render_lid_glide(data);
    else if (type == PLAQUE) render_plaque(data); 
    else if (type == JAR) render_jar(data); 
    else if (type == JAR_LID) render_jar_lid(data);
    else if (type == BOX_GRID) render_box_grid(data); 
    else if (type == JAR_GRID) render_jar_grid(data);
}

module build_platter(manifest) { 
    for (i = [0 : len(manifest) - 1]) { 
        pos = get_xy(manifest, i); 
        translate([pos[0], pos[1], 0]) build_part(manifest[i]);
    } 
}

final_build_queue = compile_manifest(Part_To_Build, ui_payload);
build_platter(final_build_queue);