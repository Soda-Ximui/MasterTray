// ==============================================================================
// FILE: MasterText.scad
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
//
// Font default is "Liberation Sans:style=Bold", which OpenSCAD bundles on every
// platform. A system font like "Arial Black" renders locally on Windows but is
// ABSENT on headless/Linux cloud render servers and CI — where text() silently
// falls back or fails, producing a wrong or empty STL with no error. Liberation
// is metric-compatible with Arial, so backing-plate sizing (TEXT_KERNING_MULT)
// stays valid. Override `f` only with another guaranteed-present font.
module render_embossed_text(txt, size, depth=1.0, f="Liberation Sans:style=Bold") {
    if (txt != "") {
        linear_extrude(depth) text(txt, size=size, font=f, halign="center", valign="center");
    }
}