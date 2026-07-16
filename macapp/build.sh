#!/bin/bash
# 정식 Xcode 없이 swiftc로 macOS 메뉴바 앱(.app)을 빌드한다.
set -e
cd "$(dirname "$0")"

APP="SeoulCamping.app"
BIN="SeoulCamping"
BUNDLE_ID="com.seoulcamping.menubar"
SDK="$(xcrun --show-sdk-path)"

echo "▶ 컴파일 (swiftc, macOS 13)…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -parse-as-library -O \
  -sdk "$SDK" -target arm64-apple-macos13.0 \
  Sources/*.swift -o "$APP/Contents/MacOS/$BIN"

echo "▶ 리소스/아이콘 복사…"
[ -f AppIcon.icns ] && cp AppIcon.icns "$APP/Contents/Resources/"

echo "▶ Info.plist 생성…"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>서울 캠핑</string>
  <key>CFBundleDisplayName</key><string>난지캠핑장</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$BIN</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>© 2026</string>
</dict>
</plist>
PLIST

echo "▶ 애드혹 코드서명(로컬 실행용)…"
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "  (서명 생략)"

echo "✅ 빌드 완료: $PWD/$APP"
echo "   실행:  open \"$PWD/$APP\"   (메뉴바에 텐트 아이콘이 나타납니다)"
