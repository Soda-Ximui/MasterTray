// ==============================================================================
// FILE: RenderJar.scad
// ARCHITECTURE: Layer 3 (Factory)
// PURPOSE: Cylindrical jar body with optional threaded neck.
// ==============================================================================
// BOSL2/std comes via MasterEngine — do NOT re-include (OpenSCAD has no include dedup; re-parse cost ~21s) [perf]
// MasterEngine is included once by MasterBuilder.scad (single owner) — not re-included here [perf]
include <RenderMesh.scad>
include <RenderGrid.scad>

module factory_render_jar(data, opts, phys) {
    w   = m_bw(data);
    h   = m_bh(data);
    sf  = m_safe_floor(data);
    sw  = m_safe_wall(data);
    noz = m_noz(data);
    // rim_chamf: matches cylindrical_mesh_wall's rim value (noz×4) so the bevel
    // is consistent from the first printed layer all the way up the wall.
    rim_chamf = noz * 4;
    is_threaded = get_val("IS_THREADED", opts, false);

    // JAR_SIDES: 0 = circle, 4/6/8/12 = polygon. Overrides $fn on all jar geometry.
    sides    = get_val("JAR_SIDES", opts, 0);
    jar_fn   = sides > 0 ? sides : $fn;

    lip_h      = JAR_LIP_HEIGHT;   // centralized in MasterConstants — not a local magic number
    wall_h     = h - sf;
    cyl_wall_h = max(0.1, is_threaded ? (wall_h - lip_h - sw * 1.5) : wall_h);
    neck_od    = w - sw * 2 - 0.6;
    neck_id    = neck_od - sw * 2;

    echo(str("-> Factory [JAR] | d=", w, " h=", h,
             " threaded=", is_threaded, " sides=", sides > 0 ? sides : "circle"));

    // Built-in grid: inject jar context so grid clips to circle and
    // lowers walls to clear the cylindrical wall height (not the full jar height).
    // Clearance snapped up to nearest layer boundary — preserves layer alignment
    // that cyl_wall_h achieved via m_safe_wall.
    lh     = m_lh(data);
    grid_h = cyl_wall_h - lh * ceil(0.5 / lh);
    jar_data = concat([[IS_JAR_GRID, true],
                       [HAS_THREADS, is_threaded],
                       [GRID_WALL_H, grid_h]], data);

    union() {
        // Built-in grid (fused to jar interior, raised to floor level)
        up(sf) render_internal_grid(jar_data);
        // Floor (circular or polygonal)
        // The floor disc spans the full outer diameter w, but the jar wall (sw thick)
        // covers the outer ring and hides it from view. Rendering the mesh against the
        // full w would cause most of the strut% solid border to vanish under the wall.
        // Fix: render the hidden outer ring as solid, mesh only the visible inner disc.
        // strut% then operates within the area the user actually sees.
        inner_d = w - sw * 2;
        up(sf / 2) union() {
            // Outer solid ring — structural, hidden under wall. Ring hole stays at the
            // true inner_d (so its polygon matches the wall exactly on low-facet jars).
            // chamfer1=rim_chamf puts the bevel at z=0 (first printed layer) so the
            // base has no sharp 90° corner — matches the cylindrical_mesh_wall's bottom
            // rim chamfer that starts one floor-height higher at z=sf. Linear_extrude
            // had no chamfer at all ("chamfering above the floor"); this fixes it.
            // Inner bore cutter uses anchor=CENTER + h=sf+EPS*2 so it extends EPS
            // beyond both faces of the ring (EPS cutter rule — no zero-thickness bottom).
            difference() {
                cyl(d=w, h=sf, chamfer1=rim_chamf, anchor=CENTER, $fn=jar_fn);
                cyl(d=inner_d, h=sf + EPS*2, anchor=CENTER, $fn=jar_fn);
            }
            // [GEOM-FIX: jar floor union seam non-manifold] Inner disc grown by EPS*2 so it
            // OVERLAPS the ring's inner edge instead of meeting it face-to-face — coincident
            // faces left non-manifold seam edges along the inner_d boundary (Jar/Threaded Jar
            // 8012 nm, Grid Test 30452 nm; the EPS-overlap rule). Growing the disc (rather
            // than shrinking the ring) keeps the ring/wall polygons vertex-aligned, which
            // matters for low-facet jars (Quad/Spool) where a shrunk ring mis-meshed. [manifold]
            framed_mesh(data, inner_d + EPS*2, inner_d + EPS*2, sf, true,
                        get_mesh_cfg(data, HOLE_FLOOR, STRUT_FLOOR), jar_fn);
        }

        // Wall — dropped EPS into the floor (height +EPS) so the wall base OVERLAPS the
        // floor top instead of meeting it face-to-face (same non-manifold seam). Wall top
        // stays at sf+cyl_wall_h, so the neck still aligns. [manifold]
        up(sf - EPS)
            cylindrical_mesh_wall(data, w, cyl_wall_h + EPS, sw,
                                  get_mesh_cfg(data, HOLE_WALL, STRUT_WALL), jar_fn);

        if (is_threaded) {
            // [GEOM-FIX: jar neck seam — EPS overlap at wall→cone and cone→thread junctions]
            // Same face-to-face seam issue as the floor→wall (fixed above with EPS drop).
            // Without EPS, the cone bottom sits exactly on the wall top face, and the
            // thread rod bottom sits exactly on the cone top face — CGAL produces a
            // degenerate cross-section at these junctions → OrcaSlicer "empty layer" warning.
            // Fix: shift each piece DOWN by EPS and extend its height by EPS so it overlaps
            // the piece below by EPS instead of touching face-to-face.
            // sf+cyl_wall_h-EPS + sw*1.5+EPS = sf+cyl_wall_h+sw*1.5 (cone top unchanged).
            // sf+cyl_wall_h+sw*1.5-EPS + lip_h+EPS = sf+cyl_wall_h+sw*1.5+lip_h = h (jar top unchanged).
            up(sf + cyl_wall_h - EPS)
                difference() {
                    cyl(d1=w, d2=neck_od, h=sw * 1.5 + EPS, anchor=BOTTOM, $fn=jar_fn);
                    down(1) cyl(d=neck_id, h=sw * 1.5 + 2, anchor=BOTTOM, $fn=jar_fn);
                }
            up(sf + cyl_wall_h + sw * 1.5 - EPS)
                difference() {
                    threaded_rod(d=neck_od, l=lip_h + EPS, pitch=m_thread_pitch(data),
                                 internal=false, anchor=BOTTOM, $fn=30);
                    down(1) cyl(d=neck_id, h=lip_h + 2, anchor=BOTTOM, $fn=jar_fn);
                }
        }
    }
}
