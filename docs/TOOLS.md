# MasterTray Project Tools

Reference for every tool available in this repo — both the project automation scripts and the underlying runtime environment they depend on.

---

## Environment / Runtimes

| Tool | Version | Path | Notes |
|---|---|---|---|
| **OpenSCAD** | 2026.04.26 | `C:\Program Files\OpenSCAD\openscad.exe` | Use this path in scripts; CGAL manifold backend enabled via Preferences → Features → manifold |
| **Python** | 3.14.5 | `C:\Python314\python.exe` | Use this interpreter, not the WindowsApps shim |
| **pymeshlab** | 2025.7.post1 | (Python package) | `pip install pymeshlab` — required by `check_manifold.py` and `nm_hunt.py` |
| **Perl** | 5.42.2 (Strawberry) | `C:\Strawberry\perl\bin\perl.exe` | Use Strawberry Perl for `build.pl`; the Git-bundled `/usr/bin/perl` lacks the required modules |
| **Template (TT2)** | 3.102 | (Strawberry Perl module) | Required by `build.pl` for report generation |
| **YAML::Tiny** | 1.76 | (Strawberry Perl module) | Required by `build.pl` for queue parsing |
| **PowerShell** | 7+ (pwsh) | system | Used by `TODO.ps1` and for general shell work |

**PATH note:** When invoking Perl from PowerShell, call Strawberry explicitly:
```powershell
C:\Strawberry\perl\bin\perl.exe build.pl queue.yaml
```
Or ensure `C:\Strawberry\perl\bin` precedes the Git Perl in `$env:PATH`.

---

## 1. `check_manifold.py` — Quick NM Edge Scanner

**Purpose:** Scan one or more exported STL/3mf files for non-manifold edges using pymeshlab. Fast sanity-check before slicing.

**Usage:**
```powershell
# Scan all STL files in the STL/ directory (default)
python check_manifold.py

# Scan a specific directory
python check_manifold.py output/

# Scan a single file
python check_manifold.py "output/Flip Single.stl"
```

**Output:** Per-file report of `nm_edges` (shared by >2 faces) and `boundary` (shared by 1 face). Zero nm_edges = manifold. Does NOT distinguish benign platter artifacts from real bugs — use `nm_hunt.py` for that.

**Requires:** `pip install pymeshlab`

---

## 2. `nm_hunt.py` — Automated Export + Manifold Check Pipeline

**Purpose:** Drives the full regression pipeline. Exports all 13 lid/box combinations via OpenSCAD CLI, runs manifold checks on each, and classifies results as OK / PLATTER-ARTIFACT / REAL BUG.

Eliminates the manual export-check-repeat cycle. Claude can run this end-to-end without human bottleneck.

**Usage:**
```powershell
python nm_hunt.py
```

**Test matrix (13 cases):**

| Label | Part | Key override |
|---|---|---|
| `Snap_Ext_Box` | Box | `Snap_External=true` |
| `Snap_Rab_Box` | Box | `Snap_Internal=true` |
| `Glide_Ext_Box` | Box | `Glide_External=true` |
| `Glide_Rab_Box` | Box | `Glide_Internal=true` |
| `Flip_Single_Box` | Box | `Flip_Single=true` |
| `Flip_Double_Box` | Box | `Flip_Double=true` |
| `Slip_Lid` | Lid | `Standalone_Lid_Type=Slip` |
| `Snap_Ext_Lid` | Lid | `Standalone_Lid_Type=Snap, Lid_Style=External` |
| `Snap_Rab_Lid` | Lid | `Standalone_Lid_Type=Snap, Lid_Style=Rabbet` |
| `Glide_Ext_Lid` | Lid | `Standalone_Lid_Type=Glide, Lid_Style=External` |
| `Glide_Rab_Lid` | Lid | `Standalone_Lid_Type=Glide, Lid_Style=Rabbet` |
| `Flip_Single_Lid` | Lid | `Standalone_Lid_Type=Flip_Single` |
| `Screw_Lid` | Lid | `Standalone_Lid_Type=Screw` |

**Classification rules:**
- **OK** — nm=0
- **PLATTER-ARTIFACT** — all NM edges are 4-face-sharing AND all at Z>0.05mm. Benign: these are coplanar box+lid face pairs where `sf == sl` (both snap to the same layer-height multiple). Does not break slicing.
- **REAL BUG** — any 3-face-sharing NM edge, or any NM edge at Z≤0.05mm (Z=0 is the floor/base — always a real intersection)

**STLs exported to:** `%TEMP%\nm_hunt_stl\`

**Requires:** OpenSCAD installed at `C:\Program Files\OpenSCAD\openscad.exe`, `pip install pymeshlab`

**Expected baseline (2026-06-09, EPS=0.01mm):**
- All 7 lid cases: nm=0 (clean)
- All 6 box cases: PLATTER-ARTIFACT at Z=1.96mm (benign)

---

## 3. `build.pl` — Production Build Queue Runner

**Purpose:** Batch-export STLs/3mfs from a YAML queue file. Generates `Report.md` and `Slicer.md` via Template Toolkit. The primary tool for producing a release set of printable files.

**Usage:**
```powershell
# Full run
perl build.pl queue.yaml

# Dry run — show what would be built without exporting
perl build.pl queue.yaml --dry-run

# Build only one intent (substring match)
perl build.pl queue.yaml --only "Flip Single"

# Custom output directory
perl build.pl queue.yaml --out C:\prints\MasterTray_v4

# Verbose OpenSCAD output
perl build.pl queue.yaml --verbose
```

**Queue file format:** See `queue.example.yaml`. Defines:
- `tools:` — paths to OpenSCAD and Perl
- `output:` — output directory, STL vs 3mf, naming pattern
- `defaults:` — base Customizer variable overrides applied to every build
- `builds:` — array of individual parts, each with `intent`, `label`, and any per-part overrides

**How it works:** Writes a JSON parameter file (avoids Windows CLI quoting issues with `-D`), calls OpenSCAD with `-p`/`-P` flags, then runs Template Toolkit to produce markdown reports. `%FIELD_MAP` in the script translates queue keys to OpenSCAD Customizer variable names.

**Requires:** Perl with `YAML::Tiny` and `Template`, OpenSCAD

---

## 4. `TODO.ps1` — Fix Tracker

**Purpose:** Grep-based status board for tracked fixes and optimizations. Shows which source files have each fix applied and which are still pending. Useful at the start of a session to see what's DONE vs TODO.

**Usage:**
```powershell
.\TODO.ps1
```

**Output:** Color-coded list of fix IDs (F1–F17+), one per line: `[DONE]` green or `[TODO]` yellow, with the file being checked.

**Priorities shown:**
- PRIORITY 1 — Correctness / Silent Failures
- PRIORITY 2 — Print Quality
- PRIORITY 3 — Cosmetic / Nice-to-Have

No arguments, no configuration needed.

---

## 5. OpenSCAD CLI — Direct Invocation

**Purpose:** Export STL/3mf from any `.scad` file with Customizer variable overrides. Used directly by `nm_hunt.py` and `build.pl`, but also useful for one-off exports or debugging.

**Path:** `C:\Program Files\OpenSCAD\openscad.exe`

**Basic export:**
```powershell
& "C:\Program Files\OpenSCAD\openscad.exe" `
    -o output.stl `
    --export-format binstl `
    -D 'Part_To_Build="Box"' `
    -D 'Flip_Single=true' `
    -D 'part_width=60' `
    MasterBuilder.scad
```

**JSON parameter file approach** (preferred on Windows — avoids shell quoting):
```powershell
# Write params.json:
# { "fileFormatVersion": "1", "parameterSets": { "run": { "Part_To_Build": "Box", ... } } }
& "C:\Program Files\OpenSCAD\openscad.exe" `
    -o output.stl `
    -p params.json -P run `
    MasterBuilder.scad
```

**Useful flags:**

| Flag | Meaning |
|---|---|
| `-o FILE` | Output file (.stl, .3mf, .png) |
| `--export-format binstl` | Binary STL (smaller, faster) |
| `-D 'KEY=VAL'` | Override Customizer variable |
| `-p FILE -P SET` | Load parameter set from JSON file |
| `--render` | Force full CGAL render (like F6) |
| `--camera x,y,z,rx,ry,rz,d` | Camera for PNG export |

**Key Customizer variables** (see `MasterBuilder.scad` for full list):

| Variable | Type | Example |
|---|---|---|
| `Part_To_Build` | string | `"Box"`, `"Lid"`, `"Simple Tray"`, `"Jar"` |
| `part_width/length/height` | number | `40`, `80`, `30` |
| `Flip_Single`, `Flip_Double` | bool | `true`/`false` |
| `Snap_External`, `Snap_Internal` | bool | `true`/`false` |
| `Glide_External`, `Glide_Internal` | bool | `true`/`false` |
| `Standalone_Lid_Type` | string | `"Slip"`, `"Snap"`, `"Glide"`, `"Flip_Single"`, `"Screw"` |
| `Lid_Style` | string | `"External"`, `"Rabbet"` |
| `mesh_pattern` | string | `"Honeycomb"`, `"None"` |
| `bool_overlap_eps` | number | `0.01` |
| `Nozzle_Diameter` | number | `0.4` |
| `Layer_Height` | number | `0.28` |

---

## 6. `queue.example.yaml` — Build Queue Reference

**Purpose:** Example queue file showing every valid field and intent for `build.pl`. Copy and modify to create a project-specific build queue.

**Location:** `queue.example.yaml` (repo root)

Covers: all box lid types, jar shapes, simple tray variants, grid drop-ins, plaque types.
