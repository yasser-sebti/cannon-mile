param(
  [Parameter(Mandatory = $true)]
  [int]$DeviceWidth,

  [Parameter(Mandatory = $true)]
  [int]$DeviceHeight,

  [double]$Scale = 0,

  [string]$Label = "$DeviceWidth x $DeviceHeight",

  [switch]$Rebuild
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path
$debugExe = Join-Path $repoRoot 'build\windows\x64\runner\Debug\cannon_mile.exe'
$releaseExe = Join-Path $repoRoot 'build\windows\x64\runner\Release\cannon_mile.exe'
$debugKernel = Join-Path $repoRoot 'build\windows\x64\runner\Debug\data\flutter_assets\kernel_blob.bin'

function Find-Flutter {
  $candidates = @()
  if ($env:FLUTTER_ROOT) {
    $candidates += (Join-Path $env:FLUTTER_ROOT 'bin\flutter.bat')
  }
  $candidates += (Join-Path $env:USERPROFILE 'develop\flutter\bin\flutter.bat')
  $candidates += 'C:\Users\sebti\develop\flutter\bin\flutter.bat'
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }
  $command = Get-Command flutter.bat -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }
  throw 'Flutter SDK not found.'
}

function Get-LatestSourceWriteTime {
  $sourceRoots = @(
    (Join-Path $repoRoot 'assets'),
    (Join-Path $repoRoot 'lib'),
    (Join-Path $repoRoot 'windows\runner')
  )
  $files = foreach ($root in $sourceRoots) {
    if (Test-Path -LiteralPath $root) {
      Get-ChildItem -LiteralPath $root -Recurse -File |
        Where-Object { $_.Name -ne '.gitkeep' }
    }
  }
  $extraFiles = @(
    (Join-Path $repoRoot 'pubspec.yaml'),
    (Join-Path $repoRoot 'pubspec.lock')
  ) | Where-Object { Test-Path -LiteralPath $_ } |
    ForEach-Object { Get-Item -LiteralPath $_ }

  @($files) + @($extraFiles) |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 -ExpandProperty LastWriteTime
}

$buildStamp = if (Test-Path -LiteralPath $debugKernel) { $debugKernel } else { $debugExe }
$shouldBuild = $Rebuild -or -not (Test-Path -LiteralPath $debugExe) -or -not (Test-Path -LiteralPath $buildStamp)
if (-not $shouldBuild) {
  $latestSourceWriteTime = Get-LatestSourceWriteTime
  $buildWriteTime = (Get-Item -LiteralPath $buildStamp).LastWriteTime
  $shouldBuild = $latestSourceWriteTime -gt $buildWriteTime
}

if ($shouldBuild) {
  $flutter = Find-Flutter
  Write-Host 'Building the Windows preview because it is missing or stale...'
  Push-Location $repoRoot
  try {
    & (Join-Path $repoRoot 'tool\ensure_flutter_dependencies.ps1') `
      -FlutterPath $flutter
    & $flutter build windows --debug --no-pub
    if ($LASTEXITCODE -ne 0) {
      throw "flutter build windows --debug failed with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }
}

$exe = if (Test-Path -LiteralPath $debugExe) { $debugExe } else { $releaseExe }
if (-not (Test-Path -LiteralPath $exe)) {
  throw 'Could not find cannon_mile.exe. Build the Windows app first.'
}

if (-not ('CannonMileWindowTools' -as [type])) {
  Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class CannonMileWindowTools {
  [DllImport("user32.dll", SetLastError=true)]
  public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

  [DllImport("user32.dll", SetLastError=true)]
  public static extern bool AdjustWindowRectEx(ref RECT lpRect, int dwStyle, bool bMenu, int dwExStyle);

  [DllImport("user32.dll", SetLastError=true)]
  public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

  [DllImport("user32.dll")]
  public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

  [StructLayout(LayoutKind.Sequential)]
  public struct RECT {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
  }
}
"@
}

Add-Type -AssemblyName System.Windows.Forms
$workArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
if ($Scale -le 0) {
  $maxPreviewWidth = [math]::Max(640, $workArea.Width - 120)
  $maxPreviewHeight = [math]::Max(360, $workArea.Height - 120)
  $Scale = [math]::Min($maxPreviewWidth / $DeviceWidth, $maxPreviewHeight / $DeviceHeight)
  $Scale = [math]::Min(1.0, [math]::Max(0.2, [double]$Scale))
}

$windowWidth = [math]::Ceiling($DeviceWidth * $Scale)
$windowHeight = [math]::Ceiling($DeviceHeight * $Scale)
$arguments = @(
  "--preview-width=$DeviceWidth",
  "--preview-height=$DeviceHeight",
  "--preview-scale=$Scale"
)

$process = Start-Process -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe) -ArgumentList $arguments -PassThru
$handle = [IntPtr]::Zero
for ($i = 0; $i -lt 80; $i++) {
  Start-Sleep -Milliseconds 125
  $process.Refresh()
  if ($process.MainWindowHandle -ne 0) {
    $handle = $process.MainWindowHandle
    break
  }
}
if ($handle -eq [IntPtr]::Zero) {
  throw 'Cannon Mile launched, but no window handle was found.'
}

$gwlStyle = -16
$gwlExStyle = -20
$swShownormal = 1
$swpNozorder = 0x0004
$swpNoactivate = 0x0010
$style = [CannonMileWindowTools]::GetWindowLong($handle, $gwlStyle)
$exStyle = [CannonMileWindowTools]::GetWindowLong($handle, $gwlExStyle)
$rect = New-Object CannonMileWindowTools+RECT
$rect.Left = 0
$rect.Top = 0
$rect.Right = $windowWidth
$rect.Bottom = $windowHeight
[void][CannonMileWindowTools]::AdjustWindowRectEx([ref]$rect, $style, $false, $exStyle)

$outerWidth = $rect.Right - $rect.Left
$outerHeight = $rect.Bottom - $rect.Top
[void][CannonMileWindowTools]::ShowWindow($handle, $swShownormal)
[void][CannonMileWindowTools]::SetWindowPos(
  $handle,
  [IntPtr]::Zero,
  80,
  40,
  $outerWidth,
  $outerHeight,
  $swpNozorder -bor $swpNoactivate
)

Write-Host "Cannon Mile test window: $Label"
Write-Host "Simulated device size: $DeviceWidth x $DeviceHeight"
Write-Host "Preview scale: $Scale x"
Write-Host "Actual client window: $windowWidth x $windowHeight"
Write-Host 'Close the game window when you finish this preset.'
