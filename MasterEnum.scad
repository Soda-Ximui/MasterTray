// ==============================================================================
// FILE: MasterEnum.scad
// ARCHITECTURE: Layer 0 (The Lexicon & Dictionary)
// ==============================================================================

TYPE = "TYPE";
WIDTH = "WIDTH";
LENGTH = "LENGTH";
HEIGHT = "HEIGHT";
DIMENSION_MODE = "DIMENSION_MODE";
BUILDER_VERSION = "BUILDER_VERSION";
LAYER_HEIGHT = "LAYER_HEIGHT";
WALL_LOOPS = "WALL_LOOPS";
NOZZLE_DIAMETER = "NOZZLE_DIAMETER";
PATTERN = "PATTERN";
HOLE_WALL    = "HOLE_WALL";
HOLE_FLOOR   = "HOLE_FLOOR";
HOLE_LID     = "HOLE_LID";
HOLE_SPACING = "HOLE_SPACING";  // gap between holes — overrides physics default when set
STRUT_WALL   = "STRUT_WALL";
STRUT_FLOOR  = "STRUT_FLOOR";
STRUT_LID    = "STRUT_LID";
GRID_LAYOUT = "GRID_LAYOUT";
GRID_HAS_BASE = "GRID_HAS_BASE";
GRID_TYPE = "GRID_TYPE";
PLAQUE_STYLE = "PLAQUE_STYLE";
PLAQUE_TEXT = "PLAQUE_TEXT";
PLAQUE_TEXT_SIZE = "PLAQUE_TEXT_SIZE";
WALL_MODIFY = "WALL_MODIFY";
WALL_TARGET = "WALL_TARGET";
THICK_FLOOR = "THICK_FLOOR";
THICK_LID = "THICK_LID";
THICK_WALL = "THICK_WALL";
THICK_DIVIDER = "THICK_DIVIDER";
LID_MIN_SOLID = "LID_MIN_SOLID";
THICK_PEG_MULT = "THICK_PEG_MULT";
TOL_SNAP_GAP = "TOL_SNAP_GAP";
TOL_CLIP = "TOL_CLIP";
PLATTER_GAP = "PLATTER_GAP";
THREAD_PITCH = "THREAD_PITCH";
PEG_HEIGHT = "PEG_HEIGHT";
SKIP_PILLARS = "SKIP_PILLARS"; // [v4.6] Added to control dynamic support pillars

HONEYCOMB = "Honeycomb";
TEARDROP = "Teardrop";
SLOTTED = "Slotted";
CIRCLE = "Circle";
SQUARE = "Square";
DIAMOND = "Diamond";
NONE = "None";
NEEDS_GROOVE = "NEEDS_GROOVE";
HAS_THREADS  = "HAS_THREADS";
JAR_SHAPE    = "JAR_SHAPE";
JAR_SIDES    = "JAR_SIDES";
GLIDE_DIR      = "GLIDE_DIR";   // "H" (horizontal) | "V" (vertical)
GLIDE_SNAP     = "GLIDE_SNAP"; // "Ball" (default) | "Tab"
GRID_WALL_H    = "GRID_WALL_H";  // injected by factory — max divider height
IS_JAR_GRID    = "IS_JAR_GRID"; // clip cartesian grid to circular jar boundary
STACKABLE      = "STACKABLE";
STACK_MODE     = "STACK_MODE";     // "Peg" | "Builtin" | "Snap"
CHAMFER_SIZE   = "CHAMFER_SIZE";   // mm — 0 = auto from nozzle
CORNER_RADIUS  = "CORNER_RADIUS";  // mm — 0 = auto from wall thickness
PEG_SOCKET_D   = "PEG_SOCKET_D";  // mm — peg/socket hole diameter
LEDGE_DEPTH    = "LEDGE_DEPTH";   // mm — nesting ledge height below floor
PEG_PROTRUSION = "PEG_PROTRUSION"; // mm — builtin peg height above tray top (0=auto)
HAS_BUILTIN_GRID = "HAS_BUILTIN_GRID";

BOX = "BOX";
LID = "LID";
LID_GLIDE = "LID_GLIDE";
TRAY_SIMPLE = "TRAY_SIMPLE";
TRAY_STACK_NEST = "TRAY_STACK_NEST";
TRAY_STACK_PEG = "TRAY_STACK_PEG";
PEG = "PEG";

BOX_GRID = "BOX_GRID";
JAR_GRID = "JAR_GRID";
JAR = "JAR";
JAR_LID = "JAR_LID";
PLAQUE = "PLAQUE";
PLAQUE_JAR = "PLAQUE_JAR";
DESICCANT_BOX = "DESICCANT_BOX";
DESICCANT_LID = "DESICCANT_LID";
FLIP_BOX = "FLIP_BOX";
FLIP_LID = "FLIP_LID";
DOUBLE_FLIP_BOX = "DOUBLE_FLIP_BOX";
SPEC_TAG = "SPEC_TAG";
