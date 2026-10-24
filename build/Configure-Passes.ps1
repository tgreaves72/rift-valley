[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateRange(1, 9007199254740991)][long]$VIPPassId,
    [Parameter(Mandatory)][ValidateRange(1, 9007199254740991)][long]$DoubleCoinsPassId,
    [Parameter(Mandatory)][ValidateRange(1, 9007199254740991)][long]$StylePackPassId
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (@($VIPPassId, $DoubleCoinsPassId, $StylePackPassId | Select-Object -Unique).Count -ne 3) { throw 'Use three distinct pass asset IDs from this experience.' }
$lunePath = Join-Path $projectRoot '.tools/lune/lune.exe'
if (-not (Test-Path -LiteralPath $lunePath)) {
    $luneCommand = Get-Command lune -ErrorAction SilentlyContinue
    if (-not $luneCommand) { throw 'Install Lune or restore the workspace .tools/lune runtime before configuring passes.' }
    $lunePath = $luneCommand.Source
}
$idsSource = "return table.freeze({ VIP = $VIPPassId, DoubleCoins = $DoubleCoinsPassId, StylePack = $StylePackPassId })`n"
$sourcePath = Join-Path $projectRoot 'src/shared/PassIds.luau'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($sourcePath, $idsSource, $utf8)
$xmlPath = Join-Path $projectRoot 'dist/RiftValley.rbxlx'
$xml = New-Object System.Xml.XmlDocument
$xml.PreserveWhitespace = $true
$xml.Load($xmlPath)
$node = $xml.SelectSingleNode("//Item[@class='ModuleScript'][Properties/string[@name='Name']='PassIds']/Properties/ProtectedString[@name='Source']")
if (-not $node) { throw 'PassIds module missing. Build version 0.2.0 first.' }
$node.InnerText = $idsSource
$settings = New-Object System.Xml.XmlWriterSettings
$settings.Encoding, $settings.OmitXmlDeclaration, $settings.Indent = $utf8, $true, $false
$writer = [System.Xml.XmlWriter]::Create($xmlPath, $settings)
try { $xml.Save($writer) } finally { $writer.Dispose() }
$catalogPath = Join-Path $projectRoot 'deploy/gamepasses.json'
$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$catalog.configured = $true
$catalog.passIds = @{ VIP = $VIPPassId; DoubleCoins = $DoubleCoinsPassId; StylePack = $StylePackPassId }
[IO.File]::WriteAllText($catalogPath, ($catalog | ConvertTo-Json -Depth 8), $utf8)
$releasePath = Join-Path $projectRoot 'deploy/release.json'
$release = Get-Content -LiteralPath $releasePath -Raw | ConvertFrom-Json
$release.monetization.configured = $true
[IO.File]::WriteAllText($releasePath, ($release | ConvertTo-Json -Depth 8), $utf8)
Push-Location $projectRoot
try {
    & $lunePath run tests/place.spec.luau
    if ($LASTEXITCODE -ne 0) { throw 'Native place validation failed; do not publish.' }
    & (Join-Path $PSScriptRoot 'Package.ps1')
    & (Join-Path $projectRoot 'deploy/Publish.ps1')
} finally { Pop-Location }
Write-Host 'Pass IDs connected and binary rebuilt. Stop any Studio test, reopen the rebuilt place, and publish the new version.'
