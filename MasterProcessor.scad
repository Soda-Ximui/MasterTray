// ==============================================================================
// FILE: MasterProcessor.scad
// ARCHITECTURE: Layer 2.1 (Data Transformation Pipeline)
// ==============================================================================

include <MasterEngine.scad>

// --- PHYSICS ENGINE ---
function get_physics_profile(data) = [
    ["SAFE_WALL", m_safe_wall(data)],
    ["SAFE_FLOOR", m_safe_floor(data)],
    ["CLEARANCE", get_val("FILAMENT_TYPE", data, "PETG") == "PETG" ? 0.2 : 0.1], 
    ["NOZZLE", m_noz(data)]
];

// --- OPTIONS ENGINE ---
function get_build_options(type, data, custom_opts=[]) = 
    let(
        default_opts = [
            ["IS_THREADED", get_val("HAS_THREADS", data, false)],
            ["IS_STACKABLE", get_val("INTENT", data, "") == "Stackable Tray"],
            ["OFFSET_XYZ", [0,0,0]] 
        ]
    )
    concat(default_opts, custom_opts);