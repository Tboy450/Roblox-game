$Root = Split-Path $PSScriptRoot -Parent
$Rojo = Join-Path $Root ".tools\rojo\rojo.exe"

if (-not (Test-Path $Rojo)) {
	Write-Host "Rojo not found. Running setup.ps1..."
	& (Join-Path $Root "setup.ps1")
}

Set-Location $Root
& $Rojo serve
