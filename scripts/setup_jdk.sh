#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
QADA_JDK="$QADA_TOOLS/java/jdk-17.0.17+10"
if [[ ! -x "$QADA_JDK/bin/javac" ]]; then
  QADA_JDK_DOWNLOAD="$(mktemp -d)"
  trap 'rm -rf "$QADA_JDK_DOWNLOAD"' EXIT
  QADA_JDK_URL='https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.17%2B10/OpenJDK17U-jdk_x64_linux_hotspot_17.0.17_10.tar.gz'
  curl -fSL --retry 2 "$QADA_JDK_URL" -o "$QADA_JDK_DOWNLOAD/jdk.tar.gz"
  curl -fsSL "$QADA_JDK_URL.sha256.txt" -o "$QADA_JDK_DOWNLOAD/checksum.txt"
  python3 - "$QADA_JDK_DOWNLOAD" <<'PY'
import hashlib, pathlib, sys
root = pathlib.Path(sys.argv[1])
expected = (root / 'checksum.txt').read_text().split()[0]
with (root / 'jdk.tar.gz').open('rb') as archive:
    if hashlib.file_digest(archive, 'sha256').hexdigest() != expected:
        raise SystemExit('Official JDK SHA-256 mismatch')
PY
  mkdir -p "$QADA_TOOLS/java"
  tar -xzf "$QADA_JDK_DOWNLOAD/jdk.tar.gz" -C "$QADA_TOOLS/java"
fi
# Trust the environment's supplied public CA, preserving the JDK's normal roots.
if [[ -n "${CODEX_PROXY_CERT:-}" && -f "$CODEX_PROXY_CERT" ]]; then
  if ! "$QADA_JDK/bin/keytool" -list -cacerts -storepass changeit -alias qada-cloud-proxy >/dev/null 2>&1; then
    "$QADA_JDK/bin/keytool" -importcert -trustcacerts -cacerts -storepass changeit -noprompt -alias qada-cloud-proxy -file "$CODEX_PROXY_CERT"
  fi
fi
"$QADA_JDK/bin/javac" -version
