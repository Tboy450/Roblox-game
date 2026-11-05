param([string]$Godot = '')
$ErrorActionPreference = 'Stop'
$RetailRoot = Split-Path $PSScriptRoot -Parent
if (-not $Godot) { $Godot = Join-Path $RetailRoot '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $Godot)) { throw 'Godot missing. Run scripts/setup-godot.ps1 or supply -Godot.' }
$Godot
