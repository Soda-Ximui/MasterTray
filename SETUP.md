# MasterTray — Dev Environment Setup

## Current tooling

| Tool | Status | Notes |
|------|--------|-------|
| Docker | ✅ Installed | |
| Mermaid | ✅ Installed | Renders `docs/SEQUENCE_DIAGRAMS.md` |
| pwsh | ✅ Default shell | `TODO.ps1` runs natively |
| Git | ✅ | |

---

## OpenSCAD CLI — highest priority install

The biggest gap in the dev loop. Every geometry fix is currently verified by
reading math only. With OpenSCAD headless, changes can be rendered and confirmed
before committing.

### Option A — Native Windows (recommended)

```powershell
winget install OpenSCAD.OpenSCAD
```

Gives you `openscad.com` on PATH. Verify with:

```powershell
openscad.com --version
```

Render to PNG for quick visual check:

```powershell
openscad.com -o out.png --camera=0,0,0,55,0,25,200 --render MasterBuilder.scad
```

Render to STL for slicer import:

```powershell
openscad.com -o out.stl MasterBuilder.scad
```

Pass Customizer variables from the command line:

```powershell
openscad.com -o out.stl -D 'Part_To_Build="Jar with Lid"' -D 'part_width=46' MasterBuilder.scad
```

### Option B — Docker (no install, display not needed)

```powershell
docker run --rm -v ${PWD}:/work openscad/openscad `
    openscad -o /work/out.stl /work/MasterBuilder.scad
```

---

## Nice-to-have

| Tool | Install | Use in this project |
|------|---------|---------------------|
| Python 3 | `winget install Python.Python.3` | Replace `build.pl`; generate `docs/images/` stubs |
| ImageMagick | `winget install ImageMagick.ImageMagick` | Crop/annotate rendered PNGs for symptom docs |
| Perl | `winget install StrawberryPerl.StrawberryPerl` | `build.pl` already in repo |

---

## What OpenSCAD CLI unlocks

Right now every geometry change (lid heights, chamfer math, strut scaling) is
verified by reading the code. With headless rendering:

- Render before/after a fix and diff the PNG visually
- Smoke-test all 23 intents in a loop without opening the GUI
- Generate `docs/images/` reference renders automatically
- Catch silent geometry failures (negative dimensions, zero-height features)
  that only show up in a render, not in the math
