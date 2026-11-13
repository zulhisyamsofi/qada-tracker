#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
./scripts/setup_jdk.sh
source scripts/env.sh
javac -version
# Flutter 3.38.5 stable, pinned to its exact release commit.
if [[ ! -d "$FLUTTER_ROOT/.git" ]]; then
  git clone --depth 1 --branch 3.38.5 https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
fi
[[ "$(git -C "$FLUTTER_ROOT" rev-parse HEAD)" == f6ff1529fd6d8af5f706051d9251ac9231c83407 ]] || { echo 'Unexpected Flutter version. Use the pinned 3.38.5 checkout.' >&2; exit 1; }
# Downloads Dart and Flutter engine artifacts from storage.googleapis.com.
flutter --version
flutter config --no-analytics
if [[ ! -x "$ANDROID_HOME/cmdline-tools/19.0/bin/sdkmanager" ]]; then
  QADA_DOWNLOAD="$(mktemp -d)"
  trap 'rm -rf "$QADA_DOWNLOAD"' EXIT
  curl -fSL --retry 2 https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip -o "$QADA_DOWNLOAD/tools.zip"
  # Checksum published in Google's repository2-1.xml for cmdline-tools;19.0.
  echo "5fdcc763663eefb86a5b8879697aa6088b041e70  $QADA_DOWNLOAD/tools.zip" | sha1sum -c -
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  unzip -q "$QADA_DOWNLOAD/tools.zip" -d "$QADA_DOWNLOAD/unpacked"
  mv "$QADA_DOWNLOAD/unpacked/cmdline-tools" "$ANDROID_HOME/cmdline-tools/19.0"
fi
python3 scripts/android_sdk.py
flutter config --android-sdk "$ANDROID_HOME"
flutter precache --android
flutter pub get --enforce-lockfile
# Flutter writes ignored android/local.properties on the first run/build.
flutter doctor -v
