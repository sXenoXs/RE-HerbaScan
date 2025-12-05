# Script to create and push v0.8.3-Fixes branch
# Run this script from PowerShell in the project directory

Write-Host "Creating branch v0.8.3-Fixes..." -ForegroundColor Green
git checkout -b v0.8.3-Fixes

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error creating branch. Trying to switch if it already exists..." -ForegroundColor Yellow
    git checkout v0.8.3-Fixes
}

Write-Host "Staging all changes..." -ForegroundColor Green
git add -A

Write-Host "Checking for changes to commit..." -ForegroundColor Green
$status = git status --short
if ($status) {
    Write-Host "Committing changes..." -ForegroundColor Green
    git commit -m "v0.8.3: Fixes and updates"
} else {
    Write-Host "No changes to commit." -ForegroundColor Yellow
}

Write-Host "Pushing branch to GitHub..." -ForegroundColor Green
git push -u origin v0.8.3-Fixes

if ($LASTEXITCODE -eq 0) {
    Write-Host "Success! Branch v0.8.3-Fixes has been pushed to GitHub." -ForegroundColor Green
} else {
    Write-Host "Error pushing branch. Please check:" -ForegroundColor Red
    Write-Host "1. Your GitHub credentials are configured" -ForegroundColor Red
    Write-Host "2. You have push access to the repository" -ForegroundColor Red
    Write-Host "3. Your internet connection is working" -ForegroundColor Red
}
