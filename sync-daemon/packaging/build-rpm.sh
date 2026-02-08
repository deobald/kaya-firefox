#!/bin/bash
set -e

# Build an .rpm package for Save Button Sync Daemon.
#
# Usage: ./build-rpm.sh <binary-path> <xpi-path>
#   binary-path: path to the compiled savebutton-sync-daemon binary
#   xpi-path:    path to the signed .xpi extension file

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION="1.0.0"
PACKAGE_NAME="savebutton-sync-daemon"

BINARY_PATH="$(realpath "${1:?Usage: $0 <binary-path> <xpi-path>}")"
XPI_PATH="$(realpath "${2:?Usage: $0 <binary-path> <xpi-path>}")"

RPMBUILD_DIR="$SCRIPT_DIR/build-rpm/rpmbuild"

echo "Building RPM package..."

# Clean previous build
rm -rf "$RPMBUILD_DIR"

# Create rpmbuild directory structure
mkdir -p "$RPMBUILD_DIR"/{SPECS,SOURCES,BUILD,RPMS,SRPMS}

# Create source tarball
TARBALL_DIR="$RPMBUILD_DIR/SOURCES/${PACKAGE_NAME}-${VERSION}"
mkdir -p "$TARBALL_DIR"
cp "$BINARY_PATH" "$TARBALL_DIR/savebutton-sync-daemon"
cp "$XPI_PATH" "$TARBALL_DIR/savebutton.xpi"

# Create native messaging manifest
cat > "$TARBALL_DIR/org.savebutton.nativehost.json" << 'EOF'
{
  "name": "org.savebutton.nativehost",
  "description": "Save Button Sync Daemon - Native messaging host for the Save Button Firefox extension",
  "path": "/usr/lib/savebutton/savebutton-sync-daemon",
  "type": "stdio",
  "allowed_extensions": ["org.savebutton@savebutton.org"]
}
EOF

tar -czf "$RPMBUILD_DIR/SOURCES/${PACKAGE_NAME}-${VERSION}.tar.gz" \
    -C "$RPMBUILD_DIR/SOURCES" "${PACKAGE_NAME}-${VERSION}"

# Create spec file
cat > "$RPMBUILD_DIR/SPECS/${PACKAGE_NAME}.spec" << EOF
Name:           ${PACKAGE_NAME}
Version:        ${VERSION}
Release:        1%{?dist}
Summary:        Save Button Sync Daemon
License:        AGPL-3.0
URL:            https://savebutton.com
Source0:        %{name}-%{version}.tar.gz

%description
Native sync daemon and Firefox extension for Save Button.
Saves bookmarks, quotes, and images locally and syncs them
with the Save Button server.

%prep
%setup -q

%install
mkdir -p %{buildroot}/usr/lib/savebutton
mkdir -p %{buildroot}/usr/lib/mozilla/native-messaging-hosts
mkdir -p %{buildroot}/etc/skel/.kaya/anga
mkdir -p %{buildroot}/etc/skel/.kaya/meta

install -m 755 savebutton-sync-daemon %{buildroot}/usr/lib/savebutton/savebutton-sync-daemon
install -m 644 savebutton.xpi %{buildroot}/usr/lib/savebutton/savebutton.xpi
install -m 644 org.savebutton.nativehost.json %{buildroot}/usr/lib/mozilla/native-messaging-hosts/org.savebutton.nativehost.json

%post
# Create data directories for the current user if running interactively
if [ -n "\$SUDO_USER" ]; then
    REAL_HOME=\$(getent passwd "\$SUDO_USER" | cut -d: -f6)
    if [ -n "\$REAL_HOME" ]; then
        su "\$SUDO_USER" -c "mkdir -p '\$REAL_HOME/.kaya/anga' '\$REAL_HOME/.kaya/meta'"
        su "\$SUDO_USER" -c "xdg-open /usr/lib/savebutton/savebutton.xpi 2>/dev/null || true" &
    fi
fi

%files
%dir /usr/lib/savebutton
/usr/lib/savebutton/savebutton-sync-daemon
/usr/lib/savebutton/savebutton.xpi
/usr/lib/mozilla/native-messaging-hosts/org.savebutton.nativehost.json
%dir /etc/skel/.kaya
%dir /etc/skel/.kaya/anga
%dir /etc/skel/.kaya/meta
EOF

# Build the RPM
rpmbuild --define "_topdir $RPMBUILD_DIR" -bb "$RPMBUILD_DIR/SPECS/${PACKAGE_NAME}.spec"

OUTPUT=$(find "$RPMBUILD_DIR/RPMS" -name "*.rpm" | head -1)
echo ""
echo "RPM package built: $OUTPUT"
