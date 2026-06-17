# setup_env.ps1 - One-time MasterTray dev environment setup (current user)
#
# Run this once from the repo root:
#   .\setup_env.ps1
#
# What it does (all per-user, no admin required):
#   1. Associates .pl files with Strawberry Perl
#   2. Associates .py files with the Python launcher (py.exe)
#   3. Adds build/ and build/scripts/ to your User PATH, so
#      mastertray.py, export_mapping.pl, export_intents.pl, build_docs.ps1
#      are runnable by name from any shell after restarting your terminal.
#
# File associations are written to HKCU:\Software\Classes, which overrides
# HKEY_CLASSES_ROOT for the current user only.

$ErrorActionPreference = "Stop"

$repoRoot   = $PSScriptRoot
$perlExe    = "C:\Strawberry\perl\bin\perl.exe"
$pyLauncher = (Get-Command py -ErrorAction SilentlyContinue)?.Source ?? "C:\Windows\py.exe"

# --- 1. .pl -> Strawberry Perl -------------------------------------------------
Write-Host "Associating .pl with $perlExe ..."
New-Item -Path "HKCU:\Software\Classes\.pl" -Value "MasterTray.PerlScript" -Force | Out-Null
New-Item -Path "HKCU:\Software\Classes\MasterTray.PerlScript\shell\open\command" -Force `
    -Value "`"$perlExe`" `"%1`" %*" | Out-Null

# --- 2. .py -> Python launcher -------------------------------------------------
Write-Host "Associating .py with $pyLauncher ..."
New-Item -Path "HKCU:\Software\Classes\.py" -Value "MasterTray.PythonScript" -Force | Out-Null
New-Item -Path "HKCU:\Software\Classes\MasterTray.PythonScript\shell\open\command" -Force `
    -Value "`"$pyLauncher`" `"%1`" %*" | Out-Null

# --- 3. Add build/ and build/scripts/ to User PATH -----------------------------
$pathsToAdd = @(
    (Join-Path $repoRoot "build"),
    (Join-Path $repoRoot "build\scripts")
)

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$entries  = $userPath -split ";" | Where-Object { $_ -ne "" }

$added = @()
foreach ($p in $pathsToAdd) {
    if ($entries -notcontains $p) {
        $entries += $p
        $added += $p
    }
}

if ($added.Count -gt 0) {
    $newPath = ($entries -join ";")
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Added to User PATH:"
    $added | ForEach-Object { Write-Host "  $_" }
    Write-Host "Restart your terminal for PATH changes to take effect."
} else {
    Write-Host "User PATH already contains build/ and build/scripts/."
}

# --- 4. Add .PY and .PL to PATHEXT, so they're runnable without the extension -
$userPathExt = [Environment]::GetEnvironmentVariable("PathExt", "User")
if (-not $userPathExt) {
    # Seed from the system default if the user hasn't customized PATHEXT yet.
    $userPathExt = [Environment]::GetEnvironmentVariable("PathExt", "Machine")
}
$extEntries = $userPathExt -split ";" | Where-Object { $_ -ne "" }
$extAdded = @()
foreach ($ext in @(".PY", ".PL")) {
    if ($extEntries -notcontains $ext) {
        $extEntries += $ext
        $extAdded += $ext
    }
}
if ($extAdded.Count -gt 0) {
    [Environment]::SetEnvironmentVariable("PathExt", ($extEntries -join ";"), "User")
    Write-Host "Added to User PATHEXT: $($extAdded -join ', ')"
} else {
    Write-Host "User PATHEXT already includes .PY and .PL."
}

Write-Host ""
Write-Host "Done. After restarting your terminal:"
Write-Host "  mastertray list intents      (or mastertray.py)"
Write-Host "  export_mapping               (or export_mapping.pl)"
Write-Host "  export_intents               (or export_intents.pl)"
Write-Host "  build_docs.ps1"
