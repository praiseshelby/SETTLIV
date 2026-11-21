@echo off
cd /d "C:\Users\shelb\Downloads\SETTLIV-X"
echo === ANALYZE ===
call "C:\tools\flutter\bin\flutter.bat" analyze
if %errorlevel% neq 0 (
    echo Analyze failed!
    exit /b %errorlevel%
)
echo.
echo === TEST ===
call "C:\tools\flutter\bin\flutter.bat" test
if %errorlevel% neq 0 (
    echo Tests failed!
    exit /b %errorlevel%
)
echo.
echo === GIT COMMIT ===
git add .
git commit -m "Task 3 Set 2: Personal space filter in Records, Personal (just me) in Add Expense, auto-focus Quick tab, personal subtitle in ExpenseTile"
echo.
echo === BUILD WEB ===
call "C:\tools\flutter\bin\flutter.bat" build web --release
echo.
echo === COMPLETED SET 2 ===
