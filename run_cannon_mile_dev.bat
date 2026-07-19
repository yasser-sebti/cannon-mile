@echo off
setlocal EnableExtensions
title Cannon Mile Dev Console - STARTING
color 0B
mode con: cols=104 lines=34
cls
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
  title Cannon Mile Dev Console - FLUTTER NOT FOUND
  echo [ERROR] Flutter SDK not found.
  echo.
  echo Checked FLUTTER_ROOT, USERPROFILE\develop\flutter, the local SDK path,
  echo and flutter.bat on PATH.
  pause
  popd
  exit /b 1
)

echo.
echo  ========================================================================
echo    CANNON MILE INTERACTIVE DEV CONSOLE
echo  ========================================================================
echo.
echo  Project:
echo    %CD%
echo.
echo  Flutter:
echo    %FLUTTER%
echo.
echo  Keep this console focused when using Flutter shortcuts.
echo    r         hot reload - press once, no Enter required
echo    Shift+R   hot restart
echo    h         Flutter help
echo    q         quit
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "tool\run_flutter_dev.ps1" -FlutterPath "%FLUTTER%"
set "DEV_EXIT=%ERRORLEVEL%"

if "%DEV_EXIT%"=="2" goto :already_running
if not "%DEV_EXIT%"=="0" goto :failure

title Cannon Mile Dev Console - STOPPED
echo.
echo  Cannon Mile dev session ended.
powershell -NoProfile -Command "Start-Sleep -Seconds 3" >nul
popd
exit /b 0

:already_running
title Cannon Mile Dev Console - DUPLICATE BLOCKED
echo.
echo [INFO] Another Cannon Mile dev console already owns hot reload.
echo        Use the original ACTIVE console for r, Shift+R, h, and q.
powershell -NoProfile -Command "Start-Sleep -Seconds 6" >nul
popd
exit /b 0

:failure
title Cannon Mile Dev Console - FAILED
echo.
echo [ERROR] The interactive development session failed with exit code %DEV_EXIT%.
echo Try flutter clean if the detailed error above reports a build failure.
pause
popd
exit /b %DEV_EXIT%
