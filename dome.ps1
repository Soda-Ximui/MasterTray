Set-Location "C:\repos\3D\MasterTray"

$printerConfig = New-TemporaryFile | Rename-Item -NewName { $_.Name + ".yaml" } -PassThru
@'
filament: PLA
nozzle: 0.4
layer_height: 0.28
walls: 2
fit: Standard
'@ | Set-Content $printerConfig

New-Item -ItemType Directory -Force build/sandbox/output | Out-Null
& "C:\Python314\python.exe" build/mastertray.py build --intent "Container" --lid "Snap (Outer Wall)" --width 50 --config $printerConfig --out "build/sandbox/output/part.stl"

Remove-Item $printerConfig
Write-Host "-> build/sandbox/output/part.stl"