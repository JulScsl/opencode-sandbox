@echo off
where pwsh >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: PowerShell not found. Please install PowerShell. >&2
    exit /b 1
)
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0opencode-sandbox.ps1" %*
