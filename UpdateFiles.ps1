param(
    [string]$BaseURL = ""
)

$ErrorActionPreference = "Stop"

$GitHubOwner = "MaleK11-glitch"
$GitHubRepo = "KINGDOM-CO-MEmu-Auto-Installer-RoK"
$GitHubBranch = "master"
$GitHubBase = "https://raw.githubusercontent.com/$GitHubOwner/$GitHubRepo/$GitHubBranch"

if (-not [string]::IsNullOrWhiteSpace($BaseURL)) {
    $GitHubBase = $BaseURL
}

$UpdateDir = "C:\Users\MaleK\AppData\Local\KINGDOM-CO_UPDATE"
$VersionPassphrase = "K1ngd0m&C0_M3mu_Aut0!2026#Rok"
$VersionSalt = [Text.Encoding]::UTF8.GetBytes("RokSalt2026!")

function Get-VersionDll($dllFile) {
    if (-not (Test-Path $dllFile)) { return $null }
    try {
        $dllBytes = [IO.File]::ReadAllBytes($dllFile)
        if ($dllBytes.Length -le 16) { 
            $text = [Text.Encoding]::UTF8.GetString($dllBytes).Trim()
            if ($text -match '^\d+(\.\d+)*$') { return $text }
            return $null
        }
        $keyGen = New-Object Security.Cryptography.Rfc2898DeriveBytes($VersionPassphrase, $VersionSalt, 10000, [Security.Cryptography.HashAlgorithmName]::SHA256)
        $aes = [Security.Cryptography.Aes]::Create()
        $aes.Key = $keyGen.GetBytes(32)
        $aes.IV = $dllBytes[0..15]
        $decryptor = $aes.CreateDecryptor()
        $cipher = $dllBytes[16..($dllBytes.Length - 1)]
        $plainText = $decryptor.TransformFinalBlock($cipher, 0, $cipher.Length)
        return [Text.Encoding]::UTF8.GetString($plainText).Trim()
    } catch { return $null }
}

function Write-VersionDll($dllFile, $Version) {
    try {
        $keyGen = New-Object Security.Cryptography.Rfc2898DeriveBytes($VersionPassphrase, $VersionSalt, 10000, [Security.Cryptography.HashAlgorithmName]::SHA256)
        $aes = [Security.Cryptography.Aes]::Create()
        $aes.Key = $keyGen.GetBytes(32)
        $aes.GenerateIV()
        $encryptor = $aes.CreateEncryptor()
        $plainBytes = [Text.Encoding]::UTF8.GetBytes($Version)
        $cipherBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)
        $dllBytes = $aes.IV + $cipherBytes
        [IO.File]::WriteAllBytes($dllFile, $dllBytes)
        return $true
    } catch { return $false }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$localDll = Join-Path $scriptDir "version.dll"
$localTxt = Join-Path $scriptDir "version.txt"
$localVersion = "0.0"

if (Test-Path $localDll) {
    $dllVer = Get-VersionDll $localDll
    if ($dllVer) { $localVersion = $dllVer }
} elseif (Test-Path $localTxt) {
    $localVersion = (Get-Content $localTxt -Raw).Trim()
}

Write-Host "KINGDOM BOTS & CO - Checking for updates..." -NoNewline

$isLocal = $GitHubBase -like "file:*" -or $GitHubBase -like "\\*" -or (Test-Path $GitHubBase -ErrorAction SilentlyContinue)

try {
    if ($isLocal) {
        $cleanPath = $GitHubBase -replace '^file:///', '' -replace '^file://', '' -replace '/', '\'
        $remoteVersion = (Get-Content (Join-Path $cleanPath "version.txt") -Raw -ErrorAction Stop).Trim()
    } else {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $remoteVersion = (Invoke-WebRequest -Uri "$GitHubBase/version.txt" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop).Content.Trim()
    }
} catch {
    Write-Host " SKIP (No Internet Connection / Repository Not Found)" -ForegroundColor DarkGray
    exit 0
}

if ($remoteVersion -eq $localVersion) {
    Write-Host " OK (v$localVersion)" -ForegroundColor Green
    exit 0
}

Write-Host " UPDATE AVAILABLE: $localVersion -> $remoteVersion" -ForegroundColor Yellow
Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "Downloading Update v$remoteVersion..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""

$filesToUpdate = @(
    "version.txt",
    "version.dll",
    "KingdomCo.Engine.dll",
    "KingROK.ps1",
    "Start.bat",
    "GnBots.ico"
)

$tempUpdateDir = Join-Path $env:TEMP "rok_update_temp"
if (Test-Path $tempUpdateDir) { Remove-Item $tempUpdateDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $tempUpdateDir -Force | Out-Null

$success = $true
foreach ($file in $filesToUpdate) {
    Write-Host "  Downloading $file..." -ForegroundColor Cyan -NoNewline
    try {
        $tempDest = Join-Path $tempUpdateDir $file
        if ($isLocal) {
            $cleanPath = $GitHubBase -replace '^file:///', '' -replace '^file://', '' -replace '/', '\'
            $srcFile = Join-Path $cleanPath $file
            if (Test-Path $srcFile) {
                Copy-Item $srcFile $tempDest -Force
                Write-Host " DONE" -ForegroundColor Green
            } else {
                throw "File not found: $srcFile"
            }
        } else {
            $url = "$GitHubBase/$file"
            Invoke-WebRequest -Uri $url -OutFile $tempDest -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
            Write-Host " DONE" -ForegroundColor Green
        }
    } catch {
        if ($file -eq "version.dll" -or $file -eq "GnBots.ico") {
            Write-Host " SKIPPED (Optional)" -ForegroundColor DarkGray
        } else {
            Write-Host " FAILED ($($_.Exception.Message))" -ForegroundColor Red
            $success = $false
        }
    }
}

if (-not $success) {
    Write-Host ""
    Write-Host "Update failed! Please check your network and try again." -ForegroundColor Red
    Start-Sleep 3
    exit 1
}

# Copy files to installation folder
Write-Host ""
Write-Host "Applying updates..." -ForegroundColor Cyan
foreach ($file in $filesToUpdate) {
    $tempDest = Join-Path $tempUpdateDir $file
    if (Test-Path $tempDest) {
        $realDest = Join-Path $scriptDir $file
        Copy-Item $tempDest $realDest -Force -ErrorAction SilentlyContinue
    }
}

# Generate/Update local version.dll (encrypted)
$versionDllPath = Join-Path $scriptDir "version.dll"
$dllOk = Write-VersionDll $versionDllPath $remoteVersion
if ($dllOk) {
    Write-Host "  Encrypted version.dll updated." -ForegroundColor Green
}

# Synchronize with AppData Update Directory
if (-not (Test-Path $UpdateDir)) { New-Item -ItemType Directory -Path $UpdateDir -Force | Out-Null }
$appDataDll = Join-Path $UpdateDir "KingdomCo.Engine.dll"
$appDataVersion = Join-Path $UpdateDir "version.dll"

if (Test-Path (Join-Path $scriptDir "KingdomCo.Engine.dll")) {
    Copy-Item (Join-Path $scriptDir "KingdomCo.Engine.dll") $appDataDll -Force -ErrorAction SilentlyContinue
}
Copy-Item $versionDllPath $appDataVersion -Force -ErrorAction SilentlyContinue

Write-Host "  AppData local cache synchronized." -ForegroundColor Green

# Cleanup
Remove-Item $tempUpdateDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Update applied successfully!" -ForegroundColor Green
Write-Host ""
Start-Sleep 2
