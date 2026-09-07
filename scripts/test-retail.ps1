$ErrorActionPreference = 'Stop'
$RetailRoot = Split-Path $PSScriptRoot -Parent
$Compiler = Join-Path $RetailRoot '.tools/luau/luau-compile.exe'
$Runner = Join-Path $RetailRoot '.tools/luau/luau.exe'
if (-not (Test-Path -LiteralPath $Compiler)) {
	throw 'Install the official luau-windows.zip release in .tools/luau before running these checks.'
}
$Sources = @(Get-ChildItem -LiteralPath (Join-Path $RetailRoot 'src') -Recurse -Filter '*.luau' | ForEach-Object FullName)
$Sources += Join-Path $RetailRoot 'plugins/BuildRetailStore.lua'
& $Compiler --null @Sources
if ($LASTEXITCODE -ne 0) { throw 'Retail Luau compilation failed.' }
& $Runner (Join-Path $RetailRoot 'tests/npc-stock-orders.spec.luau')
if ($LASTEXITCODE -ne 0) { throw 'NPC order tests failed.' }

$UpdaterFixture = Get-Content -LiteralPath (Join-Path $RetailRoot 'tests/updater-mock.luau') -Raw
$Updater = Get-Content -LiteralPath (Join-Path $RetailRoot 'plugins/BuildRetailStore.lua') -Raw
$UpdaterChecks = Get-Content -LiteralPath (Join-Path $RetailRoot 'tests/updater-checks.luau') -Raw
$UpdaterTestPath = Join-Path $RetailRoot '.tools/retail-updater-test.luau'
[System.IO.File]::WriteAllText($UpdaterTestPath, "$UpdaterFixture`n$Updater`n$UpdaterChecks")
& $Runner $UpdaterTestPath
if ($LASTEXITCODE -ne 0) { throw 'Updater lifecycle tests failed.' }

# Execute the actual blueprint with construction doubles to check its generated geometry.
$Fixture = Get-Content -LiteralPath (Join-Path $RetailRoot 'tests/blueprint-mock.luau') -Raw
$Catalog = Get-Content -LiteralPath (Join-Path $RetailRoot 'src/shared/RetailCatalog.luau') -Raw
$Blueprint = Get-Content -LiteralPath (Join-Path $RetailRoot 'src/shared/RetailStoreBlueprint.luau') -Raw
$Checks = Get-Content -LiteralPath (Join-Path $RetailRoot 'tests/blueprint-checks.luau') -Raw
$Generated = "$Fixture`nlocal RetailCatalog = (function()`n$Catalog`nend)()`nlocal function require(_) return RetailCatalog end`nlocal Blueprint = (function()`n$Blueprint`nend)()`n$Checks"
$GeneratedPath = Join-Path $RetailRoot '.tools/retail-blueprint-test.luau'
[System.IO.File]::WriteAllText($GeneratedPath, $Generated)
& $Runner $GeneratedPath
if ($LASTEXITCODE -ne 0) { throw 'Blueprint geometry checks failed.' }
& (Join-Path $RetailRoot '.tools/rojo/rojo.exe') build (Join-Path $RetailRoot 'default.project.json') -o (Join-Path $RetailRoot 'build.rbxlx')
if ($LASTEXITCODE -ne 0) { throw 'Rojo retail build failed.' }
