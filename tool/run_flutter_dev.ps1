param(
  [Parameter(Mandatory = $true)]
  [string]$FlutterPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$projectRootWithSeparator = $projectRoot.TrimEnd('\') + '\'
$pidFile = Join-Path $projectRoot '.dart_tool\cannon_mile_flutter.pid'
$exitCode = 1
$mutexAcquired = $false

function Set-DevConsoleTitle([string]$Title) {
  try {
    $Host.UI.RawUI.WindowTitle = $Title
  } catch {
    # A redirected/non-interactive verification shell may not expose a title.
  }
}

if (-not (Test-Path -LiteralPath $FlutterPath -PathType Leaf)) {
  Write-Error "Flutter was not found at $FlutterPath"
  exit 1
}

$sha256 = [System.Security.Cryptography.SHA256]::Create()
try {
  $projectBytes = [System.Text.Encoding]::UTF8.GetBytes(
    $projectRoot.ToLowerInvariant()
  )
  $mutexHash = ($sha256.ComputeHash($projectBytes) | ForEach-Object {
    $_.ToString('x2')
  }) -join ''
} finally {
  $sha256.Dispose()
}

$mutex = [System.Threading.Mutex]::new(
  $false,
  "Local\CannonMileFlutterDev_$($mutexHash.Substring(0, 16))"
)

try {
  try {
    $mutexAcquired = $mutex.WaitOne(0)
  } catch [System.Threading.AbandonedMutexException] {
    $mutexAcquired = $true
  }

  if (-not $mutexAcquired) {
    Write-Host '[INFO] A Cannon Mile Flutter dev session is already active.'
    $exitCode = 2
  } else {
    Set-Location -LiteralPath $projectRoot

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
        $isExpectedBuildPath = [string]::Equals(
          $resolvedBuildPath,
          $expectedBuildPath,
          [System.StringComparison]::OrdinalIgnoreCase
        ) -and $resolvedBuildPath.StartsWith(
          $projectRootWithSeparator,
          [System.StringComparison]::OrdinalIgnoreCase
        )
        if (-not $isExpectedBuildPath) {
          throw "Refusing to clean unexpected build path: $resolvedBuildPath"
        }

        Write-Host '[INFO] Path mismatch detected in CMake cache.'
        Write-Host '       Cleaning the stale workspace build directory...'
        Remove-Item -LiteralPath $resolvedBuildPath -Recurse -Force
      }
    }

    & (Join-Path $projectRoot 'tool\ensure_flutter_dependencies.ps1') `
      -FlutterPath $FlutterPath

    # Remove only orphaned Cannon Mile executables from this workspace. A live
    # session created by this runner is protected by the named mutex above.
    foreach ($process in @(Get-Process -Name 'cannon_mile' -ErrorAction SilentlyContinue)) {
      try {
        $processPath = $process.Path
      } catch {
        continue
      }
      if ($processPath -and $processPath.StartsWith(
        $projectRootWithSeparator,
        [System.StringComparison]::OrdinalIgnoreCase
      )) {
        Write-Host "Closing orphaned Cannon Mile process $($process.Id)..."
        Stop-Process -Id $process.Id -Force
        [void]$process.WaitForExit(5000)
      }
    }

    if (Test-Path -LiteralPath $pidFile -PathType Leaf) {
      Remove-Item -LiteralPath $pidFile -Force
    }

    Set-DevConsoleTitle 'Cannon Mile Dev Console - ACTIVE (r reload, Shift+R restart)'
    Write-Host 'Starting Cannon Mile in attached Windows debug mode...'
    Write-Host 'Use this ACTIVE console for r, Shift+R, h, and q.'
    & $FlutterPath run `
      -d windows `
      --debug `
      --hot `
      --no-pub `
      --pid-file $pidFile
    $exitCode = $LASTEXITCODE
  }
} catch {
  Write-Error $_
  $exitCode = 1
} finally {
  if (Test-Path -LiteralPath $pidFile -PathType Leaf) {
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
  }
  if ($mutexAcquired) {
    $mutex.ReleaseMutex()
  }
  $mutex.Dispose()
}

exit $exitCode
