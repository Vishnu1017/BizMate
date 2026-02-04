#!/bin/bash

set -e

FILE="pubspec.yaml"

# Ensure pubspec.yaml exists
if [ ! -f "$FILE" ]; then
  echo "❌ pubspec.yaml not found"
  exit 1
fi

# Extract current version line
VERSION_LINE=$(grep "^version:" "$FILE")

# Validate version line
if [ -z "$VERSION_LINE" ]; then
  echo "❌ version not found in pubspec.yaml"
  exit 1
fi

# Split version name and build number
VERSION_NAME=$(echo "$VERSION_LINE" | cut -d'+' -f1 | cut -d' ' -f2)
BUILD_NUMBER=$(echo "$VERSION_LINE" | cut -d'+' -f2)

# Ensure build number is numeric
if ! [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "❌ Invalid build number: $BUILD_NUMBER"
  exit 1
fi

# Increment build number
NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))

# Update pubspec.yaml (macOS compatible)
sed -i "" "s/^version:.*/version: $VERSION_NAME+$NEW_BUILD_NUMBER/" "$FILE"

echo "✅ Build number updated: $VERSION_NAME+$NEW_BUILD_NUMBER"
