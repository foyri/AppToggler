#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="AppToggler"
APP_BUNDLE="$ROOT/dist/${APP_NAME}.app"
APP_BIN="$ROOT/.build/release/${APP_NAME}"
APP_RES="$APP_BUNDLE/Contents/Resources"
APP_MACOS="$APP_BUNDLE/Contents/MacOS"
APP_PLIST="$APP_BUNDLE/Contents/Info.plist"

LAUNCH=0
if [[ "${1:-}" == "--launch" ]]; then
  LAUNCH=1
fi

mkdir -p "$ROOT/dist"

swift build -c release

mkdir -p "$APP_MACOS" "$APP_RES"

if [[ ! -f "$APP_PLIST" ]]; then
  cat > "$APP_PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>AppToggler</string>
  <key>CFBundleDisplayName</key>
  <string>AppToggler</string>
  <key>CFBundleExecutable</key>
  <string>AppToggler</string>
  <key>CFBundleIdentifier</key>
  <string>com.local.apptoggler</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF
fi

cp "$APP_BIN" "$APP_MACOS/$APP_NAME"
chmod +x "$APP_MACOS/$APP_NAME"

# Copy SwiftPM resource bundles (required by KeyboardShortcuts recorder localization).
find "$ROOT/.build" -type d -path '*/release/*.bundle' -print0 | while IFS= read -r -d '' bundle; do
  name="$(basename "$bundle")"
  rm -rf "$APP_RES/$name"
  cp -R "$bundle" "$APP_RES/$name"
done

codesign --force --deep --sign - "$APP_BUNDLE"

ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ROOT/dist/${APP_NAME}-macOS.zip"

if [[ "$LAUNCH" -eq 1 ]]; then
  pkill -f '/dist/AppToggler.app/Contents/MacOS/AppToggler' || true
  open "$APP_BUNDLE" || true
fi

echo "Built: $APP_BUNDLE"
echo "Zip:   $ROOT/dist/${APP_NAME}-macOS.zip"
