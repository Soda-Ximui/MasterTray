// ==============================================================================
// FILE: MasterMeshPatterns.scad
// ARCHITECTURE: Layer 2.1 (Mesh Pattern Generation)
// ==============================================================================

include <BOSL2/std.scad>
include <MasterEngine.scad>

// Flat-top teardrop — 45° self-supporting roof, tip truncated to one extrusion width.
//
// WHY 45°: FDM critical overhang angle is 45° from horizontal. Roof sides steeper
// than this need support; shallower are self-supporting. Starting the roof at the
// 45° points of the circle guarantees the sides land exactly on this boundary.
//
// WHY FLAT TOP: a razor-sharp tip forces Arachne to pinch the bead to near-zero
// width, triggering a pressure-control slowdown. A flat top of exactly one
// extrusion width (nozzle_d * 1.05) lets the slicer lay a single normal-speed dot.
//
// GEOMETRY: roof is a trapezoid from the 45° circle points up to a flat top.
//   base corners : [±r·cos45, r·sin45]  = [±r·0.707, r·0.707]
//   flat top     : [±extrusion_w/2, r + r·sin45]  (height = r·(1 + sin45))
//
//   Previous (wrong) approach started the triangle from [-d/2, 0] → [d/2, 0],
//   producing ~56° sides — steeper than 45°, overhangs needed support.
module native_teardrop(d, extrusion_w = nozzle_d * 1.05) {
  r  = d / 2;
  w  = max(extrusion_w, 0.01);     // guard: never truly zero
  bx = r * cos(45);                // x of 45° point on circle
  by = r * sin(45);                // y of 45° point on circle
  th = r + by;                     // total height of flat top above origin
  union() {
    circle(d=d);
    // trapezoid: wide base at 45° circle points, narrow flat top of 1 extrusion width
    polygon([[- bx, by], [bx, by], [w/2, th], [-w/2, th]]);
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
  // rounding: proportional or extrusion-width, whichever is larger — never sharper than nozzle
  grid_copies(spacing=[step * 1.5, step], n=[nx, ny])
    rect([hole * 2, hole], rounding=max(hole * 0.2, nozzle_d * 1.05));
}

module pattern_circle(hole, step, nx, ny) {
  grid_copies(spacing=step, n=[nx, ny]) circle(d=hole);
}

module pattern_square(hole, step, nx, ny) {
  // rounding=nozzle_d: eliminates sharp 90° corners that cause Arachne pressure spikes
  grid_copies(spacing=step, n=[nx, ny]) rect([hole, hole], rounding=nozzle_d);
}

// Truncated rhombus: top and bottom points chopped to one extrusion width wide.
// rounding=nozzle_d on a rotated rect only softens side corners — it does not fix
// the vertical axis tips where Arachne pinches. Explicit polygon truncation does.
//   r  = hole/2 (half-width of the diamond)
//   top/bottom flat: y = ±(r - extrusion_w/2), x = ±extrusion_w/2
module native_diamond(hole, extrusion_w = nozzle_d * 1.05) {
  r = hole / 2;
  w = max(extrusion_w, 0.01);
  ty = r - w / 2;                  // y-height where tip is truncated
  polygon([
    [ 0,   r - w/2],               // top flat — right corner
    [ w/2, ty     ],               // top flat — right
    [ r,   0      ],               // right point (horizontal — no truncation needed)
    [ w/2, -ty    ],               // bottom flat — right
    [ 0,  -(r - w/2)],             // bottom flat — left corner
    [-w/2, -ty    ],               // bottom flat — left
    [-r,   0      ],               // left point
    [-w/2,  ty    ],               // top flat — left
  ]);
}
module pattern_diamond(hole, step, nx, ny) {
  grid_copies(spacing=step, n=[nx, ny]) native_diamond(hole);
}

module render_rectangular_pattern(pat, hole, step, nx, ny) {
  if      (pat == HONEYCOMB) pattern_honeycomb(hole, step, nx, ny);
  else if (pat == TEARDROP)  pattern_teardrop(hole, step, nx, ny);
  else if (pat == SLOTTED)   pattern_slotted(hole, step, nx, ny);
  else if (pat == CIRCLE)    pattern_circle(hole, step, nx, ny);
  else if (pat == SQUARE)    pattern_square(hole, step, nx, ny);
  else if (pat == DIAMOND)   pattern_diamond(hole, step, nx, ny);
}

module pattern_cylindrical_honeycomb(hole, wall_t) { cyl(d=hole / sin(60), h=wall_t * 4, $fn=6); }
module pattern_cylindrical_teardrop(hole, wall_t) { linear_extrude(wall_t * 4, center=true) native_teardrop(hole); }
module pattern_cylindrical_slotted(hole, wall_t) { cuboid([hole * 2, hole, wall_t * 4], rounding=max(hole * 0.2, nozzle_d * 1.05), except=TOP+BOTTOM); }
module pattern_cylindrical_circle(hole, wall_t) { cyl(d=hole, h=wall_t * 4); }
module pattern_cylindrical_square(hole, wall_t) { cuboid([hole, hole, wall_t * 4], rounding=nozzle_d, except=TOP+BOTTOM); }
module pattern_cylindrical_diamond(hole, wall_t) { linear_extrude(wall_t * 4, center=true) native_diamond(hole); }

module render_cylindrical_pattern(pat, hole, wall_t) {
  if      (pat == HONEYCOMB) pattern_cylindrical_honeycomb(hole, wall_t);
  else if (pat == TEARDROP)  pattern_cylindrical_teardrop(hole, wall_t);
  else if (pat == SLOTTED)   pattern_cylindrical_slotted(hole, wall_t);
  else if (pat == CIRCLE)    pattern_cylindrical_circle(hole, wall_t);
  else if (pat == SQUARE)    pattern_cylindrical_square(hole, wall_t);
  else if (pat == DIAMOND)   pattern_cylindrical_diamond(hole, wall_t);
}
