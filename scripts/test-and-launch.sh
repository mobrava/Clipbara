#!/bin/bash
# Run the unhosted unit tests, then build and relaunch Clipbara.
# Usage: bash scripts/test-and-launch.sh [output-directory]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${1:-$ROOT/build/verification}"
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
RUN="$OUTPUT/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$RUN"
exec > >(tee "$RUN/verification.log") 2>&1
trap 'code=$?; printf "%s\n" "$code" > "$RUN/exit-code"; if [ "$code" -ne 0 ]; then printf "\n    FAILED (exit %s). Log: %s\n" "$code" "$RUN/verification.log"; fi' EXIT

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd "$ROOT"
echo "==> Log: $RUN/verification.log"

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Running unit tests (no app launch, no store access)..."
xcodebuild \
  -project Clipbara.xcodeproj \
  -scheme ClipbaraTests \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$OUTPUT/DerivedData" \
  -resultBundlePath "$RUN/UnitTests.xcresult" \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  test

echo "==> Building Clipbara (Debug)..."
xcodebuild \
  -project Clipbara.xcodeproj \
  -scheme Clipbara \
  -configuration Debug \
  -derivedDataPath "$OUTPUT/DerivedData" \
  build

echo "==> Quitting the running app and launching the new build..."
APP="$OUTPUT/DerivedData/Build/Products/Debug/Clipbara.app"
test -d "$APP"
pkill -f 'Clipbara.app/Contents/MacOS/Clipbara' || true
sleep 2
if pgrep -f 'Clipbara.app/Contents/MacOS/Clipbara' >/dev/null; then
  echo "    FATAL: the previous instance is still running. Quit Clipbara and run this again."
  echo "    A second instance would register the global shortcut twice."
  exit 1
fi
open "$APP"

echo "==> Unit tests and the build passed, and the Debug app was launched."
echo "    UI behaviour is not covered here. Follow the notes under docs/testing to verify it."
echo "    This script is done and the window can be closed."
echo "    Log: $RUN/verification.log"
