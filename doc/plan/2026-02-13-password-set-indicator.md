# Plan: Make it obvious when the password is set

## Problem

The password field in the Preferences page (`options.html`) is always empty, even if the user has previously saved a password. This is confusing because it looks like the password hasn't been configured. Additionally, clicking "Test Connection" requires re-entering the password every time, even though it's already saved.

The password is stored encrypted at rest by the Rust daemon in `~/.kaya/.config`. The extension never stores the password itself — it only sends it to the daemon via a `config` message. So the extension currently has no way to know whether a password has been set.

## Approach

Two changes work together:

1. The daemon reports whether a password is stored (via `config_status`), and the extension displays `"••••••••"` as the password field's **value** (not placeholder) when one is saved.
2. The daemon's `test_connection` handler falls back to stored credentials when the extension doesn't send them, so the user doesn't need to re-enter the password just to test.

### 1. Rust daemon: `config_status` message handler (already implemented)

Returns `has_password: true/false` indicating whether an encrypted password exists in `~/.kaya/.config`.

### 2. Rust daemon: `test_connection` falls back to stored credentials

When `server`, `email`, or `password` are missing from the incoming message, fall back to the values stored in `~/.kaya/.config` (decrypting the password as needed). This allows "Test Connection" to work without the user re-entering credentials.

### 3. Extension `options.js`: display bullets and use sentinel tracking

- On load, query `config_status`. If `has_password` is true, set the password field's **value** to `"••••••••"` and set a flag `passwordChanged = false`.
- When the user modifies the password field, set `passwordChanged = true`.
- **Test Connection**: If `passwordChanged` is false, send the `test_connection` message without a password (the daemon uses stored credentials). If true, send the user's new password.
- **Save**: If `passwordChanged` is false, skip sending a password in the config message (preserving the existing stored password). If true, send the new password. Also require the password field to be non-empty and not the sentinel when saving.

### 4. Extension `background.js`: `checkConfigStatus` action (already implemented)

Sends `{ "message": "config_status" }` to the native host and returns the response.

## Files changed

- `sync-daemon/src/main.rs` — `handle_test_connection()` falls back to stored config
- `extension/options/options.js` — sentinel tracking, adjusted save/test logic

## Decisions

1. Use `"••••••••"` (8 bullet characters) as the field value when a password is saved.
2. Skip the popup setup view — it only appears on first use before any config exists.
