// ==============================================================================
// FILE: MasterSafety.scad [v1.0]
// ARCHITECTURE: Layer 1.1 (Safety & Tolerance Validation)
// PURPOSE: FDM-specific safety constraints (split from MasterChecks v4.0)
// ==============================================================================

include <MasterEngine.scad>
include <MasterConstants.scad>

// === Z-AXIS SAFETY: Layer Height Alignment ===
// Floors and lids must be strict multiples of the slicer's layer height to prevent micro-stepping.
// "Micro-stepping" = slicing engine applies tiny Z-movements between layers, causing:
//   - Surface roughness on top/bottom
//   - Layer adhesion stress
//   - Warping on large flat surfaces
// 
// Example: 2.0mm floor on 0.20mm layer height
//   Safe:   round(2.0 / 0.20) * 0.20 = 2.0mm (10 exact layers)
//   Unsafe: 2.0mm / 0.20 = 10.0 (exact, but only by luck—no rounding)
//
// Also capped at 35% of total height to prevent accidentally thick floors
// turning small trays into solid bricks of plastic.

function m_safe_floor(data) = 
    max(
        m_lh(data), 
        round(
            min(
                get_val(THICK_FLOOR, data, THICK_FLOOR0), 
                m_bh(data) * (MAX_FLOOR_THICKNESS_PCT / 100)
            ) / m_lh(data)
        ) * m_lh(data)
    );

function m_safe_lid(data) = 
    max(
        m_lh(data), 
        round(
            min(
                get_val(THICK_LID, data, THICK_LID0), 
                m_bh(data) * (MAX_LID_THICKNESS_PCT / 100)
            ) / m_lh(data)
        ) * m_lh(data)
    );

// === X/Y-AXIS SAFETY: Nozzle Diameter Alignment ===
// Wall thicknesses must snap to exact multiples of the nozzle diameter.
// Reason: FDM extrusion is delivered in discrete threads of plastic.
// If wall = 2.3mm but nozzle = 0.4mm, slicer generates:
//   - 5 passes @ 0.4mm = 2.0mm (undersize, weak)
//   - 6 passes @ 0.4mm = 2.4mm (oversize, might hit adjacent geometry)
// 
// Solution: Force walls to 2.0mm or 2.4mm, eliminating ambiguity.
// Also enforces minimum: (Nozzle Size × Wall Loops)
// Example: 0.4mm nozzle × 3 loops = minimum 1.2mm wall

function m_safe_wall(data) = 
    max(
        m_noz(data) * m_wloops(data),  // Minimum physical thickness
        round(
            min(
                get_val(THICK_WALL, data, THICK_WALL0), 
                min(m_bw(data), m_bl(data)) * (MAX_WALL_THICKNESS_PCT / 100)
            ) / m_noz(data)
        ) * m_noz(data)
    );

// === GEOMETRIC HARDWARE BOUNDS: Corner Radius ===
// Automatically derives a safe inner bounding box corner radius based on wall thickness.
// Why this matters: BOSL2's `cuboid(..., rounding=r)` applies radius to *outer* edges.
// If the inner radius drops below the wall thickness, internal geometry breaks and inverts.
// 
// Formula: wall_thickness + (min_extrusion × 0.5) - 0.5
// The 0.5mm margin prevents edge cases where rounding is *exactly* at the boundary.

function m_c_rad(data) = 
    m_safe_wall(data) + ((m_noz(data) * m_wloops(data)) / 2) - 0.5;

// === OVERHANG SAFETY: Chamfer Limits ===
// FDM printers struggle with overhangs beyond 45° (critical angle).
// At 45°, supported height = overhang distance.
// Chamfers beyond 2.5x nozzle diameter cause bridging failures.
// 
// Example: 0.4mm nozzle → max chamfer 1.0mm (0.4 × 2.5)
// Excessive chamfer (e.g., 3mm) causes slicer to generate unsupported bridges.

function m_chamf(data) = m_noz(data) * MAX_CHAMFER_MULT;

// === WALL MODIFICATION SAFETY: Parse & Validate ===
// Safely parses string-based wall modification toggles into a 0-100 decimal multiplier.
// Input formats:
//   "None"     → 100 (full height)
//   "Dropped"  → 0 (no wall)
//   "50%"      → 50
//   "25%"      → 25
// 
// Regex-free approach: extract all digits, interpret as single/dual/triple digit number.

function m_wall_mod_p(data) = 
    let(s = str(get_val(WALL_MODIFY, data, WALL_MODIFY0))) 
    (s == "None") ? 100 : 
    (s == "Dropped") ? 0 : 
    let(n = get_digits(s)) 
    (len(n) == 1) ? n[0] : 
    (len(n) == 2) ? n[0] * 10 + n[1] : 
    (len(n) == 3) ? n[0] * 100 + n[1] * 10 + n[2] : 
    100;

// === AUDIT LOG ===
// v1.0: Split from MasterChecks v4.0 to isolate FDM safety logic
//       Allows future split of printer profiles into separate module
//       All comments expanded with engineering rationale
