# MasterTray Builder — QA / Build Guide

Build printable parts without needing to know anything about OpenSCAD or the
Customizer. Everything is described in plain terms: container size, lid type,
filament, etc.

**Prefer a web UI?** The [`/builder`](/builder) page on the Astro site offers the
same options as a form, and can generate a `.ps1` script or build the STL directly
via a local server (`just build-server`). See `docs/TOOLS.md` section 9 for details.

## Setup (one-time)

Requires Python 3 with PyYAML:
```
pip install pyyaml
```

## Quick start

The examples below assume you're in the repo root (`python build/mastertray.py
...`). All paths in `mastertray.py` and `build/build.py` are resolved from the
script's own location, so if you `cd build` first, drop the `build/` prefix
(`python mastertray.py ...`) — both work the same, and `--out`/`--config`
paths are always resolved relative to wherever you're running from.

```powershell
# See what you can build
python build/mastertray.py list intents

# See what lid types are available for a container
python build/mastertray.py list lids --intent Container

# Build a container + lid as one set
python build/mastertray.py build --intent Container --lid "Flip (Double)" `
    --width 50 --length 100 --height 30 --out my_box.stl

# Build just a replacement lid (box already printed)
python build/mastertray.py build --intent "Container Lid" --lid "Flip (Single)" `
    --width 40 --length 80 --out my_lid.stl
```

`--width`, `--length`, `--height` are in millimetres. For "Container Lid",
use the **same dimensions as the box** — the tool figures out the correct
lid size automatically (including splitting Flip (Double) into its two
half-lids).

## Even quicker: build/build.py

`build/build.py` is a terser shorthand front-end for the same `mastertray.py
build` command above — a short intent name plus comma-separated option
groups, no `--intent`/`--width`/`--length`/`--height` needed:

```powershell
# Same defaults as MasterBuilder.scad itself -> box.stl
python build/build.py

# intent "box" (see build/mapping.yaml cli_aliases) -> box.stl
python build/build.py box

python build/build.py box -o my_box.stl

# Total (outer) dimensions, mm: LxWxH
python build/build.py box -dim "100x50x30"

# Usable (interior) dimensions, mm: LxWxH
python build/build.py box -use "100x50x30"

# Mesh pattern: name, hole size, hole spacing
python build/build.py box -mesh "Slotted, 1.8, 1.2"

# Strut (solid %): lid, floor, wall
python build/build.py box -strut "40, 50, 30"

# One build per lid type, output names get the lid name appended
python build/build.py box -lid "Flip (Single), Flip (Double)"
```

`--config`, `--set`, `--dry-run`, `--hardwarnings`, `--export-format`,
`--openscad`, and `--no-report` all pass through unchanged. Run
`python build/build.py --help` for the full flag list, and see
`build/mapping.yaml`'s `cli_aliases` section for all intent shorthands
(`box`, `lid`, `tray`, `jar`, `pillbox`, ...).

## Dimension mode

```powershell
python build/mastertray.py build --intent Container --lid "Snap (Outer Wall)" `
    --width 50 --length 100 --height 30 --mode Usable --out my_box.stl
```

- `Total` (default) — width/length/height are the **outside** dimensions of
  the finished container.
- `Usable` — width/length/height are the **inside** (storage) dimensions;
  the tool adds wall thickness automatically.

## Lid types

For `--intent Container` (build a box + matching lid together):

| Lid type | Description |
|---|---|
| `Snap (Outer Wall)` | Press-fit lid, retention bead clicks under the outer wall rim |
| `Snap (Inner Wall)` | Press-fit lid, retention bead clicks into a groove inside the wall |
| `Slide (Outer Wall)` | Lid slides into grooves on the outside of the walls |
| `Slide (Inner Wall)` | Lid slides into grooves on the inside of the walls |
| `Flip (Single)` | Hinged lid with one C-clip hinge and one latch |
| `Flip (Double)` | Hinged lid in two halves, opening from a centre spine |

For `--intent "Container Lid"` (reprint a single lid for an existing box),
all of the above are available, plus:

| Lid type | Description |
|---|---|
| `Plain` | Flat press-fit slab, no retention — for prototyping |
| `Screw Cap` | Threaded cap (for jars) |

### Slide options

If you picked a `Slide (...)` lid type, you can also set:

```powershell
--slide-direction Horizontal   # or Vertical
--slide-catch "Ball Detent"    # or "Tab Detent"
```

## Printer / material settings

If you don't pass `--config`, `MasterBuilder.scad`'s own Customizer defaults
apply (roughly: 0.4mm nozzle, 2 walls, 0.28mm layer height, PLA, Standard fit).
To override printer settings, copy the example config and pass it with
`--config`:

```powershell
python build/mastertray.py init-config
# writes build/sandbox/printer.yaml, mesh.yaml, advanced.yaml (gitignored)
# edit build/sandbox/printer.yaml as needed
python build/mastertray.py build --intent Container --lid "Flip (Single)" `
    --width 50 --length 100 --height 30 `
    --config build/sandbox/printer.yaml `
    --out my_box.stl
```

`--config` is repeatable and order-sensitive (later files win on conflicting
keys), so you can mix and match:

```powershell
python build/mastertray.py build --intent Container --lid "Flip (Single)" `
    --width 50 --length 100 --height 30 `
    --config build/sandbox/printer.yaml --config build/sandbox/mesh.yaml `
    --out my_box.stl
```

`build/sandbox/` is your personal scratch space — anything written there is
gitignored, so feel free to experiment. `build/configs/` holds versioned
*example* override files (not defaults); don't edit those directly. Pass
`--out my_settings` to `init-config` if you'd rather use a different directory.

## Mesh (decorative pattern) settings

`build/configs/mesh.yaml` is an example `--config` file for the decorative
perforation pattern on walls/floor/lid. Default (no `--config`) is
`pattern: None` (solid). See comments in that file for all options.

## Advanced settings

`build/configs/advanced.yaml` is an example `--config` file for wall/floor/lid
thicknesses and other engineering parameters. The Customizer defaults are
correct for almost all builds — check with a developer before overriding these.

## Build reports

Every successful build also writes `<out>.report.yaml` and `<out>.report.html`
next to the output file (e.g. `my_box.stl` → `my_box.report.yaml` and
`my_box.report.html`). They record the build parameters, the resulting
printer/slicer settings, the full set of Customizer overrides used, and a
`changes:` list of any `--config` values that differ from the
`build/configs/*.yaml` defaults. The `.yaml` report is for diff tooling; the
`.html` report is a styled page for viewing in a browser. Use these to
document a specific build or diff two builds against each other. Pass
`--no-report` to skip both.

## Other useful flags

```powershell
--dry-run            # show what would be run, without building
--hardwarnings       # fail (exit code 1) if OpenSCAD reports geometry warnings
--export-format 3mf  # export as 3MF instead of STL
--no-report          # skip writing <out>.report.yaml / <out>.report.html
```

## Troubleshooting

- **"unknown --lid"** — run `list lids --intent <your intent>` to see valid
  names for that intent (lid options differ between Container and Container Lid).
- **"config file not found"** / **"unknown key"** — run `init-config` to get a
  starting template, or check your `--config` file paths and key names against
  `build/mapping.yaml`'s `config.*` sections.
- For anything not covered here, ask a developer — see `docs/CLI_GUIDE.md`
  and `build/mapping.yaml` for the full technical reference.
