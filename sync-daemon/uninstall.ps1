#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Uninstalls the Kaya Sync Daemon from Windows.

.DESCRIPTION
    This script removes the Kaya Sync Daemon binary, native messaging manifest,
    and registry entries. It does NOT remove user data in ~/.kaya.

.NOTES
    Requires Administrator privileges.
#>

$ErrorActionPreference = "Stop"

$BinaryName = "kaya-sync-daemon.exe"
$ManifestName = "ca.deobald.Kaya.nativehost"
$InstallDir = "$env:ProgramFiles\Kaya"

Write-Host "Uninstalling Kaya Sync Daemon..." -ForegroundColor Cyan

# Remove registry entry
Write-Host "Removing registry entry..." -ForegroundColor Cyan
$RegistryPath = "HKLM:\SOFTWARE\Mozilla\NativeMessagingHosts\$ManifestName"
if (Test-Path $RegistryPath) {
    Remove-Item -Path $RegistryPath -Recurse -Force
    Write-Host "  Registry key removed: $RegistryPath" -ForegroundColor Gray
} else {
    Write-Host "  Registry key not found (already removed)" -ForegroundColor Gray
}

# Remove installation directory
Write-Host "Removing installation directory..." -ForegroundColor Cyan
if (Test-Path $InstallDir) {
    Remove-Item -Path $InstallDir -Recurse -Force
    Write-Host "  Directory removed: $InstallDir" -ForegroundColor Gray
} else {
    Write-Host "  Directory not found (already removed)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Uninstallation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Note: User data in $env:USERPROFILE\.kaya was NOT removed." -ForegroundColor Yellow
Write-Host "Delete it manually if you want to remove all Kaya data." -ForegroundColor Yellow
