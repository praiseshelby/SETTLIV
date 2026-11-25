@echo off
cd /d "C:\Users\shelb\Downloads\SETTLIV-X"
echo Starting Settliv web app on http://localhost:3000 ...
flutter run -d chrome --web-port 3000 --no-pub
pause
