@echo off
REM PXABCDEF Pattern Detection - Backtest
REM
REM Reads all settings from python_implementation\inputs\config.xlsx
REM including the data file path, pattern type, channel type, etc.
REM
REM Usage:
REM   detect.bat                         (uses Excel config for everything)
REM   detect.bat data\USDJPY_M1.csv      (override data file, rest from Excel)
REM   detect.bat --pattern XAB           (override pattern type)
REM   detect.bat data.csv --buffer 0.5   (override data file and buffer)

cd /d "%~dp0"
echo ============================================================
echo   PXABCDEF Pattern Detection Engine
echo ============================================================
echo.
echo Reading configuration from: python_implementation\inputs\config.xlsx
echo CLI arguments override Excel values when provided.
echo.
python -m python_implementation.main detect %*
echo.
pause
