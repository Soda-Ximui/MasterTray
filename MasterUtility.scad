// ==============================================================================
// FILE: MasterUtility.scad [v4.8]
// ARCHITECTURE: Layer 1.5 (Utilities & Output Pipelines)
// ==============================================================================

include <MasterChecks.scad>
include <MasterText.scad>
include <MasterValidation.scad>

// [V4.7: Advanced Spec Tag Migration]
// Moved from MasterRender to MasterUtility. This centralizes all metadata/reporting 
// tools in Layer 1.5, keeping Layer 2 purely for physical part geometry.
module render_spec_tag(data) {
    noz = m_noz(data);
    loops = m_wloops(data);
    lh = m_lh(data);
    ver = get_val(BUILDER_VERSION, data, "Unknown");
    
    // [V4.7: Expanded Baseplate] Increased to 120x60mm to accommodate 6 lines of text
    difference() {
        cuboid([120, 60, 0.6], rounding=1.5, edges="Z", anchor=BOTTOM);
        up(0.2) linear_extrude(1) {
            
            // --- TOP SECTION ---
            // [V4.7: Version Header] Largest font size (6.5), center aligned
            translate([0, 18, 0]) 
                text(str("Master Tray ", ver), size=6.5, font="Arial Black", halign="center", valign="center");
            
            // --- MIDDLE SECTION ---
            // [V4.7: Split-Color Alignment Trick] 
            // To color ONLY the numbers red, the string is split in half. 
            // Labels are pushed slightly left (halign="right"), numbers are pushed slightly right (halign="left").
            
            // Nozzle
            translate([-2, 6, 0]) 
                text("Nozzle ", size=4.5, font="Arial Black", halign="right", valign="center");
            color("red") translate([2, 6, 0]) 
                text(str(noz), size=4.5, font="Arial Black", halign="left", valign="center");
            
            // Wall Loops
            translate([-2, 0, 0]) 
                text("Wall Loops ", size=4.5, font="Arial Black", halign="right", valign="center");
            color("red") translate([2, 0, 0]) 
                text(str(loops), size=4.5, font="Arial Black", halign="left", valign="center");
            
            // Layer Height
            translate([-2, -6, 0]) 
                text("Layer Height ", size=4.5, font="Arial Black", halign="right", valign="center");
            color("red") translate([2, -6, 0]) 
                text(str(lh), size=4.5, font="Arial Black", halign="left", valign="center");
            
            // --- BOTTOM SECTION ---
            // [V4.7: Copyright & Licensing] Smallest font size (3), center aligned
            translate([0, -18, 0]) 
                text("For personal use only", size=3, font="Arial Black", halign="center", valign="center");
            translate([0, -23, 0]) 
                text("All rights reserved by ongchau3D@gmail.com", size=3, font="Arial Black", halign="center", valign="center");
        }
    }
}

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