# Fix: Native messaging manifest trailing comma causes NetworkError

## Problem

The Firefox extension shows "Connection failed: NetworkError when attempting to fetch resource" when attempting to communicate with the native sync daemon. The daemon itself is running and syncing with the server successfully — the problem is that Firefox cannot parse the native messaging manifest.

All four native messaging manifest files contain a trailing comma after the last JSON value, which is invalid strict JSON:

```json
{
  ...
  "allowed_extensions": ["org.savebutton@savebutton.org"],
}
```

Firefox requires strict JSON for native messaging manifests. When it fails to parse the manifest, `browser.runtime.connectNative()` fails with a NetworkError.

## Root cause

The Zed text editor (installed as Flatpak) was configured to treat all `*.json` files as JSONC via:

```json
"file_types": {
    "JSONC": ["*.json", "tsconfig*.json", ".eslintrc.json"],
}
```

JSONC permits trailing commas. The JSON language server's formatter added trailing commas on save, which are valid JSONC but invalid JSON. This setting has since been corrected to remove `"*.json"`, but a Zed restart may be required for the change to take effect.

## Plan

### 1. Remove trailing commas from all four manifest files

- `sync-daemon/manifests/org.savebutton.nativehost.json`
- `sync-daemon/manifests/org.savebutton.nativehost.linux.json`
- `sync-daemon/manifests/org.savebutton.nativehost.macos.json`
- `sync-daemon/manifests/org.savebutton.nativehost.windows.json`

### 2. Remove trailing comma from the installed manifest

- `~/.mozilla/native-messaging-hosts/org.savebutton.nativehost.json`

### 3. Verify Firefox can connect

After fixing the manifests and restarting Firefox (or reloading the extension), the "NetworkError" should be resolved.

## Files changed

- `sync-daemon/manifests/org.savebutton.nativehost.json`
- `sync-daemon/manifests/org.savebutton.nativehost.linux.json`
- `sync-daemon/manifests/org.savebutton.nativehost.macos.json`
- `sync-daemon/manifests/org.savebutton.nativehost.windows.json`
- `~/.mozilla/native-messaging-hosts/org.savebutton.nativehost.json` (installed copy)
