// ==============================================================================
// FILE: RenderTray.scad
// ARCHITECTURE: Layer 3 (Factory)
// ==============================================================================
include <BOSL2/std.scad>
include <MasterEngine.scad>

module factory_render_tray(data, opts, phys) {
    w = m_bw(data); l = m_bl(data); h = m_bh(data);
    is_stackable = get_val("IS_STACKABLE", opts, false);
    
    echo(str("-> Factory [TRAY] | Dim: ", w, "x", l, "x", h, " | Stackable: ", is_stackable));
    
    difference() {
        cuboid([w, l, h], anchor=BOTTOM);
        if (is_stackable) {
            up(h) {
                translate([ w/2 - 5,  l/2 - 5, 0]) cyl(d=10.5, h=10, anchor=TOP);
                translate([-w/2 + 5,  l/2 - 5, 0]) cyl(d=10.5, h=10, anchor=TOP);
                translate([ w/2 - 5, -l/2 + 5, 0]) cyl(d=10.5, h=10, anchor=TOP);
                translate([-w/2 + 5, -l/2 + 5, 0]) cyl(d=10.5, h=10, anchor=TOP);
            }
        }
    }
}