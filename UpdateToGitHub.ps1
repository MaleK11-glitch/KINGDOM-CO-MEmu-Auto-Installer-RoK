# ============================================
# KINGDOM CO - Upload Update to GitHub
# ============================================

$repo = "MaleK11-glitch/KINGDOM-CO-MEmu-Auto-Installer-RoK"
$tokenFile = Join-Path $env:TEMP "kc_github_token.txt"

# Get token
if (Test-Path $tokenFile) {
    $token = Get-Content $tokenFile -Raw
} else {
    Write-Host ""
    Write-Host "  ============================================" -Fore Cyan
    Write-Host "    KINGDOM CO - Upload Update to GitHub" -Fore Cyan
    Write-Host "  ============================================" -Fore Cyan
    Write-Host ""
    $token = Read-Host "  Enter GitHub token"
    $token | Out-File $tokenFile -Force
    Write-Host "  Token saved." -Fore Green
}

$headers = @{ Authorization = "token $token"; Accept = "application/vnd.github+json" }

# Get current version from GitHub
Write-Host ""
Write-Host "  Checking latest version on GitHub..." -Fore Yellow
try {
    $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers -ErrorAction Stop
    $currentVer = $latest.tag_name
    Write-Host "  Current version: $currentVer" -Fore Green
} catch {
    $currentVer = "v0.0.0"
    Write-Host "  No releases found. Starting from v0.0.0" -Fore Yellow
}

# Ask for new version
Write-Host ""
Write-Host "  Available versions:" -Fore Cyan
Write-Host "    v2.1 (patch)" -Fore Gray
Write-Host "    v3.0 (major)" -Fore Gray
Write-Host "    (or type custom version)" -Fore Gray
Write-Host ""
$newVer = Read-Host "  Enter new version (current: $currentVer)"

if (-not $newVer.StartsWith("v")) { $newVer = "v$newVer" }

# Confirm
Write-Host ""
Write-Host "  Upgrade: $currentVer -> $newVer" -Fore Yellow
$confirm = Read-Host "  Confirm? (y/n)"
if ($confirm -ne "y") {
    Write-Host "  Cancelled." -Fore Red
    exit
}

# Ask for file path
Write-Host ""
Write-Host "  Enter path to KINGDOM CO Installer RoK.exe:" -Fore Cyan
Write-Host "  (or drag and drop the file here)" -Fore Gray
Write-Host ""
$exePath = Read-Host "  Path"

# Clean path (remove quotes)
$exePath = $exePath.Trim('"').Trim("'")

if (-not (Test-Path $exePath)) {
    Write-Host "  File not found: $exePath" -Fore Red
    exit
}

$fileSize = [math]::Round((Get-Item $exePath).Length / 1MB, 1)
Write-Host "  File: $([System.IO.Path]::GetFileName($exePath)) ($fileSize MB)" -Fore Green

# Create release
Write-Host ""
Write-Host "  Creating release $newVer..." -Fore Yellow
$body = @{
    tag_name = $newVer
    name = "KINGDOM CO Installer RoK $newVer"
    body = "KINGDOM CO Installer RoK $newVer - Auto-update enabled"
    draft = $false
    prerelease = $false
} | ConvertTo-Json

try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases" -Method Post -Body $body -ContentType "application/json" -Headers $headers
    Write-Host "  Release created!" -Fore Green
    Write-Host "  URL: $($release.html_url)" -Fore Cyan
} catch {
    Write-Host "  Failed to create release: $($_.Exception.Message)" -Fore Red
    exit 1
}

# Upload file
Write-Host ""
Write-Host "  Uploading $fileSize MB..." -Fore Yellow
$exeBytes = [IO.File]::ReadAllBytes($exePath)
$fileName = [System.IO.Path]::GetFileName($exePath) -replace '\s', '+'
$uploadUri = "https://uploads.github.com/repos/$repo/releases/$($release.id)/assets?name=$fileName"

try {
    $asset = Invoke-RestMethod -Uri $uploadUri -Method Post -Body $exeBytes -ContentType "application/octet-stream" -Headers $headers
    Write-Host "  Upload complete!" -Fore Green
    Write-Host "  Download: $($asset.browser_download_url)" -Fore Cyan
} catch {
    Write-Host "  Upload failed: $($_.Exception.Message)" -Fore Red
    exit 1
}

Write-Host ""
Write-Host "  ============================================" -Fore Green
Write-Host "    DONE! Version $newVer is now live." -Fore Green
Write-Host "    Users will auto-update on next launch." -Fore Green
Write-Host "  ============================================" -Fore Green
Write-Host ""
