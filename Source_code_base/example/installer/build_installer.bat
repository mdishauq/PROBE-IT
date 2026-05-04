@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0.."

echo [1/3] Building Flutter Windows release...
flutter clean
if errorlevel 1 goto :fail

flutter pub get
if errorlevel 1 goto :fail

flutter build windows --release
if errorlevel 1 goto :fail

echo [2/3] Locating Inno Setup compiler...
set ISCC=
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" set ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe
if exist "C:\Program Files\Inno Setup 6\ISCC.exe" set ISCC=C:\Program Files\Inno Setup 6\ISCC.exe

if "%ISCC%"=="" (
  echo ERROR: Inno Setup 6 not found.
  echo Install Inno Setup 6 from: https://jrsoftware.org/isinfo.php
  goto :fail
)

echo [3/3] Building installer EXE...
"%ISCC%" "installer\probeit_installer.iss"
if errorlevel 1 goto :fail

echo.
echo SUCCESS: Installer created in example\installer\dist
exit /b 0

:fail
echo.
echo FAILED: Build or packaging did not complete.
exit /b 1
