<#
Validated dry-run by default. Add -Publish only when you intend to upload a place version.
Set the destination and credential in this process's environment, never in this file.
This uploads a version to an existing experience. It does not create an experience,
set its audience, upload artwork, or change the server size.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Publish,
    [string]$UniverseId = $env:ROBLOX_UNIVERSE_ID,
    [string]$PlaceId = $env:ROBLOX_PLACE_ID
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$release = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'release.json') -Raw | ConvertFrom-Json
$placeFile = Join-Path $projectRoot $release.placeBinary
if (-not (Test-Path -LiteralPath $placeFile -PathType Leaf)) { throw 'Build the binary place file before deployment.' }
$placeFile = (Resolve-Path -LiteralPath $placeFile).Path
if (-not $placeFile.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Place file must remain inside the project.' }
$bytes = (Get-Item -LiteralPath $placeFile).Length
if ($bytes -le 0 -or $bytes -gt 104857600) { throw 'Place file is empty or exceeds the Roblox 100 MB limit.' }
$hash = (Get-FileHash -LiteralPath $placeFile -Algorithm SHA256).Hash
$checksums = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'checksums.json') -Raw | ConvertFrom-Json
if ($hash -ne $checksums.binarySHA256) { throw 'Release checksum mismatch. Rebuild and validate the release before upload.' }
$preflight = [ordered]@{
    mode = $(if ($Publish) { 'publish' } else { 'dry-run' })
    game = $release.name
    version = $release.version
    file = $placeFile
    bytes = $bytes
    sha256 = $hash
    destinationConfigured = ($UniverseId -match '^\d+$' -and $PlaceId -match '^\d+$')
    credentialConfigured = (-not [string]::IsNullOrWhiteSpace($env:ROBLOX_OPEN_CLOUD_API_KEY))
}
$preflight | ConvertTo-Json
if (-not $Publish) { Write-Output 'Preflight complete. No network request made.'; return }
if ($UniverseId -notmatch '^\d+$' -or $PlaceId -notmatch '^\d+$' -or $UniverseId -eq '0' -or $PlaceId -eq '0') { throw 'Set the intended Roblox universe and place IDs before publishing.' }
$endpoint = "https://apis.roblox.com/universes/v1/$UniverseId/places/$PlaceId/versions?versionType=Published"
if ($PSCmdlet.ShouldProcess("Universe $UniverseId / Place $PlaceId", 'Upload Rift Valley place version')) {
    if ([string]::IsNullOrWhiteSpace($env:ROBLOX_OPEN_CLOUD_API_KEY)) { throw 'Set ROBLOX_OPEN_CLOUD_API_KEY in the process environment. Do not paste it into chat.' }
    try {
        $result = Invoke-RestMethod -Method Post -Uri $endpoint -Headers @{ 'x-api-key' = $env:ROBLOX_OPEN_CLOUD_API_KEY } -ContentType 'application/octet-stream' -InFile $placeFile
    } catch {
        throw 'Roblox refused or interrupted the upload. Check the target IDs, API key scope, ownership and network access. Verify place version history before retrying an uncertain request.'
    }
    if (-not $result.versionNumber) { throw 'Upload outcome is uncertain. Verify place version history before retrying.' }
    [ordered]@{ game = $release.name; universeId = $UniverseId; placeId = $PlaceId; versionNumber = $result.versionNumber; uploadedUTC = [DateTime]::UtcNow.ToString('o'); sha256 = $hash } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'last-publish.json') -Encoding utf8
    Write-Output "Uploaded place version $($result.versionNumber). Configure audience separately in Creator Dashboard."
}
