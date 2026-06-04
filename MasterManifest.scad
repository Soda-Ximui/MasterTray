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
  (intent == "Threaded Jar") ? [
    ["JAR", data, jar_opts([["IS_THREADED", true]],  data), get_physics_profile(data)],
    ["LID", data, [["LID_TYPE", "Screw"]],                  get_physics_profile(data)]
  ] :
  (intent == "Jar with Lid") ? [
    ["JAR", data, jar_opts([["IS_THREADED", true]],  data), get_physics_profile(data)],
    ["LID", data, [["LID_TYPE", "Screw"]],                  get_physics_profile(data)]
  ] :
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
  (intent == "Open Jar") ? [
    ["JAR", data, jar_opts([["IS_THREADED", false]], data), get_physics_profile(data)]
  ] :
  (intent == "Flip Box") ? [
    ["FLIP_BOX", data, [],                            get_physics_profile(data)],
    ["LID",      data, [["LID_TYPE", "Flip_Single"]], get_physics_profile(data)]
  ] :
  (intent == "Double Flip Box") ? [
    ["DOUBLE_FLIP_BOX", data, [],                     get_physics_profile(data)]
  ] :
  (intent == "Box") ? [
    ["BOX", data, [],                                 get_physics_profile(data)]
  ] :
  (intent == "Simple Tray") ? [
    ["TRAY", data, [],                                get_physics_profile(data)]
  ] :
  // Unrecognised intent — fall back to a plain tray and warn in console.
  // TODO: add manifest entries for remaining intents.
  let(_ = echo(str("WARNING: Unknown intent '", intent, "' — rendering as Simple Tray")))
  [["TRAY", data, [],                                 get_physics_profile(data)]];
