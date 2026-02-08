#!/bin/bash
set -e

# Build a .deb package for Save Button Sync Daemon.
#
# Usage: ./build-deb.sh <binary-path> <xpi-path>
#   binary-path: path to the compiled savebutton-sync-daemon binary
#   xpi-path:    path to the signed .xpi extension file

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION="1.0.0"
PACKAGE_NAME="savebutton-sync-daemon"
ARCH="amd64"

BINARY_PATH="${1:?Usage: $0 <binary-path> <xpi-path>}"
XPI_PATH="${2:?Usage: $0 <binary-path> <xpi-path>}"

BUILD_DIR="$SCRIPT_DIR/build-deb"
PKG_ROOT="$BUILD_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}"

echo "Building DEB package..."

# Clean previous build
rm -rf "$PKG_ROOT"

# Create directory structure
mkdir -p "$PKG_ROOT/DEBIAN"
mkdir -p "$PKG_ROOT/usr/lib/savebutton"
mkdir -p "$PKG_ROOT/usr/lib/mozilla/native-messaging-hosts"
mkdir -p "$PKG_ROOT/etc/skel/.kaya/anga"
mkdir -p "$PKG_ROOT/etc/skel/.kaya/meta"

# Copy binary
cp "$BINARY_PATH" "$PKG_ROOT/usr/lib/savebutton/savebutton-sync-daemon"
chmod 755 "$PKG_ROOT/usr/lib/savebutton/savebutton-sync-daemon"

# Copy .xpi
cp "$XPI_PATH" "$PKG_ROOT/usr/lib/savebutton/savebutton.xpi"
chmod 644 "$PKG_ROOT/usr/lib/savebutton/savebutton.xpi"

# Create native messaging manifest with correct path
cat > "$PKG_ROOT/usr/lib/mozilla/native-messaging-hosts/org.savebutton.nativehost.json" << 'EOF'
{
  "name": "org.savebutton.nativehost",
  "description": "Save Button Sync Daemon - Native messaging host for the Save Button Firefox extension",
  "path": "/usr/lib/savebutton/savebutton-sync-daemon",
  "type": "stdio",
  "allowed_extensions": ["org.savebutton@savebutton.org"]
}
EOF

# Create control file
cat > "$PKG_ROOT/DEBIAN/control" << EOF
Package: ${PACKAGE_NAME}
Version: ${VERSION}
Architecture: ${ARCH}
Maintainer: deobald.ca
Description: Save Button Sync Daemon
 Native sync daemon and Firefox extension for Save Button.
 Saves bookmarks, quotes, and images locally and syncs them
 with the Save Button server.
Section: web
Priority: optional
Homepage: https://savebutton.com
EOF

# Create postinst script
cat > "$PKG_ROOT/DEBIAN/postinst" << 'POSTINST'
#!/bin/bash
set -e

# Create data directories for the current user if running interactively
if [ -n "$SUDO_USER" ]; then
    REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    if [ -n "$REAL_HOME" ]; then
        su "$SUDO_USER" -c "mkdir -p '$REAL_HOME/.kaya/anga' '$REAL_HOME/.kaya/meta'"
        # Open the .xpi in Firefox to prompt extension installation
        su "$SUDO_USER" -c "xdg-open /usr/lib/savebutton/savebutton.xpi 2>/dev/null || true" &
    fi
fi
POSTINST
chmod 755 "$PKG_ROOT/DEBIAN/postinst"

# Build the .deb
dpkg-deb --build --root-owner-group "$PKG_ROOT"

OUTPUT="${PKG_ROOT}.deb"
echo ""
echo "DEB package built: $OUTPUT"
