// ==============================================================================
// FILE: MasterText.scad [v4.0]
// ARCHITECTURE: Layer 1.2 (Text & Font Geometry Engine)
// ==============================================================================
include <MasterEnum.scad>

// --- Dynamic Plaque Sizing ---
// Approximates the physical X-axis width of a text string based on font size and character count.
// Uses a standard kerning multiplier (0.65) to ensure auto-generated backing plates are 
// always large enough to frame the user's string without manual slider adjustments.
function get_text_plaque_width(txt, size, min_w=25) = max(min_w, size * len(txt) * 0.65);

// --- 3D Text Renderer ---
// Standardized wrapper for generating embossed or debossed text.
// Ensures consistent center/center origin alignment and handles empty string skips.
module render_embossed_text(txt, size, depth=1.0, f="Arial Black") {
    if (txt != "") {
        linear_extrude(depth) text(txt, size=size, font=f, halign="center", valign="center");
    }
}