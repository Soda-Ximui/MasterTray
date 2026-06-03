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

function compile_manifest(intent, data) =
  (intent == "Threaded Jar") ? [
    ["JAR", data, [["IS_THREADED", true]],         get_physics_profile(data)],
    ["LID", data, [["LID_TYPE",   "Screw"]],        get_physics_profile(data)]
  ] :
  (intent == "Flip Box") ? [
    ["FLIP_BOX", data, [],                          get_physics_profile(data)],
    ["LID",      data, [["LID_TYPE", "Flip_Single"]], get_physics_profile(data)]
  ] :
  (intent == "Double Flip Box") ? [
    ["DOUBLE_FLIP_BOX", data, [],                   get_physics_profile(data)]
  ] :
  (intent == "Box") ? [
    ["BOX", data, [],                               get_physics_profile(data)]
  ] :
  // default → Simple Tray
  [["TRAY", data, [],                               get_physics_profile(data)]];
