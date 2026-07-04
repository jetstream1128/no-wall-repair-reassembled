param(
    [string]$OutputDirectory = "releases"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$infoPath = Join-Path $root "info.json"

if (-not (Test-Path -LiteralPath $infoPath)) {
    throw "info.json not found in $root"
}

$info = Get-Content -Raw -LiteralPath $infoPath | ConvertFrom-Json
$modName = $info.name
$version = $info.version

if (-not $modName -or -not $version) {
    throw "info.json must contain name and version"
}

if ($modName -notmatch "^[A-Za-z0-9_-]+$") {
    throw "Unsupported mod name '$modName'. Expected only letters, numbers, dashes, and underscores."
}

if ($version -notmatch "^[0-9]+\.[0-9]+\.[0-9]+$") {
    throw "Unsupported version '$version'. Expected Factorio format number.number.number."
}

$packageName = "${modName}_${version}"
$outputPath = Join-Path $root $OutputDirectory
$zipPath = Join-Path $outputPath "$packageName.zip"
$stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) "factorio-mod-build"
$stagingMod = Join-Path $stagingRoot $packageName

function Assert-UnderDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$ChildPath,
        [Parameter(Mandatory = $true)][string]$ParentPath
    )

    $child = [System.IO.Path]::GetFullPath($ChildPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $parent = [System.IO.Path]::GetFullPath($ParentPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)

    if (-not $child.StartsWith($parent + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove path outside staging directory: $child"
    }
}

if (Test-Path -LiteralPath $stagingMod) {
    Assert-UnderDirectory -ChildPath $stagingMod -ParentPath $stagingRoot
    Remove-Item -LiteralPath $stagingMod -Recurse -Force
}

New-Item -ItemType Directory -Path $stagingMod -Force | Out-Null
New-Item -ItemType Directory -Path $outputPath -Force | Out-Null

$entries = @(
    "info.json",
    "control.lua",
    "data.lua",
    "data-updates.lua",
    "data-final-fixes.lua",
    "settings.lua",
    "settings-updates.lua",
    "settings-final-fixes.lua",
    "changelog.txt",
    "thumbnail.png",
    "License.txt",
    "Readme.txt",
    "locale",
    "migrations"
)

foreach ($entry in $entries) {
    $source = Join-Path $root $entry
    if (-not (Test-Path -LiteralPath $source)) {
        continue
    }

    $destination = Join-Path $stagingMod $entry
    $parent = Split-Path -Parent $destination
    if ($parent) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
}

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -Path $stagingMod -DestinationPath $zipPath -CompressionLevel Optimal
Assert-UnderDirectory -ChildPath $stagingMod -ParentPath $stagingRoot
Remove-Item -LiteralPath $stagingMod -Recurse -Force

Write-Output "Built $zipPath"
