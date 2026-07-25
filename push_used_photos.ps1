# push_used_photos.ps1 — Push used-book photos to GitHub Pages
# Same pattern as push_b7o_covers.ps1 but for used-book-photos repo.
# Handles first-time repo init if needed.
#
# USAGE: Right-click > Run with PowerShell
#        or: powershell -File push_used_photos.ps1 batch-4.16

param([string]$BatchName)

$ErrorActionPreference = "Stop"
$photosDir = "$HOME\Claude\Projects\bm\used-book-photos"

Write-Host "`n=== BM: Push Used-Book Photos ===" -ForegroundColor Cyan

# Resolve batch name
if (-not $BatchName) {
    # Auto-detect: find batch-* folders that have SKU subfolders
    $batches = Get-ChildItem "$photosDir\batch-*" -Directory |
        Where-Object { (Get-ChildItem $_.FullName -Directory).Count -gt 0 } |
        Sort-Object Name
    if ($batches.Count -eq 0) {
        Write-Host "No batch folders found in $photosDir" -ForegroundColor Red
        pause; exit 1
    }
    Write-Host "Available batches:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $batches.Count; $i++) {
        $photoCount = (Get-ChildItem $batches[$i].FullName -Recurse -File -Filter "*.jpg").Count
        $skuCount = (Get-ChildItem $batches[$i].FullName -Directory).Count
        Write-Host "  [$($i+1)] $($batches[$i].Name) ($skuCount books, $photoCount photos)"
    }
    $choice = Read-Host "`nPush which batch? [1-$($batches.Count)]"
    $BatchName = $batches[[int]$choice - 1].Name
}

$batchDir = "$photosDir\$BatchName"
if (-not (Test-Path $batchDir)) {
    Write-Host "Batch folder not found: $batchDir" -ForegroundColor Red
    pause; exit 1
}

$photoCount = (Get-ChildItem $batchDir -Recurse -File -Filter "*.jpg").Count
$skuCount = (Get-ChildItem $batchDir -Directory).Count
Write-Host "Batch: $BatchName ($skuCount books, $photoCount photos)" -ForegroundColor Green

# 1. Init repo if needed
Set-Location $photosDir
if (-not (Test-Path ".git")) {
    Write-Host "`n[1/4] Initializing git repo..." -ForegroundColor Yellow
    git init
    git branch -M main

    # .gitignore: exclude raw photos, temp files, scripts
    @"
# Raw photo folders (originals before processing)
[0-9].[0-9]*/

# Archives
*.tar

# Contact sheets and thumbnails
contact_*.jpg
thumbs_*.json

# Processing scripts
process_batch.py
"@ | Set-Content -Path ".gitignore" -Encoding UTF8
    git add .gitignore
    git commit -m "init: add .gitignore"

    # Create GitHub repo via gh CLI
    $hasGh = Get-Command gh -ErrorAction SilentlyContinue
    if ($hasGh) {
        gh repo create barneyeatscelery/used-book-photos --public --source=. --remote=origin
    } else {
        Write-Host "  Create repo manually: https://github.com/new" -ForegroundColor Yellow
        Write-Host "  Name: used-book-photos, Public, empty (no README)" -ForegroundColor White
        Read-Host "  Press Enter after creating"
        git remote add origin https://github.com/barneyeatscelery/used-book-photos.git
    }
    Write-Host "  Repo initialized." -ForegroundColor Green
} else {
    Write-Host "`n[1/4] Git repo already initialized." -ForegroundColor Green
}

# 2. Add batch photos
Write-Host "`n[2/4] Adding $BatchName photos..." -ForegroundColor Yellow
git add "$BatchName/"
$status = git status --porcelain
if ($status) {
    git commit -m "add $BatchName`: $skuCount used books, $photoCount photos"
    Write-Host "  Committed." -ForegroundColor Green
} else {
    Write-Host "  No changes to commit." -ForegroundColor Green
}

# 3. Push
Write-Host "`n[3/4] Pushing to GitHub..." -ForegroundColor Yellow
git push -u origin main

# 4. GitHub Pages reminder (first time only)
$pagesUrl = "https://barneyeatscelery.github.io/used-book-photos"
Write-Host "`n[4/4] Checking GitHub Pages..." -ForegroundColor Yellow
$hasGh = Get-Command gh -ErrorAction SilentlyContinue
if ($hasGh) {
    $pages = gh api repos/barneyeatscelery/used-book-photos/pages 2>$null
    if ($pages) {
        Write-Host "  Pages already enabled." -ForegroundColor Green
    } else {
        Write-Host "  Enable Pages: https://github.com/barneyeatscelery/used-book-photos/settings/pages" -ForegroundColor Yellow
        Write-Host "  Source: Deploy from branch, Branch: main, Folder: / (root)" -ForegroundColor White
    }
} else {
    Write-Host "  Verify Pages at: https://github.com/barneyeatscelery/used-book-photos/settings/pages" -ForegroundColor Yellow
}

Write-Host "`n=== Done! ===" -ForegroundColor Cyan
Write-Host "Base URL: $pagesUrl"
Write-Host "Example:  $pagesUrl/$BatchName/4.16-001/01.jpg`n" -ForegroundColor Green
pause
