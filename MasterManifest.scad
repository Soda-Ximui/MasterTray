// ==============================================================================
// FILE: MasterManifest.scad [v1.8]
// ARCHITECTURE: Layer 2.8 (The Intent Compiler & Manifest Generator)
// PURPOSE: Routes user intent into a sequence of renderable parts
// ==============================================================================

include <MasterDispatcher.scad>
include <MasterTolerance.scad> 
include <GridLayout.scad>

function make_assembly(intents, p, idx=0) = 
    (idx >= len(intents)) ? [] : concat(get_raw_queue(intents[idx], p), make_assembly(intents, p, idx + 1));

function get_raw_queue(intent, p) =
    let(
        w = get_val(WIDTH, p, 50), l = get_val(LENGTH, p, 50), noz = get_val(NOZZLE_DIAMETER, p, 0.4),
        
        c_clip_tol = breathing_room(COMP_CCLIP, p),
        spine_gap = breathing_room(COMP_SPINE, p),
        
        clip_outer = 4.0 + (c_clip_tol * 2) + (noz * 8),
        hinge_off = (clip_outer / 2) + spine_gap, 
        
        cols = (intent == "7-Day Pill Box" || intent == "14-Day AM/PM Box") ? 7 : 
               (intent == "1-Day 2-Compartment (Single Lid)") ? 2 : 1,
        
        cw = w / cols, dbl_l = (l * 2) + (hinge_off * 2),
        lid_l_std = l, lid_l_dbl = l - hinge_off
    )
    
    // --- THE MANIFEST ROUTER ---
    (intent == "Box") ? [ make_part(TRAY_STACK_NEST, p), make_part(LID, p) ] :
    (intent == "Standalone Box") ? [ make_part(BOX, concat([[WALL_MODIFY, "Dropped"], [WALL_TARGET, "Front"], [NEEDS_GROOVE, true]], p)), make_part(LID_GLIDE, p) ] :
    (intent == "Flip Box") ? [ make_part(FLIP_BOX, p), make_part(FLIP_LID, concat([[WIDTH, w - 0.6], [LENGTH, lid_l_std]], p)) ] :
    
    // [v1.8] Pillboxes strictly enforce built-in grid states to prevent UI slider bleeding
    (intent == "1-Day AM/PM Box") ? concat([ make_part(DOUBLE_FLIP_BOX, concat([[GRID_LAYOUT, "1x2"], [HAS_BUILTIN_GRID, true], [GRID_TYPE, "Built-in"], [LENGTH, dbl_l]], p)) ], [ make_part(FLIP_LID, concat([[WIDTH, cw - 0.6], [LENGTH, lid_l_dbl], [PLAQUE_TEXT, "AM"]], p)) ], [ make_part(FLIP_LID, concat([[WIDTH, cw - 0.6], [LENGTH, lid_l_dbl], [PLAQUE_TEXT, "PM"]], p)) ]) :
    (intent == "1-Day 2-Compartment (Single Lid)") ? [ make_part(FLIP_BOX, concat([[GRID_LAYOUT, "2x1"], [HAS_BUILTIN_GRID, true], [GRID_TYPE, "Built-in"], [SKIP_PILLARS, true]], p)), make_part(FLIP_LID, concat([[WIDTH, w - 0.6], [LENGTH, lid_l_std], [PLAQUE_TEXT, "AM / PM"]], p)) ] :
    (intent == "7-Day Pill Box") ? concat([ make_part(FLIP_BOX, concat([[GRID_LAYOUT, "7x1"], [HAS_BUILTIN_GRID, true], [GRID_TYPE, "Built-in"]], p)) ], [ for (i=[0:6]) make_part(FLIP_LID, concat([[WIDTH, cw - 0.6], [LENGTH, lid_l_std], [PLAQUE_TEXT, ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"][i]]], p)) ]) :
    (intent == "14-Day AM/PM Box") ? concat([ make_part(DOUBLE_FLIP_BOX, concat([[GRID_LAYOUT, "7x2"], [HAS_BUILTIN_GRID, true], [GRID_TYPE, "Built-in"], [LENGTH, dbl_l]], p)) ], [ for (i=[0:6]) make_part(FLIP_LID, concat([[WIDTH, cw - 0.6], [LENGTH, lid_l_dbl], [PLAQUE_TEXT, str(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"][i], " AM")]], p)) ], [ for (i=[0:6]) make_part(FLIP_LID, concat([[WIDTH, cw - 0.6], [LENGTH, lid_l_dbl], [PLAQUE_TEXT, str(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"][i], " PM")]], p)) ]) :
    
    // --- NEW PILLBOX SET COMPOSITES ---
    (intent == "Pillbox Set (Double Lid)") ? make_assembly(["14-Day AM/PM Box", "1-Day AM/PM Box"], p) :
    (intent == "Pillbox Set (Single Lid)") ? make_assembly(["7-Day Pill Box", "1-Day 2-Compartment (Single Lid)"], p) :
    (intent == "Pillbox Full Set") ? make_assembly(["Pillbox Set (Double Lid)", "Pillbox Set (Single Lid)"], p) :
    
    (intent == "Nesting Tray (Short)") ? [ make_part(TRAY_STACK_NEST, p) ] : 
    (intent == "Modular Peg Tray (Long)") ? [ make_part(TRAY_STACK_PEG, p), make_part(PEG, p), make_part(PEG, p), make_part(PEG, p), make_part(PEG, p) ] :
    (intent == "Standalone Box Grid") ? [ make_part(BOX_GRID, p) ] :
    (intent == "Lid") ? [ make_part(LID, p) ] : 
    (intent == "Simple Tray") ? [ make_part(TRAY_SIMPLE, p) ] : 
    (intent == "Plaque") ? [ make_part(PLAQUE, p) ] :
    
    // --- JAR DUAL-SPAWNING LOGIC ---
    (intent == "Standalone Jar Grid") ? 
        (w != l) ? [ make_part(JAR_GRID, p), make_part(JAR_GRID, concat([[WIDTH, l]], p)) ] : 
        [ make_part(JAR_GRID, p) ] :
    (intent == "Open Jar") ?
        (w != l) ? [ make_part(JAR, concat([[HAS_THREADS, false]], p)), make_part(JAR, concat([[HAS_THREADS, false], [WIDTH, l]], p)) ] :
        [ make_part(JAR, concat([[HAS_THREADS, false]], p)), make_part(JAR, concat([[HAS_THREADS, false]], p)) ] :
    (intent == "Threaded Jar") ?
        (w != l) ? [ make_part(JAR, concat([[HAS_THREADS, true]], p)), make_part(JAR, concat([[HAS_THREADS, true], [WIDTH, l]], p)) ] :
        [ make_part(JAR, concat([[HAS_THREADS, true]], p)) ] :
    (intent == "Jar with Lid") ?
        (w != l) ? [ make_part(JAR, concat([[HAS_THREADS, true]], p)), make_part(JAR_LID, p), make_part(JAR, concat([[HAS_THREADS, true], [WIDTH, l]], p)), make_part(JAR_LID, concat([[WIDTH, l]], p)) ] :
        [ make_part(JAR, concat([[HAS_THREADS, true]], p)), make_part(JAR_LID, p) ] :
    (intent == "S4 Center Jar") ? [ make_part(JAR, concat([[HAS_THREADS, true]], p)), make_part(JAR_LID, p) ] :
    (intent == "S4 Wedge Box") ? [ make_part(BOX, concat([[HEIGHT, 90]], p)), make_part(LID, p) ] :
    (intent == "S4 Set") ? make_assembly(["S4 Center Jar", "S4 Wedge Box"], p) : [ make_part(BOX, p) ];

// --- GLOBAL MANIFEST COMPILER ---
function compile_manifest(intent, global_payload) = 
    let(
        base_queue = get_raw_queue(intent, global_payload),
        
        g_str = get_val(GRID_LAYOUT, global_payload, ""),
        g_type = get_val(GRID_TYPE, global_payload, "None"),
        
        is_pillbox_intent = (intent == "1-Day AM/PM Box" || intent == "1-Day 2-Compartment (Single Lid)" || intent == "7-Day Pill Box" || intent == "14-Day AM/PM Box" || intent == "Pillbox Set (Double Lid)" || intent == "Pillbox Set (Single Lid)" || intent == "Pillbox Full Set"),
        needs_drop_in = (g_str != "" && g_type == "Drop-in" && !is_pillbox_intent),
        
        first_type = len(base_queue) > 0 ? get_val(TYPE, base_queue[0], BOX) : BOX,
        is_base_jar = (first_type == JAR || first_type == JAR_LID || first_type == JAR_GRID || first_type == PLAQUE_JAR),
        
        w = get_val(WIDTH, global_payload, 50),
        l = get_val(LENGTH, global_payload, 50),
        
        rad_req = has_radial(g_str),
        cart_req = has_cartesian(g_str),
        
        p_grid_1 = is_base_jar ? concat([["IS_JAR_GRID", true]], global_payload) : global_payload,
        p_grid_2 = is_base_jar ? concat([["IS_JAR_GRID", true], [WIDTH, l]], global_payload) : concat([[WIDTH, l]], global_payload),
        
        drop_in_1 = !needs_drop_in ? [] :
            (rad_req && cart_req) ? [make_part(BOX_GRID, p_grid_1), make_part(JAR_GRID, p_grid_1)] :
            rad_req ? [make_part(JAR_GRID, p_grid_1)] :
            cart_req ? [make_part(BOX_GRID, p_grid_1)] :
            is_base_jar ? [make_part(JAR_GRID, p_grid_1)] : [make_part(BOX_GRID, p_grid_1)],
            
        drop_in_2 = (!needs_drop_in || !is_base_jar || w == l || intent == "S4 Center Jar" || intent == "S4 Set" || intent == "Standalone Jar Grid") ? [] :
            (rad_req && cart_req) ? [make_part(BOX_GRID, p_grid_2), make_part(JAR_GRID, p_grid_2)] :
            rad_req ? [make_part(JAR_GRID, p_grid_2)] :
            cart_req ? [make_part(BOX_GRID, p_grid_2)] :
            [make_part(JAR_GRID, p_grid_2)],
            
        final_queue = concat(base_queue, drop_in_1, drop_in_2)
    )
    [ for (part = final_queue) process_part(part) ];