// ==============================================================================
// FILE: RenderPeg.scad
// ARCHITECTURE: Layer 3 (Factory)
// PURPOSE: Standalone peg rod — bridges two stacked trays via corner sockets.
//
// Peg is a horizontal cylinder printed flat on bed (flat face cut on underside
// prevents it rolling during print). Length = PEG_HEIGHT, fits socket_d = 8mm.
// Tolerance (CLEARANCE from phys) subtracted from diameter for sliding fit.
// ==============================================================================
include <BOSL2/std.scad>
include <MasterEngine.scad>

module factory_render_peg(data, opts, phys) {
    p_len = get_val(PEG_HEIGHT, data, 80);
    p_dia = 8.0 - get_val("CLEARANCE", phys, 0.2) * 2;

    echo(str("-> Factory [PEG] | len=", p_len, " dia=", p_dia));

    // Horizontal rod, printed flat — flat cut on underside prevents rolling.
    difference() {
        yrot(90) cyl(d=p_dia, h=p_len, chamfer=0.5, anchor=CENTER);
        down(p_dia / 2) cuboid([p_len + 2, p_dia + 2, 1], anchor=BOTTOM);
    }
}
