#!/bin/bash
set -e

BINARY_NAME="savebutton-sync-daemon"
MANIFEST_NAME="org.savebutton.nativehost.json"

if [[ "$OSTYPE" == "darwin"* ]]; then
    INSTALL_DIR="/usr/local/bin"
    MANIFEST_DIR="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    INSTALL_DIR="/usr/local/bin"
    MANIFEST_DIR="$HOME/.mozilla/native-messaging-hosts"
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

echo "Uninstalling Save Button Sync Daemon..."

BINARY_PATH="$INSTALL_DIR/$BINARY_NAME"
if [ -f "$BINARY_PATH" ]; then
    sudo rm "$BINARY_PATH"
    echo "  Removed binary: $BINARY_PATH"
else
    echo "  Binary not found (already removed): $BINARY_PATH"
fi

MANIFEST_PATH="$MANIFEST_DIR/$MANIFEST_NAME"
if [ -f "$MANIFEST_PATH" ]; then
    rm "$MANIFEST_PATH"
    echo "  Removed manifest: $MANIFEST_PATH"
else
    echo "  Manifest not found (already removed): $MANIFEST_PATH"
fi

echo ""
echo "Uninstallation complete!"
echo ""
echo "Note: User data in ~/.kaya was NOT removed."
echo "Delete it manually if you want to remove all Save Button data."
