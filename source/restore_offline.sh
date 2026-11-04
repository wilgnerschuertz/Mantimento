#!/bin/bash
set -euo pipefail
KIT="$(cd -- "$(dirname -- "$0")" && pwd)"
DEST="${1:-$HOME/Library/Application Support/Mantimento}"
if [ "$(uname -m)" != arm64 ]; then echo 'Requer Apple Silicon.'; exit 1; fi
if [ -e "$DEST" ]; then echo 'Destino já existe. Escolha uma pasta nova para não sobrescrever dados.'; exit 1; fi
cd "$KIT"
if [ -e INCOMPLETO ] || [ ! -s SHA256SUMS ]; then echo 'Kit incompleto; exporte novamente.'; exit 1; fi
/usr/bin/shasum -a 256 -c SHA256SUMS >/dev/null
mkdir -p "$(dirname -- "$DEST")"
/usr/bin/ditto "$KIT/data" "$DEST"
# Recreate the venv at its final absolute path; never copy an old venv.
PYTHON="$(find "$DEST/python" -type f -name python3.12 -path '*/bin/*' -print -quit)"
if [ -z "$PYTHON" ]; then echo 'Python gerenciado não encontrado.'; exit 1; fi
export UV_PYTHON_INSTALL_DIR="$DEST/python"
export UV_OFFLINE=1
"$DEST/tools/uv" venv --offline --python "$PYTHON" "$DEST/venv"
"$DEST/tools/uv" pip install --offline --no-index --find-links "$DEST/offline-wheels" --python "$DEST/venv/bin/python" -r "$DEST/offline-wheels/requirements-macos-arm64.txt"
"$DEST/venv/bin/python" -c 'import mlx_lm; print("Ambiente restaurado sem internet.")'
echo "Dados restaurados em: $DEST"
echo 'Copie Mantimento.app para Aplicativos. Para um destino personalizado, use MANTIMENTO_DATA ao executar o runtime.'
