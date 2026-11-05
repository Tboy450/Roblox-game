param(
    [string]$Hython = 'C:\Program Files\Side Effects Software\Houdini 22.0.466\bin\hython.exe',
    [string]$Blender = '',
    [switch]$SkipRender
)
$ErrorActionPreference = 'Stop'
$RetailRoot = Split-Path $PSScriptRoot -Parent
if (-not $Blender) { $Blender = Join-Path $RetailRoot '.tools/blender-4.5.15-windows-x64/blender.exe' }
foreach ($Tool in @($Hython, $Blender)) { if (-not (Test-Path -LiteralPath $Tool)) { throw "Tool missing: $Tool" } }
& $Hython (Join-Path $RetailRoot 'art/houdini/build_store.py')
if ($LASTEXITCODE -ne 0) { throw 'Houdini scene generation failed.' }
$ReviewArgs = @((Join-Path $RetailRoot 'art/houdini/review_and_export.py'))
if ($SkipRender) { $ReviewArgs += '--skip-render' }
& $Hython @ReviewArgs
if ($LASTEXITCODE -ne 0) { throw 'Houdini export/review failed.' }
$BlenderArgs = @('--background', '--python-exit-code', '1', '--python', (Join-Path $RetailRoot 'art/blender/build_store.py'))
if (-not $SkipRender) { $BlenderArgs += @('--', '--render') }
& $Blender @BlenderArgs
if ($LASTEXITCODE -ne 0) { throw 'Blender checkout generation failed.' }
& $Blender --background --python-exit-code 1 --python (Join-Path $RetailRoot 'art/blender/validate_checkout.py')
if ($LASTEXITCODE -ne 0) { throw 'Checkout GLB validation failed.' }
& (Join-Path $PSScriptRoot 'package-retail-assets.ps1')
