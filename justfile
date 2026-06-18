# ──────────────────────────────────────────────────────────────────────────────
# MasterTray  (justfile)
#
# just           — start Astro dev server (default)
# just dev       — start Astro dev server on :4321
# just build     — build Astro site → astro/dist/
# just preview   — Astro's built-in preview of astro/dist/
# just serve     — Caddy serves astro/dist/ (production-like, auto-HTTPS on localhost)
# just open      — open http://localhost:4321 in default browser
# just e2e       — run Playwright tests
# just check-build — build every public intent under STRICT_KEYS (regression gate)
# just check-build-strict — check-build + promote OpenSCAD warnings to failures
# just check-build-manifold — check-build that FAILS on non-manifold STL (pymeshlab)
# just validate-stl [dir] — check STLs for non-manifold edges (run before printing!)
# just render    — render MasterBuilder.scad to output/preview.png (smoke test)
# just render-all — render all 23 intents to output/
# just mapping   — regenerate build/mapping.json from build/mapping.yaml
# just intents   — regenerate build/intents.json (public/internal classification)
# just defaults  — regenerate build/scad_defaults.json from MasterBuilder.scad
# just check-configs — verify build/configs/*.yaml match MasterBuilder.scad defaults
# just validate  — validate mapping.yaml schema and cross-references
# just meta      — regenerate mapping.json + intents.json + scad_defaults.json, check config sync + validate
# ──────────────────────────────────────────────────────────────────────────────

set shell := ["powershell.exe", "-NoProfile", "-Command"]

astro_dir := "astro"
dist_dir  := "astro/dist"
out_dir   := "output"
openscad  := "C:/Program Files/OpenSCAD/openscad.com"
perl      := "C:/Strawberry/perl/bin/perl.exe"

# ── default ───────────────────────────────────────────────────────────────────
default: dev

# ── Astro dev server ──────────────────────────────────────────────────────────
[group('docs')]
dev:
    Set-Location {{astro_dir}}; pnpm dev

# ── build static site ─────────────────────────────────────────────────────────
[group('docs')]
build:
    Set-Location {{astro_dir}}; pnpm build

# ── Astro built-in preview (serves astro/dist/) ───────────────────────────────
[group('docs')]
preview: build
    Set-Location {{astro_dir}}; pnpm preview

# ── Caddy: serve astro/dist/ with automatic local HTTPS ───────────────────────
[group('docs')]
serve: build
    caddy file-server --root {{dist_dir}} --listen :8080 --browse

# ── open docs in browser ──────────────────────────────────────────────────────
[group('docs')]
open:
    Start-Process "http://localhost:4321"

# ── Playwright end-to-end tests ───────────────────────────────────────────────
[group('test')]
e2e:
    Set-Location {{astro_dir}}; pnpm exec playwright test

# ── handoff history: every session's final state ─────────────────────────────
[group('docs')]
handoffs:
    git log --follow --oneline docs/HANDOFF.md

# ── show one handoff by number (0=latest, 1=previous, …) ─────────────────────
[group('docs')]
handoff n='0':
    $hash = git log --follow --format="%H" docs/HANDOFF.md | Select-Object -Index {{n}}; `
    git show "$hash`:docs/HANDOFF.md"

# ── OpenSCAD: quick render to output/preview.png ─────────────────────────────
[group('render')]
render:
    New-Item -ItemType Directory -Force {{out_dir}} | Out-Null
    & "{{openscad}}" -o {{out_dir}}/preview.png --render `
    --camera=0,20,30,55,0,25,350 --colorscheme=DeepOcean `
    MasterBuilder.scad
    Write-Host "→ {{out_dir}}/preview.png"

# ── OpenSCAD: render all major intents ────────────────────────────────────────
[group('render')]
render-all:
    New-Item -ItemType Directory -Force {{out_dir}} | Out-Null
    @( `
    "Simple Tray", "Box", "Standalone Box", "Flip Box", "Double Flip Box", `
    "Nesting Tray (Short)", "Modular Peg Tray (Long)", `
    "Open Jar", "Threaded Jar", "Jar with Lid", `
    "Simple Jar", "S4 Jar", "Spool Jar", "S4 Wedge", "S4 Set" `
    ) | ForEach-Object { `
    $slug = $_ -replace '[^a-zA-Z0-9]+', '-'; `
    $out  = "{{out_dir}}/$slug.png"; `
    & "{{openscad}}" -o $out --render --camera=0,20,30,55,0,25,350 `
    --colorscheme=DeepOcean -D "Part_To_Build=`"$_`"" MasterBuilder.scad; `
    Write-Host "  → $out" `
    }

# ── regenerate build/mapping.json from build/mapping.yaml ─────────────────────
[group('build')]
mapping:
    & "{{perl}}" build/scripts/export_mapping.pl

# ── regenerate build/intents.json (public/internal classification) ────────────
[group('build')]
intents:
    & "{{perl}}" build/scripts/export_intents.pl

# ── verify build/configs/*.yaml match MasterBuilder.scad @CONFIG_SECTION defaults ──
[group('build')]
check-configs:
    & "{{perl}}" build/scripts/check_config_sync.pl

# ── regenerate build/scad_defaults.json from MasterBuilder.scad ───────────────
[group('build')]
defaults:
    python build/mastertray.py dump-defaults

# ── validate mapping.yaml schema and cross-references ─────────────────────────
[group('build')]
validate:
    python build/mastertray.py validate

# ── regenerate all generated build-tooling JSON ────────────────────────────────
[group('build')]
meta: mapping intents defaults check-configs validate

# ── regenerate build/docs/README.html from build/docs/README.md (pandoc) ──────
[group('build')]
docs:
    pwsh -NoProfile -File build/scripts/build_docs.ps1

# ── build-matrix regression gate: every public intent builds under STRICT_KEYS ──
[group('test')]
check-build:
    python build/scripts/build_matrix.py

# ── build-matrix gate with OpenSCAD warnings promoted to failures ──────────────
[group('test')]
check-build-strict:
    python build/scripts/build_matrix.py --hardwarnings

# ── build-matrix gate that FAILS on non-manifold STL export (needs pymeshlab) ──
# Component count does NOT detect non-manifold edges; this does. Jars currently fail.
[group('test')]
check-build-manifold:
    python build/scripts/build_matrix.py --strict-manifold

# ── validate STL files for non-manifold edges / open boundaries (pymeshlab) ────
# ALWAYS run before sending any STL to print. `just validate-stl "STL/Test Prints"`
[group('test')]
validate-stl dir='STL':
    python validSTL.py "{{dir}}"

# ── printability gate before sending STLs: manifold/watertight (hard) + overhang hint ──
# Manifold is auto-verified; overhang is a HINT only (mesh/thread false-positives) —
# confirm overhangs with a slicer preview / test print. `just check-printable "STL/Test Prints"`
[group('test')]
check-printable dir='STL':
    python build/scripts/check_printable.py "{{dir}}"

# ── local-only live build server for the /builder web page ────────────────────
[group('build')]
build-server:
    node build/scripts/build_server.mjs
