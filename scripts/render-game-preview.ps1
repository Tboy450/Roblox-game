param([string]$Godot = '')
$ErrorActionPreference = 'Stop'
$RetailRoot = Split-Path $PSScriptRoot -Parent
$RetailGodot = & (Join-Path $PSScriptRoot 'game-tool.ps1') -Godot $Godot
$RetailBuild = Join-Path $RetailRoot 'builds'
New-Item -ItemType Directory -Path $RetailBuild -Force | Out-Null
& $RetailGodot --headless --path (Join-Path $RetailRoot 'game') --import *> (Join-Path $RetailBuild 'render-import.log')
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed before rendering' }
$RetailRender = Start-Process -FilePath $RetailGodot -ArgumentList @('--path', 'game', '--script', 'res://tests/capture_preview.gd', '--resolution', '1280x720', '--audio-driver', 'Dummy') -WorkingDirectory $RetailRoot -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput (Join-Path $RetailBuild 'render.log') -RedirectStandardError (Join-Path $RetailBuild 'render-errors.log')
if ($RetailRender.ExitCode -ne 0) { throw 'Scripted GPU render failed; see builds/render-errors.log' }
Write-Host 'Actual engine frame saved: builds/godot-preview.png'
