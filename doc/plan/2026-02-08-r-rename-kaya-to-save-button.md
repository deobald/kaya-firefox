# Plan: Rename "Kaya" to "Save Button" in All User-Facing Locations

## Context

The user-facing product name is changing from "Kaya" to "Save Button". Internal references (`~/.kaya/`, variable names, log messages, documentation) remain unchanged. The gecko ID, native messaging application name, and manifest filename also change to the new `org.savebutton` namespace.

## Decided Details

- Action verb phrasing for toolbar/context menus: **"Add to Save Button"**
- Default server URL changes from `https://kaya.town` to **`https://savebutton.com`**
- `homepage_url` in manifest changes to **`https://savebutton.com`**
- MSI installer filename changes to **`SaveButton.Installer.msi`**

## Naming Mapping

| Old | New |
|-----|-----|
| `Kaya` (user-facing name) | `Save Button` |
| `ca.deobald.Kaya@deobald.ca` (gecko ID) | `org.savebutton@savebutton.org` |
| `ca.deobald.Kaya.nativehost` (app name) | `org.savebutton.nativehost` |
| `ca.deobald.Kaya.nativehost.json` (manifest file) | `org.savebutton.nativehost.json` |
| `https://kaya.town` (default server URL) | `https://savebutton.com` |
| `homepage_url` | `https://savebutton.com` |
| `Save to Kaya` (action text) | `Add to Save Button` |
| `Kaya.Installer.msi` | `SaveButton.Installer.msi` |
| `~/.kaya/` (data directory) | *unchanged* |
| `kaya-sync-daemon` (binary name) | *unchanged* |

## Changes by File

### 1. `extension/manifest.json`
- `"name": "Kaya"` → `"name": "Save Button"`
- `"description": "Save bookmarks, quotes, and images to Kaya"` → `"description": "Save bookmarks, quotes, and images with Save Button"`
- `"homepage_url": "https://kaya.town"` → `"homepage_url": "https://savebutton.com"`
- `"id": "ca.deobald.Kaya@deobald.ca"` → `"id": "org.savebutton@savebutton.org"`
- `"default_title": "Save to Kaya"` → `"default_title": "Add to Save Button"`

### 2. `extension/background.js`
- `NATIVE_HOST_NAME = 'ca.deobald.Kaya.nativehost'` → `'org.savebutton.nativehost'`
- Context menu `title: 'Save to Kaya'` (×2) → `'Add to Save Button'`
- `showNotification('Text saved to Kaya')` → `'Text added to Save Button'`
- `showNotification('Image saved to Kaya')` → `'Image added to Save Button'`
- `title: 'Kaya'` (notification title) → `'Save Button'`

### 3. `extension/popup/popup.html`
- `<h2>Welcome to Kaya</h2>` → `<h2>Welcome to Save Button</h2>`
- `"Enter your Kaya server details"` → `"Enter your Save Button server details"`
- `<label>Kaya Server</label>` → `<label>Save Button Server</label>`
- `placeholder="https://kaya.town"` → `placeholder="https://savebutton.com"`

### 4. `extension/popup/popup.js`
- `"https://kaya.town"` (×2, default values) → `"https://savebutton.com"`

### 5. `extension/options/options.html`
- `<title>Kaya Preferences</title>` → `<title>Save Button Preferences</title>`
- `<h1>Kaya Preferences</h1>` → `<h1>Save Button Preferences</h1>`
- `<label>Kaya Server</label>` → `<label>Save Button Server</label>`
- `placeholder="https://kaya.town"` → `placeholder="https://savebutton.com"`
- `"The URL of your Kaya server"` → `"The URL of your Save Button server"`

### 6. `extension/options/options.js`
- `'https://kaya.town'` (×3, default values) → `'https://savebutton.com'`

### 7. Native messaging manifests (rename files + update contents)

Rename files:
- `sync-daemon/manifests/ca.deobald.Kaya.nativehost.json` → `org.savebutton.nativehost.json`
- `sync-daemon/manifests/ca.deobald.Kaya.nativehost.linux.json` → `org.savebutton.nativehost.linux.json`
- `sync-daemon/manifests/ca.deobald.Kaya.nativehost.macos.json` → `org.savebutton.nativehost.macos.json`
- `sync-daemon/manifests/ca.deobald.Kaya.nativehost.windows.json` → `org.savebutton.nativehost.windows.json`

In each file:
- `"name": "ca.deobald.Kaya.nativehost"` → `"name": "org.savebutton.nativehost"`
- `"description": "Kaya Sync Daemon..."` → `"Save Button Sync Daemon..."`
- `"allowed_extensions": ["ca.deobald.Kaya@deobald.ca"]` → `["org.savebutton@savebutton.org"]`

### 8. `sync-daemon/install.sh`
- `MANIFEST_NAME="ca.deobald.Kaya.nativehost.json"` → `"org.savebutton.nativehost.json"`
- `echo "Building Kaya Sync Daemon..."` → `"Building Save Button Sync Daemon..."`
- `MANIFEST_SRC="manifests/ca.deobald.Kaya.nativehost.macos.json"` → `"manifests/org.savebutton.nativehost.macos.json"`
- `MANIFEST_SRC="manifests/ca.deobald.Kaya.nativehost.linux.json"` → `"manifests/org.savebutton.nativehost.linux.json"`
- `"Configure the extension with your Kaya server credentials"` → `"...Save Button server credentials"`

### 9. `sync-daemon/install.ps1`
- `$ManifestName = "ca.deobald.Kaya.nativehost"` → `"org.savebutton.nativehost"`
- `$InstallDir = "$env:ProgramFiles\Kaya"` → `"$env:ProgramFiles\Save Button"`
- All `Write-Host` strings: `"Kaya Sync Daemon"` → `"Save Button Sync Daemon"`, etc.
- `"manifests\ca.deobald.Kaya.nativehost.windows.json"` → `"manifests\org.savebutton.nativehost.windows.json"`
- `"ca.deobald.Kaya.nativehost.json"` → `"org.savebutton.nativehost.json"`
- `"Configure the extension with your Kaya server credentials"` → `"...Save Button server credentials"`

### 10. `sync-daemon/uninstall.ps1`
- `$ManifestName = "ca.deobald.Kaya.nativehost"` → `"org.savebutton.nativehost"`
- `$InstallDir = "$env:ProgramFiles\Kaya"` → `"$env:ProgramFiles\Save Button"`
- `"Uninstalling Kaya Sync Daemon..."` → `"Uninstalling Save Button Sync Daemon..."`
- `"remove all Kaya data"` → `"remove all Save Button data"`

### 11. `sync-daemon/installer/build.ps1`
- `"Building Kaya Sync Daemon (Release)..."` → `"Building Save Button Sync Daemon (Release)..."`
- MSI output path: `Kaya.Installer.msi` → `SaveButton.Installer.msi`

### 12. `sync-daemon/installer/Package.wxs`
- `Name="Kaya Sync Daemon"` (product name) → `"Save Button Sync Daemon"`
- `Description="Kaya Sync Daemon..."` → `"Save Button Sync Daemon..."`
- `Name="Kaya"` (installation folder) → `"Save Button"`
- `ca.deobald.Kaya.nativehost` references → `org.savebutton.nativehost`
- `Feature Title="Kaya Sync Daemon"` → `"Save Button Sync Daemon"`

### Not Changed

These remain as-is:
- `~/.kaya/` and `%USERPROFILE%\.kaya` directory paths
- Internal Rust code: `Cargo.toml` package name (`kaya-sync-daemon`), log messages, variable names
- `CLAUDE.md`, `AGENTS.md`, `README.md`, ADRs, and other documentation
- Binary name `kaya-sync-daemon` / `kaya-sync-daemon.exe`
