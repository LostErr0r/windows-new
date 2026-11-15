@echo off
:: WindowsDoProgram - launcher. Right-click -> Run as administrator (or just double-click: the script asks for elevation itself).
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup.ps1" %*
if errorlevel 1 pause
