<#
.SYNOPSIS
    Builds the Kaya Sync Daemon MSI installer.

.DESCRIPTION
    This script builds the Rust binary and then creates an MSI installer
    using the WiX Toolset.

.NOTES
    Requirements:
    - Rust toolchain with x86_64-pc-windows-msvc target
    - .NET SDK 6.0+
    - WiX Toolset v4 (installed via dotnet tool or SDK)
#>

$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
$ProjectDir = Split-Path $ScriptDir -Parent

Write-Host "Building Kaya Sync Daemon (Release)..." -ForegroundColor Cyan
Push-Location $ProjectDir
try {
    cargo build --release --target x86_64-pc-windows-msvc
    if ($LASTEXITCODE -ne 0) {
        throw "Cargo build failed"
    }
} finally {
    Pop-Location
}

Write-Host "Building MSI installer..." -ForegroundColor Cyan
Push-Location $ScriptDir
try {
    # Set paths for WiX
    $BinaryPath = Join-Path $ProjectDir "target\x86_64-pc-windows-msvc\release"
    $ManifestPath = Join-Path $ProjectDir "manifests"

    dotnet build -c Release -p:BinaryPath="$BinaryPath" -p:ManifestPath="$ManifestPath"
    if ($LASTEXITCODE -ne 0) {
        throw "WiX build failed"
    }
} finally {
    Pop-Location
}

$MsiPath = Join-Path $ScriptDir "bin\Release\Kaya.Installer.msi"
if (Test-Path $MsiPath) {
    Write-Host ""
    Write-Host "Build successful!" -ForegroundColor Green
    Write-Host "Installer created at: $MsiPath" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "Build completed but MSI not found at expected location." -ForegroundColor Yellow
    Write-Host "Check the bin directory for output files." -ForegroundColor Yellow
}
