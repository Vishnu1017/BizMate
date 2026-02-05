#!/bin/bash

set -e

dart run tool/increment_version.dart
dart run tool/increment_build.dart
flutter clean
flutter build apk
flutter install
