#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product Projektfach
binary_dir="$(swift build -c release --show-bin-path)"
# Sign in local temporary storage before a synchronized project directory can add Finder metadata.
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
bundle="$stage/Projektfach.app"
mkdir -p "$bundle/Contents/MacOS"
install -m 755 "$binary_dir/Projektfach" "$bundle/Contents/MacOS/Projektfach"
install -m 644 Resources/Info.plist "$bundle/Contents/Info.plist"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" "$bundle"
codesign --verify --strict "$bundle"
mkdir -p dist
ditto --norsrc --noextattr "$bundle" dist/Projektfach.app
codesign --verify dist/Projektfach.app
echo "Fertig: dist/Projektfach.app"
