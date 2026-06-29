$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$Rojo = Join-Path $Root ".tools\rojo\rojo.exe"
$Project = Join-Path $Root "shooter.project.json"
$Output = Join-Path $Root "shooter.rbxlx"

if (-not (Test-Path -LiteralPath $Rojo)) {
	& (Join-Path $Root "setup.ps1")
}

Set-Location $Root
& $Rojo build $Project -o $Output
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}

Write-Host "Built $Output"
