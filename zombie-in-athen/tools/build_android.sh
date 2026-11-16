#!/usr/bin/env bash
# Baut die Debug-APK für Android arm64 (ohne Gradle).
#
# Voraussetzungen:
#   * Godot 4.5.x (Standard-Build) als "godot" im PATH oder über $GODOT
#   * Godot-Export-Templates 4.5.x (Editor: "Export-Vorlagen verwalten")
#   * Android SDK mit build-tools (apksigner) und platform-tools
#   * JDK 17 oder neuer
#   * In den Godot-Editor-Einstellungen (Export > Android): Pfade zu Java-SDK,
#     Android-SDK und einem Debug-Keystore
#     (z. B. keytool -genkeypair -keyalg RSA -alias androiddebugkey -keypass android \
#        -keystore ~/.android/debug.keystore -storepass android \
#        -dname "CN=Android Debug,O=Android,C=US" -validity 9999)
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p build
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-debug "Android arm64" build/ZombieInAthen-debug.apk
ls -la build/ZombieInAthen-debug.apk
echo "Installieren:  adb install -r build/ZombieInAthen-debug.apk"
