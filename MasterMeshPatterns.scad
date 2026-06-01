// ==============================================================================
// FILE: MasterMeshPatterns.scad [v1.0]
// ARCHITECTURE: Layer 2.1 (Mesh Pattern Generation)
// PURPOSE: Extracted pattern logic from framed_mesh for readability
// ==============================================================================

include <BOSL2/std.scad>
include <MasterEnum.scad>
include <MasterEngine.scad>
include <MasterConstants.scad>

// --- NATIVE TEARDROP SHAPE ---
// Custom teardrop for FDM-friendly mesh patterns
module native_teardrop(d) { 
    union() { 
        circle(d=d); 
        polygon([[-d/2, 0], [d/2, 0], [0, d/2 * 1.5]]); 
    } 
}

// === RECTANGULAR MESH PATTERNS ===
// Generate mesh holes in rectangular grids

// Pattern: Honeycomb (hexagonal grid)
module pattern_honeycomb(hole, step, nx, ny) {
    grid_copies(spacing=[step, step * sin(60)], n=[nx, ny], stagger=true) 
        circle(d=hole / sin(60), $fn=6);
}

// Pattern: Teardrop (triangular orientation)
module pattern_teardrop(hole, step, nx, ny) {
    grid_copies(spacing=step, n=[nx, ny]) 
        native_teardrop(hole);
}

// Pattern: Slotted (rectangular holes)
module pattern_slotted(hole, step, nx, ny) {
    grid_copies(spacing=[step*1.5, step], n=[nx, ny]) 
        rect([hole * 2, hole], rounding=hole*0.2);
}

// Pattern: Circle (circular holes)
module pattern_circle(hole, step, nx, ny) {
    grid_copies(spacing=step, n=[nx, ny]) 
        circle(d=hole);
}

// Pattern: Square (square holes)
module pattern_square(hole, step, nx, ny) {
    grid_copies(spacing=step, n=[nx, ny]) 
        rect([hole, hole]);
}

// Pattern: Diamond (rotated squares)
module pattern_diamond(hole, step, nx, ny) {
    grid_copies(spacing=step, n=[nx, ny]) 
        rotate(45) rect([hole, hole]);
}

// --- DISPATCHER: Render correct pattern based on type ---
module render_rectangular_pattern(pat, hole, step, nx, ny) {
    if (pat == HONEYCOMB) { 
        pattern_honeycomb(hole, step, nx, ny); 
    } else if (pat == TEARDROP) { 
        pattern_teardrop(hole, step, nx, ny); 
    } else if (pat == SLOTTED) { 
        pattern_slotted(hole, step, nx, ny); 
    } else if (pat == CIRCLE) { 
        pattern_circle(hole, step, nx, ny); 
    } else if (pat == SQUARE) { 
        pattern_square(hole, step, nx, ny); 
    } else if (pat == DIAMOND) { 
        pattern_diamond(hole, step, nx, ny); 
    }
}

// === CYLINDRICAL MESH PATTERNS ===
// Generate mesh holes in spiral/radial patterns

// Pattern: Honeycomb (radial)
module pattern_cylindrical_honeycomb(hole, wall_t) {
    cyl(d=hole / sin(60), h=wall_t * 4, $fn=6);
}

// Pattern: Teardrop (radial)
module pattern_cylindrical_teardrop(hole, wall_t) {
    linear_extrude(wall_t * 4, center=true) 
        native_teardrop(hole);
}

// Pattern: Slotted (radial)
module pattern_cylindrical_slotted(hole, wall_t) {
    cuboid([hole*2, hole, wall_t * 4]);
}

// Pattern: Circle (radial)
module pattern_cylindrical_circle(hole, wall_t) {
    cyl(d=hole, h=wall_t * 4);
}

// Pattern: Square (radial)
module pattern_cylindrical_square(hole, wall_t) {
    cuboid([hole, hole, wall_t * 4]);
}

// Pattern: Diamond (radial, rotated)
module pattern_cylindrical_diamond(hole, wall_t) {
    zrot(45) cuboid([hole, hole, wall_t * 4]);
}

// --- DISPATCHER: Render correct cylindrical pattern ---
module render_cylindrical_pattern(pat, hole, wall_t) {
    if (pat == HONEYCOMB) { 
        pattern_cylindrical_honeycomb(hole, wall_t); 
    } else if (pat == TEARDROP) { 
        pattern_cylindrical_teardrop(hole, wall_t); 
    } else if (pat == SLOTTED) { 
        pattern_cylindrical_slotted(hole, wall_t); 
    } else if (pat == CIRCLE) { 
        pattern_cylindrical_circle(hole, wall_t); 
    } else if (pat == SQUARE) { 
        pattern_cylindrical_square(hole, wall_t); 
    } else if (pat == DIAMOND) { 
        pattern_cylindrical_diamond(hole, wall_t); 
    }
}

// === AUDIT LOG ===
// v1.0: Extracted pattern logic from MasterRender.framed_mesh (line 19)
//       and MasterRender.cylindrical_mesh_wall (line 26)
//       Reduces complexity of parent modules from 500+ chars to ~200 chars
