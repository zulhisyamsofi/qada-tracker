#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
# Run dart format lib test before this check if changing code.
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
