@echo off
setlocal
chcp 65001 >nul
title Update Blog

cd /d C:\Users\Administrator\myblog

echo ============================================
echo    Update Blog via GitHub Actions
echo ============================================
echo.

echo [1/2] Staging changes...
git add -A

echo [2/2] Commit & Push to source branch...
git commit -m "Update blog" >nul 2>&1
git push origin source

echo.
echo ============================================
echo    Done! GitHub Actions will build & deploy.
echo    Wait 1-2 min, then visit:
echo    https://FxzClh88.github.io
echo ============================================
echo.
pause
