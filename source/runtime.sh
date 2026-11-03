#!/bin/bash
set -euo pipefail
ROOT="${QWEN_LOCAL_DATA:-$HOME/Library/Application Support/QwenLocal}"
export UV_PYTHON_INSTALL_DIR="$ROOT/python"
MODEL="${2:-mlx-community/Qwen3.5-9B-4bit}"
export HF_HOME="$ROOT/cache"
mkdir -p "$ROOT"
case "${1:-}" in
setup)
 if [ -x "$ROOT/venv/bin/python" ] && "$ROOT/venv/bin/python" -c "import mlx_lm" >/dev/null 2>&1; then
  echo "Ambiente já preparado."
  exit 0
 fi
 /usr/bin/python3 -m pip install --disable-pip-version-check --target "$ROOT/bootstrap" 'uv>=0.8,<1'
 export PYTHONPATH="$ROOT/bootstrap"
 /usr/bin/python3 -m uv venv --python 3.12 "$ROOT/venv"
 /usr/bin/python3 -m uv pip install --python "$ROOT/venv/bin/python" mlx-lm==0.32.2 huggingface-hub==2.4.0
 "$ROOT/venv/bin/python" -c 'import mlx_lm; print("Ambiente pronto.")'
 ;;
download)
 if [ -d "$MODEL" ]; then echo "Pasta local selecionada; download não necessário."; exit 0; fi
 "$ROOT/venv/bin/python" -c 'from huggingface_hub import snapshot_download; import sys; snapshot_download(sys.argv[1])' "$MODEL"
 ;;
start)
 "$ROOT/venv/bin/python" -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",12345)); s.close()' || { echo "A porta 12345 está ocupada. Encerre o outro servidor antes de iniciar."; exit 1; }
 export HF_HUB_OFFLINE=1
 export TRANSFORMERS_OFFLINE=1
 exec "$ROOT/venv/bin/python" -m mlx_lm server --model "$MODEL" --host 127.0.0.1 --port 12345 --allowed-origins http://127.0.0.1:12345 --prompt-cache-size 1 --decode-concurrency 1 --prompt-concurrency 1 --prefill-step-size 512
 ;;
*) exit 2 ;;
esac
