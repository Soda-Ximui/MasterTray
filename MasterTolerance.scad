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
ROOM_SPINE_PETG = 0.50; ROOM_SPINE_TPU = 0.20; ROOM_SPINE_PLA = 0.30;
ROOM_CCLIP_PETG = 0.25; ROOM_CCLIP_TPU = 0.10; ROOM_CCLIP_PLA = 0.15;
ROOM_GLIDE_PETG = 0.40; ROOM_GLIDE_TPU = 0.60; ROOM_GLIDE_PLA = 0.20; 

// --- BASELINE ENGAGEMENTS (Overlap / Depth) ---
// Larger number = deeper/tighter grab
ENG_CLASP_PETG = 4.6; ENG_CLASP_TPU = 5.5; ENG_CLASP_PLA = 4.0;
ENG_BELLY_PETG = 0.6; ENG_BELLY_TPU = 0.4; ENG_BELLY_PLA = 0.5;

// --- MODIFIER STEP CONSTANTS ---
STEP_ROOM = 0.05; // Adjusts gap clearances by 50 microns per fit level
STEP_ENG  = 0.20; // Adjusts snap engagements by 0.2mm per fit level


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
    let(fil = get_val("FILAMENT_TYPE", data, FIL_PLA), mod = get_fit_mod(data))
    (component == COMP_SPINE) ? 
        ((fil == FIL_PETG) ? ROOM_SPINE_PETG : (fil == FIL_TPU) ? ROOM_SPINE_TPU : ROOM_SPINE_PLA) + (mod * STEP_ROOM) :
    (component == COMP_CCLIP) ? 
        ((fil == FIL_PETG) ? ROOM_CCLIP_PETG : (fil == FIL_TPU) ? ROOM_CCLIP_TPU : ROOM_CCLIP_PLA) + (mod * STEP_ROOM) :
    (component == COMP_GLIDE) ? 
        ((fil == FIL_PETG) ? ROOM_GLIDE_PETG : (fil == FIL_TPU) ? ROOM_GLIDE_TPU : ROOM_GLIDE_PLA) + (mod * STEP_ROOM) :
    0.0;

function engagement_depth(component, data) = 
    let(fil = get_val("FILAMENT_TYPE", data, FIL_PLA), mod = get_fit_mod(data))
    (component == COMP_CLASP) ? 
        ((fil == FIL_PETG) ? ENG_CLASP_PETG : (fil == FIL_TPU) ? ENG_CLASP_TPU : ENG_CLASP_PLA) - (mod * STEP_ENG) :
    (component == COMP_BELLY) ? 
        ((fil == FIL_PETG) ? ENG_BELLY_PETG : (fil == FIL_TPU) ? ENG_BELLY_TPU : ENG_BELLY_PLA) : 
    0.0;