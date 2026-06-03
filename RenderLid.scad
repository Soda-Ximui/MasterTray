// ==============================================================================
// FILE: RenderGrid.scad [v3.2]
// ARCHITECTURE: Layer 2.1 (Domain Module)
// ==============================================================================

include <BOSL2/std.scad>
include <GridLayout.scad>
include <RenderRib.scad> 

module render_internal_grid(data) {
    debug_grid_parser(data);
    
    if (get_val(HAS_BUILTIN_GRID, data, false)) {
        type = get_val(TYPE, data, BOX);
        cfg = get_grid_config(data);
        rays = cfg[1][0]; 
        
        if (type == JAR) {
            if (rays > 0) { render_jar_grid_core(data, true); } 
            else { render_box_grid_core(data, true); }
        } else {
            render_box_grid_core(data, true);
        }
        
        // Builtin grids are already shifted Z=sf by the parent BOX module
        render_franken_ribs(data);
    }
}

module render_box_grid(data) {
    render_box_grid_core(data, false);
    // [v3.2] Properly shift Drop-in overlay to sit on the base, not float at Z=sf
    cfg = get_grid_config(data);
    up(cfg[4]) render_franken_ribs(data); 
}

module render_jar_grid(data) {
    render_jar_grid_core(data, false);
    // [v3.2] Properly shift Drop-in overlay
    cfg = get_grid_config(data);
    up(cfg[4]) render_franken_ribs(data); 
}

// ... [Keep your existing render_cartesian_walls, render_box_grid_core, and render_jar_grid_core here] ...