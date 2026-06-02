// ==============================================================================
// FILE: MasterUtility.scad [v4.9]
// ARCHITECTURE: Layer 1.5 (Utilities & Output Pipelines)
// ==============================================================================
// AUDIT LOG:
// [v4.9] Added Slicer Intelligence. The preflight report now dynamically calculates 
//        and echoes optimal wall order recommendations based on the part's TYPE taxonomy.
// ==============================================================================

include <MasterChecks.scad>
include <MasterText.scad>
include <MasterValidation.scad>

// --- SLICER INTELLIGENCE ENGINE ---
function get_wall_order_recommendation(type) =
    (type == BOX_GRID || type == JAR_GRID || type == TRAY_SIMPLE || type == TRAY_STACK_NEST) ? 
        "Outer -> Inner (Maximum dimensional accuracy for vertical walls)" :
    (type == FLIP_BOX || type == DOUBLE_FLIP_BOX || type == FLIP_LID) ? 
        "Inner -> Outer -> Inner (Best for diamond overhangs & snap-fits)" :
    (type == JAR || type == JAR_LID) ? 
        "Inner -> Outer (Crucial to support thread overhangs)" :
        "Inner -> Outer (Standard FDM default)";

// --- PREFLIGHT REPORTING ---
module generate_preflight_report(data) {
    type = get_val(TYPE, data, BOX);
    wall_rec = get_wall_order_recommendation(type);
    
    echo(str("[FACTORY_REPORT] | --- Profiling Part: ", type, " ---"));
    echo(str("[FACTORY_REPORT] | Builder_Version: ", get_val(BUILDER_VERSION, data, "Unknown")));
    echo(str("[FACTORY_REPORT] | Dimension_Mode: ", get_val(DIMENSION_MODE, data, "Total")));
    echo(str("[FACTORY_REPORT] | Nozzle_Diameter: ", m_noz(data)));
    echo(str("[FACTORY_REPORT] | Wall_Loops_Calculated: ", m_wloops(data)));
    echo(str("[FACTORY_REPORT] | Wall_Thickness_Actual: ", m_safe_wall(data)));
    echo(str("[FACTORY_REPORT] | Floor_Thickness_Actual: ", m_safe_floor(data)));
    
    // [v4.9] Dynamic Slicer Recommendations
    echo(str("[MANUFACTURING]  | ⚠ RECOMMENDED WALL ORDER: ", wall_rec));
}