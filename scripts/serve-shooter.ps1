$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$Rojo = Join-Path $Root ".tools\rojo\rojo.exe"
$Project = Join-Path $Root "shooter.project.json"

if (-not (Test-Path -LiteralPath $Rojo)) {
	& (Join-Path $Root "setup.ps1")
}

Set-Location $Root
& $Rojo serve $Project
