@echo off
cd /d "%~dp0"
echo Starting Quizforge question server: http://127.0.0.1:8765/health
start "Quizforge Question Server" cmd /k "C:\Users\myles\Tools\qfenv\Scripts\python.exe server\app.py"
echo Starting Quizforge sharing server: http://127.0.0.1:8766/health
start "Quizforge Sharing Server" cmd /k "C:\Users\myles\Tools\qfenv\Scripts\python.exe server\sharing_server.py"
echo.
echo Health URLs:
echo   http://127.0.0.1:8765/health
echo   http://127.0.0.1:8766/health
