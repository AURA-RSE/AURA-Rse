#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcodebuild -project ios/Aura.xcodeproj -scheme Aura -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath .build/ios CODE_SIGNING_ALLOWED=NO build
