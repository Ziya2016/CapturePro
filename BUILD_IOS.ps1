###################################################################
## CAPTURE PRO — BUILD IOS APP AUTOMATION SCRIPT
## Run this script in PowerShell on Windows to build your iOS (.ipa) file
###################################################################

Write-Host "Starting Capture Pro iOS Build Process..." -ForegroundColor Cyan

# 1. Navigate to project directory
cd "E:\Google Antigravity\Capture Pro"

# 2. Stage all local changes
Write-Host "Staging local files..." -ForegroundColor Yellow
git add .

# 3. Create commit with timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
git commit -m "iOS Build update - $timestamp"

# 4. Ensure GitHub remote is set to Ziya2016/CapturePro
git remote set-url origin https://github.com/Ziya2016/CapturePro.git

# 5. Push to GitHub to trigger automated iOS build
Write-Host "Pushing code to GitHub Ziya2016/CapturePro..." -ForegroundColor Yellow
git push -u origin main

Write-Host ""
Write-Host "SUCCESS! Code pushed to GitHub successfully." -ForegroundColor Green
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Your iOS build is now running automatically on a cloud Mac!" -ForegroundColor Green
Write-Host "Track build status & download your CapturePro_iOS_IPA here:" -ForegroundColor Yellow
Write-Host "https://github.com/Ziya2016/CapturePro/actions" -ForegroundColor White
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
