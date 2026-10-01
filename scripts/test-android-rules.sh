#!/bin/bash
set -euo pipefail
AURA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AURA_JAVA="${JAVA_HOME:-$AURA_ROOT/.toolchains/jdk/Contents/Home}"
mkdir -p "$AURA_ROOT/.build/android-rules"
"$AURA_JAVA/bin/javac" -d "$AURA_ROOT/.build/android-rules" "$AURA_ROOT/android/app/src/main/java/app/aura/pilot/PresenceRules.java" "$AURA_ROOT/android/app/src/testLocal/java/app/aura/pilot/PresenceRulesTest.java"
"$AURA_JAVA/bin/java" -cp "$AURA_ROOT/.build/android-rules" app.aura.pilot.PresenceRulesTest

node "$AURA_ROOT/scripts/android-wire-fixture.mjs" "$AURA_ROOT/.build/android-rules/transfer.properties"
"$AURA_JAVA/bin/javac" -d "$AURA_ROOT/.build/android-rules" "$AURA_ROOT/android/app/src/main/java/app/aura/pilot/SolanaWire.java" "$AURA_ROOT/android/app/src/testLocal/java/app/aura/pilot/SolanaWireTest.java"
"$AURA_JAVA/bin/java" -cp "$AURA_ROOT/.build/android-rules" app.aura.pilot.SolanaWireTest "$AURA_ROOT/.build/android-rules/transfer.properties"
