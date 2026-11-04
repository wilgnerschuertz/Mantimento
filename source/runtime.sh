#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Keep old overrides and existing data for upgrades from Qwen Local.
if [ -n "${MANTIMENTO_DATA:-}" ]; then
 ROOT="$MANTIMENTO_DATA"
elif [ -n "${QWEN_LOCAL_DATA:-}" ]; then
 ROOT="$QWEN_LOCAL_DATA"
elif [ -d "$HOME/Library/Application Support/Mantimento" ]; then
 ROOT="$HOME/Library/Application Support/Mantimento"
elif [ -d "$HOME/Library/Application Support/QwenLocal" ]; then
 ROOT="$HOME/Library/Application Support/QwenLocal"
else
 ROOT="$HOME/Library/Application Support/Mantimento"
fi
export UV_PYTHON_INSTALL_DIR="$ROOT/python"
MODEL="${2:-mlx-community/Qwen3.5-9B-4bit}"
export HF_HOME="$ROOT/cache"
export MANTIMENTO_DATA="$ROOT"
mkdir -p "$ROOT"
case "${1:-}" in
setup)
 if [ "$(/usr/bin/uname -m)" != "arm64" ]; then
  echo "Esta versão requer um Mac Apple Silicon (M1 ou posterior)."; exit 1
 fi
 UV="$ROOT/tools/uv"
 export UV_CACHE_DIR="$ROOT/cache/uv"
 if [ ! -x "$UV" ]; then
  bootstrap_tmp="$(/usr/bin/mktemp -d "$ROOT/bootstrap.XXXXXX")"
  trap '/bin/rm -rf "$bootstrap_tmp"' EXIT
  /usr/bin/curl --proto '=https' --tlsv1.2 -fL --retry 2 --connect-timeout 20 -o "$bootstrap_tmp/uv.tar.gz" https://github.com/astral-sh/uv/releases/download/0.13.7/uv-aarch64-apple-darwin.tar.gz
  echo "81b811b57e4624df7ed3aac148e0359100d9962f3d9dce00aec533dc2e086731  $bootstrap_tmp/uv.tar.gz" | /usr/bin/shasum -a 256 -c -
  /usr/bin/tar -xzf "$bootstrap_tmp/uv.tar.gz" -C "$bootstrap_tmp"
  /bin/mkdir -p "$ROOT/tools"
  /bin/cp "$bootstrap_tmp/uv-aarch64-apple-darwin/uv" "$UV"
  /bin/chmod +x "$UV"
 fi
 if [ -x "$ROOT/venv/bin/python" ] && "$ROOT/venv/bin/python" -c "import mlx_lm" >/dev/null 2>&1; then
  echo "Ambiente já preparado."
  exit 0
 fi
 "$UV" venv --python 3.12 "$ROOT/venv"
 "$UV" pip install --python "$ROOT/venv/bin/python" -r "$SCRIPT_DIR/requirements-macos-arm64.txt"
 "$ROOT/venv/bin/python" -c 'import mlx_lm; print("Ambiente pronto.")'
 ;;
download|remove)
 if [ -d "$MODEL" ]; then echo "Pasta local selecionada; download não necessário."; exit 0; fi
 exec "$ROOT/venv/bin/python" "$SCRIPT_DIR/model_manager.py" "$1" "$MODEL"
 ;;
packages)
 bash "$SCRIPT_DIR/runtime.sh" setup
 bash "$SCRIPT_DIR/prepare_offline.sh"
 ;;
kit)
 exec "$ROOT/venv/bin/python" "$SCRIPT_DIR/offline_kit.py"
 ;;
start)
 "$ROOT/venv/bin/python" -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",12345)); s.close()' || { echo "A porta 12345 está ocupada. Encerre o outro servidor antes de iniciar."; exit 1; }
 export HF_HUB_OFFLINE=1
 export TRANSFORMERS_OFFLINE=1
 exec "$ROOT/venv/bin/python" -m mlx_lm server --model "$MODEL" --host 127.0.0.1 --port 12345 --allowed-origins http://127.0.0.1:12345 --prompt-cache-size 1 --decode-concurrency 1 --prompt-concurrency 1 --prefill-step-size 512
 ;;
*) exit 2 ;;
esac
