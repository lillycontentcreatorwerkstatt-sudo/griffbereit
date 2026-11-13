#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product Griffbereit
binary_dir="$(swift build -c release --show-bin-path)"
# Sign in local temporary storage before a synchronized project directory can add Finder metadata.
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
bundle="$stage/Griffbereit.app"
mkdir -p "$bundle/Contents/MacOS"
install -m 755 "$binary_dir/Griffbereit" "$bundle/Contents/MacOS/Griffbereit"
install -m 644 Resources/Info.plist "$bundle/Contents/Info.plist"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" "$bundle"
codesign --verify --strict "$bundle"
mkdir -p dist
ditto --norsrc --noextattr "$bundle" dist/Griffbereit.app
codesign --verify dist/Griffbereit.app
echo "Fertig: dist/Griffbereit.app"
