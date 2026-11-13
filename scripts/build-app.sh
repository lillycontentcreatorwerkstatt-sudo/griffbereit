#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product Projektfach
binary_dir="$(swift build -c release --show-bin-path)"
bundle="dist/Projektfach.app"
mkdir -p "$bundle/Contents/MacOS"
install -m 755 "$binary_dir/Projektfach" "$bundle/Contents/MacOS/Projektfach"
install -m 644 Resources/Info.plist "$bundle/Contents/Info.plist"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" "$bundle"
codesign --verify --strict "$bundle"
echo "Fertig: $bundle"
