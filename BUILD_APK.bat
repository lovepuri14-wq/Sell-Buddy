@echo off
title Build SellBuddy APK
cd /d "%~dp0mobile"
echo This builds an APK for Android Emulator default backend URL (10.0.2.2).
echo For public customers, deploy backend first and edit API_BASE_URL in the command below.
flutter pub get
flutter build apk --release
if %errorlevel%==0 (
  echo.
  echo APK created at:
  echo %cd%\build\app\outputs\flutter-apk\app-release.apk
)
pause
