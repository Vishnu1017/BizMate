#!/bin/bash

set -e

echo "📦 Updating version and build number..."
dart run tool/increment_version.dart
dart run tool/increment_build.dart

echo "🧹 Cleaning previous build..."
flutter clean
flutter pub get

echo "⚡ Building optimized split APKs (--split-per-abi, --obfuscate)..."
flutter build apk --split-per-abi --obfuscate --split-debug-info=build/debug-info

echo ""
echo "=============================================="
echo "🎉 Build Complete! APK Sizes:"
echo "=============================================="
ls -lh build/app/outputs/flutter-apk/*.apk
echo "=============================================="
echo "📱 Modern Android phones use: app-arm64-v8a-release.apk"
echo ""

# Install arm64-v8a APK to connected device
APK_PATH="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
if [ -f "$APK_PATH" ]; then
  echo "📲 Installing $APK_PATH to connected device..."
  flutter install --use-application-binary="$APK_PATH" || echo "⚠️ Could not auto-install (no device connected or install failed). APK is located at: $APK_PATH"
fi
