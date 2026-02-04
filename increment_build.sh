#!/bin/bash

FILE="pubspec.yaml"

# Extract current version line
VERSION_LINE=$(grep "^version:" $FILE)

# Split version and build number
VERSION_NAME=$(echo $VERSION_LINE | cut -d'+' -f1 | cut -d' ' -f2)
BUILD_NUMBER=$(echo $VERSION_LINE | cut -d'+' -f2)

# Increment build number
NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))

# Replace version line
sed -i "" "s/^version:.*/version: $VERSION_NAME+$NEW_BUILD_NUMBER/" $FILE

echo "✅ Build number updated to $NEW_BUILD_NUMBER"
