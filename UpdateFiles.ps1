param(
    [string]$GistURL = ""
)

$ErrorActionPreference = "Stop"

# Default Gist URL for version.json
$DefaultGistURL = "https://gist.githubusercontent.com/MaleK11-glitch/ba3b32f309441438edc7ae6d91a60edf/raw/version.json"

if (-not [string]::IsNullOrWhiteSpace($GistURL)) {
    $DefaultGistURL = $GistURL
}

$UpdateDir = "C:\Users\MaleK\AppData\Local\KINGDOM-CO_UPDATE"
$VersionPassphrase = "K1ngd0m&C0_M3mu_Aut0!2026#Rok"
$VersionSalt = [Text.Encoding]::UTF8.GetBytes("RokSalt2026!")

function Get-VersionDll($dllFile) {
    if (-not (Test-Path $dllFile)) { return $null }
    try {
        $dllBytes = [IO.File]::ReadAllBytes($dllFile)
        if ($dllBytes.Length -le 16) { 
            $text = [Text.Encoding]::UTF8.GetString($dllBytes).Trim().Trim([char]0xFEFF)
            if ($text -match '^[vV]?\d+(\.\d+)*$') { return $text }
            return $null
        }
        $keyGen = New-Object Security.Cryptography.Rfc2898DeriveBytes($VersionPassphrase, $VersionSalt, 10000, [Security.Cryptography.HashAlgorithmName]::SHA256)
        $aes = [Security.Cryptography.Aes]::Create()
        $aes.Key = $keyGen.GetBytes(32)
        $aes.IV = $dllBytes[0..15]
        $decryptor = $aes.CreateDecryptor()
        $cipher = $dllBytes[16..($dllBytes.Length - 1)]
        $plainText = $decryptor.TransformFinalBlock($cipher, 0, $cipher.Length)
        return [Text.Encoding]::UTF8.GetString($plainText).Trim().Trim([char]0xFEFF)
    } catch { return $null }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$localDll = Join-Path $scriptDir "version.dll"
$localTxt = Join-Path $scriptDir "version.txt"
$localVersion = "0.0"

if (Test-Path $localDll) {
    $dllVer = Get-VersionDll $localDll
    if ($dllVer) { $localVersion = $dllVer }
}
if (($localVersion -eq "0.0" -or [string]::IsNullOrWhiteSpace($dllVer)) -and (Test-Path $localTxt)) {
    $localVersion = (Get-Content $localTxt -Raw).Trim().Trim([char]0xFEFF)
}

Write-Host "KINGDOM BOTS & CO - Checking for updates..." -NoNewline

$isLocal = $DefaultGistURL -like "file:*" -or $DefaultGistURL -like "\\*" -or (Test-Path $DefaultGistURL -ErrorAction SilentlyContinue)

try {
    if ($isLocal) {
        $cleanPath = $DefaultGistURL -replace '^file:///', '' -replace '^file://', '' -replace '/', '\'
        $jsonText = (Get-Content $cleanPath -Raw -ErrorAction Stop).Trim()
    } else {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $uniqueUrl = $DefaultGistURL + "?t=" + [DateTime]::UtcNow.Ticks
        $jsonText = (Invoke-WebRequest -Uri $uniqueUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop).Content.Trim()
    }
    
    $json = $jsonText | ConvertFrom-Json -ErrorAction Stop
    $remoteVersion = $json.version
    $downloadUrl = $json.download_url
} catch {
    Write-Host " SKIP (No Internet Connection / Update Info Not Found)" -ForegroundColor DarkGray
    exit 0
}

# Normalize versions for comparison (strip leading 'v' or 'V')
$cleanLocal = $localVersion.ToLower().TrimStart('v')
$cleanRemote = $remoteVersion.ToLower().TrimStart('v')

$needsUpdate = $false
try {
    if ([version]$cleanRemote -gt [version]$cleanLocal) {
        $needsUpdate = $true
    }
} catch {
    # Fallback to string comparison if version parsing fails
    if ($cleanRemote -ne $cleanLocal) {
        $needsUpdate = $true
    }
}

if (-not $needsUpdate) {
    Write-Host " OK (v$localVersion)" -ForegroundColor Green
    exit 0
}

Write-Host " UPDATE AVAILABLE: $localVersion -> $remoteVersion" -ForegroundColor Yellow
Write-Host ""

$response = ""
while ($response -notmatch '^[yn]$') {
    $response = Read-Host " [?] هل تريد تنزيل وتثبيت التحديث الجديد؟ Do you want to update? (Y/N)"
    $response = $response.Trim().ToLower()
}

if ($response -eq 'n') {
    Write-Host ""
    Write-Host " Skipping update. Starting application..." -ForegroundColor Yellow
    Start-Sleep 1
    exit 0
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "Downloading Installer v$remoteVersion..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""

$tempUpdateDir = Join-Path $env:TEMP "rok_installer_temp"
if (Test-Path $tempUpdateDir) { Remove-Item $tempUpdateDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $tempUpdateDir -Force | Out-Null

$installerName = "KINGDOM_CO_Installer_RoK_Update.exe"
$tempDest = Join-Path $tempUpdateDir $installerName

try {
    Write-Host "  Downloading installer from $downloadUrl..." -ForegroundColor Cyan
    if ($downloadUrl -like "file:*" -or $downloadUrl -like "\\*" -or (Test-Path $downloadUrl -ErrorAction SilentlyContinue)) {
        $cleanSrc = $downloadUrl -replace '^file:///', '' -replace '^file://', '' -replace '/', '\'
        Copy-Item $cleanSrc $tempDest -Force
    } else {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempDest -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop
    }
    Write-Host "  Download complete!" -ForegroundColor Green
} catch {
    Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Remove-Item $tempUpdateDir -Recurse -Force -ErrorAction SilentlyContinue
    Start-Sleep 3
    exit 1
}
$localInstaller = Join-Path $scriptDir "KINGDOM CO Installer RoK.exe"
$runPath = $localInstaller

try {
    Write-Host "  Updating local installer executable..." -ForegroundColor Cyan
    Copy-Item $tempDest $localInstaller -Force -ErrorAction Stop
    Write-Host "  Local installer updated successfully." -ForegroundColor Green
} catch {
    Write-Host "  Warning: Could not overwrite '$localInstaller'. It might be in use." -ForegroundColor Yellow
    Write-Host "  Proceeding with temporary installer..." -ForegroundColor Yellow
    $runPath = $tempDest
}

Write-Host ""
Write-Host "Launching installer..." -ForegroundColor Yellow
Write-Host "This application will now exit to allow the installer to overwrite files." -ForegroundColor Cyan
Start-Sleep 2

# Write a helper post-install script to update local version files to the remote version once the installer exits
$postInstallScript = Join-Path $tempUpdateDir "post_install.ps1"
$postInstallContent = @"
`$ErrorActionPreference = "Stop"
Start-Sleep -Seconds 2
try {
    `$proc = Start-Process -FilePath "$runPath" -PassThru
    `$proc.WaitForExit()
} catch {
    exit 1
}

`$VersionPassphrase = "K1ngd0m&C0_M3mu_Aut0!2026#Rok"
`$VersionSalt = [Text.Encoding]::UTF8.GetBytes("RokSalt2026!")

function Write-VersionDll(`$dllFile, `$Version) {
    try {
        `$keyGen = New-Object Security.Cryptography.Rfc2898DeriveBytes(`$VersionPassphrase, `$VersionSalt, 10000, [Security.Cryptography.HashAlgorithmName]::SHA256)
        `$aes = [Security.Cryptography.Aes]::Create()
        `$aes.Key = `$keyGen.GetBytes(32)
        `$aes.GenerateIV()
        `$encryptor = `$aes.CreateEncryptor()
        `$plainBytes = [Text.Encoding]::UTF8.GetBytes(`$Version)
        `$cipherBytes = `$encryptor.TransformFinalBlock(`$plainBytes, 0, `$plainBytes.Length)
        `$dllBytes = `$aes.IV + `$cipherBytes
        [IO.File]::WriteAllBytes(`$dllFile, `$dllBytes)
        return `$true
    } catch { return `$false }
}

# Write version.txt
"$cleanRemote" | Out-File "$localTxt" -Encoding UTF8 -NoNewline

# Write version.dll
Write-VersionDll "$localDll" "$cleanRemote"

# Synchronize with AppData Update Directory
`$UpdateDir = "C:\Users\MaleK\AppData\Local\KINGDOM-CO_UPDATE"
if (-not (Test-Path `$UpdateDir)) { New-Item -ItemType Directory -Path `$UpdateDir -Force | Out-Null }
`$appDataDll = Join-Path `$UpdateDir "KingdomCo.Engine.dll"
`$appDataVersion = Join-Path `$UpdateDir "version.dll"

if (Test-Path "$scriptDir\KingdomCo.Engine.dll") {
    Copy-Item "$scriptDir\KingdomCo.Engine.dll" `$appDataDll -Force -ErrorAction SilentlyContinue
}
Copy-Item "$localDll" `$appDataVersion -Force -ErrorAction SilentlyContinue
"@

$postInstallContent | Out-File $postInstallScript -Encoding UTF8

# Start the post-install helper script in a hidden PowerShell background process
Start-Process -FilePath "powershell.exe" -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$postInstallScript`""

# Exit with code 2 to tell Start.bat to terminate
exit 2
