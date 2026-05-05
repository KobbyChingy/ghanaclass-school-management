# Flutter PATH Fix Script
# This script adds Flutter to your PATH for the current PowerShell session

Write-Host "Adding Flutter to PATH..." -ForegroundColor Green

# Add Flutter to PATH for this session
$env:PATH = "c:\flutter\bin;$env:PATH"

Write-Host "✓ Flutter added to PATH for this session" -ForegroundColor Green
Write-Host ""
Write-Host "Testing Flutter..." -ForegroundColor Cyan
flutter --version

Write-Host ""
Write-Host "You can now use Flutter commands in this PowerShell window!" -ForegroundColor Green
Write-Host ""
Write-Host "To make this permanent, add Flutter to your System PATH:" -ForegroundColor Yellow
Write-Host "1. Press Win + X and select 'System'" -ForegroundColor Yellow
Write-Host "2. Click 'Advanced system settings'" -ForegroundColor Yellow
Write-Host "3. Click 'Environment Variables'" -ForegroundColor Yellow
Write-Host "4. Under 'User variables', select 'Path' and click 'Edit'" -ForegroundColor Yellow
Write-Host "5. Click 'New' and add: c:\Users\ENOCH\Desktop\flutter\bin" -ForegroundColor Yellow
Write-Host "6. Click 'OK' on all dialogs" -ForegroundColor Yellow
