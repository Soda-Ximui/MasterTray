// ==============================================================================
// FILE: RenderPlaque.scad
// ARCHITECTURE: Layer 2.1 (Domain Module)
// ==============================================================================

module render_plaque(data) { 
    txt = get_val(PLAQUE_TEXT, data, ""); txt_size = get_val(PLAQUE_TEXT_SIZE, data, 8);
    p_w = get_val(WIDTH, data, get_text_plaque_width(txt, txt_size)); 
    difference() { 
        cuboid([p_w, 20, 1.0], rounding=1.5, edges="Z", anchor=BOTTOM); 
        up(0.4) render_embossed_text(txt, txt_size, 1.0);
    } 
}