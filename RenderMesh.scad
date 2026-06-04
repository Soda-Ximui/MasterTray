// ==============================================================================
// FILE: RenderMesh.scad
// ARCHITECTURE: Layer 2.1 (Mesh Surface Builder)
// PURPOSE: Flat and cylindrical mesh surfaces with pattern hole cutting.
//
// PARAMETERS (cfg = [hole, strut]):
//   hole  — diameter of each hole (mm)
//   strut — solid border surrounding the mesh region, as % of surface dimension
//           0% = holes go edge-to-edge   20% = 10% solid border each side
//          99% = nearly solid (get_mesh_cfg returns undef at >= 99)
//
// PERFORMANCE: tile count is sized to the mesh region (strut-scaled), not the
// full surface. Tiles outside the intersection are clipped and would be wasted.
// F5 preview uses 2× step → ~4× fewer tiles, same coverage.
// ==============================================================================
include <BOSL2/std.scad>
include <MasterEngine.scad>
include <MasterMeshPatterns.scad>

// framed_mesh — flat mesh slab for floor and lid surfaces.
// is_cyl=true uses a circular boundary (jar floors/lids).
module framed_mesh(data, w, l, h, is_cyl=false, cfg=undef, fn=0) {
    noz = m_noz(data);
    pat = get_val(PATTERN, data, TEARDROP);
    cyl_fn = fn > 0 ? fn : $fn;
    if (cfg == undef) {
        linear_extrude(height=h, center=true) {
            if (is_cyl) circle(d=w, $fn=cyl_fn);
            else        rect([w, l]);
        }
    } else {
        hole    = cfg[0];
        strut   = cfg[1];
        spacing = m_wloops(data) * noz;
        base_step = get_grid_step(hole, spacing, noz);
        // F5 preview: 2× step → ~4× fewer tiles, full mesh region still covered.
        step = $preview ? base_step * 2 : base_step;
        // Size tile grid to the mesh region only — tiles outside are clipped.
        nx  = get_n_steps(w, strut, step);
        ny  = get_n_steps(l, strut, step);
        // pad keeps holes slightly away from the mesh region boundary.
        pad = is_cyl ? 0 : noz * 4.5;
        linear_extrude(height=h, center=true) difference() {
            if (is_cyl) circle(d=w, $fn=cyl_fn);
            else        rect([w, l]);
            intersection() {
                if (is_cyl) circle(d=get_mesh_dim(w, strut), $fn=cyl_fn);
                else        rect([max(0.1, get_mesh_dim(w, strut) - pad),
                                  max(0.1, get_mesh_dim(l, strut) - pad)]);
                render_rectangular_pattern(pat, hole, step, nx, ny);
            }
        }
    }
}

// cylindrical_mesh_wall — hollow cylinder shell with optional radial pattern holes.
module cylindrical_mesh_wall(data, d, h, wall_t, cfg=undef, fn=0) {
    noz = m_noz(data);
    pat = get_val(PATTERN, data, TEARDROP);
    cyl_fn = fn > 0 ? fn : $fn;
    if (cfg == undef) {
        difference() {
            cyl(d=d, h=h, anchor=BOTTOM, $fn=cyl_fn);
            down(1) cyl(d=d - wall_t*2, h=h+2, anchor=BOTTOM, $fn=cyl_fn);
        }
    } else {
        hole    = cfg[0];
        strut   = cfg[1];
        spacing = m_wloops(data) * noz;
        base_step = get_grid_step(hole, spacing, noz);
        step     = $preview ? base_step * 2 : base_step;
        h_active = h * (1 - strut / 100);
        nz = max(1, floor(h_active / step));
        na = max(3, floor((PI * d) / step));
        a_step = 360 / na;
        z_step = h_active / nz;
        difference() {
            difference() {
                cyl(d=d, h=h, anchor=BOTTOM, $fn=cyl_fn);
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
