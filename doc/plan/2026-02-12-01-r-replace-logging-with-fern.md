# Refactoring: Replace hand-rolled logging with `log` + `fern`

## Problem

The sync daemon uses a hand-rolled logging system: `log_message()`, `log_info()`, and `log_error()` functions that write to both stderr and `~/.kaya/log`. This works but only supports INFO and ERROR levels. We need WARN for upcoming filename validation work, and using the standard Rust logging toolchain is better practice.

## Plan

### 1. Add `log` and `fern` dependencies

Add to `sync-daemon/Cargo.toml`:

```toml
log = "0.4"
fern = "0.7"
```

- `log` — the standard Rust logging facade, providing `info!`, `warn!`, `error!`, `debug!`, `trace!` macros
- `fern` — lightweight logging backend supporting multiple simultaneous outputs (stderr + file)

### 2. Initialize `fern` in `main()`

Add a `setup_logging()` function that configures `fern` to:

- Dispatch to both stderr and the `~/.kaya/log` file (append mode)
- Format: `[%Y-%m-%dT%H:%M:%S%.3fZ] LEVEL: message` (matches existing format)
- Minimum level: `Info`

Call `setup_logging()` at the top of `main()`, before `ensure_directories()`. If `fern` setup fails (e.g. can't open the log file), fall back to stderr-only via `eprintln!` and continue.

### 3. Remove hand-rolled logging functions

Delete these functions from `main.rs`:
- `log_message()` (lines 23-35)
- `log_error()` (lines 37-39)
- `log_info()` (lines 41-43)
- `get_log_path()` (lines 19-21) — the path will be inlined in `setup_logging()`

### 4. Replace all call sites

Every `log_info(...)` becomes `log::info!(...)` and every `log_error(...)` becomes `log::error!(...)`. Specific call sites:

| Line | Old | New |
|------|-----|-----|
| 191 | `log_info(&format!("Received config..."))` | `log::info!("Received config...")` |
| 219 | `log_info(&format!("Received anga..."))` | `log::info!("Received anga...")` |
| 256 | `log_info(&format!("Received meta..."))` | `log::info!("Received meta...")` |
| 377 | `log_info(&format!("Sync complete..."))` | `log::info!("Sync complete...")` |
| 504 | `log_error(&format!("Failed to upload anga..."))` | `log::error!("Failed to upload anga...")` |
| 630 | `log_error(&format!("Failed to upload meta..."))` | `log::error!("Failed to upload meta...")` |
| 661 | `log_error(&format!("Failed to create directories..."))` | `log::error!("Failed to create directories...")` |
| 665 | `log_info("Kaya sync daemon started")` | `log::info!("Kaya sync daemon started")` |
| 673 | `log_error(&format!("Sync error..."))` | `log::error!("Sync error...")` |
| 714 | `log_error(&format!("Failed to write response..."))` | `log::error!("Failed to write response...")` |
| 719 | `log_info("Kaya sync daemon shutting down")` | `log::info!("Kaya sync daemon shutting down")` |
| 723 | `log_error(&format!("Error reading message..."))` | `log::error!("Error reading message...")` |

Note: `log::info!` and `log::error!` accept format args directly (`log::info!("foo {}", bar)`), so the `&format!(...)` wrappers can be removed.

### 5. Add per-file sync logging

In the `sync_anga()` and `sync_meta()` download/upload loops, log each filename before the network transfer:

```
  downloading anga: 2026-01-27T171207-www-deobald-ca.url
  uploading anga: 2026-02-12T143000-example-com.url
  downloading meta: 2026-01-27T171207-note.toml
  uploading meta: 2026-02-12T143000-note.toml
```

These lines appear naturally before the existing `Sync complete: N downloaded, M uploaded` summary.

## Files changed

- `sync-daemon/Cargo.toml` — add `log` and `fern` dependencies
- `sync-daemon/src/main.rs` — replace logging setup and all call sites

## Scope

- Pure refactoring: no behavior changes beyond gaining WARN/DEBUG/TRACE levels and per-file sync log lines
- No changes to the Firefox extension
- No changes to message formats or sync logic
