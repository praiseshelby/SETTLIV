@echo off
echo ========================================
echo  SETTLIV-X — Final Checks
echo ========================================
cd /d "C:\Users\shelb\Downloads\SETTLIV-X"
if errorlevel 1 (
  echo ERROR: Could not find project directory.
  pause
  exit /b 1
)

echo.
echo [1/4] Running flutter analyze...
flutter analyze --no-pub
if errorlevel 1 (
  echo.
  echo !! Analyze found issues. Fix before committing.
  pause
  exit /b 1
)

echo.
echo [2/4] Running flutter test...
flutter test --no-pub
if errorlevel 1 (
  echo.
  echo !! Tests failed. Fix before committing.
  pause
  exit /b 1
)

echo.
echo [3/4] Git commit...
git add -A
git commit -m "Set 3 complete: insights+budgets, savings goals, screen lock WebAuthn, help & feedback, logomark, motion polish, QA docs"
if errorlevel 1 (
  echo (Nothing to commit or git error above)
)

echo.
echo [4/4] Release build...
flutter build web --release --no-web-resources-cdn
if errorlevel 1 (
  echo.
  echo !! Build failed.
  pause
  exit /b 1
)

echo.
echo ========================================
echo  All done! Build output: build\web\
echo  To deploy: copy vercel.json build\web\
echo             cd build\web
echo             npx vercel --prod --yes
echo ========================================
pause
