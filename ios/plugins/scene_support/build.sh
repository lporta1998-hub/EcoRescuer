#!/bin/zsh
# Rebuilds scene_support.xcframework (device + simulator) from src/.
set -e
cd "$(dirname "$0")"
OUT=$(mktemp -d)
for SDK in iphoneos iphonesimulator; do
  if [ $SDK = iphoneos ]; then ARCHS=(-arch arm64); TGT=-miphoneos-version-min=16.0; else ARCHS=(-arch arm64 -arch x86_64); TGT=-mios-simulator-version-min=16.0; fi
  mkdir -p $OUT/$SDK
  xcrun -sdk $SDK clang++ -c src/scene_support.mm -o $OUT/$SDK/scene_support.o $ARCHS $TGT -fobjc-arc -O2 -std=c++17
  xcrun -sdk $SDK libtool -static -o $OUT/$SDK/libscene_support.a $OUT/$SDK/scene_support.o
done
rm -rf scene_support.xcframework
xcodebuild -create-xcframework -library $OUT/iphoneos/libscene_support.a -library $OUT/iphonesimulator/libscene_support.a -output scene_support.xcframework >/dev/null
rm -rf $OUT
echo "built scene_support.xcframework"
