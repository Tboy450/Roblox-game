# Downloads Rojo + Wally into .tools/ (idempotent)
$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$Tools = Join-Path $Root ".tools"

function Install-Tool($Name, $Url, $ZipName, $ExeName) {
	$dir = Join-Path $Tools $Name
	$exe = Join-Path $dir $ExeName
	if (Test-Path $exe) {
		Write-Host "$Name already installed at $exe"
		return
	}

	Write-Host "Downloading $Name..."
	New-Item -ItemType Directory -Force -Path $dir | Out-Null
	$zip = Join-Path $env:TEMP "$ZipName.zip"
	Invoke-WebRequest -Uri $Url -OutFile $zip -UseBasicParsing
	Expand-Archive -Path $zip -DestinationPath $dir -Force
	Remove-Item $zip -ErrorAction SilentlyContinue

	if (-not (Test-Path $exe)) {
		throw "Expected $exe after install"
	}
	Write-Host "Installed $Name -> $exe"
}

Install-Tool "rojo" "https://github.com/rojo-rbx/rojo/releases/download/v7.6.1/rojo-7.6.1-windows-x86_64.zip" "rojo-7.6.1-windows-x86_64" "rojo.exe"
Install-Tool "wally" "https://github.com/UpliftGames/wally/releases/download/v0.3.2/wally-v0.3.2-win64.zip" "wally-v0.3.2-win64" "wally.exe"

$pluginsDir = Join-Path $env:LOCALAPPDATA "Roblox\Plugins"
New-Item -ItemType Directory -Force -Path $pluginsDir | Out-Null

foreach ($name in @("LinkToCursor.lua", "BuildRetailStore.lua")) {
	$pluginSrc = Join-Path $Root "plugins\$name"
	$pluginDst = Join-Path $pluginsDir $name
	if (Test-Path $pluginSrc) {
		Copy-Item -Path $pluginSrc -Destination $pluginDst -Force
		Write-Host "Installed plugin -> $pluginDst"
	}
}

Write-Host ""
Write-Host "Done. Run:  .\scripts\dev.ps1"
