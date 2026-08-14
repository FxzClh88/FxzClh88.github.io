@echo off
setlocal
chcp 65001 >nul
title Update Blog

rem Clear NODE_OPTIONS to avoid the safe-delete shim breaking hexo deploy
set NODE_OPTIONS=
set NODE=C:\Users\Administrator\.workbuddy\binaries\node\versions\22.22.2\node.exe

cd /d C:\Users\Administrator\myblog

echo ============================================
echo    Update Blog & Deploy to GitHub Pages
echo ============================================
echo.

echo [1/3] Cleaning cache...
%NODE% node_modules\hexo\bin\hexo clean
echo.

echo [2/3] Generating static files...
%NODE% node_modules\hexo\bin\hexo generate
echo.

echo [3/3] Deploying to GitHub Pages...
%NODE% node_modules\hexo\bin\hexo deploy
echo.

echo ============================================
echo    Done! Visit https://FxzClh88.github.io
echo    (Wait 1-2 min for GitHub to build)
echo ============================================
echo.
pause
