#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
command -v xcrun >/dev/null
command -v ldid >/dev/null
sdk=$(xcrun --sdk iphoneos --show-sdk-path)
mkdir -p build/Payload/RouteLab.app
app="build/Payload/RouteLab.app"
# Pure route math checks run without an iOS device.
clang -std=c11 -Wall -Wextra -Werror Sources/RouteMath.c tests/RouteMathTests.c -lm -o build/route-math-tests
./build/route-math-tests
xcrun --sdk iphoneos clang -target arm64-apple-ios16.0 -isysroot "$sdk" -std=c11 -Os \
  -c Sources/RouteMath.c -o build/route-math-ios.o
xcrun --sdk iphoneos clang -target arm64-apple-ios16.0 -isysroot "$sdk" \
  -fobjc-arc -fmodules -Os -Wall -Wextra -Werror=return-type \
  -I Sources -I Vendor/locsim -include Foundation/Foundation.h \
  Sources/App.m Sources/RoutePlan.m Sources/SimulationController.m build/route-math-ios.o \
  Vendor/locsim/LSMGPXParserDelegate.m \
  -framework Foundation -framework UIKit -framework WebKit -framework CoreLocation \
  -o "$app/RouteLab"
cp Resources/Info.plist "$app/Info.plist"
cp Resources/config.json "$app/config.json"
cp -R Resources/web "$app/web"
cp LICENSE "$app/LICENSE"
cp THIRD-PARTY.md "$app/THIRD-PARTY.md"
plutil -lint "$app/Info.plist" entitlements.plist
ldid -Sentitlements.plist "$app/RouteLab"
ldid -e "$app/RouteLab" > build/embedded-entitlements.plist
plutil -lint build/embedded-entitlements.plist
(cd build && zip -qr RouteLab-iPhone-0.1.0.tipa Payload)
shasum -a 256 build/RouteLab-iPhone-0.1.0.tipa > build/SHA256SUMS.txt
printf '%s\n' 'TrollStore test package built; device validation still required.'
