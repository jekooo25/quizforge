@echo off
cd /d "C:\Users\myles\OneDrive\Documents\Default Project"
echo Starting Quizforge server...
echo Health check: http://127.0.0.1:8765/health
"C:\Users\myles\Tools\qfenv\Scripts\python.exe" server\app.py
pause