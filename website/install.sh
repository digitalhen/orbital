#!/bin/bash
set -e

echo "Installing Orbital..."

TMP=$(mktemp -d)
DMG="$TMP/Orbital.dmg"

curl -fsSL "https://apps.cleartextlabs.com/orbital/Orbital-1.0.dmg" -o "$DMG"

hdiutil attach -nobrowse -quiet "$DMG"
cp -R "/Volumes/Orbital/Orbital.app" /Applications/
hdiutil detach "/Volumes/Orbital" -quiet
rm -rf "$TMP"

# Remove quarantine so Gatekeeper doesn't block it
xattr -dr com.apple.quarantine /Applications/Orbital.app 2>/dev/null || true

echo "Orbital installed to /Applications"
echo "Starting Orbital..."
open /Applications/Orbital.app
