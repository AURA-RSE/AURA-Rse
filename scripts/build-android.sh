#!/bin/bash
set -euo pipefail
AURA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export JAVA_HOME="${JAVA_HOME:-$AURA_ROOT/.toolchains/jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-$AURA_ROOT/.toolchains/android-sdk}"
export ANDROID_USER_HOME="$AURA_ROOT/.toolchains/android-user"
export GRADLE_USER_HOME="$AURA_ROOT/.toolchains/gradle-user"
export PATH="$JAVA_HOME/bin:$PATH"
if [[ ! -x "$JAVA_HOME/bin/java" ]]; then
  echo 'Java toolchain missing. Install JDK 17+ and Android SDK 35, or run scripts/setup-android-tools.py.' >&2
  exit 1
fi
cd "$AURA_ROOT/android"
if [[ -x ./gradlew ]]; then exec ./gradlew --no-daemon --max-workers=2 "$@"; fi
exec "$AURA_ROOT/.toolchains/gradle-8.11.1/bin/gradle" --no-daemon --max-workers=2 "$@"
