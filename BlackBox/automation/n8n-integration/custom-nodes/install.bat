@echo off
echo 🚀 Installing Allixios Custom n8n Nodes...

REM Check if npm is available
where npm >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ npm is not installed. Please install Node.js first.
    exit /b 1
)

REM Install dependencies
echo 📦 Installing dependencies...
call npm install

REM Build TypeScript files
echo 🔨 Building TypeScript files...
call npm run build

REM Create n8n custom nodes directory
set N8N_CUSTOM_DIR=%USERPROFILE%\.n8n\custom
if not exist "%N8N_CUSTOM_DIR%" mkdir "%N8N_CUSTOM_DIR%"

REM Copy built files to n8n custom directory
echo 📁 Copying files to n8n custom directory...
copy dist\*.js "%N8N_CUSTOM_DIR%\"
copy package.json "%N8N_CUSTOM_DIR%\"

echo ✅ Installation complete!
echo.
echo 📋 Next steps:
echo 1. Restart your n8n instance
echo 2. The Allixios nodes will appear in the 'Allixios' category
echo 3. Configure your Supabase credentials in the nodes
echo.
echo 🔧 Available nodes:
echo    - Allixios Content Generator
echo    - Allixios SEO Analyzer
echo    - Allixios Analytics Processor
echo    - Allixios Workflow Monitor

pause