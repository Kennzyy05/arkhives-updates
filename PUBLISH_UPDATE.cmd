@echo off
setlocal
if "%~1"=="" (
  echo.
  echo ARKhives Update Publisher
  echo.
  echo Drag a signed .arkenpatch file onto this PUBLISH_UPDATE.cmd file.
  echo.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\publish_update.ps1" -PatchPath "%~1"
set EXITCODE=%ERRORLEVEL%

echo.
if not "%EXITCODE%"=="0" (
  echo Publishing failed. Nothing newer should be advertised unless the script reported otherwise.
) else (
  echo Publishing completed successfully.
)
echo.
pause
exit /b %EXITCODE%
