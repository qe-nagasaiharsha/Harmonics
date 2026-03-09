@echo off
title Harmonics Dashboard

echo.
echo  Starting Harmonics Dashboard...
echo  The network URL will be shown below once the server starts.
echo.

cd /d "%~dp0"
python -m python_implementation.api.server

pause
