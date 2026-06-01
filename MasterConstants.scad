// ==============================================================================
// FILE: MasterConstants.scad [v1.0]
// ARCHITECTURE: Layer 0.5 (Physical & Engineering Constants)
// PURPOSE: Centralize all magic numbers with documented rationale
// ==============================================================================

// === FDM GEOMETRY CONSTRAINTS ===
// Physical limits imposed by FDM printing mechanics and materials
HINGE_DIAMETER = 4.0;          // Standard snap-fit pin diameter (PETG testbed)
JAR_LIP_HEIGHT = 8.0;          // Threaded jar neck height (supports M8-equivalent threads)
THREAD_CHAMFER = 0.5;          // Chamfer on threading to prevent slicer bridging failures
SPEC_TAG_WIDTH = 120;          // Spec label plate width (accommodates 6 lines of text)
SPEC_TAG_HEIGHT = 60;          // Spec label plate height (splits into 3 sections)
SPEC_TAG_DEPTH = 0.6;          // Thin label thickness (mounted on printed base)

// === SNAP-FIT & ASSEMBLY ===
// Tolerances and geometry for mechanical assembly (snap, clips, hinges)
HINGE_CLEARANCE = 0.2;         // Clearance around hinge pin (accounts for print tolerance ±0.1mm)
CLIP_JAW_SPREAD = 0.8;         // C-clip jaw opening as % of hinge diameter (80% of axle)
CLIP_WALL_THICKNESS_MULT = 4.0; // Clip wall = nozzle_diameter × this factor

// === MATERIAL SAFETY ===
// Percentage caps to prevent over-thick features that waste material
MAX_FLOOR_THICKNESS_PCT = 35;  // Floors capped at 35% of total height (prevent solid bases)
MAX_LID_THICKNESS_PCT = 35;    // Lids capped at 35% of total height
MAX_WALL_THICKNESS_PCT = 45;   // Walls capped at 45% of XY footprint (prevent thick shells)

// === OVERHANG & BRIDGING ===
// FDM print angle and overhang limits (assumes 45° critical angle)
MAX_CHAMFER_MULT = 2.5;        // Chamfer capped at nozzle_diameter × 2.5 (FDM overhang limit)

// === MESH & GRID ===
// Parameters controlling pattern generation and spacing
MIN_HOLE_SPACING = 1.2;        // Minimum gap between adjacent holes (prevents wall collapse)
HEXAGON_HEIGHT_MULT = 0.866;   // sin(60°) for honeycomb grid spacing

// === PLAQUE & TEXT ===
// Text rendering and sizing for embossed features
TEXT_KERNING_MULT = 0.65;      // Approximate character width as size × 0.65 (Arial Black baseline)
TEXT_PLAQUE_MIN_WIDTH = 25;    // Minimum plaque backing width (prevents tiny labels)
TEXT_EMBOSS_DEPTH = 1.0;       // Standard depth for embossed/debossed text

// === GRID SYSTEMS ===
// Built-in vs drop-in grid dimensions
GRID_DROP_IN_TOLERANCE = 0.4;  // Clearance between grid and container (allows insertion)
GRID_BASE_HEIGHT_MULT = 4.0;   // Base thickness = layer_height × 4 (2-3 shells)

// === PLATTER LAYOUT ===
// Build plate packing algorithm
PLATTER_DEFAULT_GAP = 15;      // Default spacing between parts on print bed
MAX_BUILD_PLATE_WIDTH = 250;   // Maximum X dimension before row wrap (Prusa MK3S+)

// === BUILD SYSTEM ===
// Metadata and version tracking
BUILDER_DEFAULT_VERSION = "v4.9.1"; // Spec tag version injection

// === PRINTER PROFILE MAPPINGS ===
// Common layer height presets (used to determine safe thickness multiples)
LAYER_HEIGHT_FAST = 0.24;      // Fast & Good Enough
LAYER_HEIGHT_STANDARD = 0.20;  // Standard (default)
LAYER_HEIGHT_DETAILED = 0.12;  // Detailed
LAYER_HEIGHT_FINE = 0.08;      // Ultra Fine

// === NOZZLE PROFILES ===
// Common nozzle diameters (drives wall/floor multiplier calculations)
NOZZLE_FINE = 0.2;             // Fine detail work
NOZZLE_STANDARD = 0.4;         // Standard (default)
NOZZLE_MEDIUM = 0.6;           // Faster prints
NOZZLE_COARSE = 0.8;           // Draft work

// === AUDIT LOG ===
// When/why constants were added or changed
// v1.0: Extracted all hard-coded values from MasterRender, MasterChecks, MasterUtility
//       Rationale: Enable single-point tuning for material science experiments
//       Example: Testing different snap-fit tolerances? Just adjust HINGE_CLEARANCE
