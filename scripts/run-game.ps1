param([string]$Godot = '')
$ErrorActionPreference = 'Stop'
$RetailGodot = & (Join-Path $PSScriptRoot 'game-tool.ps1') -Godot $Godot
$RetailGame = Join-Path (Split-Path $PSScriptRoot -Parent) 'game'
& $RetailGodot --headless --path $RetailGame --import
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
& $RetailGodot --path $RetailGame
