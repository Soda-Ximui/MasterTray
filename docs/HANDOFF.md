# Session Handoff — MasterTray
_Last updated: 2026-06-05 — mesh semantics, strut fixes, Astro site_

---

## How to Resume

```
cd C:\repos\3D\MasterTray
claude
```

Then tell Claude: "Read HANDOFF.md and continue."

---

## Branch & State

**Branch:** `refactor/code-clarity-and-safety`
**Last commit:** `bcc83d6`
**Status:** All committed, NOT pushed since last session.

```
bcc83d6 fix: jar floor strut% now relative to visible inner diameter
87cf6a1 test: set defaults for strut% visual verification
4559f87 docs: clarify strut% vs hole spacing semantics in engine comments
1b38d52 refactor: remove needs_margin — container geometry owns the solid edge
5e55c74 fix: screw lid strut not sticking — needs_margin=false for Screw type
e679682 fix: mesh defaults — hole 2.0mm, struts 25%, spacing min 1.0mm
fb55c04 fix: mesh_hole_spacing default 0.8mm — remove misleading 0=auto sentinel
fc018da fix: restore mesh_hole_spacing Customizer knob; add Double Flip Box to dropdown
59a4179 refactor: move root *.md into docs/, simplify Astro content glob
```

---

## What Was Done This Session

### Astro docs site fixes
- Dead links fixed — content collection now covers `docs/**/*.md` (all root-level docs moved into `docs/`)
- Mermaid diagrams render as SVG (Shiki uses `pre[data-language="mermaid"]`, not `code.language-mermaid`)
- All Astro root config files committed (`package.json`, `astro.config.mjs`, etc.)
- Old `html/` static site and `index.html` deleted — Astro replaces them
- `.claude/launch.json` updated with Astro dev server entry (port 4321)
- `justfile` completely rewritten: `just dev`, `just build`, `just serve` (Caddy), `just e2e` (Playwright), `just render`, `just render-all`

### Tools confirmed installed
| Tool | Status |
|------|--------|
| Playwright | ✅ Installed |
| Caddy | ✅ Installed |
| Bruno | ✅ Installed |

### Mesh system fixes

**Strut% semantics (critical — was confused, now correct):**
- `strut%` = solid BORDER region surrounding the mesh (NOT hole density)
- `hole spacing` = density/pitch of holes within the mesh region (independent of strut%)
- For rectangular: strut% shrinks the inner mesh rectangle, leaving a solid border on each side
- For cylindrical: strut% sets solid band height at top + bottom; mesh fills the middle
- These two controls are fully orthogonal — `get_grid_step` never reads strut%, `get_mesh_dim` never reads spacing

**`needs_margin` removed entirely (`1b38d52`):**
- Was forcing lid strut% to `max(user, (200×min_solid_edge)/size)` — silently overriding user settings
- Correct principle: the minimum solid margin at jar neck / box lip is provided by the PHYSICAL container geometry (jar neck cylinder, box wall), not by the mesh border
- `needs_margin` parameter removed from `get_mesh_cfg`; `LID_MIN_SOLID` and `min_solid_edge_for_lid` deleted

**Mesh defaults fixed (`e679682`):**
- `mesh_hole_size`: `0.0` → `2.0mm` (was triggering `hole <= 0.05` guard → no mesh ever rendered → strut% had nothing to work on)
- `strut_*_perc`: `100` → `25%` (100 also disables mesh)
- `mesh_hole_spacing` min slider: `0.1` → `1.0mm`

**Customizer additions:**
- `mesh_hole_spacing = 0.8` added to `[Mesh Aesthetics]` below hole size
- `"Double Flip Box"` added to `Part_To_Build` dropdown (was implemented in manifest but missing from UI)

**Jar floor strut fix (`bcc83d6`):**
- Bug: floor mesh used full outer diameter `w`. Jar wall (sw≈2.4mm) covers the outer ring of the floor, hiding most of the strut border. At 25% strut on a 54mm jar, visible solid ring was only ~1.25mm instead of expected ~3.6mm.
- Fix: split floor into two parts in `RenderJar.scad`:
  1. Outer solid ring (`w` to `inner_d = w - sw*2`) — structural, hidden under wall
  2. Inner meshed disc (`inner_d`) — strut% relative to visible inner area

---

## IMMEDIATE NEXT STEP — min_margin in mesh system

**This was agreed on in the session and must be implemented.**

**The principle:** ALL mesh surfaces reserve a minimum structural margin BEFORE strut% applies. strut=0% should never push holes into structurally required material — it means "mesh to the edge of the safe zone."

Currently strut=0% means:
- Floor: holes go right to the inner wall edge (no minimum ring)
- Cylindrical wall: holes span full cylinder height (no minimum solid bands at top/bottom)
- Lid: holes go to the lid edge

**The fix:** add `min_margin = noz * m_wloops(data)` to `mesh_params` as a 6th return element, then use it in `framed_mesh` and `cylindrical_mesh_wall`.

### mesh_params (RenderMesh.scad ~L36)
Add `min_m = noz * m_wloops(data)` and return as `[noz, pat, hole, strut, step, min_m]`.

### framed_mesh (RenderMesh.scad ~L53)
```scad
min_m = mp[5];
eff_w = max(0.1, w - 2*min_m);
eff_l = max(0.1, l - 2*min_m);
// For circular:
mesh_d = eff_w * sqrt(max(0, 1 - strut/100));
// For rectangular:
mesh_w = max(0.1, eff_w * (1 - strut/100) - pad);
mesh_l = max(0.1, eff_l * (1 - strut/100) - pad);
// Update nx/ny based on mesh_d or mesh_w/mesh_l
// Update clip circle/rect to use mesh_d / [mesh_w, mesh_l]
```

### cylindrical_mesh_wall (RenderMesh.scad ~L94)
```scad
min_m    = mp[5];
eff_h    = max(0.1, h - 2*min_m);
h_mesh   = eff_h * (1 - strut/100);
z_offset = min_m + (eff_h - h_mesh) / 2;
// replace: z_pos = (h - h_active)/2 + ...
// with:    z_pos = z_offset + (i + 0.5) * z_step
```

**Result at strut=0%:** holes stop `min_m ≈ 0.8mm` from every structural edge. Hole density unchanged.

**After implementing:** re-render with test defaults (below) and confirm visible solid bands on wall at strut=0%.

---

## Test Defaults (leave in MasterBuilder.scad)

```scad
part_width = 54.5;  part_length = 54;  part_height = 55;
mesh_hole_size = 1.6;   mesh_hole_spacing = 1.2;
strut_wall_perc  =  0;   // should show narrow solid band at top+bottom after min_margin fix
strut_floor_perc = 25;   // should show clear solid ring inside jar
strut_lid_perc   = 75;   // should show mostly solid with small central mesh
```

**Render command (PowerShell):**
```powershell
$o = "C:\Program Files\OpenSCAD\openscad.com"
& $o -o output/test.png --render --camera=80,0,30,55,0,20,500 --colorscheme=Tomorrow -D 'Part_To_Build="Jar with Lid"' MasterBuilder.scad
```

---

## Key Architecture Rules

| Rule | Where |
|------|-------|
| strut% = solid border surrounding mesh region | RenderMesh.scad header |
| hole size + spacing = density, independent of strut% | MasterEngine.scad `get_grid_step` |
| Container geometry owns the structural margin (not the mesh) | MasterEngine.scad `get_mesh_cfg` comment |
| Jar floor mesh uses inner_d (w - sw*2), not outer w | RenderJar.scad |
| Factory IS the implementation — opts drive variants | LESSONS.md §1 |
| All circle dims are diameters | LESSONS.md §0b |
| Support-free always | LESSONS.md §0c |
| 0 = auto for geometry overrides (chamfer, corner radius) | MasterBuilder Advanced |
| Salvage from 858dabc and d84fbcc before writing | LESSONS.md feedback |

---

## Key Files

| File | Purpose |
|------|---------|
| `MasterBuilder.scad` | Customizer UI — USE THIS |
| `MasterManifest.scad` | Intent → component list |
| `MasterEngine.scad` | Physics getters, `get_mesh_cfg`, `get_grid_step` |
| `MasterConstants.scad` | All named constants |
| `RenderMesh.scad` | `framed_mesh` + `cylindrical_mesh_wall` — **min_margin needed here** |
| `RenderJar.scad` | Jar factory — floor split into outer ring + inner disc this session |
| `RenderLid.scad` | All lid types — needs_margin removed this session |
| `docs/BUGS.md` | B1 (sqrt scaling), B2 (screw lid height) |
| `astro/` | Docs site — `cd astro && pnpm dev` → localhost:4321 |

---

## Primitives Status

| # | Primitive | Status |
|---|-----------|--------|
| 1 | TRAY | ✅ Done |
| 2 | JAR | ✅ Done (floor strut fix this session) |
| 3 | LID | ✅ Done (needs_margin removed this session) |
| 3b | BOX | ✅ Done |
| 4 | GRID | ✅ Done |
| 5 | RIB | ⬜ Not started |

Pill box intents (1-Day, 7-Day, 14-Day, Pillbox Set) are wired in MasterManifest.scad.

---

## Open Code Items (from TODO.md Priority 1)

| ID | File | Issue |
|----|------|-------|
| F15 | RenderBox.scad ~L103 | flip-box hinge assert |
| F18 | RenderGrid.scad | lip_h → JAR_LIP_HEIGHT (check if done) |
| F6 | RenderLid.scad ~L120 | diamond latch layer_snap |
| F14 | RenderLid.scad ~L44 | snap bead layer-align |

---

## Uncommitted / Untracked

```
 M gemini               ← leave alone (unrelated)
?? .claude/settings.json
?? astro/.vscode/
?? build.pl
?? output/             ← render outputs, not tracked
```
