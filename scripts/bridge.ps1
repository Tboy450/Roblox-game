# Receives messages from the Studio "link" plugin and saves them for Cursor chat.
$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$Inbox = Join-Path $Root ".studio\inbox.md"
$Port = 8765

function Write-InboxEntry($Source, $Message) {
	$dir = Split-Path $Inbox
	if (-not (Test-Path $dir)) {
		New-Item -ItemType Directory -Force -Path $dir | Out-Null
	}

	$stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	$block = @"

## $stamp ($Source)
$Message

"@

	Add-Content -Path $Inbox -Value $block -Encoding utf8
	Write-Host ""
	Write-Host "[bridge] Saved from $Source at $stamp"
	Write-Host "  Message: $Message"
	Write-Host "  File:    $Inbox"
	Write-Host "  Next:    Queued for Cursor (.studio/pending.md) if from Studio"
	Write-Host ""
}

function Send-JsonResponse($Context, [int]$StatusCode, $Payload) {
	$json = $Payload | ConvertTo-Json -Compress
	$bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
	$response = $Context.Response
	$response.StatusCode = $StatusCode
	$response.ContentType = "application/json"
	$response.ContentLength64 = $bytes.Length
	$response.OutputStream.Write($bytes, 0, $bytes.Length)
	$response.Close()
}

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host "========================================"
Write-Host " Cursor link bridge - KEEP THIS OPEN"
Write-Host "========================================"
Write-Host "  Health: http://127.0.0.1:$Port/health"
Write-Host "  Link:   http://127.0.0.1:$Port/link"
Write-Host "  Inbox:  $Inbox"
Write-Host "Press Ctrl+C to stop."
Write-Host ""

while ($listener.IsListening) {
	$context = $listener.GetContext()
	$request = $context.Request
	$path = $request.Url.AbsolutePath.TrimEnd("/")

	try {
		if ($request.HttpMethod -eq "GET" -and $path -eq "/health") {
			Send-JsonResponse $context 200 @{ ok = $true; service = "cursor-bridge" }
		}
		elseif ($request.HttpMethod -eq "POST" -and $path -eq "/link") {
			$reader = [System.IO.StreamReader]::new($request.InputStream, $request.ContentEncoding)
			$body = $reader.ReadToEnd()
			$reader.Close()

			$data = $body | ConvertFrom-Json
			$message = [string]$data.message
			$source = if ($data.source) { [string]$data.source } else { "Studio" }

			if ([string]::IsNullOrWhiteSpace($message)) {
				throw "message is required"
			}

			if ($message.Length -gt 4000) {
				throw "message too long (max 4000 characters)"
			}

			Write-InboxEntry $source $message

			if ($source -eq "Studio") {
				& (Join-Path $Root "scripts\on-studio-message.ps1") -Message $message -Source $source
			}

			Send-JsonResponse $context 200 @{ ok = $true }
		}
		else {
			Send-JsonResponse $context 404 @{ ok = $false; error = "not found" }
		}
	}
	catch {
		Send-JsonResponse $context 400 @{ ok = $false; error = $_.Exception.Message }
	}
}
