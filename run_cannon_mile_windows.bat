@echo off
setlocal EnableExtensions
title Cannon Mile - Building...
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
  pause
  popd
  exit /b 1
)

echo.
echo  =====================================
echo    CANNON MILE - BUILD AND LAUNCH
echo  =====================================
echo.
echo  Closing an existing instance, if present...
taskkill /F /IM cannon_mile.exe /T >nul 2>&1

echo  Syncing populated asset folders...
powershell -NoProfile -ExecutionPolicy Bypass -File "tool\sync_asset_folders.ps1"
if errorlevel 1 goto :failure

echo  Preparing Flutter packages...
call "%FLUTTER%" pub get >nul
if errorlevel 1 goto :failure

echo  Building the Windows release...
call "%FLUTTER%" build windows --release --no-pub
if errorlevel 1 goto :failure

echo.
echo  Launching Cannon Mile...
start "" "%~dp0build\windows\x64\runner\Release\cannon_mile.exe"
popd
exit /b 0

:failure
echo.
echo [ERROR] The release build or launch preparation failed.
pause
popd
exit /b 1
