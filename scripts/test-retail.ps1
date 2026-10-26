$ErrorActionPreference = 'Stop'
$RetailRoot = Split-Path $PSScriptRoot -Parent
$Compiler = Join-Path $RetailRoot '.tools/luau/luau-compile.exe'
$Runner = Join-Path $RetailRoot '.tools/luau/luau.exe'
if (-not (Test-Path -LiteralPath $Compiler)) {
	throw 'Install the official luau-windows.zip release in .tools/luau before running these checks.'
}
$Sources = @(Get-ChildItem -LiteralPath (Join-Path $RetailRoot 'src') -Recurse -Filter '*.luau' | ForEach-Object FullName)
$Sources += Join-Path $RetailRoot 'plugins/BuildRetailStore.lua'
$Sources += Join-Path $RetailRoot 'plugins/RetailAssetKit.lua'
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
$Checks += "`n" + (Get-Content -LiteralPath (Join-Path $RetailRoot 'tests/layout-checks.luau') -Raw)
$Generated = "$Fixture`nlocal RetailCatalog = (function()`n$Catalog`nend)()`nlocal function require(_) return RetailCatalog end`nlocal Blueprint = (function()`n$Blueprint`nend)()`n$Checks"
$GeneratedPath = Join-Path $RetailRoot '.tools/retail-blueprint-test.luau'
[System.IO.File]::WriteAllText($GeneratedPath, $Generated)
& $Runner $GeneratedPath
if ($LASTEXITCODE -ne 0) { throw 'Blueprint geometry checks failed.' }

$DoorMock = Get-Content -LiteralPath (Join-Path $RetailRoot 'tests/room-doors-mock.luau') -Raw
$Doors = Get-Content -LiteralPath (Join-Path $RetailRoot 'src/server/RetailRoomDoors.server.luau') -Raw
$DoorChecks = Get-Content -LiteralPath (Join-Path $RetailRoot 'tests/room-doors-checks.luau') -Raw
$DoorTestPath = Join-Path $RetailRoot '.tools/retail-room-doors-test.luau'
[System.IO.File]::WriteAllText($DoorTestPath, "$Fixture`n$DoorMock`n$Doors`n$DoorChecks")
& $Runner $DoorTestPath
if ($LASTEXITCODE -ne 0) { throw 'Private room door checks failed.' }

$VehicleFixture = Get-Content -LiteralPath (Join-Path $RetailRoot 'tests/vehicle-mock.luau') -Raw
$Traffic = Get-Content -LiteralPath (Join-Path $RetailRoot 'src/server/RetailTraffic.server.luau') -Raw
$VehicleChecks = Get-Content -LiteralPath (Join-Path $RetailRoot 'tests/vehicle-checks.luau') -Raw
$VehicleTestPath = Join-Path $RetailRoot '.tools/retail-vehicle-test.luau'
[System.IO.File]::WriteAllText($VehicleTestPath, "$Fixture`n$VehicleFixture`n$Traffic`n$VehicleChecks")
& $Runner $VehicleTestPath
if ($LASTEXITCODE -ne 0) { throw 'Vehicle model checks failed.' }

$Definitions = Get-Content -LiteralPath (Join-Path $RetailRoot 'src/shared/RetailAssetDefinitions.luau') -Raw
$AssetTest = Get-Content -LiteralPath (Join-Path $RetailRoot 'src/shared/RetailAssetTestBlueprint.luau') -Raw
$AssetChecks = Get-Content -LiteralPath (Join-Path $RetailRoot 'tests/asset-kit-checks.luau') -Raw
$Bootstrap = Get-Content -LiteralPath (Join-Path $RetailRoot 'src/server/BuildRetailMap.server.luau') -Raw
$BootstrapChecks = Get-Content -LiteralPath (Join-Path $RetailRoot 'tests/asset-bootstrap-checks.luau') -Raw
$AssetGenerated = "$Fixture`nlocal CFrame = { new = function(position) return { Position = position } end }`nlocal RetailCatalog = (function()`n$Catalog`nend)()`nlocal Definitions = (function()`n$Definitions`nend)()`nlocal function require(name) return if name == 'RetailCatalog' then RetailCatalog else Definitions end`nlocal AssetTest = (function()`n$AssetTest`nend)()`n$AssetChecks"
$AssetGenerated += "`nlocal function runBootstrap(services)`nlocal game = { GetService = function(_, name) return services[name] end }`nlocal function require(name) assert(name == 'RetailAssetTestBlueprint'); return AssetTest end`nlocal warningLog = {}`nlocal function warn(message) table.insert(warningLog, message) end`nlocal function execute()`n$Bootstrap`nend`nexecute()`nreturn warningLog`nend`n$BootstrapChecks"
$AssetTestPath = Join-Path $RetailRoot '.tools/retail-asset-test.luau'
[IO.File]::WriteAllText($AssetTestPath, $AssetGenerated)
& $Runner $AssetTestPath
if ($LASTEXITCODE -ne 0) { throw 'Imported asset integration checks failed.' }
& (Join-Path $RetailRoot '.tools/rojo/rojo.exe') build (Join-Path $RetailRoot 'default.project.json') -o (Join-Path $RetailRoot 'build.rbxlx')
if ($LASTEXITCODE -ne 0) { throw 'Rojo retail build failed.' }
& (Join-Path $RetailRoot '.tools/rojo/rojo.exe') build (Join-Path $RetailRoot 'asset-test.project.json') -o (Join-Path $RetailRoot 'art/exports/retail-asset-test.rbxlx')
if ($LASTEXITCODE -ne 0) { throw 'Rojo asset test build failed.' }
