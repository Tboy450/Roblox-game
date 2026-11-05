$ErrorActionPreference = 'Stop'
$RetailRoot = Split-Path $PSScriptRoot -Parent
$RetailToolDir = Join-Path $RetailRoot '.tools/godot'
$RetailVersion = '4.7.2'
New-Item -ItemType Directory -Path $RetailToolDir -Force | Out-Null
$RetailArchive = Join-Path $RetailToolDir 'godot.zip'
Invoke-WebRequest -Uri "https://downloads.godotengine.org/?version=$RetailVersion&flavor=stable&slug=win64.exe.zip&platform=windows.64" -OutFile $RetailArchive
Expand-Archive -LiteralPath $RetailArchive -DestinationPath $RetailToolDir -Force
Write-Host "Portable Godot $RetailVersion ready in $RetailToolDir"
