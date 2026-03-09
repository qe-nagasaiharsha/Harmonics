@echo off
title PXABCDEF Harmonic Pattern Detection Dashboard
echo.
echo  ============================================
echo   Harmonics Dashboard — Startup
echo  ============================================
echo.

REM Start FastAPI backend in a new window
start "Harmonics API Server" cmd /k "cd /d %~dp0 && python -m python_implementation.api.server"

REM Brief pause so the server can bind
timeout /t 3 /nobreak >nul

REM Start React dev server in a new window
start "Harmonics UI (Vite)" cmd /k "cd /d %~dp0\frontend && npm run dev"

timeout /t 3 /nobreak >nul

echo.
echo  Backend API  : http://localhost:8000
echo  Dashboard UI : http://localhost:5173
echo.
echo  Opening browser...
start http://localhost:5173

echo.
echo  Both servers are running in separate windows.
echo  Close those windows to stop the servers.
pause
