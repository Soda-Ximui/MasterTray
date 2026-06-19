// ==============================================================================
// FILE: MasterManifest.scad
// ARCHITECTURE: Layer 2 (Build Intent Compiler)
// PURPOSE: Translates user intent string into a typed manifest array.
// ==============================================================================
// compile_manifest(intent, data) is the single source of truth for what gets
// built. Each manifest item is a tuple: [type, data, opts, phys].
//
//   type  — dispatch key: "TRAY", "BOX", "FLIP_BOX", "DOUBLE_FLIP_BOX",
//            "JAR", "LID", "GRID", "PLAQUE"
//   data  — the full ui_payload key-value array
//   opts  — per-component options array (IS_THREADED, LID_TYPE, etc.)
//   phys  — computed FDM physics: [SAFE_WALL, SAFE_FLOOR, CLEARANCE, NOZZLE]
//
// Adding a new part type: add a branch here, add a factory in the appropriate
// Render*.scad, and add a dispatch case in MasterBuilder.scad.
// ==============================================================================

// MasterEngine is included once by MasterBuilder.scad (single owner) — not re-included here [perf]
include <MasterProcessor.scad>
include <GridLayout.scad>

// has_grid — true when grid_layout is non-empty and valid.
function has_grid(data) =
  let(g = m_grid_layout(data))
  g != "" && is_valid_grid_layout(g) && grid_bounds_ok(g, data);

// grid_variants — when grid_layout is present, returns two drop-in GRID entries:
//   one without a base plate and one with.
// The drop-in grid has no surrounding walls — just dividers (+ optional base).
// Call once per jar size for W≠L jars (prepend WIDTH to data before calling).
// is_jar=true clips the grid to a circular boundary and enables radial tokens.
// Returns [] when grid_layout is absent or invalid — safe to call unconditionally.
function grid_variants(data, phys, is_jar=false) =
  !has_grid(data) ? [] :
  let(opts = is_jar ? [[IS_JAR_GRID, true]] : [])
  [
    ["GRID", concat([[GRID_HAS_BASE, false]], data), opts, phys],
    ["GRID", concat([[GRID_HAS_BASE, true]],  data), opts, phys]
  ];

// box_lid_variant — shared skeleton for the single-mechanism box intents
// (Snap/Glide × External/Rabbet, plus Flip Single). Emits a box + its matching
// lid, and a second built-in-grid box when a grid layout is present. Collapses
// five formerly copy-pasted branches in compile_manifest into one definition.
//   lid_type — "Snap" | "Glide" | "Flip_Single"
//   style    — "External" (over-wall groove) | "Rabbet" (inside-wall groove)
function box_lid_variant(lid_type, style, data) =
  let(phys = get_physics_profile(data),
      hg   = has_grid(data),
      sty  = [LID_STYLE, style],
      d0   = concat([[HAS_BUILTIN_GRID, false], sty], data),
      d1   = concat([[HAS_BUILTIN_GRID, true],  sty], data),
      dl   = concat([sty], data))
  concat(
    [["BOX", d0, [["LID_TYPE", lid_type]], phys],
     ["LID", dl, [["LID_TYPE", lid_type]], phys]],
    hg ? [["BOX", d1, [["LID_TYPE", lid_type]], phys]] : []
  );

// Desiccant mesh overrides — prepended to data so they take priority over Customizer.
// rect: box/wedge surfaces.   cyl: jar surfaces.
DESICCANT_MESH_RECT = [
    [PATTERN,      TEARDROP],
    [HOLE_WALL,    1.8], [HOLE_FLOOR,  1.8], [HOLE_LID,   1.8],
    [HOLE_SPACING, 1.2],
    [STRUT_WALL,   20],  [STRUT_FLOOR, 25],  [STRUT_LID,  10]
];
DESICCANT_MESH_CYL = [
    [PATTERN,      TEARDROP],
    [HOLE_WALL,    1.8], [HOLE_FLOOR,  1.8], [HOLE_LID,   1.8],
    [HOLE_SPACING, 1.2],
    [STRUT_WALL,   15],  [STRUT_FLOOR, 15],  [STRUT_LID,  15]
];

// Maps jar_shape string → polygon side count. 0 = full circle ($fn from global).
function jar_sides(data) =
  let(s = get_val(JAR_SHAPE, data, "Circle"))
  (s == "Quad")   ? 4  :
  (s == "Hexa")   ? 6  :
  (s == "Octa")   ? 8  :
  (s == "Dodeca") ? 12 :
  0;

function jar_opts(base, data) = concat(base, [["JAR_SIDES", jar_sides(data)]]);

// FLIP-LID GEOMETRY MOVED OUT OF THIS LAYER [review #3/#7]
// flip_half_lid_l() — a tolerance-derived dimension — now lives in
// MasterTolerance.scad (Layer 1.8), next to its dependency breathing_room().
// It is still called from the flip branches below (functions are global), but
// no longer DEFINED in the intent compiler. flip_hinge_y() was dead code
// (defined, never called) and has been deleted.
//
// FROZEN: flip lids failed their print test (sideways slide on the C-clip,
// weak latch retention). The live small-organizer path is the Glide pillbox.
// The branches below stay because the build matrix still exercises them; do
// NOT extend flip geometry without a deliberate mechanical redesign.

function compile_manifest(intent, data) =

  // ── JAR PRIVATE INTENTS ─────────────────────────────────────────────────────
  // "Open Jar"    — accessible top: plain + built-in grid + drop-in grids.
  // "Threaded Jar" — screw lid always on: plain + built-in grid. NO drop-in
  //                  (insert can't be accessed through the screw neck).
  // W≠L: both diameters built. Screw lid is diameter-independent → emitted once.

  (intent == "Open Jar") ?
    let(w    = get_val(WIDTH, data, WIDTH0), l = get_val(LENGTH, data, LENGTH0),
        phys = get_physics_profile(data),
        hg   = has_grid(data),
        d0   = concat([[HAS_BUILTIN_GRID, false]], data),
        d1   = concat([[HAS_BUILTIN_GRID, true]],  data))
    concat(
      (w == l) ? [
        ["JAR", d0, jar_opts([["IS_THREADED", false]], data), phys]
      ] : [
        ["JAR", concat([[WIDTH, w]], d0), jar_opts([["IS_THREADED", false]], data), phys],
        ["JAR", concat([[WIDTH, l]], d0), jar_opts([["IS_THREADED", false]], data), phys]
      ],
      hg ? (w == l ? [
        ["JAR", d1, jar_opts([["IS_THREADED", false]], data), phys]
      ] : [
        ["JAR", concat([[WIDTH, w]], d1), jar_opts([["IS_THREADED", false]], data), phys],
        ["JAR", concat([[WIDTH, l]], d1), jar_opts([["IS_THREADED", false]], data), phys]
      ]) : [],
      // Drop-in circular clip grids — open top means inserts are usable
      w == l
        ? grid_variants(data, phys, true)
        : concat(grid_variants(concat([[WIDTH, w]], data), phys, true),
                 grid_variants(concat([[WIDTH, l]], data), phys, true))
    )
  :
  (intent == "Threaded Jar") ?
    let(w    = get_val(WIDTH, data, WIDTH0), l = get_val(LENGTH, data, LENGTH0),
        phys = get_physics_profile(data),
        hg   = has_grid(data),
        d0   = concat([[HAS_BUILTIN_GRID, false]], data),
        d1   = concat([[HAS_BUILTIN_GRID, true]],  data))
    concat(
      (w == l) ? [
        ["JAR", d0,   jar_opts([["IS_THREADED", true]], data), phys],
        ["LID", data, [["LID_TYPE", "Screw"]],                 phys]
      ] : [
        ["JAR", concat([[WIDTH, w]], d0), jar_opts([["IS_THREADED", true]], data), phys],
        ["JAR", concat([[WIDTH, l]], d0), jar_opts([["IS_THREADED", true]], data), phys],
        ["LID", data,                     [["LID_TYPE", "Screw"]],                phys]
      ],
      hg ? (w == l ? [
        ["JAR", d1, jar_opts([["IS_THREADED", true]], data), phys]
      ] : [
        ["JAR", concat([[WIDTH, w]], d1), jar_opts([["IS_THREADED", true]], data), phys],
        ["JAR", concat([[WIDTH, l]], d1), jar_opts([["IS_THREADED", true]], data), phys]
      ]) : []
      // No drop-in grids — screw lid blocks insert access
    )
  :

  // ── JAR PUBLIC AGGREGATOR ────────────────────────────────────────────────────
  // "Jar" dispatches to the private intent based on the Jar_Lid checkbox.
  // Legacy names forward cleanly.
  (intent == "Jar") ?
    get_val(JAR_WITH_LID, data, false)
      ? compile_manifest("Threaded Jar", data)
      : compile_manifest("Open Jar",     data)
  :
  // Legacy aliases
  (intent == "Jar with Lid" || intent == "Simple Jar") ?
    compile_manifest("Threaded Jar", data)
  :

  // ── BOX / TRAY PRIVATE INTENTS ─────────────────────────────────────────────
  // Each is self-contained: box + lid + built-in grid variant (if grid_layout set).
  // Drop-in grid variants are NOT emitted here — they are shared decoration and
  // emitted once by the public aggregator intents (Box, Simple Tray).
  // These may be exposed in the Customizer dropdown individually in the future.

  // --- Single-mechanism box variants (table-driven; see box_lid_variant) ---
  // Snap/Glide × External/Rabbet and Flip Single all share one skeleton:
  // box + matching lid (+ built-in-grid box when a grid layout is present).
  (intent == "Snap Box (External)")  ? box_lid_variant("Snap",        "External", data) :
  (intent == "Snap Box (Internal)")  ? box_lid_variant("Snap",        "Rabbet",   data) :
  (intent == "Glide Box (External)") ? box_lid_variant("Glide",       "External", data) :
  (intent == "Glide Box (Internal)") ? box_lid_variant("Glide",       "Rabbet",   data) :
  (intent == "Flip Box" || intent == "Flip Box (Single)")
                                     ? box_lid_variant("Flip_Single", "External", data) :
  (intent == "Double Flip Box" || intent == "Flip Box (Double)") ?
    let(phys  = get_physics_profile(data), hg = has_grid(data),
        ext   = [LID_STYLE, "External"],
        lid_l = flip_half_lid_l(data),
        d0    = concat([[HAS_BUILTIN_GRID, false], ext], data),
        d1    = concat([[HAS_BUILTIN_GRID, true],  ext], data),
        dl    = concat([ext], data))
    concat(
      [["BOX", d0,                               [["LID_TYPE", "Flip_Double"]], phys],
       ["LID", concat([[LENGTH, lid_l]], dl),    [["LID_TYPE", "Flip_Single"]], phys],
       ["LID", concat([[LENGTH, lid_l]], dl),    [["LID_TYPE", "Flip_Single"]], phys]],
      hg ? [["BOX", d1, [["LID_TYPE", "Flip_Double"]], phys]] : []
    )
  :

  // --- Stackable tray variants ---
  (intent == "Stackable Tray (Nesting)") ?
    let(phys = get_physics_profile(data))
    [["TRAY", data, [[STACKABLE, true], [STACK_MODE, "Snap"]], phys]]
  :
  (intent == "Stackable Tray (Peg)") ?
    let(phys = get_physics_profile(data))
    concat(
      [["TRAY", data, [[STACKABLE, true], [STACK_MODE, "Peg"]], phys]],
      [for (i = [0:3]) ["PEG", data, [], phys]]
    )
  :
  // --- PILL BOX INTENTS ---
  // Box with an N-column internal grid + a single Glide lid covering the whole top.
  // Compartment labels are not engraved — add them post-print (e.g. in the slicer).
  (intent == "1-Day AM/PM Box") ?
    compile_manifest("7-Day AM/PM Box", concat([[PILLBOX_DAYS, 1]], data))
  :
  (intent == "1-Day 2-Compartment (Single Lid)") ?
    let(phys = get_physics_profile(data),
        w = get_val(WIDTH, data, WIDTH0),
        box_d = concat([[GRID_LAYOUT, "2x1"], [HAS_BUILTIN_GRID, true], [SKIP_PILLARS, true]], data))
    [
      ["BOX", box_d,                                                     [["LID_TYPE", "Flip_Single"]], phys],
      ["LID", concat([[WIDTH, w - 0.6], [PLAQUE_TEXT, "AM / PM"]], data), [["LID_TYPE", "Flip_Single"]], phys]
    ]
  :
  (intent == "7-Day Pill Box") ?
    let(phys = get_physics_profile(data),
        days = max(1, min(7, get_val(PILLBOX_DAYS, data, 7))),
        // GLIDE_SNAP="Tab": tab stop on lid trailing edge — no ball-boss geometry on box
        // so the box stays a single manifold component (ball-snap boss causes CGAL disconnect).
        box_d = concat([[GRID_LAYOUT, str(days, "x1")], [HAS_BUILTIN_GRID, true],
                         [GLIDE_SNAP, "Tab"]], data))
    [
      ["BOX", box_d, [["LID_TYPE", "Glide"]], phys],
      ["LID", box_d, [["LID_TYPE", "Glide"]], phys]
    ]
  :
  (intent == "7-Day AM/PM Box") ?
    let(phys = get_physics_profile(data),
        days = max(1, min(7, get_val(PILLBOX_DAYS, data, 7))),
        box_d = concat([[GRID_LAYOUT, str(days, "x2")], [HAS_BUILTIN_GRID, true],
                         [GLIDE_SNAP, "Tab"]], data))
    [
      ["BOX", box_d, [["LID_TYPE", "Glide"]], phys],
      ["LID", box_d, [["LID_TYPE", "Glide"]], phys]
    ]
  :
  (intent == "Pillbox Set (Double Lid)") ?
    concat(compile_manifest("7-Day AM/PM Box", data), compile_manifest("1-Day AM/PM Box", data))
  :
  (intent == "Pillbox Set (Single Lid)") ?
    concat(compile_manifest("7-Day Pill Box", data), compile_manifest("1-Day AM/PM Box", data))
  :
  (intent == "Pillbox Full Set") ?
    concat(compile_manifest("7-Day AM/PM Box", data), compile_manifest("7-Day Pill Box", data), compile_manifest("1-Day AM/PM Box", data))
  :
  // ── STANDALONE LID ─────────────────────────────────────────────────────────
  // Builds one lid of the selected type. Useful for reprinting a lost lid or
  // testing fit. LID_TYPE_SEL from Customizer selects the type; LID_STYLE selects
  // External (over-wall groove) vs Rabbet (inside-wall groove) for Snap/Glide.
  // Glide also reads GLIDE_DIR and GLIDE_SNAP from the Customizer as normal.
  //
  // Flip_Single: pass part_length = your box length. The renderer subtracts
  //   clip_outer_d internally, so the lid body + hinge assembly = box length exactly.
  //
  // Flip_Double: emits TWO lids at flip_half_lid_l each (box_length/2 - spine_gap).
  //   spine_gap = breathing_room(COMP_SPINE, data) — filament-driven, not hardcoded.
  //   Pass part_length = your full box length; the system divides and subtracts for you.
  (intent == "Lid") ?
    let(phys     = get_physics_profile(data),
        lid_type = get_val(LID_TYPE_SEL, data, "Flip_Single"),
        half_l   = flip_half_lid_l(data))
    // Flip_Double's two half-lids are mirror images: each one's hinge sits at the
    // box's centre spine and its latch engages the opposite outer wall. The
    // Flip_Single renderer always puts the C-clip hinge on local +Y and the
    // latch arm on local -Y, so the second half must be rotated 180° about Z to
    // swap those ends — otherwise its latch points into the spine gap (no wall
    // to engage) instead of at its outer wall ("open cantilever").
    (lid_type == "Flip_Double")
        ? [["LID", concat([[LENGTH, half_l]], data), [["LID_TYPE", "Flip_Single"]], phys],
           ["LID", concat([[LENGTH, half_l]], data), [["LID_TYPE", "Flip_Single"], ["ROTATE_180", true]], phys]]
        : [["LID", data, [["LID_TYPE", lid_type]], phys]]
  :

  // ── BOX / TRAY PUBLIC AGGREGATORS ──────────────────────────────────────────
  // Each checkbox = one compile_manifest call to the matching private intent.
  // Drop-in grids are decoration — emitted once here, not inside the private intents.

  (intent == "Box" || intent == "Standalone Box") ?
    let(phys    = get_physics_profile(data),
        do_snap = get_val(BUILD_SNAP,        data, false),
        do_h    = get_val(SLIDE_H,           data, false),
        do_v    = get_val(SLIDE_V,           data, false),
        do_f1   = get_val(BUILD_FLIP_SINGLE, data, false),
        do_f2   = get_val(BUILD_FLIP_DOUBLE, data, false))
    concat(
      // Snap: Outer-wall + Inner-wall (thumb notch baked into each lid).
      do_snap ? concat(
        box_lid_variant("Snap", "External", data),
        box_lid_variant("Snap", "Rabbet",   data)
      ) : [],
      // H Slide: 3 variants (External+Tab, Rabbet+Ball, Rabbet+Tab).
      // External+Ball is excluded: groove lips are ~0.9mm at standard wall thickness;
      // the boss disconnects from the box body (non-manifold). See RenderBox.scad §External.
      do_h ? concat(
        box_lid_variant("Glide","External", concat([[GLIDE_DIR,"H"],[GLIDE_SNAP,"Tab"]], data)),
        box_lid_variant("Glide","Rabbet",   concat([[GLIDE_DIR,"H"],[GLIDE_SNAP,"Ball"]], data)),
        box_lid_variant("Glide","Rabbet",   concat([[GLIDE_DIR,"H"],[GLIDE_SNAP,"Tab"]], data))
      ) : [],
      // V Slide: same 3 variants in vertical orientation.
      do_v ? concat(
        box_lid_variant("Glide","External", concat([[GLIDE_DIR,"V"],[GLIDE_SNAP,"Tab"]], data)),
        box_lid_variant("Glide","Rabbet",   concat([[GLIDE_DIR,"V"],[GLIDE_SNAP,"Ball"]], data)),
        box_lid_variant("Glide","Rabbet",   concat([[GLIDE_DIR,"V"],[GLIDE_SNAP,"Tab"]], data))
      ) : [],
      do_f1 ? compile_manifest("Flip Box (Single)", data) : [],
      do_f2 ? compile_manifest("Flip Box (Double)", data) : [],
      grid_variants(data, phys)
    )
  :
  (intent == "Simple Tray") ?
    let(phys    = get_physics_profile(data),
        hg      = has_grid(data),
        d0      = concat([[HAS_BUILTIN_GRID, false]], data),
        d1      = concat([[HAS_BUILTIN_GRID, true]],  data),
        do_nest = get_val(STACK_NESTING, data, true),
        do_peg  = get_val(STACK_PEG,    data, true))
    concat(
      [["TRAY", d0, [], phys]],
      hg ? [["TRAY", d1, [], phys]] : [],
      grid_variants(data, phys),
      do_nest ? compile_manifest("Stackable Tray (Nesting)", data) : [],
      do_peg  ? compile_manifest("Stackable Tray (Peg)",    data) : []
    )
  :

  // ── STANDALONE DROP-IN GRID ─────────────────────────────────────────────────
  // Pure insert — no container. Set grid_layout; LWH are the container dims the
  // grid is sized to fit inside (Total mode) or the desired interior (Usable mode).
  // Always emits: GRID + GRID(base) [rectangular].
  // Square (w==l): + JAR_GRID + JAR_GRID(base)         → 4 total
  // Non-square:   + JAR_GRID(w) + JAR_GRID(w,base)
  //               + JAR_GRID(l) + JAR_GRID(l,base)     → 6 total
  // ── STANDALONE DROP-IN GRID ─────────────────────────────────────────────────
  // Pure rectangular drop-in insert — no base and with base.
  // Jar grid variants are intentionally excluded: for typical rectangular containers
  // the jar clip radius (= w or l) is too large to produce useful circular grids.
  // Jar grids are generated by jar intents (Threaded Jar, Jar with Lid, etc.).
  // ── STANDALONE PLAQUE ──────────────────────────────────────────────────────
  // Emits two print-ready pieces side by side: U-Clip + swivel face plate.
  // Wall thickness (sw) from physics profile. All clip/plate params from data.
  (intent == "Plaque") ?
    let(phys = get_physics_profile(data))
    [["PLAQUE", data, [], phys]]
  :

  (intent == "Grid") ?
    let(phys = get_physics_profile(data))
    grid_variants(data, phys)
  :

  // Legacy aliases — forward to Simple Tray with only the relevant stack flag set.
  (intent == "Nesting Tray (Short)") ?
    compile_manifest("Simple Tray",
      concat([[STACK_NESTING, true], [STACK_PEG, false]], data))
  :
  (intent == "Modular Peg Tray (Long)") ?
    compile_manifest("Simple Tray",
      concat([[STACK_NESTING, false], [STACK_PEG, true]], data))
  :
  // --- GRID TEST INTENTS ---
  // Not exposed in the Customizer individually — exercised via "Grid Test".
  // Uses the user's GRID_LAYOUT string from the Customizer unchanged.
  //
  // Drop-in variants: containers get HAS_BUILTIN_GRID=false (overrides Customizer
  // default "Built-in") so the container is empty and the grid is a separate object.
  // Built-in variants: HAS_BUILTIN_GRID=true prepended so it wins over Customizer.
  // Jar variants dual-spawn when W≠L, matching real "Jar with Lid" behaviour.
  (intent == "Tray with Grid Test") ?
    let(phys  = get_physics_profile(data),
        empty = concat([[HAS_BUILTIN_GRID, false]], data))
    [
      ["TRAY", empty, [],  phys],
      ["GRID", data,  [],  phys]
    ]
  :
  (intent == "Tray with Built-In Grid Test") ?
    let(phys = get_physics_profile(data),
        d    = concat([[HAS_BUILTIN_GRID, true]], data))
    [["TRAY", d, [], phys]]
  :
  (intent == "Box with Grid Test") ?
    let(phys  = get_physics_profile(data),
        empty = concat([[HAS_BUILTIN_GRID, false]], data))
    [
      ["TRAY", empty, [],                     phys],
      ["LID",  data,  [["LID_TYPE", "Snap"]], phys],
      ["GRID", data,  [],                     phys]
    ]
  :
  (intent == "Box with Built-in Grid Test") ?
    let(phys = get_physics_profile(data),
        d    = concat([[HAS_BUILTIN_GRID, true]], data))
    [
      ["TRAY", d,    [],                     phys],
      ["LID",  data, [["LID_TYPE", "Snap"]], phys]
    ]
  :
  (intent == "Jar with Grid Test") ?
    let(phys  = get_physics_profile(data),
        w     = get_val(WIDTH, data, WIDTH0),
        l     = get_val(LENGTH, data, LENGTH0),
        no_bi = [[HAS_BUILTIN_GRID, false]],
        jo    = [[IS_JAR_GRID, true]])
    (w == l) ? [
      ["JAR",  concat(no_bi, data),               jar_opts([], data), phys],
      ["GRID", data,                               jo,                 phys]
    ] : [
      ["JAR",  concat(no_bi, [[WIDTH, w]], data),  jar_opts([], data), phys],
      ["GRID", concat([[WIDTH, w]], data),          jo,                 phys],
      ["JAR",  concat(no_bi, [[WIDTH, l]], data),  jar_opts([], data), phys],
      ["GRID", concat([[WIDTH, l]], data),          jo,                 phys]
    ]
  :
  (intent == "Jar with Built-In Grid Test") ?
    let(phys = get_physics_profile(data),
        w    = get_val(WIDTH, data, WIDTH0),
        l    = get_val(LENGTH, data, LENGTH0),
        d    = concat([[HAS_BUILTIN_GRID, true]], data))
    (w == l) ?
      [["JAR", d, jar_opts([], d), phys]]
    :
      [
        ["JAR", concat([[WIDTH, w]], d), jar_opts([], d), phys],
        ["JAR", concat([[WIDTH, l]], d), jar_opts([], d), phys]
      ]
  :
  (intent == "Jar with Lid and Grid Test") ?
    let(phys  = get_physics_profile(data),
        w     = get_val(WIDTH, data, WIDTH0),
        l     = get_val(LENGTH, data, LENGTH0),
        no_bi = [[HAS_BUILTIN_GRID, false]],
        jo    = [[IS_JAR_GRID, true]],
        thr   = [["IS_THREADED", true]],
        screw = [["LID_TYPE", "Screw"]])
    (w == l) ? [
      ["JAR",  concat(no_bi, data),               jar_opts(thr, data), phys],
      ["LID",  data,                               screw,               phys],
      ["GRID", data,                               jo,                  phys]
    ] : [
      ["JAR",  concat(no_bi, [[WIDTH, w]], data),  jar_opts(thr, data), phys],
      ["LID",  concat([[WIDTH, w]], data),          screw,               phys],
      ["GRID", concat([[WIDTH, w]], data),          jo,                  phys],
      ["JAR",  concat(no_bi, [[WIDTH, l]], data),  jar_opts(thr, data), phys],
      ["LID",  concat([[WIDTH, l]], data),          screw,               phys],
      ["GRID", concat([[WIDTH, l]], data),          jo,                  phys]
    ]
  :
  (intent == "Jar with Lid and Built-In Grid Test") ?
    let(phys  = get_physics_profile(data),
        w     = get_val(WIDTH, data, WIDTH0),
        l     = get_val(LENGTH, data, LENGTH0),
        d     = concat([[HAS_BUILTIN_GRID, true]], data),
        thr   = [["IS_THREADED", true]],
        screw = [["LID_TYPE", "Screw"]])
    (w == l) ? [
      ["JAR",  d,    jar_opts(thr, d), phys],
      ["LID",  data, screw,            phys]
    ] : [
      ["JAR",  concat([[WIDTH, w]], d), jar_opts(thr, d), phys],
      ["LID",  concat([[WIDTH, w]], data), screw,          phys],
      ["JAR",  concat([[WIDTH, l]], d), jar_opts(thr, d), phys],
      ["LID",  concat([[WIDTH, l]], data), screw,          phys]
    ]
  :
  (intent == "Grid Test") ?
    concat(
      compile_manifest("Tray with Grid Test",               data),
      compile_manifest("Tray with Built-In Grid Test",      data),
      compile_manifest("Box with Grid Test",                data),
      compile_manifest("Box with Built-in Grid Test",       data),
      compile_manifest("Jar with Grid Test",                data),
      compile_manifest("Jar with Built-In Grid Test",       data),
      compile_manifest("Jar with Lid and Grid Test",        data),
      compile_manifest("Jar with Lid and Built-In Grid Test", data)
    )
  :
  // --- S4 SYSTEM ---
  (intent == "S4 Jar") ?
    let(d = concat([["WIDTH", 49], ["LENGTH", 49], ["HEIGHT", 140]], DESICCANT_MESH_CYL, data))
    [
      ["JAR", d, jar_opts([["IS_THREADED", true]], d), get_physics_profile(d)],
      ["LID", d, [["LID_TYPE", "Screw"]],              get_physics_profile(d)]
    ]
  :
  (intent == "Spool Jar") ?
    let(d = concat([["WIDTH", 55], ["LENGTH", 55], ["HEIGHT", 55]], DESICCANT_MESH_CYL, data))
    [
      ["JAR", d, jar_opts([["IS_THREADED", true]], d), get_physics_profile(d)],
      ["LID", d, [["LID_TYPE", "Screw"]],              get_physics_profile(d)]
    ]
  :
  (intent == "S4 Wedge") ?
    let(d = concat([["WIDTH", 140], ["LENGTH", 46], ["HEIGHT", 140]], DESICCANT_MESH_RECT, data))
    [
      ["BOX", d, [["NEEDS_GROOVE", true]],  get_physics_profile(d)],
      ["LID", d, [["LID_TYPE", "Glide"]],   get_physics_profile(d)]
    ]
  :
  (intent == "S4 Set") ?
    concat(
      compile_manifest("S4 Jar",   data),
      compile_manifest("Spool Jar", data),
      compile_manifest("S4 Wedge", data)
    )
  :
  // ── LID TESTING ─────────────────────────────────────────────────────────────
  // Generates all lid type × style combinations + their matching boxes on one platter.
  // Snap Rabbet, Snap External, Glide External, Glide Rabbet, Flip Single, Flip Double.
  // Use LWH from Customizer; lid_glide_direction and lid_glide_snap apply to Glide pairs.
  (intent == "Lid Testing") ?
    let(phys  = get_physics_profile(data),
        ext   = concat([[LID_STYLE, "External"]], data),
        rab   = concat([[LID_STYLE, "Rabbet"]],   data),
        lid_l = flip_half_lid_l(data))
    [
      // Snap External — lid cams past wall rim
      ["BOX", ext, [["LID_TYPE", "Snap"]], phys],
      ["LID", ext, [["LID_TYPE", "Snap"]], phys],
      // Snap Rabbet — lid bead clicks into inner-wall groove
      ["BOX", rab, [["LID_TYPE", "Snap"]], phys],
      ["LID", rab, [["LID_TYPE", "Snap"]], phys],
      // Glide External — lid rides in outer-wall groove
      ["BOX", ext, [["LID_TYPE", "Glide"]], phys],
      ["LID", ext, [["LID_TYPE", "Glide"]], phys],
      // Glide Rabbet — lid drops into inner-wall groove, flush top
      ["BOX", rab, [["LID_TYPE", "Glide"]], phys],
      ["LID", rab, [["LID_TYPE", "Glide"]], phys],
      // Flip Single — one lid, C-clip hinge +Y, diamond latch −Y
      ["BOX", data, [["LID_TYPE", "Flip_Single"]], phys],
      ["LID", data, [["LID_TYPE", "Flip_Single"]], phys],
      // Flip Double — open spine (original)
      ["BOX", data, [["LID_TYPE", "Flip_Double"]], phys],
      ["LID", concat([[LENGTH, lid_l]], data), [["LID_TYPE", "Flip_Single"]], phys],
      ["LID", concat([[LENGTH, lid_l]], data), [["LID_TYPE", "Flip_Single"]], phys],
      // Flip Double — solid filled spine (rigidity test)
      ["BOX", data, [["LID_TYPE", "Flip_Double"], ["SPINE_FILL", true]], phys],
      ["LID", concat([[LENGTH, lid_l]], data), [["LID_TYPE", "Flip_Single"]], phys],
      ["LID", concat([[LENGTH, lid_l]], data), [["LID_TYPE", "Flip_Single"]], phys]
    ]
  :

  // Unrecognised intent — fail loud. Previously this silently fell back to a
  // plain tray, so a typo'd Part_To_Build produced a wrong (but valid-looking)
  // model with only a buried console warning. The trailing expression is never
  // reached; it satisfies the ternary's value branch.
  assert(false, str("compile_manifest: unknown intent '", intent, "'"))
  [["TRAY", data, [], get_physics_profile(data)]];
