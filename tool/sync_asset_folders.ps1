param(
  [switch]$Check
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
$assetRoot = Join-Path $repoRoot 'assets'
$beginMarker = '    # BEGIN GENERATED GAME ASSETS'
$endMarker = '    # END GENERATED GAME ASSETS'
$supportedExtensions = @(
  '.gif', '.jpeg', '.jpg', '.json', '.mp3', '.ogg', '.otf', '.png',
  '.svg', '.ttf', '.txt', '.wav', '.webp'
)

if (-not (Test-Path -LiteralPath $pubspecPath)) {
  throw "pubspec.yaml not found at $pubspecPath"
}
if (-not (Test-Path -LiteralPath $assetRoot)) {
  throw "Asset folder not found at $assetRoot"
}

$assetDirectories = Get-ChildItem -LiteralPath $assetRoot -Directory |
  Where-Object { $_.Name -ne 'branding' } |
  Where-Object {
    $directory = $_
    $contentFiles = Get-ChildItem -LiteralPath $directory.FullName -File -Recurse |
      Where-Object {
        $_.Name -ne '.gitkeep' -and
        $supportedExtensions -contains $_.Extension.ToLowerInvariant()
      }
    @($contentFiles).Count -gt 0
  } |
  Sort-Object Name

$content = [System.IO.File]::ReadAllText($pubspecPath)
$newline = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
$generatedLines = @($beginMarker)
foreach ($directory in $assetDirectories) {
  $generatedLines += "    - assets/$($directory.Name)/"
}
$generatedLines += $endMarker
$generatedBlock = $generatedLines -join $newline

$pattern = '(?ms)^    \# BEGIN GENERATED GAME ASSETS\r?\n.*?^    \# END GENERATED GAME ASSETS'
if (-not [regex]::IsMatch($content, $pattern)) {
  throw 'Generated game asset markers were not found in pubspec.yaml.'
}

$updated = [regex]::Replace(
  $content,
  $pattern,
  [System.Text.RegularExpressions.MatchEvaluator] { param($match) $generatedBlock },
  1
)

if ($Check) {
  if ($updated -ne $content) {
    Write-Error 'pubspec.yaml asset entries are out of sync. Run tool\sync_asset_folders.ps1.'
    exit 1
  }
  Write-Host 'Game asset folders are already in sync.'
  exit 0
}

if ($updated -ne $content) {
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($pubspecPath, $updated, $utf8NoBom)
  Write-Host "Synced $($assetDirectories.Count) populated game asset folders."
} else {
  Write-Host 'Game asset folders are already in sync.'
}
