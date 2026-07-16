@echo off
setlocal EnableExtensions
title Cannon Mile Dev Console
color 0B
mode con: cols=96 lines=32
cls
pushd "%~dp0"

set "CURRENT_DIR=%CD%"
set "CURRENT_DIR_FORWARD=%CURRENT_DIR:\=/%"
set "CLEAN_BUILD="
if exist "build\windows\x64\CMakeCache.txt" (
  findstr /I /C:"For build in directory: %CURRENT_DIR_FORWARD%/build/windows/x64" "build\windows\x64\CMakeCache.txt" >nul
  if errorlevel 1 set "CLEAN_BUILD=1"
)

if defined CLEAN_BUILD (
  echo.
  echo  [INFO] Path mismatch detected in CMake cache.
  echo         Cleaning the stale build directory...
  rmdir /s /q "build"
)

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
  echo.
  echo Checked FLUTTER_ROOT, USERPROFILE\develop\flutter, the local SDK path,
  echo and flutter.bat on PATH.
  pause
  popd
  exit /b 1
)

echo.
echo  ================================================================
echo    CANNON MILE DEV CONSOLE
echo  ================================================================
echo.
echo  Project:
echo    %CD%
echo.
echo  Flutter:
echo    %FLUTTER%
echo.
echo  Dev shortcuts in this console:
echo    r   hot reload
echo    R   hot restart
echo    h   Flutter help
echo    q   quit
echo.

echo  Syncing populated asset folders...
powershell -NoProfile -ExecutionPolicy Bypass -File "tool\sync_asset_folders.ps1"
if errorlevel 1 goto :failure

echo  Preparing Flutter packages...
call "%FLUTTER%" pub get >nul
if errorlevel 1 goto :failure

echo  Starting Cannon Mile in Windows debug mode...
call "%FLUTTER%" run -d windows --debug --no-pub
if errorlevel 1 goto :failure

echo.
echo  Cannon Mile dev run ended.
pause
popd
exit /b 0

:failure
echo.
echo [ERROR] The development launch failed.
echo Try flutter clean, then run this file again.
pause
popd
exit /b 1
