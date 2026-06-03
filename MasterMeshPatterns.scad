// ==============================================================================
// FILE: MasterMeshPatterns.scad
// ARCHITECTURE: Layer 2.1 (Mesh Pattern Generation)
// ==============================================================================

include <BOSL2/std.scad>
include <MasterEngine.scad>

module native_teardrop(d) {
  union() {
    circle(d=d);
    polygon([[-d / 2, 0], [d / 2, 0], [0, d / 2 * 1.5]]);
  }
}

module pattern_honeycomb(hole, step, nx, ny) {
  grid_copies(spacing=[step, step * sin(60)], n=[nx, ny], stagger=true)
    circle(d=hole / sin(60), $fn=6);
}

module pattern_teardrop(hole, step, nx, ny) {
  grid_copies(spacing=step, n=[nx, ny]) native_teardrop(hole);
}

module pattern_slotted(hole, step, nx, ny) {
  grid_copies(spacing=[step * 1.5, step], n=[nx, ny])
    rect([hole * 2, hole], rounding=hole * 0.2);
}

module pattern_circle(hole, step, nx, ny) {
  grid_copies(spacing=step, n=[nx, ny]) circle(d=hole);
}

module pattern_square(hole, step, nx, ny) {
  grid_copies(spacing=step, n=[nx, ny]) rect([hole, hole]);
}

module pattern_diamond(hole, step, nx, ny) {
  grid_copies(spacing=step, n=[nx, ny]) rotate(45) rect([hole, hole]);
}

module render_rectangular_pattern(pat, hole, step, nx, ny) {
  if (pat == "HONEYCOMB" || pat == 1) {
    pattern_honeycomb(hole, step, nx, ny);
  } else if (pat == "TEARDROP" || pat == 2) {
    pattern_teardrop(hole, step, nx, ny);
  } else if (pat == "SLOTTED" || pat == 3) {
    pattern_slotted(hole, step, nx, ny);
  } else if (pat == "CIRCLE" || pat == 4) {
    pattern_circle(hole, step, nx, ny);
  } else if (pat == "SQUARE" || pat == 5) {
    pattern_square(hole, step, nx, ny);
  } else if (pat == "DIAMOND" || pat == 6) {
    pattern_diamond(hole, step, nx, ny);
  }
}

module pattern_cylindrical_honeycomb(hole, wall_t) { cyl(d=hole / sin(60), h=wall_t * 4, $fn=6); }
module pattern_cylindrical_teardrop(hole, wall_t) { linear_extrude(wall_t * 4, center=true) native_teardrop(hole); }
module pattern_cylindrical_slotted(hole, wall_t) { cuboid([hole * 2, hole, wall_t * 4]); }
module pattern_cylindrical_circle(hole, wall_t) { cyl(d=hole, h=wall_t * 4); }
module pattern_cylindrical_square(hole, wall_t) { cuboid([hole, hole, wall_t * 4]); }
module pattern_cylindrical_diamond(hole, wall_t) { zrot(45) cuboid([hole, hole, wall_t * 4]); }

module render_cylindrical_pattern(pat, hole, wall_t) {
  if (pat == "HONEYCOMB" || pat == 1) {
    pattern_cylindrical_honeycomb(hole, wall_t);
  } else if (pat == "TEARDROP" || pat == 2) {
    pattern_cylindrical_teardrop(hole, wall_t);
  } else if (pat == "SLOTTED" || pat == 3) {
    pattern_cylindrical_slotted(hole, wall_t);
  } else if (pat == "CIRCLE" || pat == 4) {
    pattern_cylindrical_circle(hole, wall_t);
  } else if (pat == "SQUARE" || pat == 5) {
    pattern_cylindrical_square(hole, wall_t);
  } else if (pat == "DIAMOND" || pat == 6) {
    pattern_cylindrical_diamond(hole, wall_t);
  }
}
