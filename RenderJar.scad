// ==============================================================================
// FILE: RenderJar.scad
// ARCHITECTURE: Layer 3 (Factory)
// PURPOSE: Render factory for threaded and smooth-walled jar geometries
// ==============================================================================
// This module constructs cylindrical jar bodies with optional threading.
// It handles:
//   - Cylindrical mesh walls (open container geometry)
//   - Threaded neck for screw-on lids (when IS_THREADED=true)
//   - Floor mesh with structural framing
//   - Dynamic material configuration
// ==============================================================================

include <BOSL2/std.scad>
include <MasterEngine.scad>
include <RenderMesh.scad>

// ============================================================================
// factory_render_jar(data, opts, phys)
// ============================================================================
// FACTORY FUNCTION: Renders a cylindrical jar body.
//
// INPUT PARAMETERS:
//   data  = Configuration array [["KEY", value], ...] with WIDTH, HEIGHT, etc.
//   opts  = Render options array including ["IS_THREADED", true/false]
//   phys  = Physical safety array [["SAFE_WALL", sw], ["SAFE_FLOOR", sf], ...]
//
// GEOMETRY STRATEGY:
//   1. Floor: Circular framed mesh (like a strainer bottom)
//   2. Walls: Cylindrical mesh shell (perforated vertical surface)
//   3. Optional Neck: Tapered transition from jar body to thread section
//   4. Optional Threads: BOSL2 threaded_rod with internal hollow cavity
//
// GEOMETRY LAYOUT (Z-stack from bottom):
//   Z = 0         : Jar bottom starts
//   Z = sf/2      : Floor center (framed_mesh)
//   Z = sf        : Walls begin (cylindrical_mesh_wall)
//   Z = sf + cyl_wall_h : Neck transition begins (if threaded)
//   Z = sf + cyl_wall_h + sw*1.5 : Threading begins (if threaded)
//   Z = sf + cyl_wall_h + sw*1.5 + lip_h : Threading ends, full height reached
//
// MATERIAL FLOW:
//   - Floor thickness (sf) is validated by m_safe_floor(data)
//   - Wall thickness (sw) is validated by m_safe_wall(data)
//   - Mesh configuration comes from material density percentages
//   - Thread parameters (pitch, ID, OD) come from "THREAD_PITCH" parameter
//
// THREADING NOTES (when IS_THREADED=true):
//   - Lip height (8.0mm) = space for M8-equivalent screw-on lid
//   - Neck tapers from jar diameter (w) down to threading diameter
//   - Threading is EXTERNAL on jar body (for screw-on lid to grip)
//   - Internal cavity (hollow) is cut using difference() to save material
// ============================================================================
module factory_render_jar(data, opts, phys) {
    // ---- Extract dimensions ----
    w = m_bw(data);           // Jar diameter (circular, so width = length)
    h = m_bh(data);           // Total jar height
    is_threaded = get_val("IS_THREADED", opts, false);

    // ---- Extract safety values from physics array ----
    // phys[0][1] = SAFE_WALL thickness
    // phys[1][1] = SAFE_FLOOR thickness
    sf = phys[1][1];          // Safe floor thickness (layer-aligned)
    sw = phys[0][1];          // Safe wall thickness (nozzle-aligned)

    // ---- Calculate wall heights ----
    lip_h = 8.0;              // Neck section height for threading grip
    actual_wall_h = h - sf;   // Subtract floor from total

    // Cylindrical wall height = remaining space after subtracting floor, lip, and transition
    // is_threaded condition: if threading, reserve space for neck + thread section
    cyl_wall_h = max(0.1,     // Ensure minimum geometry (0.1mm) to avoid OpenSCAD errors
                     is_threaded ?
                       (actual_wall_h - lip_h - sw * 1.5)  // Leave room for lip and transition
                       : actual_wall_h                       // Use full remaining height if no threads
                    );

    // ---- Calculate neck/threading geometry ----
    neck_od = w - sw * 2 - 0.6;      // Neck outer diameter (step inward from jar walls)
    neck_id = neck_od - sw * 2;      // Neck inner diameter (create hollow cavity)

    // ---- Status report ----
    echo(str("-> Factory [JAR]  | Dia: ", w, " | Height: ", h,
             " | Threaded: ", is_threaded, " | Wall Height: ", cyl_wall_h));

    // ---- Build jar body using union (combine all parts) ----
    union() {
        // COMPONENT 1: Circular floor mesh
        // Position: centered at Z = sf/2 (middle of floor thickness)
        // Geometry: framed_mesh creates a hollow circle with optional pattern
        // is_cyl=true tells framed_mesh to use circular pattern instead of rectangular
        up(sf / 2)
            framed_mesh(data, w, w, sf, true,
                        get_mesh_cfg(data, "HOLE_FLOOR", "STRUT_FLOOR"));

        // COMPONENT 2: Cylindrical wall mesh
        // Position: starts at Z = sf (on top of floor)
        // Geometry: Hollow cylinder with optional hole pattern (like a colander)
        up(sf)
            cylindrical_mesh_wall(data, w, cyl_wall_h, sw,
                                  get_mesh_cfg(data, "HOLE_WALL", "STRUT_WALL"));

        // COMPONENT 3: Neck transition (optional, only if threading)
        // This tapers from jar diameter down to thread diameter
        // Uses difference() to hollow it out (create internal cavity for lid)
        if (is_threaded) {
            up(sf + cyl_wall_h) {
                difference() {
                    // Outer shape: tapered cone from jar diameter (w) to neck diameter (neck_od)
                    cyl(d1=w,              // Bottom diameter (at jar)
                        d2=neck_od,        // Top diameter (at thread)
                        h=sw * 1.5,        // Transition height
                        anchor=BOTTOM);

                    // Inner cavity: tall hollow cylinder to scoop out interior
                    // down(1) extends below the transition to avoid manifold issues
                    down(1)
                        cyl(d=neck_id,     // Diameter of inner hollow
                            h=sw * 1.5 + 2, // Extra height to ensure clean cut
                            anchor=BOTTOM);
                }
            }

            // COMPONENT 4: Threading (optional, only if threading)
            // This is the external screw thread that the lid grips
            // Position: starts at Z = sf + cyl_wall_h + sw*1.5 (on top of neck)
            up(sf + cyl_wall_h + sw * 1.5) {
                difference() {
                    // Outer shape: BOSL2's threaded_rod creates the actual screw geometry
                    threaded_rod(d=neck_od,              // Thread outer diameter
                                 l=lip_h,                // Thread length (8mm)
                                 pitch=get_val("THREAD_PITCH", data, 2.0),
                                 internal=false,         // External threading (true = internal)
                                 anchor=BOTTOM);

                    // Inner cavity: ensure thread is hollow inside
                    down(1)
                        cyl(d=neck_id,     // Diameter of inner hollow
                            h=lip_h + 2,   // Extra height to ensure clean cut
                            anchor=BOTTOM);
                }
            }
        }
    }
}