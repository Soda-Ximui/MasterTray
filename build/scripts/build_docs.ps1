# build_docs.ps1 - Generate build/docs/README.html from build/docs/README.md
#
# Run after editing build/docs/README.md (the QA build guide). The Astro site
# (astro/src/content.config.ts -> "docs" collection) reads the .md directly,
# so README.html is only needed for offline/standalone viewing.
#
# Usage:
#   .\build\scripts\build_docs.ps1
#
# Requires: pandoc (https://pandoc.org/), e.g. `choco install pandoc`

$ErrorActionPreference = "Stop"

$buildDir = Split-Path -Parent $PSScriptRoot
$src = Join-Path $buildDir "docs\README.md"
$out = Join-Path $buildDir "docs\README.html"

if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) {
    Write-Error "pandoc not found on PATH. Install with: choco install pandoc"
    exit 1
}

& pandoc $src -o $out --standalone --metadata title="MasterTray Build Guide"
Write-Host "wrote: $out"
