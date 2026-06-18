# MasterTray — Dev Environment Setup

## Current tooling

| Tool | Status | Version / Notes |
|------|--------|-----------------|
| Docker | ✅ Installed | Image `openscad/openscad:latest` (2021.01) available |
| Mermaid | ✅ Installed | `minlag/mermaid-cli:latest` — renders `docs/SEQUENCE_DIAGRAMS.md` |
| pwsh | ✅ Default shell | `TODO.ps1` runs natively |
| Git | ✅ | |
| Python | ✅ Installed | 3.14.5 |
| ImageMagick | ✅ Installed | 7.1.2-25 — `magick` command |
| OpenSCAD native | ✅ Installed | 2026.04.26 — **use this, not Docker (newer + faster)** |

---

## OpenSCAD CLI

**Executable:** `C:\Program Files\OpenSCAD\openscad.com`
Not on the bash PATH — use PowerShell or add to `$env:PATH`.

### Add to PowerShell PATH (one-time)

```powershell
$env:PATH += ";C:\Program Files\OpenSCAD"
```

To make permanent, add to your PowerShell profile (`$PROFILE`).

### Render to PNG (visual check)

```powershell
$openscad = "C:\Program Files\OpenSCAD\openscad.com"
& $openscad -o out.png --camera=0,20,30,55,0,25,350 --render `
  --colorscheme=Tomorrow MasterBuilder.scad
```

### Render to STL (slicer import)

```powershell
& $openscad -o out.stl MasterBuilder.scad
```

### Override Customizer variables from command line

```powershell
& $openscad -o out.png --render --camera=0,20,30,55,0,25,350 `
  -D 'Part_To_Build="Jar with Lid"' `
  -D 'part_width=46' -D 'part_height=60' `
  MasterBuilder.scad
```

### Docker alternative (older build, slower)

```powershell
docker run --rm -v ${PWD}:/work openscad/openscad:latest `
    openscad -o /work/out.stl /work/MasterBuilder.scad
```

---

## OpenSCAD — SCAD file authoring rules

### BOSL2 / MasterEngine includes — single-owner rule (MANDATORY)

OpenSCAD's `include` is **textual substitution with no dedup**. Every `include` re-parses the
target file in full. BOSL2 is large; re-parsing it costs ~21 s per extra include.

**How it is wired:**

```
MasterBuilder.scad
  └── include <MasterEngine.scad>   ← ONLY file that includes MasterEngine
        └── include <BOSL2/std.scad>   ← ONLY file that includes BOSL2
        └── include <BOSL2/threading.scad>
```

All sub-files (`RenderBox`, `RenderMesh`, `RenderJar`, `RenderLid`, `RenderGrid`, …) inherit
BOSL2 and MasterEngine symbols because MasterBuilder loaded them first. They must NOT include
them again.

**Correct header for any new sub-file:**

```openscad
// BOSL2/std comes via MasterEngine — do NOT re-include (OpenSCAD has no include dedup;
// re-parse cost ~21s) [perf]
// MasterEngine is included once by MasterBuilder.scad (single owner) — not re-included
// here [perf]
include <RenderMesh.scad>   // only other sub-files you directly depend on
```

**What happens if you break the rule:** the build still succeeds but slows by ~21 s per extra
BOSL2 include. A diamond graph (A→B, A→C, B→D, C→D each including BOSL2) multiplies this.
This was the measured root cause of a 23.8 s → 1.6 s improvement once the graph was flattened.

**Tradeoff (accepted):** sub-files cannot be opened standalone in the OpenSCAD GUI — symbols
are undefined without MasterBuilder's includes. To preview a part, open `MasterBuilder.scad`
and set `Part_To_Build` in the Customizer panel.

---

## ImageMagick

`magick` command available system-wide. Useful operations:

```powershell
# Trim whitespace + annotate a render
magick out.png -trim -bordercolor white -border 20 `
  -annotate +10+30 "label text" out_annotated.png

# Side-by-side before/after diff
magick before.png after.png +append diff.png

# Crop to specific region
magick out.png -crop 300x300+100+50 cropped.png
```

---

## What OpenSCAD CLI unlocks

Verified working 2026-06-04. Before this, every geometry fix was verified
by reading code math only. Now:

- Render before/after a fix and visually confirm
- Smoke-test all 23 intents in a loop without opening the GUI
- Generate `docs/images/` reference renders automatically
- Catch silent geometry failures (negative dimensions, zero-height features)
  that only show up in a render, not in the math

---

## Web development tools

For building web apps and sites — what's recommended and why:

### Install these

| Tool | Install | Why |
|------|---------|-----|
| **Node.js** | `winget install OpenJS.NodeJS.LTS` | npm ecosystem; required by most web tooling |
| **pnpm** | `npm install -g pnpm` | Faster/leaner npm alternative — disk-efficient for monorepos |
| **Vite** | `pnpm create vite` | Fast dev server + bundler; works with React/Vue/Svelte/vanilla |

### Framework — pick one

| Framework | Best for | Notes |
|-----------|----------|-------|
| **React + TypeScript** | Component-heavy apps, large teams | Largest ecosystem; pairs with shadcn/ui for ready-made components |
| **SvelteKit** | Sites + apps, smaller bundles | Less boilerplate than React; great for content sites |
| **Astro** | Docs sites, mostly-static | Ships zero JS by default; perfect for the MasterTray docs site |

For the MasterTray docs site specifically: **Astro** — it renders Markdown natively, supports Mermaid, and the output is a static site with no server needed.

### Also useful

| Tool | Install | Why |
|------|---------|-----|
| **Playwright** | ✅ Installed | Browser automation + screenshot testing for web UIs — `just e2e` |
| **Caddy** | ✅ Installed | Dead-simple local HTTPS dev server — `just serve` |
| **Bruno** | ✅ Installed | API client (Postman alternative, files-based — works with git) |

### What's already covered

- Docker covers containerised deployments
- Python 3.14 covers backend APIs (FastAPI is the current best-in-class)
- ImageMagick covers image pipeline work
- pwsh covers scripting and CI

### Minimum useful web stack right now

```powershell
winget install OpenJS.NodeJS.LTS
npm install -g pnpm
```

That unlocks everything else on demand.
