$Root = Split-Path $PSScriptRoot -Parent
$Rojo = Join-Path $Root ".tools\rojo\rojo.exe"

if (-not (Test-Path $Rojo)) {
	Write-Host "Rojo not found. Running setup.ps1..."
	& (Join-Path $Root "setup.ps1")
}

Set-Location $Root
& $Rojo serve (Join-Path $Root "default.project.json") --address 127.0.0.1 --port 34872
