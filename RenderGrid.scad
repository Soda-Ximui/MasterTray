// ==============================================================================
// FILE: RenderGrid.scad
// ARCHITECTURE: Layer 3 (Factory)
// PURPOSE: Factory entry point for FrankenTray rib/divider geometry.
// ==============================================================================

include <BOSL2/std.scad>
include <MasterEngine.scad>
include <RenderRib.scad>

module factory_render_grid(data, opts, phys) {
    render_franken_ribs(data);
}
