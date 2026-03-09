@echo off
REM PXABCDEF Diagnostic Dashboard
REM Reads defaults from inputs\config.xlsx
REM Usage: dashboard.bat [--port PORT] [--debug]

cd /d "%~dp0.."
echo Starting PXABCDEF Diagnostic Dashboard...
echo Open http://localhost:8050 in your browser
echo Press Ctrl+C to stop
echo.
python -m python_implementation.main dashboard %*
