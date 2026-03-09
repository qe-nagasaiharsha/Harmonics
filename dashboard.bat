@echo off
REM PXABCDEF Diagnostic Dashboard
REM
REM Reads default settings from python_implementation\inputs\config.xlsx
REM Auto-detects data file and runs detection on startup.
REM Dashboard controls can be adjusted interactively in the browser.
REM
REM Usage:
REM   dashboard.bat                  (default port 8050)
REM   dashboard.bat --port 8080      (custom port)
REM   dashboard.bat --debug          (enable debug mode)

cd /d "%~dp0"
echo ============================================================
echo   PXABCDEF Diagnostic Dashboard
echo ============================================================
echo.
echo Running initial pattern detection, please wait...
echo Once ready, open http://localhost:8050 in your browser
echo Press Ctrl+C to stop
echo.
python -m python_implementation.main dashboard %*
echo.
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Dashboard failed to start. See error above.
)
pause
