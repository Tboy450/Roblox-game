# One terminal: Rojo (background job) + link bridge (foreground). Keep this window open.
$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

if (-not (Test-Path (Join-Path $Root ".tools\rojo\rojo.exe"))) {
	& (Join-Path $Root "setup.ps1")
}

$existingBridge = Get-NetTCPConnection -LocalPort 8765 -State Listen -ErrorAction SilentlyContinue
if ($existingBridge) {
	Write-Host "Bridge already listening on port 8765."
}
else {
	Write-Host "Starting bridge on port 8765..."
}

$rojoExe = Join-Path $Root ".tools\rojo\rojo.exe"
$rojoJob = Start-Job -Name "RojoServe" -ScriptBlock {
	param($exe, $dir)
	Set-Location $dir
	& $exe serve 2>&1
} -ArgumentList $rojoExe, $Root

Start-Sleep 1
if ($rojoJob.State -eq "Failed") {
	Receive-Job $rojoJob
	throw "Rojo failed to start"
}

Write-Host "Rojo job started (localhost:34872)"

$watchJob = Start-Job -Name "InboxWatcher" -ScriptBlock {
	param($dir)
	Set-Location $dir
	& (Join-Path $dir "scripts\watch-inbox.ps1")
} -ArgumentList $Root

Write-Host "Inbox watcher job started (auto-queue Studio messages)"
Write-Host ""

# Bridge runs in this window so it cannot close silently
& (Join-Path $Root "scripts\bridge.ps1")

Stop-Job $watchJob -ErrorAction SilentlyContinue
Remove-Job $watchJob -Force -ErrorAction SilentlyContinue

Stop-Job $rojoJob -ErrorAction SilentlyContinue
Remove-Job $rojoJob -Force -ErrorAction SilentlyContinue
