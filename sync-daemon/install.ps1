#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs the Save Button Sync Daemon on Windows.

.DESCRIPTION
    This script builds and installs the Save Button Sync Daemon native messaging host
    for the Firefox extension. It installs the binary to Program Files and
    registers the native messaging manifest in the Windows Registry.

.NOTES
    Requires Administrator privileges.
    Requires Rust/Cargo to be installed for building from source.
#>

$ErrorActionPreference = "Stop"

$BinaryName = "savebutton-sync-daemon.exe"
$ManifestName = "org.savebutton.nativehost"
$InstallDir = "$env:ProgramFiles\Save Button"
$KayaDataDir = "$env:USERPROFILE\.kaya"

Write-Host "Building Save Button Sync Daemon..." -ForegroundColor Cyan
Push-Location $PSScriptRoot
try {
    cargo build --release
    if ($LASTEXITCODE -ne 0) {
        throw "Cargo build failed"
    }
} finally {
    Pop-Location
}

Write-Host "Creating installation directory..." -ForegroundColor Cyan
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

Write-Host "Installing binary..." -ForegroundColor Cyan
$BinarySource = Join-Path $PSScriptRoot "target\release\$BinaryName"
$BinaryDest = Join-Path $InstallDir $BinaryName
Copy-Item -Path $BinarySource -Destination $BinaryDest -Force

Write-Host "Installing native messaging manifest..." -ForegroundColor Cyan
$ManifestSource = Join-Path $PSScriptRoot "manifests\org.savebutton.nativehost.windows.json"
$ManifestDest = Join-Path $InstallDir "org.savebutton.nativehost.json"
Copy-Item -Path $ManifestSource -Destination $ManifestDest -Force

Write-Host "Registering native messaging host in registry..." -ForegroundColor Cyan
$RegistryPath = "HKLM:\SOFTWARE\Mozilla\NativeMessagingHosts\$ManifestName"
if (-not (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
}
Set-ItemProperty -Path $RegistryPath -Name "(Default)" -Value $ManifestDest

Write-Host "Creating data directories..." -ForegroundColor Cyan
$AngaDir = Join-Path $KayaDataDir "anga"
$MetaDir = Join-Path $KayaDataDir "meta"
if (-not (Test-Path $AngaDir)) {
    New-Item -ItemType Directory -Path $AngaDir -Force | Out-Null
}
if (-not (Test-Path $MetaDir)) {
    New-Item -ItemType Directory -Path $MetaDir -Force | Out-Null
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Binary installed to: $BinaryDest" -ForegroundColor White
Write-Host "Manifest installed to: $ManifestDest" -ForegroundColor White
Write-Host "Registry key created: $RegistryPath" -ForegroundColor White
Write-Host "Data directory: $KayaDataDir" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Install the Firefox extension from about:debugging or addons.mozilla.org"
Write-Host "2. Configure the extension with your Save Button server credentials"
