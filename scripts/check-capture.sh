#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
xcrun swiftc -parse-as-library -emit-library -emit-module -module-name FachCore \
  -I Sources/CSQLite Sources/FachCore/*.swift -emit-module-path "$stage/FachCore.swiftmodule" -o "$stage/libFachCore.dylib"
xcrun swiftc -parse-as-library -I "$stage" -I Sources/CSQLite -L "$stage" -lFachCore \
  Sources/Griffbereit/Desk.swift Sources/Griffbereit/QuickPaste.swift Sources/Griffbereit/ScreenshotFolder.swift Sources/Griffbereit/ProjectBrowser.swift Tests/CaptureFlow/Check.swift -o "$stage/CaptureFlow"
"$stage/CaptureFlow"
