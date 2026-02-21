# Fix: Downloaded anga/meta filenames should retain URL-encoding

## Problem

When the sync daemon downloads files from the server, it URL-decodes the filenames from the server listing before saving to disk. For example, `2025-01-01T120000-India%20Income%20Tax.pdf` becomes `2025-01-01T120000-India Income Tax.pdf` on disk.

This causes two problems:

1. Filenames with spaces are created locally, which is undesirable.
2. The decoded local filename never matches the server's URL-encoded listing on subsequent syncs, so the file is re-uploaded every 60 seconds in an infinite loop (getting a 409 CONFLICT each time).

## Root cause

In `sync_anga()` and `sync_meta()`, the server file listing is decoded:

```rust
.map(|l| urlencoding::decode(l.trim()).unwrap_or_default().to_string())
```

This decodes `%20` to spaces, `%2C` to commas, etc. The decoded names are then used for disk storage and for set-difference comparison with local files.

## Fix

Remove the `urlencoding::decode()` call from the server listing parsing in both `sync_anga()` and `sync_meta()`. Keep the filenames exactly as the server returns them (URL-encoded). This means:

- Files are stored on disk with URL-encoded names (e.g. `India%20Income%20Tax.pdf`)
- The set comparison between server and local files works correctly
- Download URLs use the filename as-is (already encoded) — so `download_anga`/`download_meta` must NOT re-encode the filename
- Upload URLs continue to use `urlencoding::encode()` since locally-created files (bookmarks, quotes) have no encoding in their names

### Changes

1. **`sync_anga()`**: Remove `urlencoding::decode()` from server listing. Just trim whitespace.
2. **`sync_meta()`**: Same.
3. **`download_anga()`**: Don't re-encode filename in URL (it's already encoded from the server listing).
4. **`download_meta()`**: Same.

### Unit tests

- Test that parsing a server listing preserves URL-encoded filenames.
- Test that a download function uses the filename as-is on disk (no decoding).

## Files changed

- `sync-daemon/src/main.rs`
