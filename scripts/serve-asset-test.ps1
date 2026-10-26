$ErrorActionPreference = 'Stop'
$RetailRoot = Split-Path $PSScriptRoot -Parent
& (Join-Path $RetailRoot '.tools/rojo/rojo.exe') serve (Join-Path $RetailRoot 'asset-test.project.json') --address 127.0.0.1 --port 34873
