// ==============================================================================
// FILE: MasterUtility.scad [v4.0]
// ARCHITECTURE: Layer 1.5 (Utilities & Output Pipelines)
// ==============================================================================

include <MasterChecks.scad>
include <MasterText.scad>

module generate_preflight_report(data) {
    type = get_val(TYPE, data, BOX);
    echo(str("[FACTORY_REPORT] | --- Profiling Part: ", type, " ---"));
    echo(str("[FACTORY_REPORT] | Builder_Version: ", get_val(BUILDER_VERSION, data, "Unknown")));
    echo(str("[FACTORY_REPORT] | Dimension_Mode: ", get_val(DIMENSION_MODE, data, "Total")));
    echo(str("[FACTORY_REPORT] | Nozzle_Diameter: ", m_noz(data)));
    echo(str("[FACTORY_REPORT] | Wall_Loops_Calculated: ", m_wloops(data)));
    echo(str("[FACTORY_REPORT] | Wall_Thickness_Actual: ", m_safe_wall(data)));
    echo(str("[FACTORY_REPORT] | Floor_Thickness_Actual: ", m_safe_floor(data)));
    echo(str("[FACTORY_REPORT] | Dimensions_Total_Payload: [", m_bw(data), ", ", m_bl(data), ", ", m_bh(data), "]"));
    echo(str("[FACTORY_REPORT] | Clearance_Snap_Gap: ", get_val(TOL_SNAP_GAP, data, 0.1)));
    echo(str("[FACTORY_REPORT] | Clearance_Clip: ", get_val(TOL_CLIP, data, 0.1)));
}