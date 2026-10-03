#!/bin/bash
set -euo pipefail
AURA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
AURA_TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/aura-spatial.XXXXXX")"
trap 'rm -rf "$AURA_TEST_DIR"' EXIT
xcrun swiftc -module-cache-path "$AURA_TEST_DIR/cache" "$AURA_ROOT/ios/Aura/Core/AR/SpatialProjection.swift" "$AURA_ROOT/tests/spatial/main.swift" -o "$AURA_TEST_DIR/check"
"$AURA_TEST_DIR/check"
