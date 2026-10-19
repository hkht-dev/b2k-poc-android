#!/usr/bin/env bash
# Build a sideloadable debug APK without GitHub Actions.
#
# Mirrors .github/workflows/android.yml step for step, so it stays honest: if
# this script works and CI does not, the difference is the runner, not the
# build. Needed while Actions cannot run on this repository
# (see docs/DECISIONS.md).
#
# Usage:  tools/build_apk.sh [output.apk]
#
# Expects on PATH or in the environment:
#   godot         Godot 4.3, headless-capable
#   ANDROID_HOME  an SDK with build-tools;34.0.0 and platforms;android-34
#   java          JDK 17 or newer
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:-$PROJECT_ROOT/build/android/journey-back-to-krishna.apk}"
GODOT="${GODOT:-godot}"
KEYSTORE="${KEYSTORE:-$PROJECT_ROOT/build/debug.keystore}"

die() { echo "build_apk: $*" >&2; exit 1; }

command -v "$GODOT" >/dev/null || die "godot not found; set GODOT to the 4.3 binary"
"$GODOT" --version | grep -q '^4\.3\.' || die "need Godot 4.3, found $("$GODOT" --version)"
[ -n "${ANDROID_HOME:-}" ] || die "set ANDROID_HOME to an Android SDK"
[ -d "$ANDROID_HOME/build-tools/34.0.0" ] || die "install build-tools;34.0.0"
command -v java >/dev/null || die "java not found; install a JDK 17 or newer"

# A debug keystore is not a secret: alias and password are the Android
# defaults and it only ever signs sideload builds. .gitignore excludes it.
if [ ! -f "$KEYSTORE" ]; then
  echo "build_apk: generating a debug keystore at $KEYSTORE"
  mkdir -p "$(dirname "$KEYSTORE")"
  keytool -keyalg RSA -genkeypair \
    -alias androiddebugkey -keypass android \
    -keystore "$KEYSTORE" -storepass android \
    -dname "CN=Android Debug,O=Android,C=US" \
    -validity 9999 -deststoretype pkcs12
fi

export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"

# Godot finds the SDK through editor settings, not the environment.
SETTINGS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/godot"
mkdir -p "$SETTINGS_DIR"
cat > "$SETTINGS_DIR/editor_settings-4.3.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"
export/android/debug_keystore = "$KEYSTORE"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOF

# Twice on purpose: GUT's editor plugin loads images and fonts during the first
# import, before they exist. See docs/DECISIONS.md.
echo "build_apk: importing"
"$GODOT" --headless --import --path "$PROJECT_ROOT" >/dev/null 2>&1 || true
"$GODOT" --headless --import --path "$PROJECT_ROOT" >/dev/null 2>&1

echo "build_apk: exporting"
mkdir -p "$(dirname "$OUTPUT")"
"$GODOT" --headless --path "$PROJECT_ROOT" --export-debug "Android" "$OUTPUT"

"$ANDROID_HOME/build-tools/34.0.0/apksigner" verify "$OUTPUT" >/dev/null \
  || die "the exported APK is not correctly signed"

bytes=$(stat -c%s "$OUTPUT")
mb=$(( bytes / 1024 / 1024 ))
echo "build_apk: ${OUTPUT} — ${mb} MB, signature verified"
