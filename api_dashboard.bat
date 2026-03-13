@echo off
title PXABCDEF Harmonic Pattern Detection Dashboard
echo.
echo  ============================================
echo   Harmonics Dashboard — Startup
echo  ============================================
echo.

SET NODE=%USERPROFILE%\nodejs\node-v22.14.0-win-x64\node.exe
SET VITE=%~dp0frontend\node_modules\vite\bin\vite.js

REM Build frontend before starting
echo  Building frontend...
cd /d %~dp0frontend
"%NODE%" "%VITE%" build
if errorlevel 1 (
    echo  [ERROR] Frontend build failed!
    pause
    exit /b 1
)
echo  Frontend built successfully.
echo.

REM Start FastAPI backend in a new window
start "Harmonics API Server" cmd /k "cd /d %~dp0 && python -m python_implementation.api.server"

REM Brief pause so the server can bind
timeout /t 3 /nobreak >nul

echo  Backend API  : http://localhost:8001
echo  Opening browser...
start http://localhost:8001

echo.
echo  API server is running in a separate window.
echo  Close that window to stop the server.
pause
