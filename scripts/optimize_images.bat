@echo off
REM Docker Image Optimization and Analysis Script (Windows)
REM Usage: scripts\optimize_images.ps1

echo [36m Docker Image Optimization Script [0m
echo ========================================
echo.

if "%1"=="" goto all
if "%1"=="build" goto build
if "%1"=="analyze" goto analyze
if "%1"=="compare" goto compare
if "%1"=="clean" goto clean
goto usage

:build
echo [34mBuilding optimized images...[0m
echo.
cd docker
docker-compose build
cd ..
echo [32mBuild complete[0m
goto end

:analyze
echo [34mAnalyzing Docker images...[0m
echo.
docker images eaglespy-rails --format "Size: {{.Size}}"
docker images eaglespy-frontend --format "Size: {{.Size}}"
docker images postgres:13-alpine --format "Size: {{.Size}}"
docker images redis:7-alpine --format "Size: {{.Size}}"
goto end

:compare
echo [34mImage Size Comparison[0m
echo ==========================
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
goto end

:clean
echo [34mCleaning up unused Docker resources...[0m
docker image prune -f
echo [32mCleanup complete[0m
goto end

:all
call :build
call :compare
call :analyze
call :clean
echo.
echo [32mOptimization complete![0m
goto end

:usage
echo Usage: %0 {build^|analyze^|compare^|clean^|all}
exit /b 1

:end
