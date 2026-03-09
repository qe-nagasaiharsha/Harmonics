@echo off
REM PXABCDEF Pattern Detection - Backtest
REM Reads settings from inputs\config.xlsx
REM Usage: detect.bat [data_file] [options]

cd /d "%~dp0.."
python -m python_implementation.main detect %*
pause
