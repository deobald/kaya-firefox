# Fix: Avoid URL-incompatible characters in filenames during sync

**Prerequisite:** [2026-02-12-r-replace-logging-with-fern.md](./2026-02-12-r-replace-logging-with-fern.md) must be completed and committed first. This plan assumes `log` + `fern` are in place and per-file sync logging already exists.

## Problem

The sync daemon currently has no validation for URL-incompatible characters in filenames. This causes problems in two directions:

1. **Upload**: If a file in `~/.kaya/anga/` or `~/.kaya/meta/` has a filename with URL-incompatible characters (e.g. spaces), the daemon should refuse to upload it and log a warning instead.

2. **Download**: If the server index contains a filename that, when decoded, has URL-incompatible characters, the daemon should log a warning and skip the download rather than saving a file with problematic characters locally.

## Definition of "URL-compatible filename"

A filename is URL-compatible if it contains only characters that don't require percent-encoding in a URL path segment:

- Alphanumeric: `A-Z`, `a-z`, `0-9`
- Unreserved: `-`, `_`, `.`, `~`

The simplest check: `urlencoding::encode(filename) == filename`. If encoding changes the filename, it contains characters that aren't URL-safe.

## Plan

### 1. Add `is_url_safe_filename()` helper

```rust
fn is_url_safe_filename(filename: &str) -> bool {
    urlencoding::encode(filename) == filename
}
```

### 2. Validate filenames before download (anga and meta)

In the download loops of `sync_anga()` and `sync_meta()`, before calling `download_anga()` / `download_meta()`, check `is_url_safe_filename()`. If it fails, log a warning and skip:

```
Skipping download of anga file with URL-incompatible filename from server: "hello world.url"
```

Decrement the download count (or track actual transfers separately) so `Sync complete` reflects reality.

### 3. Validate filenames before upload (anga and meta)

In the upload loops of `sync_anga()` and `sync_meta()`, before calling `upload_anga()` / `upload_meta()`, check `is_url_safe_filename()`. If it fails, log a warning and skip:

```
Skipping upload of anga file with URL-incompatible filename: "hello world.url"
```

Same count adjustment.

### 4. Add error logging for failed downloads

The `download_anga()` and `download_meta()` functions currently silently ignore non-success HTTP responses. Add error logging for download failures, consistent with the existing upload failure logging:

```
Failed to download anga {filename}: {status}
```

## Files changed

- `sync-daemon/src/main.rs` — all changes

## Scope

- No new dependencies (uses existing `urlencoding` crate)
- No changes to the Firefox extension
- No changes to message formats
- No changes to upload/download HTTP mechanics, only filtering around them
