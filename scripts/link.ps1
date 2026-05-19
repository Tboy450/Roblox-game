param(
	[Parameter(Mandatory = $true, Position = 0)]
	[string]$Message
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$Inbox = Join-Path $Root ".studio\inbox.md"
$uri = "http://127.0.0.1:8765/link"
$body = @{ message = $Message; source = "terminal" } | ConvertTo-Json -Compress

try {
	Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json" | Out-Null
	Write-Host "Sent to Cursor inbox via bridge."
}
catch {
	$dir = Split-Path $Inbox
	if (-not (Test-Path $dir)) {
		New-Item -ItemType Directory -Force -Path $dir | Out-Null
	}
	$stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	$block = @"

## $stamp (terminal, bridge offline)
$Message

"@
	Add-Content -Path $Inbox -Value $block -Encoding utf8
	Write-Host "Bridge offline - wrote directly to $Inbox"
	Write-Host 'Start bridge: .\scripts\bridge.ps1'
}
