#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Uninstalls the Save Button Sync Daemon from Windows.

.DESCRIPTION
    This script removes the Save Button Sync Daemon binary, native messaging manifest,
    and registry entries. It does NOT remove user data in ~/.kaya.

.NOTES
    Requires Administrator privileges.
#>

$ErrorActionPreference = "Stop"

$BinaryName = "savebutton-sync-daemon.exe"
$ManifestName = "org.savebutton.nativehost"
$InstallDir = "$env:ProgramFiles\Save Button"

Write-Host "Uninstalling Save Button Sync Daemon..." -ForegroundColor Cyan

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
Write-Host "Delete it manually if you want to remove all Save Button data." -ForegroundColor Yellow
