// ==============================================================================
// FILE: RenderMesh.scad
// ARCHITECTURE: Layer 2.1 (Mesh Surface Builder)
// PURPOSE: Flat and cylindrical mesh surfaces with pattern hole cutting.
//
// PARAMETERS (cfg = [hole, strut]):
//   hole  — diameter of each hole (mm)
//   strut — solid border surrounding the mesh region, as % of surface area
//           0% = holes go edge-to-edge   20% = 20% solid border
//          99% = nearly solid (get_mesh_cfg returns undef at >= 99)
//
// STRUT % SEMANTICS (see BUGS.md B1, docs/FEATURES.md §Mesh Control):
//   Flat rectangle : each linear dim scales as (1 − strut/100); solid = strut%/2 per side
//   Flat circle    : diameter scales as sqrt(1 − strut/100) so mesh AREA = (1−strut/100)
//   Cylindrical    : height only; solid bands top+bottom each strut%/2; full circumference meshed
//
// PERFORMANCE: tile count is sized to the mesh region (strut-scaled), not the
// full surface. Tiles outside the intersection are clipped and would be wasted.
// F5 preview uses 2× step → ~4× fewer tiles, same coverage.
// ==============================================================================
include <BOSL2/std.scad>
include <MasterEngine.scad>
include <MasterMeshPatterns.scad>

// ------------------------------------------------------------------------------
// SHARED HELPER — cfg unpacking + step computation.
// Both framed_mesh and cylindrical_mesh_wall need the same derived values.
// Returns [noz, pat, hole, strut, step].
//
//   [0] noz   — resolved nozzle diameter from data
//   [1] pat   — pattern string (TEARDROP, SLOTTED, …)
//   [2] hole  — hole diameter (mm)
//   [3] strut — solid border percentage
//   [4] step  — center-to-center tile pitch (preview-doubled when $preview)
// ------------------------------------------------------------------------------
function mesh_params(cfg, data) =
  let(
    noz       = m_noz(data),
    pat       = get_val(PATTERN, data, TEARDROP),
    hole      = cfg[0],
    strut     = cfg[1],
    spacing   = get_val(HOLE_SPACING, data, m_wloops(data) * noz),
    // Slotted pillars carry vertical load — need 4 full extrusion passes
    // (2 perimeters each side). line_width = noz × EXTRUSION_WIDTH_MULT.
    // All other patterns use the standard physics minimum spacing.
    min_sp    = (pat == SLOTTED) ? noz * EXTRUSION_WIDTH_MULT * 4 : spacing,
    base_step = get_grid_step(hole, min_sp, noz)
  )
  [noz, pat, hole, strut, $preview ? base_step * 2 : base_step];

// framed_mesh — flat mesh slab for floor and lid surfaces.
// is_cyl=true uses a circular boundary (jar floors/lids).
module framed_mesh(data, w, l, h, is_cyl=false, cfg=undef, fn=0) {
    cyl_fn = fn > 0 ? fn : $fn;
    if (cfg == undef) {
        linear_extrude(height=h, center=true) {
            if (is_cyl) circle(d=w, $fn=cyl_fn);
            else        rect([w, l]);
        }
    } else {
        mp    = mesh_params(cfg, data);
        noz   = mp[0];  pat  = mp[1];  hole = mp[2];
        strut = mp[3];  step = mp[4];

        // pad keeps holes slightly away from the mesh region boundary on flat
        // rectangular surfaces — prevents clipped half-holes against the frame wall.
        // Circular boundary uses no pad (the circle clips cleanly at the edge).
        pad = is_cyl ? 0 : noz * 4.5;

        // Size tile grid to the mesh region only — tiles outside are clipped.
        nx  = get_n_steps(w, strut, step);
        ny  = get_n_steps(l, strut, step);

        linear_extrude(height=h, center=true) difference() {
            if (is_cyl) circle(d=w, $fn=cyl_fn);
            else        rect([w, l]);
            intersection() {
                if (is_cyl)
                    // FIX B1 (BUGS.md): area-preserving diameter scaling.
                    // BEFORE: circle(d=get_mesh_dim(w, strut))  — linear scaling
                    //   gave mesh area = (1−strut%)² of total (e.g. 81% at strut=10%).
                    // AFTER:  sqrt scaling → mesh area = (1−strut%) of total (90% at strut=10%).
                    circle(d=w * sqrt(max(0, 1 - strut / 100)), $fn=cyl_fn);
                else
                    rect([max(0.1, get_mesh_dim(w, strut) - pad),
                          max(0.1, get_mesh_dim(l, strut) - pad)]);
                render_rectangular_pattern(pat, hole, step, nx, ny);
            }
        }
    }
}

// cylindrical_mesh_wall — hollow cylinder shell with optional radial pattern holes.
module cylindrical_mesh_wall(data, d, h, wall_t, cfg=undef, fn=0) {
    cyl_fn    = fn > 0 ? fn : $fn;
    // Safety chamfer on top and bottom rim: 4 extrusion passes wide so it's
    // always printable and provides a tactile rounded edge (no knife rim).
    rim_chamf = m_noz(data) * 4;
    if (cfg == undef) {
        difference() {
            cyl(d=d, h=h, chamfer=rim_chamf, anchor=BOTTOM, $fn=cyl_fn);
            down(1) cyl(d=d - wall_t*2, h=h+2, anchor=BOTTOM, $fn=cyl_fn);
        }
    } else {
        mp    = mesh_params(cfg, data);
        noz   = mp[0];  pat  = mp[1];  hole = mp[2];
        strut = mp[3];  step = mp[4];

        // Strut % splits height symmetrically: solid band = strut%/2 top + strut%/2 bottom.
        // Holes fill the full circumference — no solid band around the cylinder.
        h_active = h * (1 - strut / 100);
        nz     = max(1, floor(h_active / step));
        na     = max(3, floor((PI * d) / step));
        a_step = 360 / na;
        z_step = h_active / nz;

        difference() {
            difference() {
                cyl(d=d, h=h, chamfer=rim_chamf, anchor=BOTTOM, $fn=cyl_fn);
                down(1) cyl(d=d - wall_t*2, h=h+2, anchor=BOTTOM, $fn=cyl_fn);
            }
            for (i = [0 : nz-1])
                for (j = [0 : na-1]) {
                    z_pos = (h - h_active) / 2 + (i + 0.5) * z_step;
                    zrot(j * a_step) translate([d/2, 0, z_pos])
                        yrot(90)
                        render_cylindrical_pattern(pat, hole, wall_t);
                }
        }
    }
}
