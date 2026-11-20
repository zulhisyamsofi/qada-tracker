#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh
python3 - <<'VERIFY'
from pathlib import Path
import hashlib
assert hashlib.sha256(Path('web/sqlite3.wasm').read_bytes()).hexdigest() == '922a76b182b6af69b030c8e2fdd3283ecc8e827248b20e4b1f3f3db170b52117', 'Unexpected SQLite WASM artifact'
VERIFY
flutter pub get
flutter build web --target lib/demo_main.dart --no-web-resources-cdn --pwa-strategy=none --no-wasm-dry-run
python3 - <<'PY'
from pathlib import Path
import zipfile
root = Path('build/web')
output = Path('build/qada-tracker-web-demo.zip')
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(root.rglob('*')):
        if file.is_file():
            archive.write(file, file.relative_to(root))
print(output)
PY
