param(
  [Parameter(Mandatory = $true)]
  [string]$FlutterPath
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
$lockPath = Join-Path $projectRoot 'pubspec.lock'
$dartToolPath = Join-Path $projectRoot '.dart_tool'
$packageConfigPath = Join-Path $dartToolPath 'package_config.json'
$stampPath = Join-Path $dartToolPath 'cannon_mile_dependencies.sha256'
$downloadAttemptPath = Join-Path $dartToolPath 'cannon_mile_download_attempt.sha256'

if (-not (Test-Path -LiteralPath $FlutterPath -PathType Leaf)) {
  throw "Flutter was not found at $FlutterPath"
}
if (-not (Test-Path -LiteralPath $pubspecPath -PathType Leaf)) {
  throw "pubspec.yaml was not found at $pubspecPath"
}
if (-not (Test-Path -LiteralPath $lockPath -PathType Leaf)) {
  throw 'pubspec.lock is missing. Dependency setup requires one online resolution.'
}
if (-not (Test-Path -LiteralPath $dartToolPath -PathType Container)) {
  [void](New-Item -ItemType Directory -Path $dartToolPath)
}

function Get-DependencyInput {
  $includedSections = @(
    'environment',
    'dependencies',
    'dev_dependencies',
    'dependency_overrides'
  )
  $builder = [System.Text.StringBuilder]::new()
  $includeCurrentSection = $false
  foreach ($line in [System.IO.File]::ReadAllLines($pubspecPath)) {
    if ($line -match '^([A-Za-z_][A-Za-z0-9_]*):') {
      $includeCurrentSection = $includedSections -contains $Matches[1]
    }
    if ($includeCurrentSection) {
      [void]$builder.AppendLine($line.TrimEnd())
    }
  }
  [void]$builder.AppendLine([System.IO.File]::ReadAllText($lockPath))
  [void]$builder.AppendLine([System.IO.Path]::GetFullPath($FlutterPath).ToLowerInvariant())

  $flutterRoot = Split-Path -Parent (Split-Path -Parent $FlutterPath)
  $flutterVersionPath = Join-Path $flutterRoot 'version'
  if (Test-Path -LiteralPath $flutterVersionPath -PathType Leaf) {
    [void]$builder.AppendLine([System.IO.File]::ReadAllText($flutterVersionPath))
  }
  return $builder.ToString()
}

function Get-Sha256([string]$Value) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    return ($sha.ComputeHash($bytes) | ForEach-Object {
      $_.ToString('x2')
    }) -join ''
  } finally {
    $sha.Dispose()
  }
}

function Write-Utf8NoBom([string]$Path, [string]$Value) {
  $encoding = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $Value, $encoding)
}

function Test-PackageConfigReady {
  if (-not (Test-Path -LiteralPath $packageConfigPath -PathType Leaf)) {
    return $false
  }
  try {
    $config = [System.IO.File]::ReadAllText($packageConfigPath) |
      ConvertFrom-Json
    $configDirectory = Split-Path -Parent $packageConfigPath
    foreach ($package in $config.packages) {
      $rootUriText = [string]$package.rootUri
      $absoluteUri = $null
      if (
        [Uri]::TryCreate(
          $rootUriText,
          [UriKind]::Absolute,
          [ref]$absoluteUri
        ) -and $absoluteUri.IsFile
      ) {
        $rootPath = $absoluteUri.LocalPath
      } else {
        $relativePath = [Uri]::UnescapeDataString($rootUriText).Replace(
          '/',
          [System.IO.Path]::DirectorySeparatorChar
        )
        $rootPath = [System.IO.Path]::GetFullPath(
          (Join-Path $configDirectory $relativePath)
        )
      }
      if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) {
        return $false
      }
    }
    return $true
  } catch {
    return $false
  }
}

$fingerprint = Get-Sha256 (Get-DependencyInput)
$savedFingerprint = if (Test-Path -LiteralPath $stampPath -PathType Leaf) {
  [System.IO.File]::ReadAllText($stampPath).Trim()
} else {
  ''
}

if ((Test-PackageConfigReady) -and $savedFingerprint -eq $fingerprint) {
  return
}

Write-Host 'Dependency metadata changed; checking the local Flutter cache...'
& $FlutterPath pub get --offline
if ($LASTEXITCODE -eq 0) {
  Write-Utf8NoBom $stampPath $fingerprint
  Remove-Item -LiteralPath $downloadAttemptPath -Force -ErrorAction SilentlyContinue
  Write-Host 'Dependencies are ready from the offline cache.'
  return
}

$previousAttempt = if (Test-Path -LiteralPath $downloadAttemptPath -PathType Leaf) {
  [System.IO.File]::ReadAllText($downloadAttemptPath).Trim()
} else {
  ''
}
if ($previousAttempt -eq $fingerprint) {
  throw @'
Required packages are not available offline. The one-time automatic download
was already attempted for this dependency state. Connect once and run:
  flutter pub get
The normal launcher will remain fully offline afterward.
'@
}

Write-Utf8NoBom $downloadAttemptPath $fingerprint
Write-Host 'A required package is absent locally; attempting one online download...'
& $FlutterPath pub get
if ($LASTEXITCODE -ne 0) {
  throw @'
The one-time dependency download failed. Existing cached builds can still run,
but a new Flutter build requires the missing package. Connect once and run:
  flutter pub get
'@
}

Write-Utf8NoBom $stampPath $fingerprint
Remove-Item -LiteralPath $downloadAttemptPath -Force -ErrorAction SilentlyContinue
Write-Host 'One-time dependency setup completed; future launches use the offline cache.'
