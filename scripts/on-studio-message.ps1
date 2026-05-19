# Called when a new Studio link message is saved.
param(
	[string]$Message,
	[string]$Source = "Studio"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$PendingJson = Join-Path $Root ".studio\pending.json"
$PendingMd = Join-Path $Root ".studio\pending.md"

$entry = @{
	id        = (Get-Date -Format "yyyyMMdd-HHmmss")
	timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
	source    = $Source
	message   = $Message
	status    = "pending"
}

$entry | ConvertTo-Json -Depth 4 | Set-Content -Path $PendingJson -Encoding utf8

@"
# Studio link (auto)

**Time:** $($entry.timestamp)
**Source:** $($entry.source)

## Request

$Message

---
_Agent: read this file or .studio/pending.json and implement. Set status to handled in pending.json when done._
"@ | Set-Content -Path $PendingMd -Encoding utf8

Write-Host "[on-studio-message] Queued for Cursor agent"

# Notify (non-blocking popup)
try {
	$ws = New-Object -ComObject WScript.Shell
	$null = $ws.Popup(
		"New Studio message queued.`n`nOpen Cursor chat - the agent should pick it up automatically if a chat is active, or say: read pending",
		8,
		"roblox-game link",
		0x40
	)
}
catch {
	Write-Host "[on-studio-message] Notification skipped"
}

# Open pending file in Cursor if CLI is available
$cursor = Get-Command cursor -ErrorAction SilentlyContinue
if ($cursor) {
	$relative = ".studio/pending.md"
	Start-Process -FilePath $cursor.Source -ArgumentList @("-r", "-g", $relative) -WorkingDirectory $Root -ErrorAction SilentlyContinue
}
