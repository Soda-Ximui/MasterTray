// ==============================================================================
// FILE: RenderJar.scad
// ARCHITECTURE: Layer 3 (Factory)
// PURPOSE: Cylindrical jar body with optional threaded neck.
// ==============================================================================
include <BOSL2/std.scad>
include <MasterEngine.scad>
include <RenderMesh.scad>

module factory_render_jar(data, opts, phys) {
    w   = m_bw(data);
    h   = m_bh(data);
    sf  = m_safe_floor(data);
    sw  = m_safe_wall(data);
    is_threaded = get_val("IS_THREADED", opts, false);

    lip_h      = 8.0;
    wall_h     = h - sf;
    cyl_wall_h = max(0.1, is_threaded ? (wall_h - lip_h - sw * 1.5) : wall_h);
    neck_od    = w - sw * 2 - 0.6;
    neck_id    = neck_od - sw * 2;

    echo(str("-> Factory [JAR] | d=", w, " h=", h, " threaded=", is_threaded));

    union() {
        // Circular floor
        up(sf / 2)
            framed_mesh(data, w, w, sf, true,
                        get_mesh_cfg(data, HOLE_FLOOR, STRUT_FLOOR));

        // Cylindrical wall
        up(sf)
            cylindrical_mesh_wall(data, w, cyl_wall_h, sw,
                                  get_mesh_cfg(data, HOLE_WALL, STRUT_WALL));

        if (is_threaded) {
            // Tapered neck transition
            up(sf + cyl_wall_h)
                difference() {
                    cyl(d1=w, d2=neck_od, h=sw * 1.5, anchor=BOTTOM);
                    down(1) cyl(d=neck_id, h=sw * 1.5 + 2, anchor=BOTTOM);
                }

            // External thread section
            up(sf + cyl_wall_h + sw * 1.5)
                difference() {
                    threaded_rod(d=neck_od, l=lip_h,
                                 pitch=m_thread_pitch(data),
                                 internal=false, anchor=BOTTOM, $fn=30);
                    down(1) cyl(d=neck_id, h=lip_h + 2, anchor=BOTTOM);
                }
        }
    }
}
