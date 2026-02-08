#!/bin/bash
set -e

# Build a .pkg installer for Save Button Sync Daemon (macOS).
#
# Usage: ./build-pkg.sh <binary-path> <xpi-path>
#   binary-path: path to the compiled savebutton-sync-daemon binary (universal)
#   xpi-path:    path to the signed .xpi extension file

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION="1.0.0"
PACKAGE_NAME="savebutton-sync-daemon"
IDENTIFIER="com.savebutton.sync-daemon"

BINARY_PATH="${1:?Usage: $0 <binary-path> <xpi-path>}"
XPI_PATH="${2:?Usage: $0 <binary-path> <xpi-path>}"

BUILD_DIR="$SCRIPT_DIR/build-pkg"
PKG_ROOT="$BUILD_DIR/root"
SCRIPTS_DIR="$BUILD_DIR/scripts"

echo "Building PKG installer..."

# Clean previous build
rm -rf "$BUILD_DIR"

# Create directory structure
mkdir -p "$PKG_ROOT/usr/local/bin"
mkdir -p "$PKG_ROOT/usr/local/lib/savebutton"
mkdir -p "$PKG_ROOT/Library/Application Support/Mozilla/NativeMessagingHosts"

# Copy binary
cp "$BINARY_PATH" "$PKG_ROOT/usr/local/bin/savebutton-sync-daemon"
chmod 755 "$PKG_ROOT/usr/local/bin/savebutton-sync-daemon"

# Copy .xpi
cp "$XPI_PATH" "$PKG_ROOT/usr/local/lib/savebutton/savebutton.xpi"
chmod 644 "$PKG_ROOT/usr/local/lib/savebutton/savebutton.xpi"

# Create native messaging manifest with correct path
cat > "$PKG_ROOT/Library/Application Support/Mozilla/NativeMessagingHosts/org.savebutton.nativehost.json" << 'EOF'
{
  "name": "org.savebutton.nativehost",
  "description": "Save Button Sync Daemon - Native messaging host for the Save Button Firefox extension",
  "path": "/usr/local/bin/savebutton-sync-daemon",
  "type": "stdio",
  "allowed_extensions": ["org.savebutton@savebutton.org"]
}
EOF

# Create postinstall script
mkdir -p "$SCRIPTS_DIR"
cat > "$SCRIPTS_DIR/postinstall" << 'POSTINSTALL'
#!/bin/bash

# Determine the real user (not root)
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(dscl . -read /Users/"$REAL_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
if [ -z "$REAL_HOME" ]; then
    REAL_HOME="/Users/$REAL_USER"
fi

# Create data directories
su "$REAL_USER" -c "mkdir -p '$REAL_HOME/.kaya/anga' '$REAL_HOME/.kaya/meta'"

# Open the .xpi in Firefox to prompt extension installation
su "$REAL_USER" -c "open /usr/local/lib/savebutton/savebutton.xpi 2>/dev/null || true" &

exit 0
POSTINSTALL
chmod 755 "$SCRIPTS_DIR/postinstall"

# Build the component package
pkgbuild \
    --root "$PKG_ROOT" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --scripts "$SCRIPTS_DIR" \
    --install-location / \
    "$BUILD_DIR/${PACKAGE_NAME}-${VERSION}.pkg"

OUTPUT="$BUILD_DIR/${PACKAGE_NAME}-${VERSION}.pkg"
echo ""
echo "PKG installer built: $OUTPUT"
