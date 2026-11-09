#!/bin/zsh
# Exports the Godot project for iOS, builds it with Xcode and installs it on
# the iPhone. Output goes to build/ios (ignored by git).
#   Tools/dev/build_ios.sh [device-id]
# Device ids: xcrun devicectl list devices
set -e
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-$HOME/Downloads/Godot.app/Contents/MacOS/Godot}"
DEVICE="${1:-00008120-000865592EF8A01E}"
mkdir -p build/ios
"$GODOT" --headless --path . --export-debug "iOS" build/ios/EcoRescuer.ipa > build/ios/export.log 2>&1
cd build/ios
xcodebuild -project EcoRescuer.xcodeproj -scheme EcoRescuer -configuration Debug \
  -destination "platform=iOS,id=$DEVICE" -derivedDataPath DerivedData -allowProvisioningUpdates build > xcb.log 2>&1 \
  || { grep -E "error:" xcb.log | head; exit 1; }
xcrun devicectl device install app --device "$DEVICE" DerivedData/Build/Products/Debug-iphoneos/EcoRescuer.app
echo "Installed on $DEVICE"
