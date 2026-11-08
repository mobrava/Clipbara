#!/bin/bash
set -euo pipefail

# Regenerates AppIcon-Dev (the ClipbaraDev icon) from AppIcon: AppIcon with a "DEV"
# badge (scripts/make-dev-icon.swift), at every size AppIcon has.
# Run again whenever AppIcon changes.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSETS="$(dirname "$SCRIPT_DIR")/Clipbara/Resources/Assets.xcassets"
SOURCE="${ASSETS}/AppIcon.appiconset"
DEST="${ASSETS}/AppIcon-Dev.appiconset"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

mkdir -p "${DEST}"
swift "${SCRIPT_DIR}/make-dev-icon.swift" "${SOURCE}/1024.png" "${DEST}/1024.png"

# Same file names and Contents.json as AppIcon, scaled from the badged 1024 px image.
for size in 512 256 128 64 32 16; do
    sips -z "${size}" "${size}" "${DEST}/1024.png" --out "${DEST}/${size}.png" >/dev/null
done
cp "${SOURCE}/Contents.json" "${DEST}/Contents.json"

echo "AppIcon-Dev written to ${DEST}"
