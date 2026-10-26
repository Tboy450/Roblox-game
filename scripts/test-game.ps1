param([string]$Godot = '')
$ErrorActionPreference = 'Stop'
$RetailRoot = Split-Path $PSScriptRoot -Parent
$RetailGodot = & (Join-Path $PSScriptRoot 'game-tool.ps1') -Godot $Godot
$RetailGame = Join-Path $RetailRoot 'game'
$RetailBuild = Join-Path $RetailRoot 'builds'
New-Item -ItemType Directory -Path $RetailBuild -Force | Out-Null
foreach ($Asset in @('checkout.glb', 'shelf.glb', 'store-shell.glb')) {
    if (-not (Test-Path (Join-Path $RetailGame "assets/generated/$Asset"))) { throw 'Run scripts/prepare-game-assets.ps1 first.' }
}
& $RetailGodot --headless --path $RetailGame --import *> (Join-Path $RetailBuild 'import.log')
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed; see builds/import.log' }
if (Select-String -LiteralPath (Join-Path $RetailBuild 'import.log') -Pattern 'SCRIPT ERROR:|Parse Error:|ERROR:' -Quiet) { throw 'Godot reported an import/script error; see builds/import.log' }
& $RetailGodot --headless --path $RetailGame --script res://tests/run_tests.gd *> (Join-Path $RetailBuild 'tests.log')
if ($LASTEXITCODE -ne 0) { Get-Content (Join-Path $RetailBuild 'tests.log'); throw 'Standalone tests failed' }
if (Select-String -LiteralPath (Join-Path $RetailBuild 'tests.log') -Pattern 'SCRIPT ERROR:|Parse Error:|ERROR:' -Quiet) { Get-Content (Join-Path $RetailBuild 'tests.log'); throw 'Godot reported a runtime error' }
$RetailReport = Get-Content (Join-Path $RetailBuild 'test-report.json') -Raw | ConvertFrom-Json
if (-not $RetailReport.passed) { throw 'Standalone test report failed' }
Write-Host "PASS: $($RetailReport.checks) standalone checks; actual imported meshes, physics and retail transactions."
