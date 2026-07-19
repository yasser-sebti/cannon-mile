@echo off
setlocal EnableExtensions
title Cannon Mile - Fast Offline Launch
pushd "%~dp0"

set "FLUTTER="
if defined FLUTTER_ROOT (
  if exist "%FLUTTER_ROOT%\bin\flutter.bat" set "FLUTTER=%FLUTTER_ROOT%\bin\flutter.bat"
)
if not defined FLUTTER (
  if exist "%USERPROFILE%\develop\flutter\bin\flutter.bat" set "FLUTTER=%USERPROFILE%\develop\flutter\bin\flutter.bat"
)
if not defined FLUTTER (
  if exist "C:\Users\sebti\develop\flutter\bin\flutter.bat" set "FLUTTER=C:\Users\sebti\develop\flutter\bin\flutter.bat"
)
if not defined FLUTTER (
  for /f "delims=" %%F in ('where flutter.bat 2^>nul') do (
    set "FLUTTER=%%F"
    goto :flutter_found
  )
)

:flutter_found
if not exist "%FLUTTER%" (
  echo [ERROR] Flutter SDK not found.
  pause
  popd
  exit /b 1
)

echo.
echo  =====================================
echo    CANNON MILE - FAST OFFLINE LAUNCH
echo  =====================================
echo.
echo  Closing an existing instance, if present...
taskkill /F /IM cannon_mile.exe /T >nul 2>&1

echo  Checking the cached release build...
powershell -NoProfile -ExecutionPolicy Bypass -File "tool\build_windows_if_needed.ps1" -FlutterPath "%FLUTTER%" -Configuration release
if errorlevel 1 (
  if exist "build\windows\x64\runner\Release\cannon_mile.exe" (
    echo.
    echo  [WARNING] Rebuild preparation failed; launching the last cached
    echo            release so the game remains available offline.
    goto :launch
  )
  goto :failure
)

:launch
echo.
echo  Launching Cannon Mile...
start "" "%~dp0build\windows\x64\runner\Release\cannon_mile.exe"
popd
exit /b 0

:failure
echo.
echo [ERROR] Offline launch preparation failed.
pause
popd
exit /b 1
