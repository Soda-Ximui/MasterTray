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

function compile_manifest(intent, data) =
  (intent == "Threaded Jar") ?
    let(w = get_val(WIDTH, data, WIDTH0), l = get_val(LENGTH, data, LENGTH0))
    (w == l) ? [
      ["JAR", data,                       jar_opts([["IS_THREADED", true]], data), get_physics_profile(data)],
      ["LID", data,                       [["LID_TYPE", "Screw"]],                 get_physics_profile(data)]
    ] : [
      ["JAR", concat([["WIDTH", w]], data), jar_opts([["IS_THREADED", true]], data), get_physics_profile(data)],
      ["JAR", concat([["WIDTH", l]], data), jar_opts([["IS_THREADED", true]], data), get_physics_profile(data)]
    ]
  :
  (intent == "Jar with Lid") ?
    let(w = get_val(WIDTH, data, WIDTH0), l = get_val(LENGTH, data, LENGTH0))
    (w == l) ? [
      ["JAR", data,                       jar_opts([["IS_THREADED", true]], data), get_physics_profile(data)],
      ["LID", data,                       [["LID_TYPE", "Screw"]],                 get_physics_profile(data)]
    ] : [
      ["JAR", concat([["WIDTH", w]], data), jar_opts([["IS_THREADED", true]], data), get_physics_profile(data)],
      ["LID", concat([["WIDTH", w]], data), [["LID_TYPE", "Screw"]],                get_physics_profile(data)],
      ["JAR", concat([["WIDTH", l]], data), jar_opts([["IS_THREADED", true]], data), get_physics_profile(data)],
      ["LID", concat([["WIDTH", l]], data), [["LID_TYPE", "Screw"]],                get_physics_profile(data)]
    ]
  :
  (intent == "Simple Jar") ?
    let(w = get_val(WIDTH, data, WIDTH0), l = get_val(LENGTH, data, LENGTH0))
    (w == l) ?
      [["JAR", data, jar_opts([], data),                    get_physics_profile(data)]]
    :
      [
        ["JAR", concat([["WIDTH", l]], data), jar_opts([], data), get_physics_profile(data)],
        ["JAR", concat([["WIDTH", w]], data), jar_opts([], data), get_physics_profile(data)]
      ]
  :
  (intent == "Open Jar") ?
    let(w = get_val(WIDTH, data, WIDTH0), l = get_val(LENGTH, data, LENGTH0))
    (w == l) ?
      [["JAR", data, jar_opts([["IS_THREADED", false]], data), get_physics_profile(data)]]
    :
      [
        ["JAR", concat([["WIDTH", w]], data), jar_opts([["IS_THREADED", false]], data), get_physics_profile(data)],
        ["JAR", concat([["WIDTH", l]], data), jar_opts([["IS_THREADED", false]], data), get_physics_profile(data)]
      ]
  :
  (intent == "Flip Box") ? [
    ["BOX", data, [["LID_TYPE", "Flip_Single"]], get_physics_profile(data)],
    ["LID", data, [["LID_TYPE", "Flip_Single"]], get_physics_profile(data)]
  ] :
  (intent == "Double Flip Box") ?
    let(phys = get_physics_profile(data),
        w = get_val(WIDTH, data, WIDTH0), l = get_val(LENGTH, data, LENGTH0),
        clearance = breathing_room(COMP_CCLIP, data),
        spine_gap = breathing_room(COMP_SPINE, data),
        hinge_y = (4.0 + clearance*2 + get_val(NOZZLE_DIAMETER, data, 0.4)*8) / 2 + spine_gap,
        lid_l = l - hinge_y)
    [
      ["BOX", data,                          [["LID_TYPE", "Flip_Double"]],   phys],
      ["LID", concat([["LENGTH", lid_l]], data), [["LID_TYPE", "Flip_Single"]], phys],
      ["LID", concat([["LENGTH", lid_l]], data), [["LID_TYPE", "Flip_Single"]], phys]
    ]
  :
  (intent == "Box") ? [
    ["BOX", data, [["LID_TYPE", "Snap"]],             get_physics_profile(data)],
    ["LID", data, [["LID_TYPE", "Snap"]],             get_physics_profile(data)]
  ] :
  (intent == "Standalone Box") ? [
    ["BOX", data, [["LID_TYPE", "Glide"]],            get_physics_profile(data)],
    ["LID", data, [["LID_TYPE", "Glide"]],            get_physics_profile(data)]
  ] :
  (intent == "Simple Tray") ? [
    ["TRAY", data, [],                                get_physics_profile(data)]
  ] :
  (intent == "Standalone Box Grid") ? [
    ["GRID", data, [],                                get_physics_profile(data)]
  ] :
  (intent == "Standalone Jar Grid") ?
    let(w = get_val(WIDTH, data, WIDTH0), l = get_val(LENGTH, data, LENGTH0),
        jar_opts = [[IS_JAR_GRID, true]])
    (w == l) ?
      [["GRID", data,                        jar_opts, get_physics_profile(data)]]
    :
      [
        ["GRID", concat([["WIDTH", w]], data), jar_opts, get_physics_profile(data)],
        ["GRID", concat([["WIDTH", l]], data), jar_opts, get_physics_profile(data)]
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
