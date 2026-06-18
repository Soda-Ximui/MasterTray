// ==============================================================================
// FILE: MasterDebug.scad
// ARCHITECTURE: Layer 0 (Diagnostics)
// PURPOSE: Two-mode build parameter report, echoed to the OpenSCAD console.
//
//   dump_build_options(intent, data)
//     Human-readable report for quick inspection at the console.
//     Enable: debug_report = true in Customizer → [Advanced - Debug].
//
//   dump_build_payload(intent, data)
//     Pipe-delimited structured records for Perl + Template Toolkit.
//     Enable: debug_payload = true.
//     Parse pattern:
//       while (<$fh>) {
//           next unless /^ECHO: "(.+)"$/;
//           my ($tag,$sec,$key,$val,$unit,$src,$formula,$flags) = split /\|/, $1;
//           ...
//       }
//     Records: META | VALUE | AUTO | SPAN | WARN
//     Fields:  tag | section | key | value | unit | src_type | formula | flags
//       src_type: USER=Customizer slider  AUTO=derived  MATERIAL=tolerance table
//                 CLAMPED=hit a constraint  GUARD=safety floor
//       flags:    semicolon-list  e.g. DRIVES=sw;sf;chamfer;AFFECTS=snap_force
// ==============================================================================

// MasterEngine is included once by MasterBuilder.scad (single owner) — not re-included here [perf]
include <MasterTolerance.scad>
include <GridLayout.scad>

// ─────────────────────────────────────────────────────────────────────────────
// Shared computation — call once, pass results to both report modules.
// ─────────────────────────────────────────────────────────────────────────────
function _dbg_w(d)          = m_bw(d);
function _dbg_l(d)          = m_bl(d);
function _dbg_h(d)          = m_bh(d);
function _dbg_sf(d)         = m_safe_floor(d);
function _dbg_sw(d)         = m_safe_wall(d);
function _dbg_sl(d)         = m_safe_lid(d);
function _dbg_noz(d)        = m_noz(d);
function _dbg_lh(d)         = m_lh(d);
function _dbg_glide_tol(d)  = breathing_room(COMP_GLIDE, d);
function _dbg_cclip_tol(d)  = breathing_room(COMP_CCLIP, d);
function _dbg_spine_gap(d)  = breathing_room(COMP_SPINE, d);
function _dbg_clasp(d)      = engagement_depth(COMP_CLASP, d);
function _dbg_belly(d)      = engagement_depth(COMP_BELLY, d);

// ─────────────────────────────────────────────────────────────────────────────
// MODULE: dump_build_options — human-readable console report
// ─────────────────────────────────────────────────────────────────────────────
module dump_build_options(intent, data) {
    w   = _dbg_w(data);   l  = _dbg_l(data);   h  = _dbg_h(data);
    sf  = _dbg_sf(data);  sw = _dbg_sw(data);  sl = _dbg_sl(data);
    noz = _dbg_noz(data); lh = _dbg_lh(data);
    wl  = get_val(WALL_LOOPS, data, 2);
    fil = get_val("FILAMENT_TYPE", data, "PETG");
    fit = get_val("FIT_PROFILE",   data, "Standard");

    glide_tol   = _dbg_glide_tol(data);
    groove_w    = w - sw + 0.6;
    groove_h    = sl + glide_tol;
    groove_z    = h - sl - 1.0;
    ball_d      = glide_ball_d(w, l, sw, noz);
    ball_r      = ball_d / 2;
    ball_protr  = glide_ball_protr(ball_r, glide_tol, noz);
    ball_x      = groove_w / 2 + noz / 2;
    dimple_z    = groove_z + groove_h / 2;

    cclip_tol   = _dbg_cclip_tol(data);
    spine_gap   = _dbg_spine_gap(data);
    clasp_depth = _dbg_clasp(data);
    flat_belly  = _dbg_belly(data);
    clip_wall   = noz * 4;
    clip_od     = 4.0 + cclip_tol*2 + clip_wall*2;
    cc_z        = clip_od / 2;
    axle_z      = h - cc_z;
    clip_len    = flip_hinge_len(w, sw);
    latch_z     = flip_latch_z(h, cc_z, clasp_depth);

    g_str  = get_val(GRID_LAYOUT,   data, "");
    g_type = get_val(GRID_TYPE,     data, "None");
    div_t  = get_val(THICK_DIVIDER, data, 1.2);
    int_w  = w - sw*2;   int_l = l - sw*2;
    cfg    = get_grid_config(data);
    cols   = cfg[0][0];  rows  = cfg[0][1];
    cw     = (cols > 1) ? (int_w - div_t*(cols-1)) / cols : int_w;
    cl     = (rows > 1) ? (int_l - div_t*(rows-1)) / rows : int_l;
    spans  = cfg[2];
    rays   = cfg[1][0];  c_raw = cfg[1][1];  is_perc = cfg[1][2];
    hub_d  = is_perc ? int_w*(c_raw/100) : c_raw;
    gwall_h = get_val(GRID_WALL_H, data, h - sf);

    // ── Header ────────────────────────────────────────────────────────────
    echo("╔══════════════════════════════════════════════════════════════╗");
    echo("║              MASTERTRAY BUILD PARAMETER REPORT              ║");
    echo("╚══════════════════════════════════════════════════════════════╝");
    echo(str("  Intent: ", intent, "   Material: ", fil, "   Fit: ", fit));

    // ── User inputs ───────────────────────────────────────────────────────
    echo("── [USER INPUTS] ───────────────────────────────────────────────────");
    echo(str("  nozzle_d   = ", noz,    " mm  ← Nozzle Diameter"));
    echo(str("  layer_h    = ", lh,     " mm  ← Layer Height"));
    echo(str("  wall_loops = ", wl,          "    ← Wall Loops"));
    echo(str("  W×L×H      = ", w, "×", l, "×", h, " mm  ← Dimensions"));
    echo(str("  material   = ", fil, "   fit = ", fit, "   ← Material & Fit"));

    // ── Auto-sized geometry ───────────────────────────────────────────────
    echo("── [AUTO-SIZED — set by the system, no user action needed] ─────────");
    echo("   Physics snapping:");
    echo(str("     sw  = ", sw,   " mm  (wall thickness snapped to nozzle multiples)"));
    echo(str("     sf  = ", sf,   " mm  (floor thickness snapped to layer-height multiples)"));
    echo(str("     sl  = ", sl,   " mm  (lid thickness snapped to layer-height multiples)"));
    echo("   Glide lid mechanism:");
    echo(str("     groove_w   = ", groove_w,   " mm  (sized to span side walls with clearance)"));
    echo(str("     groove_h   = ", groove_h,   " mm  (sl + glide tolerance = lid + play)"));
    echo(str("     groove_z   = ", groove_z,   " mm  (lid recessed 1 mm below box rim)"));
    echo(str("     ball_d     = ", ball_d,     " mm  (3% of max(W,L), cap sw×2 — scales with box)"));
    echo(str("     ball_protr = ", ball_protr, " mm  (positions ball noz/2 past groove wall)"));
    echo(str("     ball_x     = ±", ball_x,   " mm  (ball centre — lid and box match automatically)"));
    echo(str("     dimple_z   = ", dimple_z,  " mm  (groove centre — ball aligns when lid seated)"));
    echo("   Flip hinge mechanism:");
    echo(str("     clip_od  = ", clip_od,     " mm  (C-clip outer dia from nozzle + tolerance)"));
    echo(str("     axle_z   = ", axle_z,      " mm  (axle pin height derived from clip geometry)"));
    echo(str("     clip_len = ", clip_len,    " mm  (hinge span = clamp(w×",
             HINGE_WIDTH_PERCENT0, ", min ", MIN_HINGE_WIDTH0, ", max w−sw×6)",
             clip_len <= 0 ? "  ⚠ TOO NARROW — hinge suppressed" : "  ✓ fits", ")"));
    echo(str("     latch_z  = ", latch_z,     " mm  (latch recess aligned to lid tip when closed)"));
    echo("   Grid:");
    echo(str("     int_w×int_l = ", int_w, "×", int_l, " mm  (interior = W/L − sw×2)"));
    echo(str("     cell w×l    = ", cw, "×", cl, " mm  (auto from layout cols×rows)"));
    echo(str("     GRID_WALL_H = ", gwall_h,  " mm  (injected by factory — flip: axle_z, jar: cyl_wall_h, plain: h−sf−sl)"));
    if (len(spans) > 0) {
        echo("     Span heights (auto-clamped to GRID_WALL_H):");
        for (i = [0 : len(spans)-1]) {
            s = spans[i];
            c = (s[4] < s[5]) ? str("CLAMPED from ", s[5], " mm") : "OK";
            echo(str("       [", i+1, "] S", s[0], "/", s[1], "/", s[2], "/", s[3],
                     " → h=", s[4], " mm  (", c, ")"));
        }
    }
    if (rays > 0)
        echo(str("     hub_d = ", hub_d, " mm  (", (hub_d - div_t*2 >= 1.5 ? "hollow ring" : "solid knob"), ")"));

    // ── Tolerances ────────────────────────────────────────────────────────
    echo("── [TOLERANCES — set by Material + Fit Profile sliders] ────────────");
    echo(str("  glide_tol   = ", glide_tol,   " mm  (ROOM_GLIDE_", fil, ")  → groove_h, lid_w, ball_protr"));
    echo(str("  cclip_tol   = ", cclip_tol,   " mm  (ROOM_CCLIP_", fil, ")  → clip bore, bore recess"));
    echo(str("  spine_gap   = ", spine_gap,   " mm  (ROOM_SPINE_", fil, ")  → double-flip hinge spacing"));
    echo(str("  clasp_depth = ", clasp_depth, " mm  (ENG_CLASP_",  fil, ")  → latch_z, diamond tip"));
    echo(str("  flat_belly  = ", flat_belly,  " mm  (ENG_BELLY_",  fil, ")  → C-clip opening gap"));
    echo(str("  fit_mod     = ", get_fit_mod(data), "  (Tighter=−2 .. Looser=+2)"));
    echo("════════════════════════════════════════════════════════════════════");
}

// ─────────────────────────────────────────────────────────────────────────────
// MODULE: dump_build_payload — pipe-delimited records for Perl + Template Toolkit
//
// Record format (8 fields, pipe-delimited):
//   TAG | SECTION | KEY | VALUE | UNIT | SRC_TYPE | FORMULA | FLAGS
//
// TAG values:
//   META   — report header / intent metadata
//   VALUE  — user-controlled Customizer input
//   AUTO   — auto-sized / derived value (no user action needed)
//   SPAN   — one span entry from GRID_LAYOUT string
//   WARN   — constraint hit or geometry issue
//   SEP    — section separator (decorative, skip in parsing)
//
// SRC_TYPE values:
//   USER       — set directly by a Customizer slider
//   DERIVED    — auto-snapped from a user input (e.g. sw from wall_thickness)
//   AUTOSIZE   — auto-sized formula from box dimensions
//   MATERIAL   — tolerance table lookup (ROOM_* / ENG_*)
//   COMPUTED   — derived from other computed values
//   CLAMPED    — hit a constraint ceiling / floor
//
// FLAGS: semicolon-separated  e.g. "DRIVES=sw;sl;chamfer;AFFECTS=snap_force"
//
// Perl parsing skeleton:
//   while (<$fh>) {
//       next unless /^ECHO: "(.+)"$/;
//       my @f = split /\|/, $1, 8;
//       next unless $f[0] =~ /^(META|VALUE|AUTO|SPAN|WARN)$/;
//       push @{ $data{$f[1]} }, {
//           tag=>$f[0], key=>$f[2], value=>$f[3], unit=>$f[4],
//           src=>$f[5], formula=>$f[6], flags=>$f[7] };
//   }
// ─────────────────────────────────────────────────────────────────────────────
module dump_build_payload(intent, data) {
    w   = _dbg_w(data);   l  = _dbg_l(data);   h  = _dbg_h(data);
    sf  = _dbg_sf(data);  sw = _dbg_sw(data);  sl = _dbg_sl(data);
    noz = _dbg_noz(data); lh = _dbg_lh(data);
    wl  = get_val(WALL_LOOPS, data, 2);
    fil = get_val("FILAMENT_TYPE", data, "PETG");
    fit = get_val("FIT_PROFILE",   data, "Standard");
    ver = get_val(BUILDER_VERSION, data, "?");
    dim_mode = get_val(DIMENSION_MODE, data, "Total");

    glide_tol   = _dbg_glide_tol(data);
    groove_w    = w - sw + 0.6;
    groove_h    = sl + glide_tol;
    groove_z    = h - sl - 1.0;
    ball_d      = glide_ball_d(w, l, sw, noz);
    ball_r      = ball_d / 2;
    ball_protr  = glide_ball_protr(ball_r, glide_tol, noz);
    ball_x      = groove_w / 2 + noz / 2;
    dimple_z    = groove_z + groove_h / 2;

    cclip_tol   = _dbg_cclip_tol(data);
    spine_gap   = _dbg_spine_gap(data);
    clasp_depth = _dbg_clasp(data);
    flat_belly  = _dbg_belly(data);
    clip_wall   = noz * 4;
    clip_od     = 4.0 + cclip_tol*2 + clip_wall*2;
    cc_z        = clip_od / 2;
    axle_z      = h - cc_z;
    clip_len    = flip_hinge_len(w, sw);
    latch_z     = flip_latch_z(h, cc_z, clasp_depth);
    hinge_y_s   = cc_z;
    hinge_y_d   = cc_z + spine_gap;

    g_str  = get_val(GRID_LAYOUT,   data, "");
    g_type = get_val(GRID_TYPE,     data, "None");
    div_t  = get_val(THICK_DIVIDER, data, 1.2);
    int_w  = w - sw*2;   int_l = l - sw*2;
    cfg    = get_grid_config(data);
    cols   = cfg[0][0];  rows  = cfg[0][1];
    cw     = (cols > 1) ? (int_w - div_t*(cols-1)) / cols : int_w;
    cl     = (rows > 1) ? (int_l - div_t*(rows-1)) / rows : int_l;
    spans  = cfg[2];
    rays   = cfg[1][0];  c_raw = cfg[1][1];  is_perc = cfg[1][2];
    hub_d  = is_perc ? int_w*(c_raw/100) : c_raw;
    gwall_h = get_val(GRID_WALL_H, data, h - sf);
    fit_mod = get_fit_mod(data);

    // ── Report header ─────────────────────────────────────────────────────
    echo("META|REPORT|intent|",         intent,   "|||intent string passed to compile_manifest|");
    echo(str("META|REPORT|material|",   fil,      "|||Filament_Type slider|"));
    echo(str("META|REPORT|fit_profile|",fit,      "|||Mechanical_Fit slider|"));
    echo(str("META|REPORT|fit_mod|",    fit_mod,  "||COMPUTED|Tighter=-2 Tight=-1 Standard=0 Loose=1 Looser=2|"));
    echo(str("META|REPORT|builder_ver|",ver,      "|||injected by MasterBuilder|"));
    echo(str("META|REPORT|dim_mode|",   dim_mode, "|||Total or Usable|"));

    // Intent-type flags — consumed by Perl slicer-settings generator.
    // Perl: grep { $_->{sec} eq 'INTENT' } @meta  to read these.
    has_flip   = ( intent == "Flip Box"     || intent == "1-Day AM/PM Box"  ||
                   intent == "7-Day Pill Box"|| intent == "14-Day AM/PM Box" ||
                   intent == "Pillbox Set (Double Lid)" || intent == "Pillbox Set (Single Lid)" ||
                   intent == "Pillbox Full Set" );
    has_glide  = ( intent == "Standalone Box" );
    has_threads= ( intent == "Threaded Jar"  || intent == "Jar with Lid"    ||
                   intent == "S4 Jar"        || intent == "Spool Jar"       ||
                   intent == "S4 Set" );
    is_jar     = ( intent == "Open Jar"      || intent == "Simple Jar"      ||
                   has_threads );
    has_lid    = ( has_flip || has_glide || intent == "Box"                 ||
                   has_threads || intent == "Jar with Lid" );
    cyl_wall_h = is_jar ? max(0.1, h - m_safe_floor(data) - 8.0 - m_safe_wall(data)*1.5) : 0;
    // Mechanism zone start Z — where layer height should drop for accuracy
    mech_z     = has_flip  ? max(0, axle_z - clip_od) :
                 has_glide ? groove_z                  :
                 has_threads ? cyl_wall_h              :
                 h - sl * 3;   // snap/plain: just the top zone
    echo(str("META|INTENT|has_flip|",    (has_flip    ? "1" : "0"), "|||derived from intent name|"));
    echo(str("META|INTENT|has_glide|",   (has_glide   ? "1" : "0"), "|||derived from intent name|"));
    echo(str("META|INTENT|has_threads|", (has_threads ? "1" : "0"), "|||derived from intent name|"));
    echo(str("META|INTENT|is_jar|",      (is_jar      ? "1" : "0"), "|||derived from intent name|"));
    echo(str("META|INTENT|has_lid|",     (has_lid     ? "1" : "0"), "|||derived from intent name|"));

    // Slicer variable-layer zone boundaries (all in mm from build plate)
    echo(str("META|SLICER|z_floor_end|",  sf,     "|mm|COMPUTED|safe_floor|Floor zone: fine layers for bond strength"));
    echo(str("META|SLICER|z_body_end|",   mech_z, "|mm|COMPUTED|mech_zone_start|Body zone: fast standard layers"));
    echo(str("META|SLICER|z_mech_start|", mech_z, "|mm|COMPUTED|h-mechanism_depth|Mechanism zone: fine layers for fit"));
    echo(str("META|SLICER|z_top|",        h,      "|mm|COMPUTED|box_height|Top of container"));
    echo(str("META|SLICER|lh_floor|",     lh <= 0.20 ? lh : 0.16,  "|mm|RECOMMEND|fine_for_strength|"));
    echo(str("META|SLICER|lh_body|",      lh,     "|mm|RECOMMEND|user_layer_height|"));
    echo(str("META|SLICER|lh_mech|",      lh <= 0.16 ? lh : 0.16,  "|mm|RECOMMEND|fine_for_accuracy|"));
    echo(str("META|SLICER|lh_lid_face|",  lh <= 0.16 ? lh : 0.12,  "|mm|RECOMMEND|finest_for_visible_face|Lid printed face-down"));

    // ── Printer / physics: user inputs ────────────────────────────────────
    echo(str("VALUE|PHYSICS|nozzle_d|",  noz, "|mm|USER|Nozzle Diameter slider|DRIVES=sw;clip_wall;chamfer;strut_min"));
    echo(str("VALUE|PHYSICS|layer_h|",   lh,  "|mm|USER|Layer Height slider|DRIVES=sf;sl;layer-snap"));
    echo(str("VALUE|PHYSICS|wall_loops|",wl,  "||USER|Wall Loops slider|DRIVES=sw_minimum"));

    // ── Printer / physics: auto-snapped ───────────────────────────────────
    echo(str("AUTO|PHYSICS|sw|", sw, "|mm|DERIVED|round(wall_thickness/noz)*noz|DRIVES=groove_w;groove_depth;boss_d;chamfer;clip_len"));
    echo(str("AUTO|PHYSICS|sf|", sf, "|mm|DERIVED|round(floor_thickness/lh)*lh|DRIVES=floor_geometry;grid_start_z"));
    echo(str("AUTO|PHYSICS|sl|", sl, "|mm|DERIVED|round(lid_thickness/lh)*lh|DRIVES=groove_h;latch_z;lid_body"));

    // ── Container ─────────────────────────────────────────────────────────
    echo(str("VALUE|CONTAINER|w|",        w, "|mm|USER|part_width (+ sw*2 if Usable)|AFFECTS=groove_w;int_w;ball_d"));
    echo(str("VALUE|CONTAINER|l|",        l, "|mm|USER|part_length|AFFECTS=int_l;ball_d"));
    echo(str("VALUE|CONTAINER|h|",        h, "|mm|USER|part_height (+ sf+sl if Usable)|AFFECTS=axle_z;latch_z;groove_z;gwall_h"));

    // ── Auto-sized: glide lid ─────────────────────────────────────────────
    echo(str("AUTO|GLIDE|groove_w|",    groove_w,   "|mm|COMPUTED|w-sw+0.6|AFFECTS=lid_w;ball_x"));
    echo(str("AUTO|GLIDE|groove_h|",    groove_h,   "|mm|COMPUTED|sl+glide_tol|AFFECTS=vertical_lid_play"));
    echo(str("AUTO|GLIDE|groove_z|",    groove_z,   "|mm|COMPUTED|h-sl-1.0|NOTE=lid_recessed_1mm_below_rim"));
    echo(str("AUTO|GLIDE|ball_d|",      ball_d,     "|mm|AUTOSIZE|min(sw*2,max(noz*5,max(w,l)*0.03))|AFFECTS=snap_force;dimple_depth"));
    echo(str("AUTO|GLIDE|ball_r|",      ball_r,     "|mm|COMPUTED|ball_d/2|"));
    echo(str("AUTO|GLIDE|ball_protr|",  ball_protr, "|mm|AUTOSIZE|ball_r-(glide_tol+noz)/2|AFFECTS=cam_entry_force;ball_x"));
    echo(str("AUTO|GLIDE|ball_x|",      ball_x,     "|mm|COMPUTED|groove_w/2+noz/2|NOTE=from_box_centre;lid_and_box_match"));
    echo(str("AUTO|GLIDE|dimple_z|",    dimple_z,   "|mm|COMPUTED|groove_z+groove_h/2|NOTE=groove_centre;ball_aligns_when_seated"));

    // ── Auto-sized: glide tolerances ──────────────────────────────────────
    echo(str("AUTO|GLIDE|glide_tol|",   glide_tol,  "|mm|MATERIAL|ROOM_GLIDE_", fil, "+fit_mod*STEP_ROOM|DRIVES=groove_h;lid_width;ball_protr"));

    // ── Auto-sized: flip hinge ────────────────────────────────────────────
    echo(str("AUTO|FLIP|cclip_tol|",    cclip_tol,  "|mm|MATERIAL|ROOM_CCLIP_", fil, "+fit_mod*STEP_ROOM|DRIVES=clip_od;bore_recess"));
    echo(str("AUTO|FLIP|clip_wall|",    clip_wall,  "|mm|COMPUTED|noz*4|DRIVES=clip_od"));
    echo(str("AUTO|FLIP|clip_od|",      clip_od,    "|mm|COMPUTED|4.0+cclip*2+clip_wall*2|DRIVES=cc_z;axle_z;hinge_y;gwall_h"));
    echo(str("AUTO|FLIP|cc_z|",         cc_z,       "|mm|COMPUTED|clip_od/2|DRIVES=axle_z;latch_z;hinge_y"));
    echo(str("AUTO|FLIP|axle_z|",       axle_z,     "|mm|COMPUTED|h-cc_z|DRIVES=hinge_pillars;gwall_h_flipbox"));
    echo(str("AUTO|FLIP|clip_len|",     clip_len,   "|mm|COMPUTED|clamp(w*", HINGE_WIDTH_PERCENT0, ", min ", MIN_HINGE_WIDTH0, ", max w-sw*6)|NOTE=hinge_span;guard=must_be_positive"));
    echo(str("AUTO|FLIP|clasp_depth|",  clasp_depth,"|mm|MATERIAL|ENG_CLASP_", fil, "-fit_mod*STEP_ENG|DRIVES=latch_z;lid_diamond_tip"));
    echo(str("AUTO|FLIP|flat_belly|",   flat_belly, "|mm|MATERIAL|ENG_BELLY_", fil, "|DRIVES=c_clip_opening_gap"));
    echo(str("AUTO|FLIP|latch_z|",      latch_z,    "|mm|COMPUTED|flip_latch_z(h,cc_z,clasp)|NOTE=recess_aligns_lid_tip_when_closed"));
    echo(str("AUTO|FLIP|hinge_y_single|",hinge_y_s, "|mm|COMPUTED|cc_z|NOTE=axle_Y_offset_single_flip"));
    echo(str("AUTO|FLIP|hinge_y_double|",hinge_y_d, "|mm|COMPUTED|cc_z+spine_gap|NOTE=axle_Y_offset_double_flip"));
    echo(str("AUTO|FLIP|spine_gap|",    spine_gap,  "|mm|MATERIAL|ROOM_SPINE_", fil, "+fit_mod*STEP_ROOM|DRIVES=hinge_y_double"));

    // ── Auto-sized: grid ─────────────────────────────────────────────────
    echo(str("VALUE|GRID|layout|",      g_str,  "||USER|grid_layout Customizer field|DRIVES=cols;rows;spans;radial"));
    echo(str("VALUE|GRID|type|",        g_type, "||USER|grid_type Customizer field (Built-in/Drop-in/None)|"));
    echo(str("VALUE|GRID|div_t|",       div_t,  "|mm|USER|divider_thickness slider|DRIVES=cell_dims;span_size"));
    echo(str("AUTO|GRID|int_w|",        int_w,  "|mm|COMPUTED|w-sw*2|DRIVES=cell_w;span_w"));
    echo(str("AUTO|GRID|int_l|",        int_l,  "|mm|COMPUTED|l-sw*2|DRIVES=cell_l;span_l"));
    echo(str("AUTO|GRID|cols|",         cols,   "||COMPUTED|parse_cartesian(layout)|"));
    echo(str("AUTO|GRID|rows|",         rows,   "||COMPUTED|parse_cartesian(layout)|"));
    echo(str("AUTO|GRID|cell_w|",       cw,     "|mm|COMPUTED|(int_w-div_t*(cols-1))/cols|"));
    echo(str("AUTO|GRID|cell_l|",       cl,     "|mm|COMPUTED|(int_l-div_t*(rows-1))/rows|"));
    echo(str("AUTO|GRID|gwall_h|",      gwall_h,"|mm|COMPUTED|GRID_WALL_H injected by factory|NOTE=flip:axle_z;jar:cyl_wall_h;plain:h-sf-sl"));
    echo(str("AUTO|GRID|rays|",         rays,   "||COMPUTED|parse_radial(layout)|NOTE=jar_only;ignored_for_box_tray"));
    if (rays > 0) {
        echo(str("AUTO|GRID|hub_d|",    hub_d,  "|mm|COMPUTED|", (is_perc ? str("int_w*",c_raw,"/100") : str(c_raw,"mm_absolute")),
                 "|NOTE=", (hub_d - div_t*2 >= 1.5 ? "hollow_ring" : "solid_knob")));
    }

    // ── Spans ─────────────────────────────────────────────────────────────
    for (i = [0 : len(spans)-1]) {
        s = spans[i];
        clamped = (s[4] < s[5]) ? "CLAMPED" : "OK";
        echo(str("SPAN|GRID|span_", i+1, "|",
                 s[0], "/", s[1], "/", s[2], "/", s[3],
                 "|mm|", clamped,
                 "|row=", s[0], ";col=", s[1], ";row_span=", s[2], ";col_span=", s[3],
                 ";h_final=", s[4], ";h_requested=", s[5],
                 "|", (s[4] < s[5] ? str("REDUCED_BY=", s[5]-s[4], "mm") : "WITHIN_LIMITS")));
    }

    // ── Warnings ─────────────────────────────────────────────────────────
    if (clip_len <= 0)
        echo(str("WARN|FLIP|clip_len|", clip_len, "|mm|GUARD|w-sw*6 <= 0 — hinge suppressed|INCREASE_W_or_REDUCE_WALL_LOOPS"));
    if (ball_protr <= 0)
        echo(str("WARN|GLIDE|ball_protr|", ball_protr, "|mm|GUARD|ball_r-(glide_tol+noz)/2 <= 0 — no snap|CHECK_GLIDE_TOLERANCE"));
    if (len(spans) > 0)
        for (i = [0 : len(spans)-1]) {
            s = spans[i];
            if (s[4] < s[5])
                echo(str("WARN|GRID|span_", i+1, "_clamped|", s[5]-s[4], "|mm|CLAMPED|",
                          "requested ", s[5], "mm but container only allows ", s[4], "mm|",
                          "REDUCE_SPAN_HEIGHT_or_INCREASE_BOX_HEIGHT"));
        }

    echo("META|REPORT|payload_end|||OK||");
}
