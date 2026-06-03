// ==============================================================================
// FILE: MasterDispatcher.scad [v3.0]
// ARCHITECTURE: Layer 2.5 (The Router & Platter Arranger)
// PURPOSE: Pure routing module. Array compilation is strictly handled by MasterManifest.
// ==============================================================================

include <MasterRender.scad>

module build_part(data) {
    generate_preflight_report(data);
    type = get_val(TYPE, data, BOX);
    
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
    else if (type == BOX_GRID || type == JAR_GRID) {
        // Apply contextual grid clipping (Spoofs TYPE to JAR for circular intersections)
        is_jar_grid = get_val("IS_JAR_GRID", data, false);
        eff_data = is_jar_grid ? concat([[TYPE, JAR]], data) : data;
        
        if (type == JAR_GRID) render_jar_grid(eff_data);
        else render_box_grid(eff_data);
    }
}

module build_platter(manifest) { 
    for (i = [0 : len(manifest) - 1]) { 
        pos = get_xy(manifest, i);
        translate([pos[0], pos[1], 0]) build_part(manifest[i]);
    } 
}