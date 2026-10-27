param([string]$Godot = '')
$ErrorActionPreference = 'Stop'
$RetailRoot = Split-Path $PSScriptRoot -Parent
$RetailGodot = & (Join-Path $PSScriptRoot 'game-tool.ps1') -Godot $Godot
$RetailGame = Join-Path $RetailRoot 'game'
$RetailBuild = Join-Path $RetailRoot 'builds'
$RetailPackage = Join-Path $RetailBuild 'CornerfieldMarket-Prototype'
New-Item -ItemType Directory -Path $RetailPackage -Force | Out-Null
& $RetailGodot --headless --path $RetailGame --export-pack 'Windows Desktop' (Join-Path $RetailPackage 'CornerfieldMarket.pck') *> (Join-Path $RetailBuild 'package.log')
if ($LASTEXITCODE -ne 0) { Get-Content (Join-Path $RetailBuild 'package.log'); throw 'Godot pack export failed' }
if (Select-String -LiteralPath (Join-Path $RetailBuild 'package.log') -Pattern 'SCRIPT ERROR:|Parse Error:|ERROR:' -Quiet) { throw 'Godot reported an export error; see builds/package.log' }
# Portable prototype uses the official editor runtime in game mode. A smaller
# production executable will use export templates once release packaging is due.
$RetailGuiRuntime = Join-Path (Split-Path $RetailGodot -Parent) 'Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path $RetailGuiRuntime)) { throw 'Official Godot GUI runtime missing beside console runtime' }
Copy-Item -LiteralPath $RetailGuiRuntime -Destination (Join-Path $RetailPackage 'CornerfieldMarket.exe') -Force
@'
Cornerfield Market — standalone prototype

Run CornerfieldMarket.exe. No Roblox Studio, Rojo or Godot editor setup required.
Keep the .exe and .pck together. This portable prototype bundles the official
Godot editor runtime in game mode; it is not a size-optimized release export.

WASD move; mouse look; E interact; Esc release/capture mouse.
1 / 2 / 3 select beans, oats or hand soap. B orders a matching twelve-unit case.
After four seconds, E collects it at Receiving; E stocks its matching shelf.
[ / ] adjust the selected product's sale price by ten cents. Active baskets
keep their quoted pickup price. O opens/closes; E serves a shopper at checkout.
N starts the next day after closing and reviewing the report.

F5 saves; F9 loads. Progress loads automatically on startup and autosaves after
transactions and on normal window close. Files use Godot's Cornerfield Market
user-data folder: cornerfield-save.json, with a previous-valid-save .bak.
Resume starts closed and returns unpaid baskets to their shelves. In-transit
deliveries, carried cases, prices, cash, day and daily totals are preserved.
If the primary is damaged, load tries the backup. Unsupported newer saves are
left unchanged; failed loads pause autosaving until a successful save/load.

First slice only: three products, one active shopper, fixed waypoint routes.
No staff, multiplayer, settings menu or final character art yet.
Source: https://github.com/Tboy450/Roblox-game (existing repository).
Godot Engine: https://godotengine.org/license/ — see GODOT-LICENSE.txt.
'@ | Set-Content -LiteralPath (Join-Path $RetailPackage 'README.txt') -Encoding utf8
Copy-Item -LiteralPath (Join-Path $RetailRoot 'game/GODOT-LICENSE.txt') -Destination $RetailPackage -Force
Copy-Item -LiteralPath (Join-Path $RetailRoot 'game/GODOT-THIRD-PARTY.txt') -Destination $RetailPackage -Force
$RetailSmokeLog = Join-Path $RetailBuild 'pack-smoke.log'
$RetailSmoke = Start-Process -FilePath (Join-Path $RetailPackage 'CornerfieldMarket.exe') -WorkingDirectory $RetailPackage -WindowStyle Hidden -PassThru -Wait -ArgumentList @('--headless', '--log-file', ('"' + $RetailSmokeLog + '"'), '--quit-after', '30', '--', '--verify-prototype')
if ($RetailSmoke.ExitCode -ne 0 -or (Select-String -LiteralPath $RetailSmokeLog -Pattern 'SCRIPT ERROR:|Parse Error:|ERROR:' -Quiet) -or -not (Select-String -LiteralPath $RetailSmokeLog -Pattern 'CORNERFIELD_SCENE_READY' -Quiet)) { throw 'Packaged executable startup failed; see builds/pack-smoke.log' }
Compress-Archive -LiteralPath $RetailPackage -DestinationPath (Join-Path $RetailBuild 'CornerfieldMarket-Prototype.zip') -Force
Write-Host "Portable standalone prototype ready: builds/CornerfieldMarket-Prototype.zip"
