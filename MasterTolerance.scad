// ==============================================================================
// FILE: MasterTolerance.scad
// ARCHITECTURE: Layer 1.8 (The Physics & Materials Engine)
// ==============================================================================

// --- FILAMENT ENUMS ---
FIL_PLA  = "PLA";
FIL_PETG = "PETG";
FIL_TPU  = "TPU";
FIL_ABS  = "ABS";

// --- FIT PROFILE ENUMS ---
FIT_TIGHTER  = "Tighter";
FIT_TIGHT    = "Tight";
FIT_STANDARD = "Standard";
FIT_LOOSE    = "Loose";
FIT_LOOSER   = "Looser";

// --- COMPONENT ENUMS ---
COMP_SPINE = "center_spine";
COMP_CCLIP = "c_clip";
COMP_CLASP = "diamond_clasp";
COMP_BELLY = "clip_flat_belly";
COMP_GLIDE = "glide_track"; 

// --- BASELINE TOLERANCES (Breathing Room / Gap) ---
// Smaller number = tighter fit
// ROOM_SPINE: gap between the two Flip_Double C-clip faces at box centre.
// B8 (2026-06-10): was 4.00 (≈clip_od/2, sized for a full 90° simultaneous-
// opening sweep), but printed parts show this leaves a closed-lid gap of
// roughly 1/3 of the spine width. Each half-lid's hinge already hard-stops
// against its own wall at ~90° (see B6), so the two clips never approach
// each other closely enough to need the full clip_od/2 clearance. Reduced
// to 1.00mm; reprint to confirm the C-clips still don't bind when both
// half-lids are opened simultaneously.
ROOM_SPINE_PETG = 1.00; ROOM_SPINE_TPU = 0.20; ROOM_SPINE_PLA = 1.00;
ROOM_CCLIP_PETG = 0.25; ROOM_CCLIP_TPU = 0.10; ROOM_CCLIP_PLA = 0.15;
ROOM_GLIDE_PETG = 0.40; ROOM_GLIDE_TPU = 0.60; ROOM_GLIDE_PLA = 0.20; 

// --- BASELINE ENGAGEMENTS (Overlap / Depth) ---
// Larger number = deeper/tighter grab
ENG_CLASP_PETG = 4.6; ENG_CLASP_TPU = 5.5; ENG_CLASP_PLA = 4.0;
ENG_BELLY_PETG = 0.6; ENG_BELLY_TPU = 0.4; ENG_BELLY_PLA = 0.5;

// --- MODIFIER STEP CONSTANTS ---
STEP_ROOM = 0.05; // Adjusts gap clearances by 50 microns per fit level
STEP_ENG  = 0.20; // Adjusts snap engagements by 0.2mm per fit level

// --- WALL-LOOP COMPENSATION ---
// More perimeter loops = more cumulative over-extrusion pressure on the
// outermost wall, which bulges outward into clearance gaps and inward-bulges
// the walls of holes/recesses (shrinking engagement pockets). Baseline
// tolerances above are tuned for WALL_LOOPS0 (3) loops; each additional loop
// nudges clearances open and engagement depths deeper to compensate.
LOOP_BASELINE   = WALL_LOOPS0; // loop count the baseline numbers above assume
STEP_LOOP_ROOM  = 0.025;       // extra clearance per loop above baseline (mm)
STEP_LOOP_ENG   = 0.05;        // extra engagement depth per loop above baseline (mm)

function loop_excess(data) = max(0, m_wloops(data) - LOOP_BASELINE);


// ==============================================================================
// LOGIC ENGINE & MATH THEORY
// ==============================================================================
// How the Multiplier works vis-a-vis User Input:
// 
// 1. The Weight (get_fit_mod):
//    Tighter = -2, Tight = -1, Standard = 0, Loose = 1, Looser = 2
//
// 2. Breathing Room (Clearance Gaps):
//    Formula: Baseline_Gap + (Weight * STEP_ROOM)
//    Math: If user selects "Tight" (-1): 0.50 + (-1 * 0.05) = 0.45mm
//    Result: A negative weight SHRINKS the physical gap, making parts fit snugger.
//
// 3. Engagement Depth (Snap Strength):
//    Formula: Baseline_Depth - (Weight * STEP_ENG)
//    Math: If user selects "Tight" (-1): 4.60 - (-1 * 0.20) = 4.80mm
//    Result: A negative weight is SUBTRACTED (double negative), which mathematically 
//    ADDS physical depth to the snap, forcing a deeper, harder mechanical lock.
// ==============================================================================

function get_fit_mod(data) = 
    let(fit = get_val("FIT_PROFILE", data, FIT_STANDARD))
    (fit == FIT_TIGHTER) ? -2 : 
    (fit == FIT_TIGHT)   ? -1 : 
    (fit == FIT_LOOSE)   ?  1 : 
    (fit == FIT_LOOSER)  ?  2 : 
    0; 
    
function breathing_room(component, data) =
    let(fil = get_val("FILAMENT_TYPE", data, FIL_PLA), mod = get_fit_mod(data),
        loop_bonus = loop_excess(data) * STEP_LOOP_ROOM)
    (component == COMP_SPINE) ?
        ((fil == FIL_PETG) ? ROOM_SPINE_PETG : (fil == FIL_TPU) ? ROOM_SPINE_TPU : ROOM_SPINE_PLA) + (mod * STEP_ROOM) + loop_bonus :
    (component == COMP_CCLIP) ?
        ((fil == FIL_PETG) ? ROOM_CCLIP_PETG : (fil == FIL_TPU) ? ROOM_CCLIP_TPU : ROOM_CCLIP_PLA) + (mod * STEP_ROOM) + loop_bonus :
    (component == COMP_GLIDE) ?
        ((fil == FIL_PETG) ? ROOM_GLIDE_PETG : (fil == FIL_TPU) ? ROOM_GLIDE_TPU : ROOM_GLIDE_PLA) + (mod * STEP_ROOM) + loop_bonus :
    0.0;

function engagement_depth(component, data) =
    let(fil = get_val("FILAMENT_TYPE", data, FIL_PLA), mod = get_fit_mod(data),
        loop_bonus = loop_excess(data) * STEP_LOOP_ENG)
    (component == COMP_CLASP) ?
        ((fil == FIL_PETG) ? ENG_CLASP_PETG : (fil == FIL_TPU) ? ENG_CLASP_TPU : ENG_CLASP_PLA) - (mod * STEP_ENG) + loop_bonus :
    (component == COMP_BELLY) ?
        ((fil == FIL_PETG) ? ENG_BELLY_PETG : (fil == FIL_TPU) ? ENG_BELLY_TPU : ENG_BELLY_PLA) + loop_bonus :
    0.0;


// ==============================================================================
// FROZEN: FLIP-LID DERIVED GEOMETRY  [review #3/#7]
// ==============================================================================
// Flip lids are FROZEN after a failed print test (sideways slide on the C-clip,
// weak latch retention). The live small-organizer path is the Glide pillbox.
// This stays because the build matrix still exercises Flip Single/Double, but do
// NOT extend flip geometry without a deliberate mechanical redesign.
//
// Moved here from MasterManifest.scad (Layer 2 → Layer 1.8): it is a
// tolerance-driven dimension (spine_gap = breathing_room(COMP_SPINE)), not
// intent-compiler logic, so it belongs alongside breathing_room above.
//
// flip_half_lid_l: Flip_Double centres the spine; each lid covers one half.
// Assembly flips the lid 180° (C-clip faces the spine). Latch lands at:
//   hinge_y + lid_l + cc_z = l/2  →  flip_half_lid_l = l/2 - spine_gap
// (l/2 - hinge_y left cc_z = 3.85mm short; the latch missed the recess every print.)
function flip_half_lid_l(data) =
    let(spine_gap = breathing_room(COMP_SPINE, data))
    get_val(LENGTH, data, LENGTH0) / 2 - spine_gap;