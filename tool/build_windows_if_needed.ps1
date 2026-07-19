param(
  [Parameter(Mandatory = $true)]
  [string]$FlutterPath,

  [ValidateSet('debug', 'release')]
  [string]$Configuration = 'release',

  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$configurationFolder = if ($Configuration -eq 'release') { 'Release' } else { 'Debug' }
$executablePath = Join-Path $projectRoot "build\windows\x64\runner\$configurationFolder\cannon_mile.exe"
$stampPath = Join-Path $projectRoot ".dart_tool\cannon_mile_${Configuration}_build.sha256"

function Get-BuildFingerprint {
  $roots = @('assets', 'lib', 'shaders', 'windows')
  $files = foreach ($relativeRoot in $roots) {
    $root = Join-Path $projectRoot $relativeRoot
    if (Test-Path -LiteralPath $root -PathType Container) {
      Get-ChildItem -LiteralPath $root -Recurse -File |
        Where-Object { $_.Name -ne '.gitkeep' }
    }
  }
  $files += @('pubspec.yaml', 'pubspec.lock') |
    ForEach-Object { Join-Path $projectRoot $_ } |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    ForEach-Object { Get-Item -LiteralPath $_ }

  $builder = [System.Text.StringBuilder]::new()
  foreach ($file in @($files | Sort-Object FullName)) {
    $relativePath = $file.FullName.Substring($projectRoot.Length + 1).Replace('\', '/')
    [void]$builder.Append($relativePath)
    [void]$builder.Append('|')
    [void]$builder.Append($file.Length)
    [void]$builder.Append('|')
    [void]$builder.AppendLine($file.LastWriteTimeUtc.Ticks)
  }
  [void]$builder.AppendLine($Configuration)

  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($builder.ToString())
    return ($sha.ComputeHash($bytes) | ForEach-Object {
      $_.ToString('x2')
    }) -join ''
  } finally {
    $sha.Dispose()
  }
}

$fingerprint = Get-BuildFingerprint
$savedFingerprint = if (Test-Path -LiteralPath $stampPath -PathType Leaf) {
  [System.IO.File]::ReadAllText($stampPath).Trim()
} else {
  ''
}

if (
  -not $Force -and
  (Test-Path -LiteralPath $executablePath -PathType Leaf) -and
  $savedFingerprint -eq $fingerprint
) {
  Write-Host "Using the current cached Windows $Configuration build."
  return
}

Write-Host 'Syncing asset folders because a rebuild is required...'
& (Join-Path $PSScriptRoot 'sync_asset_folders.ps1')

& (Join-Path $PSScriptRoot 'ensure_flutter_dependencies.ps1') `
  -FlutterPath $FlutterPath

$cachePath = Join-Path $projectRoot 'build\windows\x64\CMakeCache.txt'
if (Test-Path -LiteralPath $cachePath -PathType Leaf) {
  $forwardRoot = $projectRoot.Replace('\', '/')
  $expectedCacheLine = "For build in directory: $forwardRoot/build/windows/x64"
  $cacheMatches = Select-String `
    -LiteralPath $cachePath `
    -SimpleMatch `
    -Pattern $expectedCacheLine `
    -Quiet
  if (-not $cacheMatches) {
    $buildPath = Join-Path $projectRoot 'build'
    $resolvedBuildPath = (Resolve-Path -LiteralPath $buildPath).Path
    $expectedBuildPath = [System.IO.Path]::GetFullPath($buildPath)
    if (-not [string]::Equals(
      $resolvedBuildPath,
      $expectedBuildPath,
      [System.StringComparison]::OrdinalIgnoreCase
    )) {
      throw "Refusing to clean unexpected build path: $resolvedBuildPath"
    }
    Write-Host 'Cleaning a stale CMake cache from a different workspace path...'
    Remove-Item -LiteralPath $resolvedBuildPath -Recurse -Force
  }
}

Push-Location $projectRoot
try {
  Write-Host "Building the Windows $Configuration executable..."
  & $FlutterPath build windows "--$Configuration" --no-pub
  if ($LASTEXITCODE -ne 0) {
    throw "Flutter Windows build failed with exit code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}

$finalFingerprint = Get-BuildFingerprint
$encoding = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($stampPath, $finalFingerprint, $encoding)
