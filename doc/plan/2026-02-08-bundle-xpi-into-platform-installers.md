# Plan: Bundle Signed .xpi into Platform Installers

## Context

The `sign-extension` GitHub Actions workflow (`.github/workflows/sign-extension.yml`) already produces a signed unlisted `.xpi` as a build artifact. This plan adds a `build-installers` job that downloads that `.xpi` and bundles it into DEB, RPM, MSI, and PKG installers alongside the native sync daemon binary.

Currently, the MSI installer is built locally via `sync-daemon/installer/build.ps1` using WiX v4. There are no DEB, RPM, or PKG build scripts yet.

## What Each Installer Must Include

Every installer packages the same three things:

1. **The sync daemon binary** (`savebutton-sync-daemon` / `savebutton-sync-daemon.exe`)
2. **The native messaging manifest** (`org.savebutton.nativehost.json`, platform-specific variant)
3. **The signed `.xpi` extension file** (downloaded from the `sign-extension` job)

Each installer must also:
- Place the native messaging manifest where Firefox expects it (platform-specific location)
- Register the manifest (via registry on Windows, via file path on Linux/macOS)
- Create `~/.kaya/anga` and `~/.kaya/meta` directories (or equivalent)
- Open the `.xpi` in Firefox as a post-install step to prompt the user to install the extension

## Decided Details

- **macOS architecture:** Universal binary (both `aarch64-apple-darwin` and `x86_64-apple-darwin` via `lipo`)
- **Linux native messaging manifest:** System-wide (`/usr/lib/mozilla/native-messaging-hosts/`) for DEB/RPM packages. `install.sh` continues to use per-user (`~/.mozilla/native-messaging-hosts/`).
- **`.xpi` install UX:** Post-install scripts open the `.xpi` in Firefox (`xdg-open` on Linux, `open` on macOS, `start` on Windows) so the install is a single operation. The `.xpi` is also kept in the install directory as a fallback.

### .xpi Auto-Open Strategy

Each platform's post-install step will attempt to open the bundled `.xpi` directly in Firefox:

- **Linux (DEB/RPM):** `xdg-open /usr/lib/savebutton/savebutton.xpi` (opens in default browser; if Firefox, prompts extension install)
- **macOS (PKG):** `open /usr/local/lib/savebutton/savebutton.xpi` (same behavior)
- **Windows (MSI):** WiX custom action runs `start "" "[INSTALLFOLDER]savebutton.xpi"` after install

This prompts Firefox's extension install dialog. If Firefox isn't running or isn't the default browser, the file simply opens or the user can install manually later.

## Platform Details

### DEB (Debian/Ubuntu)

**Build tool:** `dpkg-deb` (available on any Debian-based system and in CI via `ubuntu-latest`)

**Package contents:**
- `/usr/lib/savebutton/savebutton-sync-daemon` (binary)
- `/usr/lib/savebutton/savebutton.xpi` (extension)
- `/usr/lib/mozilla/native-messaging-hosts/org.savebutton.nativehost.json` (system-wide manifest)

**Post-install script (`postinst`):**
- Creates `/etc/skel/.kaya/anga` and `/etc/skel/.kaya/meta` (for new users)
- Opens `savebutton.xpi` via `xdg-open` (as the invoking user, not root)

**Cross-compilation:** The Rust binary targets `x86_64-unknown-linux-gnu`. Build on `ubuntu-latest` in CI.

### RPM (Fedora/RHEL)

**Build tool:** `rpmbuild` (install via `apt install rpm` on Ubuntu CI runners)

**Package contents:** Same paths as DEB:
- `/usr/lib/savebutton/savebutton-sync-daemon`
- `/usr/lib/savebutton/savebutton.xpi`
- `/usr/lib/mozilla/native-messaging-hosts/org.savebutton.nativehost.json`

**Post-install script (`%post`):** Same as DEB `postinst`.

### MSI (Windows)

**Build tool:** WiX v4 (already set up in `sync-daemon/installer/`)

**Changes needed:**
- Add the `.xpi` as a new `<File>` component in `Package.wxs`
- It gets installed to `C:\Program Files\Save Button\savebutton.xpi`
- Add a custom action to open the `.xpi` after install

### PKG (macOS)

**Build tool:** `pkgbuild` + `productbuild` (built into macOS, available on `macos-latest` runners)

**Package contents:**
- `/usr/local/bin/savebutton-sync-daemon` (universal binary)
- `/Library/Application Support/Mozilla/NativeMessagingHosts/org.savebutton.nativehost.json` (system-wide manifest)
- `/usr/local/lib/savebutton/savebutton.xpi` (extension)

**Post-install script:** Creates `~/.kaya/anga` and `~/.kaya/meta`, opens `.xpi` via `open`.

**Cross-compilation:** Build both `aarch64-apple-darwin` and `x86_64-apple-darwin` targets, then combine with `lipo` into a universal binary. Build on `macos-latest` in CI.

## GitHub Actions Workflow

Add a `build-installers` job to `.github/workflows/sign-extension.yml`:

```
build-installers:
  needs: sign-extension
  strategy:
    matrix:
      include:
        - target: deb
          os: ubuntu-latest
          rust_target: x86_64-unknown-linux-gnu
        - target: rpm
          os: ubuntu-latest
          rust_target: x86_64-unknown-linux-gnu
        - target: msi
          os: windows-latest
          rust_target: x86_64-pc-windows-msvc
        - target: pkg
          os: macos-latest
          rust_targets: aarch64-apple-darwin,x86_64-apple-darwin
  runs-on: ${{ matrix.os }}
  steps:
    1. Checkout repository
    2. Download unlisted .xpi artifact from sign-extension job
    3. Install Rust toolchain (for pkg: both targets)
    4. Build savebutton-sync-daemon (for pkg: both architectures + lipo)
    5. Run platform-specific packaging script
    6. Upload installer to GitHub Release
```

## Files to Create

1. **`sync-daemon/packaging/build-deb.sh`** -- builds the `.deb` package
2. **`sync-daemon/packaging/build-rpm.sh`** -- builds the `.rpm` package
3. **`sync-daemon/packaging/build-pkg.sh`** -- builds the `.pkg` package
4. **Update `sync-daemon/installer/Package.wxs`** -- add `.xpi` file component and post-install open action
5. **Update `.github/workflows/sign-extension.yml`** -- add `build-installers` job
