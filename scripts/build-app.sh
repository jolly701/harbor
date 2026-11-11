#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$root"

"$root/scripts/prepare-runtime.sh"
swift build -c release --arch arm64

bin="$root/.build/release/Harbor"
app="$root/dist/Harbor.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/bun" "$app/Contents/Resources/copilot-api"

cp "$bin" "$app/Contents/MacOS/Harbor"
cp "$root/Info.plist" "$app/Contents/Info.plist"
cp -R "$root/Resources/en.lproj" "$root/Resources/zh-Hans.lproj" "$app/Contents/Resources/"
mkdir -p "$app/Contents/Resources/zh-Hant.lproj"
cp "$root/Resources/zh-Hans.lproj/Localizable.strings" "$app/Contents/Resources/zh-Hant.lproj/Localizable.strings"
cp "$root/.build/harbor-runtime/bun/bun" "$app/Contents/Resources/bun/bun"
chmod +x "$app/Contents/Resources/bun/bun"
rsync -a "$root/.build/harbor-runtime/copilot-api/" "$app/Contents/Resources/copilot-api/"

iconset="$root/dist/AppIcon.iconset"
rm -rf "$iconset"
mkdir -p "$iconset"
png="$root/dist/icon-1024.png"
swift "$root/scripts/render-icon.swift" \
  "$root/Assets/boat-leaving-port.png" \
  "$png" \
  "$app/Contents/Resources/MenuBarIcon.png"
sips -z 16 16 "$png" --out "$iconset/icon_16x16.png" >/dev/null
sips -z 32 32 "$png" --out "$iconset/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$png" --out "$iconset/icon_32x32.png" >/dev/null
sips -z 64 64 "$png" --out "$iconset/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$png" --out "$iconset/icon_128x128.png" >/dev/null
sips -z 256 256 "$png" --out "$iconset/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$png" --out "$iconset/icon_256x256.png" >/dev/null
sips -z 512 512 "$png" --out "$iconset/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$png" --out "$iconset/icon_512x512.png" >/dev/null
cp "$png" "$iconset/icon_512x512@2x.png"
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$app/Contents/Resources/bun/bun"
codesign --force --deep --sign - "$app"
echo "$app"
