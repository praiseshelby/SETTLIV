@echo off
echo === GIT COMMIT ===
cd /d "C:\Users\shelb\Downloads\SETTLIV-X"
git add .
git commit -m "Task 3 Set 1: Pearl Glass theme, docked nav bar, home revamp, balances screen, insights, plan, recent activity engine, font specimen, viewport fix"
echo.
echo === BUILD WEB ===
"C:\tools\flutter\bin\flutter.bat" build web --release
echo.
echo === BUILD DONE ===
echo Now run: cd build\web ^& python -m http.server 3000
