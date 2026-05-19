$Root = Split-Path $PSScriptRoot -Parent
$Rojo = Join-Path $Root ".tools\rojo\rojo.exe"
$Out = Join-Path $Root "build.rbxlx"

if (-not (Test-Path $Rojo)) {
	& (Join-Path $Root "setup.ps1")
}

Set-Location $Root
& $Rojo build -o $Out
Write-Host "Built $Out"
