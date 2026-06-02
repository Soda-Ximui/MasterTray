// ==============================================================================
// FILE: MasterManifest.scad [v1.2]
// ARCHITECTURE: Layer 2.8 (The Intent Compiler & Manifest Generator)
// ==============================================================================

include <MasterDispatcher.scad>
include <MasterTolerance.scad> 

function make_assembly(intents, p, idx=0) = 
    (idx >= len(intents)) ? [] : concat(get_raw_queue(intents[idx], p), make_assembly(intents, p, idx + 1));

function get_raw_queue(intent, p) =
    let(
        w = get_val(WIDTH, p, 50), l = get_val(LENGTH, p, 50), noz = get_val(NOZZLE_DIAMETER, p, 0.4),
        
        // Physics Engine Call using ENUMS
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
    (intent == "Box") ?
    [ make_part(TRAY_STACK_NEST, p), make_part(LID, p) ] :
    
    (intent == "Standalone Box") ?
    [ make_part(BOX, concat([[WALL_MODIFY, "Dropped"], [WALL_TARGET, "Front"], [NEEDS_GROOVE, true]], p)), make_part(LID_GLIDE, p) ] :
    
    (intent == "Flip Box") ?
    [ make_part(FLIP_BOX, p), make_part(FLIP_LID, concat([[WIDTH, w - 0.6], [LENGTH, lid_l_std]], p)) ] :
    
    (intent == "1-Day AM/PM Box") ?
    concat([ make_part(DOUBLE_FLIP_BOX, concat([[GRID_LAYOUT, "1x2"], [LENGTH, dbl_l]], p)) ], [ make_part(FLIP_LID, concat([[WIDTH, cw - 0.6], [LENGTH, lid_l_dbl], [PLAQUE_TEXT, "AM"]], p)) ], [ make_part(FLIP_LID, concat([[WIDTH, cw - 0.6], [LENGTH, lid_l_dbl], [PLAQUE_TEXT, "PM"]], p)) ]) :
    
    (intent == "1-Day 2-Compartment (Single Lid)") ?
    [ make_part(FLIP_BOX, concat([[GRID_LAYOUT, "2x1"], [SKIP_PILLARS, true]], p)), make_part(FLIP_LID, concat([[WIDTH, w - 0.6], [LENGTH, lid_l_std], [PLAQUE_TEXT, "AM / PM"]], p)) ] :
    
    (intent == "7-Day Pill Box") ?
    concat([ make_part(FLIP_BOX, concat([[GRID_LAYOUT, "7x1"]], p)) ], [ for (i=[0:6]) make_part(FLIP_LID, concat([[WIDTH, cw - 0.6], [LENGTH, lid_l_std], [PLAQUE_TEXT, ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"][i]]], p)) ]) :
    
    (intent == "14-Day AM/PM Box") ?
    concat([ make_part(DOUBLE_FLIP_BOX, concat([[GRID_LAYOUT, "7x2"], [LENGTH, dbl_l]], p)) ], [ for (i=[0:6]) make_part(FLIP_LID, concat([[WIDTH, cw - 0.6], [LENGTH, lid_l_dbl], [PLAQUE_TEXT, str(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"][i], " AM")]], p)) ], [ for (i=[0:6]) make_part(FLIP_LID, concat([[WIDTH, cw - 0.6], [LENGTH, lid_l_dbl], [PLAQUE_TEXT, str(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"][i], " PM")]], p)) ]) :
    
    (intent == "Nesting Tray (Short)") ?
    [ make_part(TRAY_STACK_NEST, p) ] : 
    
    (intent == "Modular Peg Tray (Long)") ?
    [ make_part(TRAY_STACK_PEG, p), make_part(PEG, p), make_part(PEG, p), make_part(PEG, p), make_part(PEG, p) ] :
    
    (intent == "Standalone Box Grid") ?
    [ make_part(BOX_GRID, p) ] :
    
    (intent == "Standalone Jar Grid") ?
    [ make_part(JAR_GRID, p) ] :
    
    (intent == "Lid") ?
    [ make_part(LID, p) ] : 
    
    (intent == "Simple Tray") ?
    [ make_part(TRAY_SIMPLE, p) ] : 
    
    (intent == "Plaque") ?
    [ make_part(PLAQUE, p) ] :
    
    (intent == "Open Jar") ?
    [ make_part(JAR, concat([[HAS_THREADS, false]], p)), make_part(JAR, concat([[HAS_THREADS, false]], p)) ] :
    
    (intent == "Threaded Jar") ?
    [ make_part(JAR, concat([[HAS_THREADS, true]], p)) ] :
    
    (intent == "Jar with Lid") ?
    [ make_part(JAR, concat([[HAS_THREADS, true]], p)), make_part(JAR_LID, p) ] :
    
    (intent == "S4 Center Jar") ?
    [ make_part(JAR, concat([[HAS_THREADS, true]], p)), make_part(JAR_LID, p) ] :
    
    (intent == "S4 Wedge Box") ?
    [ make_part(BOX, concat([[HEIGHT, 90]], p)), make_part(LID, p) ] :
    
    (intent == "S4 Set") ?
    make_assembly(["S4 Center Jar", "S4 Wedge Box"], p) : [ make_part(BOX, p) ];

function compile_manifest(intent, global_payload) = 
    [ for (part = get_raw_queue(intent, global_payload)) process_part(part) ];