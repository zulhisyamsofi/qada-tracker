#!/usr/bin/env bash
# Source this file; do not change HOME or rely on live processes surviving a task.
QADA_TOOLS="${QADA_TOOLS:-/workspace/toolchains}"
if [[ -d "$QADA_TOOLS/java/jdk-17.0.17+10" ]]; then
  export JAVA_HOME="$QADA_TOOLS/java/jdk-17.0.17+10"
  export PATH="$JAVA_HOME/bin:$PATH"
fi
export FLUTTER_ROOT="$QADA_TOOLS/flutter"
export ANDROID_HOME="$QADA_TOOLS/android"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="$QADA_TOOLS/android-user"
export ANDROID_AVD_HOME="$ANDROID_USER_HOME/avd"
export GRADLE_USER_HOME="$QADA_TOOLS/gradle"
export PUB_CACHE="$QADA_TOOLS/pub-cache"
export XDG_CONFIG_HOME="$QADA_TOOLS/config"
export PATH="$FLUTTER_ROOT/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/19.0/bin:$PATH"
mkdir -p "$ANDROID_USER_HOME/cache" "$GRADLE_USER_HOME" "$PUB_CACHE" "$XDG_CONFIG_HOME"
# Java/Gradle do not automatically honor HTTPS_PROXY. Preserve the session route.
if [[ -n "${HTTPS_PROXY:-}" ]]; then
  QADA_JAVA_PROXY="$(python3 - <<'PY'
import os, urllib.parse
p = urllib.parse.urlsplit(os.environ['HTTPS_PROXY'])
if p.hostname and p.port:
    print(f'-Dhttps.proxyHost={p.hostname} -Dhttps.proxyPort={p.port} -Dhttp.proxyHost={p.hostname} -Dhttp.proxyPort={p.port} -Dhttp.nonProxyHosts=localhost|127.*')
PY
)"
  export GRADLE_OPTS="${GRADLE_OPTS:-} $QADA_JAVA_PROXY"
fi
# sqlite3's Linux FFI loader expects the unversioned soname. Reuse the
# image's verified system library without requiring a system-wide dev package.
if [[ "$(uname -s)" == Linux ]] && command -v ldconfig >/dev/null; then
  QADA_SQLITE_LIB="$(ldconfig -p | awk '/libsqlite3.so.0 / { if (!found) { lib=$NF; found=1 } } END { print lib }')"
  if [[ -n "$QADA_SQLITE_LIB" ]]; then
    mkdir -p "$QADA_TOOLS/native"
    ln -sfn "$QADA_SQLITE_LIB" "$QADA_TOOLS/native/libsqlite3.so"
    export LD_LIBRARY_PATH="$QADA_TOOLS/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  fi
fi
