$ErrorActionPreference = 'Stop'
$RetailRoot = Split-Path $PSScriptRoot -Parent
$ExportRoot = Join-Path $RetailRoot 'art/exports'
$BundleRoot = Join-Path $ExportRoot 'retail-import-kit'
New-Item -ItemType Directory -Force -Path $BundleRoot | Out-Null
foreach ($Filename in @('checkout-01.glb', 'checkout-01-manifest.json', 'checkout-validation.json', 'gondola-01.obj', 'gondola-01.mtl', 'gondola-01-manifest.json')) {
    $Source = Join-Path $ExportRoot $Filename
    if (-not (Test-Path -LiteralPath $Source)) { throw "Generate the asset first: $Filename" }
    Copy-Item -LiteralPath $Source -Destination (Join-Path $BundleRoot $Filename) -Force
}
Copy-Item -LiteralPath (Join-Path $RetailRoot 'docs/ASSET_IMPORT_TEST.md') -Destination (Join-Path $BundleRoot 'README.md') -Force
Copy-Item -LiteralPath (Join-Path $RetailRoot 'plugins/RetailAssetKit.lua') -Destination (Join-Path $BundleRoot 'RetailAssetKit.lua') -Force
Compress-Archive -Path (Join-Path $BundleRoot '*') -DestinationPath (Join-Path $ExportRoot 'retail-import-kit.zip') -Force
Write-Output (Join-Path $ExportRoot 'retail-import-kit.zip')
