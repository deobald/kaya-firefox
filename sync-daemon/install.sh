#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY_NAME="savebutton-sync-daemon"
MANIFEST_NAME="org.savebutton.nativehost.json"

echo "Building Save Button Sync Daemon..."
cd "$SCRIPT_DIR"
cargo build --release

echo "Installing binary..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    INSTALL_DIR="/usr/local/bin"
    MANIFEST_DIR="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"
    MANIFEST_SRC="manifests/org.savebutton.nativehost.macos.json"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    INSTALL_DIR="/usr/local/bin"
    MANIFEST_DIR="$HOME/.mozilla/native-messaging-hosts"
    MANIFEST_SRC="manifests/org.savebutton.nativehost.linux.json"
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

sudo cp "target/release/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
sudo chmod +x "$INSTALL_DIR/$BINARY_NAME"

echo "Installing native messaging manifest..."
mkdir -p "$MANIFEST_DIR"

# Update path in manifest to actual install location
cat "$MANIFEST_SRC" | sed "s|/usr/local/bin/savebutton-sync-daemon|$INSTALL_DIR/$BINARY_NAME|g" > "$MANIFEST_DIR/$MANIFEST_NAME"

echo "Creating ~/.kaya directories..."
mkdir -p "$HOME/.kaya/anga"
mkdir -p "$HOME/.kaya/meta"

echo ""
echo "Installation complete!"
echo ""
echo "Binary installed to: $INSTALL_DIR/$BINARY_NAME"
echo "Manifest installed to: $MANIFEST_DIR/$MANIFEST_NAME"
echo ""
echo "Next steps:"
echo "1. Install the Firefox extension from about:debugging or addons.mozilla.org"
echo "2. Configure the extension with your Save Button server credentials"
