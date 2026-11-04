#!/bin/bash
set -euo pipefail
HERE="$(cd -- "$(dirname -- "$0")" && pwd)"
ROOT="${MANTIMENTO_DATA:?}"
UV="$ROOT/tools/uv"
if [ ! -x "$UV" ]; then
 echo 'Execute Preparar ambiente primeiro. Se o ambiente for antigo, o kit precisa do uv oficial.'
 exit 1
fi
TMP="$(mktemp -d "$ROOT/offline-packages.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export UV_PYTHON_INSTALL_DIR="$ROOT/python"
"$UV" pip install --python "$ROOT/venv/bin/python" --target "$TMP/pip" 'pip==25.3'
mkdir -p "$ROOT/offline-wheels"
PYTHONPATH="$TMP/pip" "$ROOT/venv/bin/python" -m pip download --only-binary=:all: --dest "$ROOT/offline-wheels" -r "$HERE/requirements-macos-arm64.txt"
cp "$HERE/requirements-macos-arm64.txt" "$ROOT/offline-wheels/requirements-macos-arm64.txt"
echo 'Pacotes offline preparados. Agora exporte o kit.'
