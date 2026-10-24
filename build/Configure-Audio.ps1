[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateRange(1, 9007199254740991)][long]$LobbyAudioId,
    [Parameter(Mandatory)][ValidateRange(1, 9007199254740991)][long]$CrystalGroveAudioId,
    [Parameter(Mandatory)][ValidateRange(1, 9007199254740991)][long]$SunsetRuinsAudioId,
    [Parameter(Mandatory)][ValidateRange(1, 9007199254740991)][long]$NeonHarborAudioId
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$lunePath = Join-Path $projectRoot '.tools/lune/lune.exe'
if (-not (Test-Path -LiteralPath $lunePath)) {
    $luneCommand = Get-Command lune -ErrorAction SilentlyContinue
    if (-not $luneCommand) { throw 'Lune is required to rebuild the native game file.' }
    $lunePath = $luneCommand.Source
}
$idsSource = "return table.freeze({ Lobby = $LobbyAudioId, CrystalGrove = $CrystalGroveAudioId, SunsetRuins = $SunsetRuinsAudioId, NeonHarbor = $NeonHarborAudioId })`n"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$xmlPath = Join-Path $projectRoot 'dist/RiftValley.rbxlx'
$xml = New-Object System.Xml.XmlDocument
$xml.PreserveWhitespace = $true
$xml.Load($xmlPath)
$node = $xml.SelectSingleNode("//Item[@class='ModuleScript'][Properties/string[@name='Name']='MusicIds']/Properties/ProtectedString[@name='Source']")
if (-not $node) { throw 'The MusicIds module is missing. Build version 0.4.0 first.' }
[IO.File]::WriteAllText((Join-Path $projectRoot 'src/shared/MusicIds.luau'), $idsSource, $utf8)
$node.InnerText = $idsSource
$settings = New-Object System.Xml.XmlWriterSettings
$settings.Encoding, $settings.OmitXmlDeclaration, $settings.Indent = $utf8, $true, $false
$writer = [System.Xml.XmlWriter]::Create($xmlPath, $settings)
try { $xml.Save($writer) } finally { $writer.Dispose() }
$catalogPath = Join-Path $projectRoot 'assets/music/catalog.json'
$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$catalog.uploaded = $true
$catalog | Add-Member -NotePropertyName audioIds -NotePropertyValue @{ Lobby = $LobbyAudioId; CrystalGrove = $CrystalGroveAudioId; SunsetRuins = $SunsetRuinsAudioId; NeonHarbor = $NeonHarborAudioId } -Force
[IO.File]::WriteAllText($catalogPath, ($catalog | ConvertTo-Json -Depth 8), $utf8)
$releasePath = Join-Path $projectRoot 'deploy/release.json'
$release = Get-Content -LiteralPath $releasePath -Raw | ConvertFrom-Json
$release.audio.assetIdsConfigured = $true
[IO.File]::WriteAllText($releasePath, ($release | ConvertTo-Json -Depth 8), $utf8)
Push-Location $projectRoot
try {
    & $lunePath run tests/place.spec.luau
    if ($LASTEXITCODE -ne 0) { throw 'Native validation failed; do not publish.' }
    & (Join-Path $PSScriptRoot 'Package.ps1')
    & (Join-Path $projectRoot 'deploy/Publish.ps1')
} finally { Pop-Location }
Write-Host 'Audio IDs connected. Reopen the rebuilt place in Studio. For live playback, grant this experience permission to use each audio asset and republish.'
