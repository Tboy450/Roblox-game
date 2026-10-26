param([string]$Output = 'art/reference/current-store-v55.json')
$ErrorActionPreference = 'Stop'
$RetailRoot = Split-Path $PSScriptRoot -Parent
$Runner = Join-Path $RetailRoot '.tools/luau/luau.exe'
if (-not (Test-Path -LiteralPath $Runner)) { throw 'Install the Luau CLI in .tools/luau first.' }
$Fixture = Get-Content -LiteralPath (Join-Path $RetailRoot 'tests/blueprint-mock.luau') -Raw
$Catalog = Get-Content -LiteralPath (Join-Path $RetailRoot 'src/shared/RetailCatalog.luau') -Raw
$Blueprint = Get-Content -LiteralPath (Join-Path $RetailRoot 'src/shared/RetailStoreBlueprint.luau') -Raw
$Exporter = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'export-retail-reference.luau') -Raw
$Generated = "$Fixture`nlocal RetailCatalog = (function()`n$Catalog`nend)()`nlocal function require(_) return RetailCatalog end`nlocal Blueprint = (function()`n$Blueprint`nend)()`n$Exporter"
$GeneratedPath = Join-Path $RetailRoot '.tools/export-retail-reference.luau'
[IO.File]::WriteAllText($GeneratedPath, $Generated)
$Rows = @(& $Runner $GeneratedPath)
if ($LASTEXITCODE -ne 0) { throw 'Reference extraction failed.' }
$Nodes = @($Rows | ForEach-Object { $_ | ConvertFrom-Json })
$Commit = & git -C $RetailRoot rev-parse HEAD
$Document = [ordered]@{
    schemaVersion = 1
    blueprintVersion = 55
    sourceCommit = $Commit
    coordinateSystem = 'Roblox: X right, Y up, Z toward storefront; dimensions in studs'
    scope = 'Static blueprint construction using test doubles; excludes runtime NPCs, cars, pets, physics, and live Studio edits'
    nodes = $Nodes
}
$OutputPath = if ([IO.Path]::IsPathRooted($Output)) { $Output } else { Join-Path $RetailRoot $Output }
New-Item -ItemType Directory -Force -Path (Split-Path $OutputPath -Parent) | Out-Null
[IO.File]::WriteAllText($OutputPath, ($Document | ConvertTo-Json -Depth 20))
Write-Output "Exported $($Nodes.Count) nodes to $OutputPath"
