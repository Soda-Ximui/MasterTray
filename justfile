# ──────────────────────────────────────────────────────────────────────────────
# MasterTray Documentation Build  (justfile)
# Recommended over Makefile for day-to-day use: self-documents, no TAB issues.
#
# just          — build HTML (default)
# just setup    — move *.md → docs/, create html/   (run once)
# just html     — convert docs/*.md → html/*.html + index.html
# just clean    — remove html/ and index.html
# just rebuild  — clean + html
# just open     — open index.html in default browser
# ──────────────────────────────────────────────────────────────────────────────

set shell := ["powershell.exe", "-NoProfile", "-Command"]

docs   := "docs"
html   := "html"
css    := "docs.css"
master := "MASTERTRAY"
filter := "fix-links.lua"

# ── default ───────────────────────────────────────────────────────────────────
default: html

# ── setup: move *.md → docs/ (run once after checkout) ───────────────────────
[group('setup')]
setup:
	New-Item -ItemType Directory -Force {{docs}}, {{html}} | Out-Null
	Get-ChildItem -Path . -Filter "*.md" -File | Where-Object { $_.Name -ne "HANDOFF.md" } | Move-Item -Destination {{docs}} -Force
	Write-Host "Moved .md files to {{docs}}/"

# ── html: convert all docs/*.md → html/*.html + index.html ───────────────────
[group('build')]
html:
	New-Item -ItemType Directory -Force {{html}} | Out-Null
	Get-ChildItem {{docs}}\*.md | Where-Object { $_.BaseName -ne "{{master}}" } | ForEach-Object { $out = "{{html}}\$($_.BaseName).html"; pandoc $_.FullName --standalone --toc --toc-depth=3 --to html5 --lua-filter {{filter}} --css ../{{css}} --metadata "pagetitle=$($_.BaseName)" -o $out; Write-Host "  $out" }
	pandoc {{docs}}\{{master}}.md --standalone --toc --toc-depth=2 --to html5 --lua-filter {{filter}} --css {{css}} --metadata "pagetitle=MasterTray Documentation" -o index.html
	Write-Host "  index.html"

# ── clean ─────────────────────────────────────────────────────────────────────
[group('build')]
clean:
	Remove-Item -Recurse -Force {{html}} -ErrorAction SilentlyContinue
	Remove-Item -Force index.html -ErrorAction SilentlyContinue
	Write-Host "Cleaned."

# ── rebuild ───────────────────────────────────────────────────────────────────
[group('build')]
rebuild: clean html

# ── open index.html in default browser ───────────────────────────────────────
[group('view')]
open:
	Start-Process index.html
