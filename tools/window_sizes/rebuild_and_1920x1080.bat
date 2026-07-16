@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0resize_cannon_mile_window.ps1" -DeviceWidth 1920 -DeviceHeight 1080 -Label "Full HD after rebuild" -Rebuild
pause
