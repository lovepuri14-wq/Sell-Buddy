@echo off
title SellBuddy Backend
cd /d "%~dp0backend"
echo ========================================
echo SellBuddy - Backend and Website
echo ========================================
where py >nul 2>nul
if %errorlevel%==0 (
  py -m pip install -r requirements.txt
  py app.py
) else (
  python -m pip install -r requirements.txt
  python app.py
)
pause
