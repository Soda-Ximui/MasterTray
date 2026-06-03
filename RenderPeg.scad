// ==============================================================================
// FILE: RenderPeg.scad
// ARCHITECTURE: Layer 3 (Factory)
// ==============================================================================
include <BOSL2/std.scad>
include <MasterEngine.scad>

module factory_render_peg(data, opts, phys) {
    pos = get_val("OFFSET_XYZ", opts, [0,0,0]);
    gap = get_val("CLEARANCE", phys, 0); 
    h = m_bh(data);
    
    echo(str("-> Factory [PEG]  | Offset: ", pos, " | Clearance Gap: ", gap));
    
    translate(pos) {
        up(h - 5) cyl(d=10 - gap, h=10, anchor=BOTTOM);
    }
}