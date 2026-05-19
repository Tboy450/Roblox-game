# Restart bridge and run a quick test (run from Cursor terminal)
$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent

Get-NetTCPConnection -LocalPort 8765 -ErrorAction SilentlyContinue |
	ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }

Start-Sleep 1

$bridgeWindow = Start-Process powershell -ArgumentList @(
	'-NoExit', '-NoProfile', '-File', (Join-Path $Root 'scripts\bridge.ps1')
) -WorkingDirectory $Root -PassThru

Start-Sleep 2

try {
	$health = Invoke-RestMethod -Uri 'http://127.0.0.1:8765/health' -TimeoutSec 3
	$test = Invoke-RestMethod -Uri 'http://127.0.0.1:8765/link' -Method Post `
		-Body '{"message":"fix-link test OK","source":"fix-link"}' `
		-ContentType 'application/json'
	Write-Host "Bridge is working. Window PID: $($bridgeWindow.Id)"
	Write-Host "Health: $($health | ConvertTo-Json -Compress)"
	Write-Host "Link:   $($test | ConvertTo-Json -Compress)"
	Write-Host ""
	Write-Host "Now in Studio: Plugins -> Link -> send a message."
}
catch {
	Write-Host "Bridge failed to start: $($_.Exception.Message)"
	Write-Host "Try running as Administrator once, or check if port 8765 is blocked."
	exit 1
}
