# Backup watcher for inbox changes (started by dev.ps1).
$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$Inbox = Join-Path $Root ".studio\inbox.md"
$HashFile = Join-Path $Root ".studio\.watch-hash.txt"

if (-not (Test-Path (Split-Path $Inbox))) {
	New-Item -ItemType Directory -Force -Path (Split-Path $Inbox) | Out-Null
}
if (-not (Test-Path $Inbox)) {
	New-Item -ItemType File -Path $Inbox | Out-Null
}

function Get-LatestStudioMessage($Content) {
	if ($Content -notmatch "\(Studio\)") {
		return $null
	}
	$blocks = [regex]::Matches($Content, "(?ms)^## .+? \(Studio\)\r?\n(.+?)(?=\r?\n## |\z)")
	if ($blocks.Count -eq 0) {
		return $null
	}
	return $blocks[$blocks.Count - 1].Groups[1].Value.Trim()
}

Write-Host "[watch-inbox] Watching $Inbox"

while ($true) {
	Start-Sleep -Seconds 2
	$content = Get-Content $Inbox -Raw -ErrorAction SilentlyContinue
	if ([string]::IsNullOrWhiteSpace($content)) {
		continue
	}

	$bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
	$stream = [System.IO.MemoryStream]::new($bytes)
	$hash = (Get-FileHash -InputStream $stream -Algorithm MD5).Hash
	$stream.Dispose()
	$lastHash = if (Test-Path $HashFile) { Get-Content $HashFile -Raw } else { "" }

	if ($hash -eq $lastHash) {
		continue
	}

	Set-Content -Path $HashFile -Value $hash -Encoding ascii -NoNewline
	$message = Get-LatestStudioMessage $content
	if ([string]::IsNullOrWhiteSpace($message)) {
		continue
	}

	& (Join-Path $Root "scripts\on-studio-message.ps1") -Message $message -Source "Studio"
}
