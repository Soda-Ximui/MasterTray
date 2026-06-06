# MasterTray Optimization TODO Tracker
# Run from the repo root:  .\TODO.ps1
# Checks which fixes are present in source files and reports status.
# Green = done, Yellow = pending.

$root = $PSScriptRoot

function Check-Fix {
    param($id, $file, $pattern, $desc)
    $path = Join-Path $root $file
    $content = Get-Content $path -Raw -ErrorAction SilentlyContinue
    if (-not $content) {
        Write-Host "  [!] $file not found" -ForegroundColor Red
        return
    }
    $found = $content -match $pattern
    $status = if ($found) { "DONE" } else { "TODO" }
    $color  = if ($found) { "Green" } else { "Yellow" }
    Write-Host ("  [{0}] F{1,-2}  {2,-55} {3}" -f $status, $id, $desc, $file) -ForegroundColor $color
}

Write-Host ""
Write-Host "MasterTray Optimization TODO" -ForegroundColor Cyan
Write-Host ("=" * 75) -ForegroundColor Cyan

Write-Host ""
Write-Host "PRIORITY 1 — Correctness / Silent Failures" -ForegroundColor White

Check-Fix 15 "RenderBox.scad" `
    'assert\(clip_len > 0' `
    "Flip-box hinge: echo -> assert"

Check-Fix 18 "RenderJar.scad" `
    'JAR_LIP_HEIGHT' `
    "lip_h = JAR_LIP_HEIGHT (RenderJar)"

Check-Fix "18b" "RenderLid.scad" `
    'JAR_LIP_HEIGHT' `
    "lip_h = JAR_LIP_HEIGHT (RenderLid)"

Check-Fix "18c" "RenderGrid.scad" `
    'JAR_LIP_HEIGHT' `
    "lip_h = JAR_LIP_HEIGHT (RenderGrid)"

Check-Fix 6 "MasterEngine.scad" `
    'function layer_snap' `
    "layer_snap() helper added to MasterEngine"

Check-Fix "6b" "RenderLid.scad" `
    'layer_snap\(0\.8' `
    "Diamond latch Z-offsets use layer_snap()"

Check-Fix 14 "RenderLid.scad" `
    'max\(3.*ceil.*noz.*lh|m_lh.*ceil.*noz' `
    "Snap bead height layer-aligned"

Write-Host ""
Write-Host "PRIORITY 2 — Print Quality Improvements" -ForegroundColor White

Check-Fix 1 "MasterEngine.scad" `
    'noz \* 8' `
    "Glide ball min raised to noz*8"

Check-Fix 2 "RenderLid.scad" `
    '0\.9.*noz\*2|noz\*2.*0\.9' `
    "Diamond hull middle Y = noz*2 (RenderLid)"

Check-Fix "2b" "RenderBox.scad" `
    '-0\.8.*noz\*2|noz\*2.*-0\.8' `
    "Diamond hull middle Y = noz*2 (RenderBox)"

Check-Fix 16 "RenderGrid.scad" `
    'min_hollow|min_solid' `
    "Radial hub thresholds nozzle-parametric"

Check-Fix 7 "RenderJar.scad" `
    'ceil\(0\.5' `
    "Jar grid clearance layer-aligned"

Check-Fix 8 "RenderBox.scad" `
    'ceil\(1\.0' `
    "Glide groove Z layer-aligned"

Check-Fix 9 "RenderLid.scad" `
    'sl - EPS' `
    "Thread rod Z-offset uses EPS"

Write-Host ""
Write-Host "PRIORITY 3 — Minor / Cosmetic" -ForegroundColor DarkGray

Check-Fix 4 "RenderTray.scad" `
    'Z_EDGES|edges.*Z.*ledge|ledge.*Z.*edges' `
    "Ledge lip Z-edge chamfer"

Check-Fix 5 "RenderBox.scad" `
    'edges=TOP.*anchor=BOTTOM\+FRONT|chamfer.*m_chamf.*edges=TOP' `
    "Hinge pillar top chamfer"

Check-Fix 17 "RenderGrid.scad" `
    'int_h_raw|round.*int_h.*m_lh' `
    "Jar grid height layer-aligned"

Check-Fix 19 "MasterConstants.scad" `
    '(?s)HINGE_BOSS_DEPTH.*RenderBox|HINGE_BOSS_DEPTH.*axle' `
    "Dead hinge constants wired or removed"

Write-Host ""
$total = 17
$done  = 0
# recount silently
$checks = @(
    @("RenderBox.scad",     'assert\(clip_len > 0'),
    @("RenderJar.scad",     'JAR_LIP_HEIGHT'),
    @("RenderLid.scad",     'JAR_LIP_HEIGHT'),
    @("RenderGrid.scad",    'JAR_LIP_HEIGHT'),
    @("MasterEngine.scad",  'function layer_snap'),
    @("RenderLid.scad",     'layer_snap\(0\.8'),
    @("RenderLid.scad",     'max\(3.*ceil|m_lh.*ceil.*noz'),
    @("MasterEngine.scad",  'noz \* 8'),
    @("RenderLid.scad",     '0\.9.*noz\*2|noz\*2.*0\.9'),
    @("RenderBox.scad",     '-0\.8.*noz\*2|noz\*2.*-0\.8'),
    @("RenderGrid.scad",    'min_hollow'),
    @("RenderJar.scad",     'ceil\(0\.5'),
    @("RenderBox.scad",     'ceil\(1\.0'),
    @("RenderLid.scad",     'sl - EPS'),
    @("RenderTray.scad",    'Z_EDGES'),
    @("RenderBox.scad",     'edges=TOP'),
    @("RenderGrid.scad",    'int_h_raw')
)
foreach ($c in $checks) {
    $content = Get-Content (Join-Path $root $c[0]) -Raw -ErrorAction SilentlyContinue
    if ($content -match $c[1]) { $done++ }
}
$pct = [int](($done / $total) * 100)
Write-Host ("Progress: {0}/{1} fixes applied ({2}%)" -f $done, $total, $pct) -ForegroundColor Cyan
Write-Host "See TODO.md for full discovery notes and before/after code." -ForegroundColor DarkGray
Write-Host ""
