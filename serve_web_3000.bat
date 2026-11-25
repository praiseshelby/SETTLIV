@echo off
cd /d "C:\Users\shelb\Downloads\SETTLIV-X"
echo Serving build/web on http://localhost:3000 ...
python -m http.server 3000 --directory build/web
pause
