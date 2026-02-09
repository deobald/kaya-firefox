# Kaya Firefox Extension

A Firefox browser extension and native sync daemon for saving bookmarks, quotes, and images to Kaya.

## Components

- `/extension` - Firefox browser extension
- `/sync-daemon` - Native Rust sync daemon

## Installation

### 1. Build and Install the Native Daemon

Requirements: Rust toolchain (rustup)

```bash
cd sync-daemon
./install.sh
```

This will:
- Build the Rust daemon
- Install the binary to `/usr/local/bin/kaya-sync-daemon`
- Install the native messaging manifest
- Create `~/.kaya/anga/` and `~/.kaya/meta/` directories

### 1.b Build the Firefox Extension locally (optional)

```
brew install web-ext
npm install -g web-ext
web-ext build --source-dir=extension/
```

### 2. Install the Firefox Extension

#### For Development

1. Open Firefox and navigate to `about:debugging`
2. Click "This Firefox" in the sidebar
3. Click "Load Temporary Add-on..."
4. Navigate to the `extension` folder and select `manifest.json`

#### For Production

Build and submit to addons.mozilla.org (see Extension Workshop docs). Automated in GitHub Actions, which kicks off with a new tag:

```
git tag v0.1.1
git push origin v0.1.1
```

## Usage

### Saving Bookmarks

Click the Kaya toolbar button to save the current page as a bookmark. A popup will appear allowing you to optionally add a note.

### Saving Text

Select text on any webpage, right-click, and choose "Save to Kaya" from the context menu.

### Saving Images

Right-click any image and choose "Save to Kaya" from the context menu.

### Configuration

Right-click the Kaya toolbar button and select "Preferences" to configure:
- Kaya Server URL (defaults to https://kaya.town)
- Email
- Password

## File Storage

All data is stored locally in `~/.kaya/`:

- `~/.kaya/anga/` - Bookmarks (.url), quotes (.md), and images
- `~/.kaya/meta/` - Metadata files (.toml) with notes and tags
- `~/.kaya/.config` - Configuration (password encrypted at rest)

## Sync

The daemon automatically syncs with the configured Kaya server every 60 seconds.

## Platform Support

- Linux: Tested
- macOS: Supported
- Windows: Manifest provided, installer not yet implemented

## Native Messaging Manifest Locations

- Linux: `~/.mozilla/native-messaging-hosts/ca.deobald.Kaya.nativehost.json`
- macOS: `~/Library/Application Support/Mozilla/NativeMessagingHosts/ca.deobald.Kaya.nativehost.json`
- Windows: Registry key pointing to manifest file
