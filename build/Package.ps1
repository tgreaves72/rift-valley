[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$binary = Join-Path $projectRoot 'dist\RiftValley.rbxl'
$xml = Join-Path $projectRoot 'dist\RiftValley.rbxlx'
if (-not (Test-Path -LiteralPath $binary)) { throw 'Run native place validation to build the binary first.' }
$release = Get-Content -LiteralPath (Join-Path $projectRoot 'deploy\release.json') -Raw | ConvertFrom-Json
[ordered]@{
    version = $release.version
    binarySHA256 = (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash
    xmlSHA256 = (Get-FileHash -LiteralPath $xml -Algorithm SHA256).Hash
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $projectRoot 'deploy\checksums.json') -Encoding utf8
$zipPath = Join-Path $projectRoot "dist\RiftValley-$($release.version).zip"
$versionedPlace = "dist\RiftValley-$($release.version).rbxl"
Copy-Item -LiteralPath $binary -Destination (Join-Path $projectRoot $versionedPlace)
$inputPaths = @('src', 'build', 'tests', 'deploy', 'assets', 'docs', 'README.md', 'requirements.txt', '.gitignore', '.gitattributes', 'dist\RiftValley.rbxl', 'dist\RiftValley.rbxlx', $versionedPlace)
if (Test-Path -LiteralPath (Join-Path $projectRoot 'dist\RiftStalker-Design.rbxm')) { $inputPaths += 'dist\RiftStalker-Design.rbxm' }
if (Test-Path -LiteralPath (Join-Path $projectRoot 'dist\RiftStalker-Animations.rbxm')) { $inputPaths += 'dist\RiftStalker-Animations.rbxm' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream = [IO.File]::Open($zipPath, [IO.FileMode]::Create)
$archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($inputPath in $inputPaths) {
        $fullPath = Join-Path $projectRoot $inputPath
        $files = if (Test-Path -LiteralPath $fullPath -PathType Container) {
            Get-ChildItem -LiteralPath $fullPath -File -Recurse | Where-Object { $_.Extension -ne '.pyc' -and $_.FullName -notmatch '[\\/]__pycache__[\\/]' }
        } else { Get-Item -LiteralPath $fullPath }
        foreach ($file in $files) {
            if (-not $file.FullName.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Archive input escaped project root.' }
            $relativePath = $file.FullName.Substring($projectRoot.Length + 1).Replace('\', '/')
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $relativePath, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    }
} finally {
    $archive.Dispose()
    $stream.Dispose()
}
Write-Output "Release package created: $zipPath"
