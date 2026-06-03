if (!is_undef(MESH_LOADED)) return;
MESH_LOADED = true;
include <BOSL2/std.scad>
include <MasterEngine.scad>
include <MasterMeshPatterns.scad>

function get_grid_step(hole, min_sp, noz) = hole + max(min_sp, noz * 2);
function get_n_steps(dim, solid, step) = max(1, ceil((dim * (1 - (solid/100))) / step));
function get_mesh_dim(dim, solid) = dim * (1 - (solid / 100));

module framed_mesh(data, w, l, h, is_cyl=false, cfg=undef) {
    noz = m_noz(data); pat = get_val("PATTERN", data, "TEARDROP"); 
    if (cfg == undef) linear_extrude(h, center=true) is_cyl ? circle(d=w) : rect([w, l]);
    else {
        hole = cfg[0]; solid = cfg[1]; step = get_grid_step(hole, 1.2, noz);
        linear_extrude(h, center=true) difference() {
            is_cyl ? circle(d=w) : rect([w, l]);
            intersection() {
                is_cyl ? circle(d=get_mesh_dim(w, solid)) : rect([get_mesh_dim(w, solid), get_mesh_dim(l, solid)]);
                render_rectangular_pattern(pat, hole, step, 10, 10);
            }
        }
    }
}

module cylindrical_mesh_wall(data, d, h, wall_t, cfg=undef) {
    if (cfg != undef) {
        difference() {
            cyl(d=d, h=h, anchor=BOTTOM);
            down(1) cyl(d=d - wall_t * 2, h=h + 2, anchor=BOTTOM);
            // ... (pattern logic)
        }
    }
}