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

include <MasterEngine.scad>
include <MasterProcessor.scad>
include <GridLayout.scad>

// has_grid — true when grid_layout is non-empty and valid.
function has_grid(data) =
  let(g = m_grid_layout(data))
  g != "" && is_valid_grid_layout(g);

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

// Shared hinge geometry for all double-flip / pill-box intents.
function flip_hinge_y(data) =
  let(clearance = breathing_room(COMP_CCLIP, data),
      spine_gap  = breathing_room(COMP_SPINE, data))
  (4.0 + clearance*2 + get_val(NOZZLE_DIAMETER, data, 0.4)*8) / 2 + spine_gap;

function flip_lid_l(data) = get_val(LENGTH, data, LENGTH0) - flip_hinge_y(data);

function compile_manifest(intent, data) =

  // ── JAR INTENTS ─────────────────────────────────────────────────────────────
  // Grid behaviour: when grid_layout is present, every jar intent emits:
  //   JAR (no built-in grid)  +  JAR (fused built-in grid)
  //   + GRID (drop-in, no base)  +  GRID (drop-in, with base)
  // For W≠L jars each group is duplicated per diameter.
  // The lid is only emitted once — it is the same regardless of grid variant.

  (intent == "Threaded Jar") ?
    let(w = get_val(WIDTH, data, WIDTH0), l = get_val(LENGTH, data, LENGTH0),
        phys = get_physics_profile(data),
        hg   = has_grid(data),
        d0   = concat([[HAS_BUILTIN_GRID, false]], data),
        d1   = concat([[HAS_BUILTIN_GRID, true]],  data))
    concat(
      (w == l) ? [
        ["JAR", d0,                       jar_opts([["IS_THREADED", true]], data), phys],
        ["LID", data,                     [["LID_TYPE", "Screw"]],                 phys]
      ] : [
        ["JAR", concat([[WIDTH, w]], d0), jar_opts([["IS_THREADED", true]], data), phys],
        ["JAR", concat([[WIDTH, l]], d0), jar_opts([["IS_THREADED", true]], data), phys]
      ],
      hg ? (w == l ? [
        ["JAR", d1,                       jar_opts([["IS_THREADED", true]], data), phys]
      ] : [
        ["JAR", concat([[WIDTH, w]], d1), jar_opts([["IS_THREADED", true]], data), phys],
        ["JAR", concat([[WIDTH, l]], d1), jar_opts([["IS_THREADED", true]], data), phys]
      ]) : [],
      w == l
        ? grid_variants(data, phys, true)
        : concat(grid_variants(concat([[WIDTH, w]], data), phys, true),
                 grid_variants(concat([[WIDTH, l]], data), phys, true))
    )
  :
  (intent == "Jar with Lid") ?
    let(w = get_val(WIDTH, data, WIDTH0), l = get_val(LENGTH, data, LENGTH0),
        phys = get_physics_profile(data),
        hg   = has_grid(data),
        d0   = concat([[HAS_BUILTIN_GRID, false]], data),
        d1   = concat([[HAS_BUILTIN_GRID, true]],  data))
    concat(
      (w == l) ? [
        ["JAR", d0,   jar_opts([["IS_THREADED", true]], data), phys],
        ["LID", data, [["LID_TYPE", "Screw"]],                 phys]
      ] : [
        ["JAR", concat([[WIDTH, w]], d0),   jar_opts([["IS_THREADED", true]], data), phys],
        ["LID", concat([[WIDTH, w]], data), [["LID_TYPE", "Screw"]],                phys],
        ["JAR", concat([[WIDTH, l]], d0),   jar_opts([["IS_THREADED", true]], data), phys],
        ["LID", concat([[WIDTH, l]], data), [["LID_TYPE", "Screw"]],                phys]
      ],
      hg ? (w == l ? [
        ["JAR", d1, jar_opts([["IS_THREADED", true]], data), phys]
      ] : [
        ["JAR", concat([[WIDTH, w]], d1), jar_opts([["IS_THREADED", true]], data), phys],
        ["JAR", concat([[WIDTH, l]], d1), jar_opts([["IS_THREADED", true]], data), phys]
      ]) : [],
      w == l
        ? grid_variants(data, phys, true)
        : concat(grid_variants(concat([[WIDTH, w]], data), phys, true),
                 grid_variants(concat([[WIDTH, l]], data), phys, true))
    )
  :
  (intent == "Simple Jar") ?
    let(w = get_val(WIDTH, data, WIDTH0), l = get_val(LENGTH, data, LENGTH0),
        phys = get_physics_profile(data),
        hg   = has_grid(data),
        d0   = concat([[HAS_BUILTIN_GRID, false]], data),
        d1   = concat([[HAS_BUILTIN_GRID, true]],  data))
    concat(
      (w == l) ? [
        ["JAR", d0, jar_opts([], data), phys]
      ] : [
        ["JAR", concat([[WIDTH, l]], d0), jar_opts([], data), phys],
        ["JAR", concat([[WIDTH, w]], d0), jar_opts([], data), phys]
      ],
      hg ? (w == l ? [
        ["JAR", d1, jar_opts([], data), phys]
      ] : [
        ["JAR", concat([[WIDTH, l]], d1), jar_opts([], data), phys],
        ["JAR", concat([[WIDTH, w]], d1), jar_opts([], data), phys]
      ]) : [],
      w == l
        ? grid_variants(data, phys, true)
        : concat(grid_variants(concat([[WIDTH, l]], data), phys, true),
                 grid_variants(concat([[WIDTH, w]], data), phys, true))
    )
  :
  (intent == "Open Jar") ?
    let(w = get_val(WIDTH, data, WIDTH0), l = get_val(LENGTH, data, LENGTH0),
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
      w == l
        ? grid_variants(data, phys, true)
        : concat(grid_variants(concat([[WIDTH, w]], data), phys, true),
                 grid_variants(concat([[WIDTH, l]], data), phys, true))
    )
  :

  // ── BOX / TRAY INTENTS ──────────────────────────────────────────────────────
  // Grid behaviour: when grid_layout is present, emits:
  //   Container (no built-in grid)  +  Container (fused built-in grid)
  //   + GRID (drop-in, no base)  +  GRID (drop-in, with base)
  // The lid is emitted once — unchanged by grid variant.

  (intent == "Flip Box") ?
    let(phys = get_physics_profile(data),
        hg   = has_grid(data),
        d0   = concat([[HAS_BUILTIN_GRID, false]], data),
        d1   = concat([[HAS_BUILTIN_GRID, true]],  data))
    concat(
      [["BOX", d0,   [["LID_TYPE", "Flip_Single"]], phys],
       ["LID", data, [["LID_TYPE", "Flip_Single"]], phys]],
      hg ? [["BOX", d1, [["LID_TYPE", "Flip_Single"]], phys]] : [],
      grid_variants(data, phys)
    )
  :
  (intent == "Double Flip Box") ?
    let(phys  = get_physics_profile(data),
        lid_l = flip_lid_l(data),
        hg    = has_grid(data),
        d0    = concat([[HAS_BUILTIN_GRID, false]], data),
        d1    = concat([[HAS_BUILTIN_GRID, true]],  data))
    concat(
      [["BOX", d0,                              [["LID_TYPE", "Flip_Double"]],   phys],
       ["LID", concat([[LENGTH, lid_l]], data), [["LID_TYPE", "Flip_Single"]], phys],
       ["LID", concat([[LENGTH, lid_l]], data), [["LID_TYPE", "Flip_Single"]], phys]],
      hg ? [["BOX", d1, [["LID_TYPE", "Flip_Double"]], phys]] : [],
      grid_variants(data, phys)
    )
  :
  // --- PILL BOX INTENTS ---
  (intent == "1-Day AM/PM Box") ?
    let(phys  = get_physics_profile(data),
        w     = get_val(WIDTH, data, WIDTH0),
        lid_l = flip_lid_l(data),
        box_d = concat([[GRID_LAYOUT, "1x2"], [HAS_BUILTIN_GRID, true]], data))
    [
      ["BOX", box_d,                                                           [["LID_TYPE", "Flip_Double"]],   phys],
      ["LID", concat([[LENGTH, lid_l], [WIDTH, w - 0.6], [PLAQUE_TEXT, "AM"]], data), [["LID_TYPE", "Flip_Single"]], phys],
      ["LID", concat([[LENGTH, lid_l], [WIDTH, w - 0.6], [PLAQUE_TEXT, "PM"]], data), [["LID_TYPE", "Flip_Single"]], phys]
    ]
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
        w = get_val(WIDTH, data, WIDTH0), l = get_val(LENGTH, data, LENGTH0),
        cw = w / 7,
        days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"],
        box_d = concat([[GRID_LAYOUT, "7x1"], [HAS_BUILTIN_GRID, true]], data))
    concat(
      [["BOX", box_d, [["LID_TYPE", "Flip_Single"]], phys]],
      [for (i = [0:6])
        ["LID", concat([[WIDTH, cw - 0.6], [PLAQUE_TEXT, days[i]]], data), [["LID_TYPE", "Flip_Single"]], phys]]
    )
  :
  (intent == "14-Day AM/PM Box") ?
    let(phys  = get_physics_profile(data),
        w     = get_val(WIDTH, data, WIDTH0),
        lid_l = flip_lid_l(data),
        cw    = w / 7,
        days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"],
        box_d = concat([[GRID_LAYOUT, "7x2"], [HAS_BUILTIN_GRID, true]], data))
    concat(
      [["BOX", box_d, [["LID_TYPE", "Flip_Double"]], phys]],
      [for (i = [0:6])
        ["LID", concat([[WIDTH, cw - 0.6], [LENGTH, lid_l], [PLAQUE_TEXT, str(days[i], " AM")]], data), [["LID_TYPE", "Flip_Single"]], phys]],
      [for (i = [0:6])
        ["LID", concat([[WIDTH, cw - 0.6], [LENGTH, lid_l], [PLAQUE_TEXT, str(days[i], " PM")]], data), [["LID_TYPE", "Flip_Single"]], phys]]
    )
  :
  (intent == "Pillbox Set (Double Lid)") ?
    concat(compile_manifest("14-Day AM/PM Box", data), compile_manifest("1-Day AM/PM Box", data))
  :
  (intent == "Pillbox Set (Single Lid)") ?
    concat(compile_manifest("7-Day Pill Box", data), compile_manifest("1-Day AM/PM Box", data))
  :
  (intent == "Pillbox Full Set") ?
    concat(compile_manifest("14-Day AM/PM Box", data), compile_manifest("7-Day Pill Box", data), compile_manifest("1-Day AM/PM Box", data))
  :
  (intent == "Box") ?
    let(phys = get_physics_profile(data),
        hg   = has_grid(data),
        d0   = concat([[HAS_BUILTIN_GRID, false]], data),
        d1   = concat([[HAS_BUILTIN_GRID, true]],  data))
    concat(
      [["BOX", d0,   [["LID_TYPE", "Snap"]], phys],
       ["LID", data, [["LID_TYPE", "Snap"]], phys]],
      hg ? [["BOX", d1, [["LID_TYPE", "Snap"]], phys]] : [],
      grid_variants(data, phys)
    )
  :
  (intent == "Standalone Box") ?
    let(phys = get_physics_profile(data),
        hg   = has_grid(data),
        d0   = concat([[HAS_BUILTIN_GRID, false]], data),
        d1   = concat([[HAS_BUILTIN_GRID, true]],  data))
    concat(
      [["BOX", d0,   [["LID_TYPE", "Glide"]], phys],
       ["LID", data, [["LID_TYPE", "Glide"]], phys]],
      hg ? [["BOX", d1, [["LID_TYPE", "Glide"]], phys]] : [],
      grid_variants(data, phys)
    )
  :
  (intent == "Simple Tray") ?
    let(phys = get_physics_profile(data),
        hg   = has_grid(data),
        d0   = concat([[HAS_BUILTIN_GRID, false]], data),
        d1   = concat([[HAS_BUILTIN_GRID, true]],  data))
    concat(
      [["TRAY", d0, [], phys]],
      hg ? [["TRAY", d1, [], phys]] : [],
      grid_variants(data, phys)
    )
  :

  // ── STANDALONE GRID INTENTS ─────────────────────────────────────────────────
  // Always emit two GRID entries: without base and with base.

  (intent == "Standalone Box Grid") ?
    let(phys = get_physics_profile(data))
    [
      ["GRID", concat([[GRID_HAS_BASE, false]], data), [], phys],
      ["GRID", concat([[GRID_HAS_BASE, true]],  data), [], phys]
    ]
  :
  (intent == "Standalone Jar Grid") ?
    let(phys = get_physics_profile(data),
        w    = get_val(WIDTH, data, WIDTH0),
        l    = get_val(LENGTH, data, LENGTH0),
        jo   = [[IS_JAR_GRID, true]])
    (w == l) ? [
      ["GRID", concat([[GRID_HAS_BASE, false]], data),              jo, phys],
      ["GRID", concat([[GRID_HAS_BASE, true]],  data),              jo, phys]
    ] : [
      ["GRID", concat([[GRID_HAS_BASE, false], [WIDTH, w]], data),  jo, phys],
      ["GRID", concat([[GRID_HAS_BASE, true],  [WIDTH, w]], data),  jo, phys],
      ["GRID", concat([[GRID_HAS_BASE, false], [WIDTH, l]], data),  jo, phys],
      ["GRID", concat([[GRID_HAS_BASE, true],  [WIDTH, l]], data),  jo, phys]
    ]
  :
  (intent == "Nesting Tray (Short)") ? [
    ["TRAY", data, [[STACKABLE, true], [STACK_MODE, "Snap"]], get_physics_profile(data)]
  ] :
  (intent == "Modular Peg Tray (Long)") ?
    concat(
      [["TRAY", data, [[STACKABLE, true], [STACK_MODE, "Peg"]], get_physics_profile(data)]],
      [for (i = [0:3]) ["PEG", data, [], get_physics_profile(data)]]
    )
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
  // Unrecognised intent — fall back to a plain tray and warn in console.
  // TODO: add manifest entries for remaining intents.
  let(_ = echo(str("WARNING: Unknown intent '", intent, "' — rendering as Simple Tray")))
  [["TRAY", data, [],                                 get_physics_profile(data)]];
