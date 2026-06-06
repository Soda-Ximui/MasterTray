# MasterTray — Project Status
_Human-readable. Updated at the end of each session._

---

## What Is This?

A parametric OpenSCAD system that generates 3D-printable storage containers — jars, boxes, trays, lids, pill organizers — from a single Customizer UI. You pick the intent ("Jar with Lid", "7-Day Pill Box", etc.), dial in dimensions and mesh density, and it produces print-ready geometry.

---

## What Works Right Now

### Containers
| Container | Status | Notes |
|-----------|--------|-------|
| Tray | ✅ | Stackable, peg variants |
| Box | ✅ | Snap/flip/double-flip lid variants |
| Jar | ✅ | Open, threaded, polygonal sides |
| Lid | ✅ | Screw, snap, glide, flip latch |
| Grid (drop-in) | ✅ | Rectangular and radial (jar) |

### Pill Box Presets
All wired and ready to render from the Customizer dropdown:
- 1-Day AM/PM, 1-Day 2-Compartment
- 7-Day, 14-Day AM/PM
- Pillbox Set (Single Lid), Pillbox Set (Double Lid), Pillbox Full Set

### Mesh System
| Feature | Status |
|---------|--------|
| Teardrop / slotted hole patterns | ✅ |
| Flat floor mesh (circular + rectangular) | ✅ |
| Cylindrical wall mesh | ✅ |
| Strut% — solid border within mesh zone | ✅ |
| Min structural margin (no-hole zone at every edge) | ✅ Done this session |

The minimum margin guarantees a solid ring at jar neck, box lip, and floor/wall bond — even when strut=0%. Size: nozzle diameter × wall loop count (≈1.2mm at standard settings).

---

## What To Try In OpenSCAD

Open `MasterBuilder.scad`, press **F5** (preview) or **F6** (full render).

**Quick sanity render (PowerShell):**
```powershell
$o = "C:\Program Files\OpenSCAD\openscad.com"
& $o -o output/test.png --render --camera=80,0,30,55,0,20,500 --colorscheme=DeepOcean -D 'Part_To_Build="Jar with Lid"' MasterBuilder.scad
```

**Color guide (DeepOcean scheme):**
- Blue = outer surfaces (correct)
- Red = inner/back faces visible through holes (normal and expected)
- Bright magenta = geometry problem (use F12 in GUI to investigate)

**Test dimensions (currently set in MasterBuilder.scad):**
```
Width=54.5  Length=54  Height=55
Hole size=1.6mm  Spacing=1.2mm
Wall strut=0%   Floor strut=25%   Lid strut=75%
```
At wall strut=0% you should see a narrow solid band at the very top and bottom of the jar wall. That's the structural margin working.

---

## What Is Not Done Yet

| Item | Priority | Notes |
|------|----------|-------|
| RIB primitive | Low | FrankenTray vector ribs — code stub in `RenderRib.scad` |
| Flip-box hinge assert (F15) | Medium | `RenderBox.scad ~L103` |
| Snap bead layer-align (F14) | Medium | `RenderLid.scad ~L44` |
| Diamond latch layer_snap (F6) | Low | `RenderLid.scad ~L120` |

---

## Grid Layout String — Quick Reference

| Token | Meaning |
|-------|---------|
| `4x3` | 4 columns × 3 rows cartesian grid |
| `R4` | 4 radial spokes (jar only), flush with jar mouth |
| `R4/80` | 4 spokes at 80mm absolute — pokes above jar mouth |
| `R4/150%` | 4 spokes at 150% of interior height |
| `R4/80,55` | **Cycling heights** — alternates tall/short per spoke (crown/flower effect) |
| `R6/100,80,60` | Cycles 3 heights over 6 spokes: 100, 80, 60, 100, 80, 60 |
| `C15%` | Hub cylinder = 15% of jar diameter |
| `C15%/120%` | Hub with explicit height override |
| `S1/1/2/3/150%` | Span at row 1 col 1, 2 cols wide, 3 rows tall, 150% wall height |

Poke-through (heights > jar interior) is allowed for **open jars** — pencil/utensil holder use case. Clamped automatically for threaded jars and all box types.

`grid_type = "Drop-in"` with a valid grid_layout string automatically adds a separate GRID object alongside the container. Invalid strings (`"Hello world"`) are silently ignored.

---

## Known Quirks (Non-Breaking)

- Grid layout strings with both `R` and `S` tokens in a JAR build: only the radial grid renders. Rectangular spans inside a circular jar don't make physical sense. Want rectangular grid in a jar? New build, drop the `R` token.

---

## How To Build

```powershell
just render          # quick preview → output/preview.png
just render-all      # renders every major intent → output/*.png
just dev             # Astro docs site → localhost:4321
```

---

## Docs Site

```powershell
cd astro && pnpm dev   # → http://localhost:4321
```
Full documentation, architecture diagrams, mesh guide, feature reference.
