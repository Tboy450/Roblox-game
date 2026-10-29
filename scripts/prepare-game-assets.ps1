param(
    [string]$Hython = 'C:\Program Files\Side Effects Software\Houdini 22.0.466\bin\hython.exe',
    [string]$Blender = ''
)
$ErrorActionPreference = 'Stop'
$RetailRoot = Split-Path $PSScriptRoot -Parent
if (-not $Blender) { $Blender = Join-Path $RetailRoot '.tools/blender-4.5.15-windows-x64/blender.exe' }
foreach ($Tool in @($Hython, $Blender)) { if (-not (Test-Path -LiteralPath $Tool)) { throw "Tool missing: $Tool" } }
if (-not (Test-Path (Join-Path $RetailRoot 'art/exports/cornerfield-prototype.hipnc'))) {
    & $Hython (Join-Path $RetailRoot 'art/houdini/build_store.py')
    if ($LASTEXITCODE -ne 0) { throw 'Houdini build failed' }
}
if (-not (Test-Path (Join-Path $RetailRoot 'art/exports/gondola-01.obj'))) {
    & $Hython (Join-Path $RetailRoot 'art/houdini/review_and_export.py') --skip-render
    if ($LASTEXITCODE -ne 0) { throw 'Shelf export failed' }
}
if (-not (Test-Path (Join-Path $RetailRoot 'art/exports/checkout-01.glb'))) {
    & $Blender --background --python-exit-code 1 --python (Join-Path $RetailRoot 'art/blender/build_store.py')
    if ($LASTEXITCODE -ne 0) { throw 'Checkout export failed' }
}
if (@('beans', 'oats', 'soap') | Where-Object { -not (Test-Path (Join-Path $RetailRoot "art/exports/merch-$_.glb")) }) {
    & $Blender --background --python-exit-code 1 --python (Join-Path $RetailRoot 'art/blender/build_packaging.py')
    if ($LASTEXITCODE -ne 0) { throw 'Packaging export failed' }
}
& $Hython (Join-Path $RetailRoot 'art/houdini/export_game_shell.py')
if ($LASTEXITCODE -ne 0) { throw 'Standalone shell export failed' }
& $Blender --background --python-exit-code 1 --python (Join-Path $RetailRoot 'art/blender/prepare_godot_assets.py')
if ($LASTEXITCODE -ne 0) { throw 'Godot asset preparation failed' }
