// ==============================================================================
// FILE: MasterRender.scad [v4.12.0]
// ARCHITECTURE: Layer 2.0 (The Render Pipeline Umbrella)
// PURPOSE: Core processing functions and geometry library inclusions.
// ==============================================================================

include <MasterUtility.scad> 
include <MasterMeshPatterns.scad>
include <MasterGridParser.scad>

// --- CORE PROCESSING ---
function apply_inductions(data) = let(type = get_val(TYPE, data, BOX), ui_pat = get_val(PATTERN, data, TEARDROP)) ((type == DESICCANT_BOX || type == DESICCANT_LID) && ui_pat != NONE) ? concat([[PATTERN, SLOTTED]], data) : data;
function enforce_safety(data) = concat([ [THICK_WALL, m_safe_wall(data)], [THICK_FLOOR, m_safe_floor(data)] ], data);
function process_part(part_data) = enforce_safety(apply_inductions(part_data));

// --- SHARED GEOMETRY ---
module apply_master_bounds(w, l, h, r, c) { 
    c_r = max(0.1, min(r, (w/2) - 0.1, (l/2) - 0.1)); 
    intersection() { 
        children();
        cuboid([w,l,h*3], rounding=c_r, edges="Z", anchor=BOTTOM); 
    } 
}

// --- DOMAIN MODULES (Layer 2.1) ---
include <RenderMesh.scad>
include <RenderGrid.scad>
include <RenderTray.scad>
include <RenderBox.scad>
include <RenderLid.scad>
include <RenderJar.scad>
include <RenderPlaque.scad>