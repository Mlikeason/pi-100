#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
xcodebuild -project ios/Pi100.xcodeproj -scheme Pi100 -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
