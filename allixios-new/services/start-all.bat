@echo off
REM Allixios Services Startup Script for Windows
REM Starts all microservices in development mode

echo 🚀 Starting Allixios Microservices Platform
echo ==========================================

REM Check if Node.js is installed
node --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js is not installed. Please install Node.js 18+ first.
    pause
    exit /b 1
)

echo [INFO] Node.js version: 
node --version

REM Check if npm is available
npm --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] npm is not available. Please ensure npm is installed.
    pause
    exit /b 1
)

echo [INFO] Installing dependencies for all services...

REM Install dependencies for each service
if exist "shared\package.json" (
    echo [SERVICE] Installing dependencies for Shared Libraries...
    cd shared
    call npm install --silent
    cd ..
    echo [INFO] Shared Libraries dependencies installed ✓
)

if exist "content-service\package.json" (
    echo [SERVICE] Installing dependencies for Content Service...
    cd content-service
    call npm install --silent
    cd ..
    echo [INFO] Content Service dependencies installed ✓
)

if exist "user-service\package.json" (
    echo [SERVICE] Installing dependencies for User Service...
    cd user-service
    call npm install --silent
    cd ..
    echo [INFO] User Service dependencies installed ✓
)

if exist "analytics-service\package.json" (
    echo [SERVICE] Installing dependencies for Analytics Service...
    cd analytics-service
    call npm install --silent
    cd ..
    echo [INFO] Analytics Service dependencies installed ✓
)

if exist "seo-service\package.json" (
    echo [SERVICE] Installing dependencies for SEO Service...
    cd seo-service
    call npm install --silent
    cd ..
    echo [INFO] SEO Service dependencies installed ✓
)

if exist "notification-service\package.json" (
    echo [SERVICE] Installing dependencies for Notification Service...
    cd notification-service
    call npm install --silent
    cd ..
    echo [INFO] Notification Service dependencies installed ✓
)

echo.
echo [INFO] All dependencies installed successfully!
echo.

echo [INFO] Starting all microservices...
echo.

REM Start services in separate windows
if exist "content-service\package.json" (
    echo [SERVICE] Starting Content Service on port 3001...
    start "Content Service" cmd /k "cd content-service && npm run dev"
    timeout /t 2 /nobreak >nul
)

if exist "user-service\package.json" (
    echo [SERVICE] Starting User Service on port 3002...
    start "User Service" cmd /k "cd user-service && npm run dev"
    timeout /t 2 /nobreak >nul
)

if exist "analytics-service\package.json" (
    echo [SERVICE] Starting Analytics Service on port 3003...
    start "Analytics Service" cmd /k "cd analytics-service && npm run dev"
    timeout /t 2 /nobreak >nul
)

if exist "seo-service\package.json" (
    echo [SERVICE] Starting SEO Service on port 3004...
    start "SEO Service" cmd /k "cd seo-service && npm run dev"
    timeout /t 2 /nobreak >nul
)

if exist "notification-service\package.json" (
    echo [SERVICE] Starting Notification Service on port 3006...
    start "Notification Service" cmd /k "cd notification-service && npm run dev"
    timeout /t 2 /nobreak >nul
)

echo.
echo [INFO] All services started successfully!
echo.

echo 🌐 Service URLs:
echo ==================
echo Content Service:      http://localhost:3001
echo User Service:         http://localhost:3002
echo Analytics Service:    http://localhost:3003
echo SEO Service:          http://localhost:3004
echo Notification Service: http://localhost:3006
echo.

echo 📚 API Documentation:
echo ======================
echo Content Service:      http://localhost:3001/api-docs
echo User Service:         http://localhost:3002/api-docs
echo Analytics Service:    http://localhost:3003/api-docs
echo SEO Service:          http://localhost:3004/api-docs
echo Notification Service: http://localhost:3006/api-docs
echo.

echo ❤️  Health Checks:
echo ==================
echo Content Service:      http://localhost:3001/health
echo User Service:         http://localhost:3002/health
echo Analytics Service:    http://localhost:3003/health
echo SEO Service:          http://localhost:3004/health
echo Notification Service: http://localhost:3006/health
echo.

echo [INFO] Platform is ready! 🎉
echo.
echo [WARN] To stop all services, close the individual service windows or run stop-all.bat
echo.

pause