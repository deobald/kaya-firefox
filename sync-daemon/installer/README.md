# Kaya Sync Daemon Windows Installer

This directory contains the WiX v4 project for building an MSI installer for Windows 11+.

## Quick Install (from source)

If you just want to install from source without building an MSI:

```powershell
# Run as Administrator
.\install.ps1
```

To uninstall:

```powershell
# Run as Administrator
.\uninstall.ps1
```

## Building the MSI Installer

### Requirements

- Windows 11
- [Rust](https://rustup.rs/) with `x86_64-pc-windows-msvc` target
- [.NET SDK 6.0+](https://dotnet.microsoft.com/download)
- WiX Toolset v4 (automatically restored via NuGet)

### Build Steps

1. Open PowerShell in the `installer` directory
2. Run the build script:

```powershell
.\build.ps1
```

The MSI installer will be created at `installer\bin\Release\Kaya.Installer.msi`.

### Manual Build

If you prefer to build manually:

```powershell
# Build the Rust binary
cd sync-daemon
cargo build --release --target x86_64-pc-windows-msvc

# Build the MSI
cd installer
dotnet build -c Release
```

## What the Installer Does

1. Installs `kaya-sync-daemon.exe` to `C:\Program Files\Kaya\`
2. Installs the native messaging manifest JSON file
3. Creates a registry key at `HKLM\SOFTWARE\Mozilla\NativeMessagingHosts\ca.deobald.Kaya.nativehost`
4. Creates the `%USERPROFILE%\.kaya\anga` and `%USERPROFILE%\.kaya\meta` directories

## Uninstallation

The MSI can be uninstalled via:
- Windows Settings > Apps > Installed apps > Kaya Sync Daemon > Uninstall
- Control Panel > Programs > Uninstall a program
- Running `msiexec /x Kaya.Installer.msi`

Note: User data in `%USERPROFILE%\.kaya` is preserved during uninstallation.
