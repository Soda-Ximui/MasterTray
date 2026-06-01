// ==============================================================================
// FILE: MasterChecks.scad [v4.0]
// ARCHITECTURE: Layer 1.1 (Safety & Tolerance Validation)
// ==============================================================================
include <MasterEngine.scad>

// --- Z-Axis Safety ---
// Floors and lids must be strict multiples of the slicer's layer height to prevent micro-stepping errors.
// They are also dynamically capped at 35% of the total object height to prevent an accidentally
// thick floor from turning a small tray into a solid brick of plastic.
function m_safe_floor(data) = max(m_lh(data), round(min(get_val(THICK_FLOOR, data, THICK_FLOOR0), m_bh(data) * 0.35) / m_lh(data)) * m_lh(data));
function m_safe_lid(data) = max(m_lh(data), round(min(get_val(THICK_LID, data, THICK_LID0), m_bh(data) * 0.35) / m_lh(data)) * m_lh(data));

// --- X/Y-Axis Safety ---
// Forces requested wall thicknesses to snap to exact multiples of the nozzle diameter.
// It strictly enforces the minimum physical thickness requirement: (Nozzle Size * Wall Loops).
function m_safe_wall(data) = max(m_noz(data) * m_wloops(data), round(min(get_val(THICK_WALL, data, THICK_WALL0), min(m_bw(data), m_bl(data)) * 0.45) / m_noz(data)) * m_noz(data));

// --- Geometric Hardware Bounds ---
// Automatically derives a safe inner bounding box corner radius based on the requested wall thickness.
// If the corner radius drops below the wall thickness, internal geometry breaks and inverts.
function m_c_rad(data) = m_safe_wall(data) + ((m_noz(data) * m_wloops(data)) / 2) - 0.5; 

// Ensures any generated chamfers do not exceed physical FDM overhang limits (capped around 2.5x nozzle).
function m_chamf(data) = m_noz(data) * 2.5;

// Safely parses string-based wall modification toggles ("50%", "Dropped") into a functional 0-100 decimal multiplier.
function m_wall_mod_p(data) = let(s = str(get_val(WALL_MODIFY, data, WALL_MODIFY0))) (s == "None") ? 100 : (s == "Dropped") ? 0 : let(n = get_digits(s)) len(n)==1?n[0]:len(n)==2?n[0]*10+n[1]:len(n)==3?n[0]*100+n[1]*10+n[2]:100;