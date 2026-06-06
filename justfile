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
# just render    — render MasterBuilder.scad to output/preview.png (smoke test)
# just render-all — render all 23 intents to output/
# ──────────────────────────────────────────────────────────────────────────────

set shell := ["powershell.exe", "-NoProfile", "-Command"]

astro_dir := "astro"
dist_dir  := "astro/dist"
out_dir   := "output"
openscad  := "C:/Program Files/OpenSCAD/openscad.com"

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
    "Simple Jar", "S4 Jar", "Spool Jar", "S4 Wedge", "S4 Set", `
    "Standalone Box Grid", "Standalone Jar Grid" `
    ) | ForEach-Object { `
    $slug = $_ -replace '[^a-zA-Z0-9]+', '-'; `
    $out  = "{{out_dir}}/$slug.png"; `
    & "{{openscad}}" -o $out --render --camera=0,20,30,55,0,25,350 `
    --colorscheme=DeepOcean -D "Part_To_Build=`"$_`"" MasterBuilder.scad; `
    Write-Host "  → $out" `
    }
