@echo off
setlocal
cd /d "%~dp0"

where dotnet >nul 2>&1
if errorlevel 1 (
  echo .NET SDK not found. Install from https://dotnet.microsoft.com/download/dotnet/8.0
  pause
  exit /b 1
)

dotnet publish -c Release -r win-x64 --self-contained true ^
  -p:PublishSingleFile=true ^
  -p:EnableCompressionInSingleFile=true ^
  -p:IncludeNativeLibrariesForSelfExtract=true ^
  -p:EnableWindowsTargeting=true ^
  -p:DebugType=none ^
  -p:DebugSymbols=false ^
  -o "%~dp0dist"

if errorlevel 1 (
  echo Publish failed.
  pause
  exit /b 1
)

echo.
echo Built: %~dp0dist\GooCollector.exe
echo.
pause
