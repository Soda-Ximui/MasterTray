// ==============================================================================
// FILE: MasterUtility.scad
// ARCHITECTURE: Layer 1.5 (Utilities & Output Pipelines)
// ==============================================================================
// AUDIT LOG:
// [v4.13] Restored Vector Math Engine (parse_val, get_rib_angle, calc_touch_dist,
//         get_rib_length) needed by RenderRib.scad and RenderGrid.scad.
// [v4.9] Added Slicer Intelligence. The preflight report now dynamically calculates
//        and echoes optimal wall order recommendations based on the part's TYPE taxonomy.
// ==============================================================================

include <MasterEngine.scad>
include <MasterText.scad>
include <MasterValidation.scad>

// --- SLICER INTELLIGENCE ENGINE ---
function get_wall_order_recommendation(type) =
  (type == BOX_GRID || type == JAR_GRID || type == TRAY_SIMPLE || type == TRAY_STACK_NEST) ?
    "Outer -> Inner (Maximum dimensional accuracy for vertical walls)"
  : (type == FLIP_BOX || type == DOUBLE_FLIP_BOX || type == FLIP_LID) ?
    "Inner -> Outer -> Inner (Best for diamond overhangs & snap-fits)"
  : (type == JAR || type == JAR_LID) ?
    "Inner -> Outer (Crucial to support thread overhangs)"
  : "Inner -> Outer (Standard FDM default)";

// --- PREFLIGHT REPORTING ---
module generate_preflight_report(data) {
  type = get_val(TYPE, data, BOX);
  wall_rec = get_wall_order_recommendation(type);

  echo(str("[FACTORY_REPORT] | --- Profiling Part: ", type, " ---"));
  echo(str("[FACTORY_REPORT] | Builder_Version: ", get_val(BUILDER_VERSION, data, "Unknown")));
  echo(str("[FACTORY_REPORT] | Dimension_Mode: ", get_val(DIMENSION_MODE, data, "Total")));
  echo(str("[FACTORY_REPORT] | Nozzle_Diameter: ", m_noz(data)));
  echo(str("[FACTORY_REPORT] | Wall_Loops_Calculated: ", m_wloops(data)));
  echo(str("[FACTORY_REPORT] | Wall_Thickness_Actual: ", m_safe_wall(data)));
  echo(str("[FACTORY_REPORT] | Floor_Thickness_Actual: ", m_safe_floor(data)));

  // [v4.9] Dynamic Slicer Recommendations
  echo(str("[MANUFACTURING]  | ⚠ RECOMMENDED WALL ORDER: ", wall_rec));
}

// --- VECTOR MATH ENGINE (FrankenTray) ---

function parse_val(s) =
    let(val = to_num(get_digits(s)))
    (len(search("-", s)) > 0) ? -val : val;

function get_rib_angle(traj, w, l, ox, oy) =
    (traj == "N") ? 90 :
    (traj == "S") ? -90 :
    (traj == "E") ? 0 :
    (traj == "W") ? 180 :
    (traj == "NE") ? atan2((l/2) - oy, (w/2) - ox) :
    (traj == "NW") ? atan2((l/2) - oy, (-w/2) - ox) :
    (traj == "SE") ? atan2((-l/2) - oy, (w/2) - ox) :
    (traj == "SW") ? atan2((-l/2) - oy, (-w/2) - ox) :
    (len(search(",", traj)) > 0) ?
        let(parts = str_split(traj, ","), tx = parse_val(parts[0]), ty = parse_val(parts[1]))
        atan2(ty, tx) :
    parse_val(traj);

function calc_touch_dist(angle, ox, oy, int_w, int_l, is_jar=false) =
    is_jar ?
        let(
            r = int_w / 2,
            vx = cos(angle), vy = sin(angle),
            a = 1,
            b = 2 * (ox * vx + oy * vy),
            c = (ox * ox) + (oy * oy) - (r * r),
            disc = b*b - 4*a*c,
            t = (disc >= 0) ? (-b + sqrt(disc)) / (2*a) : 999999
        )
        t > 0 ? t : 999999
    :
        let(
            vx = cos(angle), vy = sin(angle),
            tx = (vx > 0.0001) ? ((int_w/2) - ox) / vx :
                 (vx < -0.0001) ? ((-int_w/2) - ox) / vx : 999999,
            ty = (vy > 0.0001) ? ((int_l/2) - oy) / vy :
                 (vy < -0.0001) ? ((-int_l/2) - oy) / vy : 999999
        )
        min(tx > 0 ? tx : 999999, ty > 0 ? ty : 999999);

function get_rib_length(angle, beh, traj, ox, oy, int_w, int_l, is_jar=false) =
    let(
        t_dist = calc_touch_dist(angle, ox, oy, int_w, int_l, is_jar)
    )
    (beh == "T") ? t_dist :
    (beh == "D") ?
        (len(search(",", traj)) > 0 ?
            let(parts=str_split(traj, ","), tx = parse_val(parts[0]), ty = parse_val(parts[1]))
            norm([tx, ty]) : t_dist) :
    (beh[0] == "F") ?
        let(perc = to_num(get_digits(beh))) t_dist * (perc / 100) :
    t_dist;
