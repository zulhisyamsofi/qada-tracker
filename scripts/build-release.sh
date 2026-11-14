#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
QADA_VERSION="$(sed -n 's/^version: \([^+]*\).*/\1/p' pubspec.yaml)"
QADA_RELEASE_DIR="build/releases/v$QADA_VERSION"
mkdir -p "$QADA_RELEASE_DIR"
# Release mode uses Dart AOT compilation, tree shaking, R8, and resource shrinking.
# Keep a universal fallback and offer one small APK per processor architecture.
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk "$QADA_RELEASE_DIR/qada-tracker-v$QADA_VERSION.apk"
flutter build apk --release --split-per-abi
for QADA_ABI in armeabi-v7a arm64-v8a x86_64; do
  cp "build/app/outputs/flutter-apk/app-$QADA_ABI-release.apk" "$QADA_RELEASE_DIR/qada-tracker-v$QADA_VERSION-$QADA_ABI.apk"
done
(
  cd "$QADA_RELEASE_DIR"
  sha256sum ./*.apk > SHA256SUMS
)
printf 'Checked release files: %s\n' "$QADA_RELEASE_DIR"
