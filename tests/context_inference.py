"""Real-model summary integration, isolated chats; requires installed Qwen3.5 9B.
Usage: python3 tests/context_inference.py DATA_ROOT
"""
from pathlib import Path
import os
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request

root = Path(sys.argv[1])
project = Path(__file__).resolve().parents[1]
with socket.socket() as sock:
    sock.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
    sock.bind(('127.0.0.1',12346))  # Fail instead of touching an existing test server.
env = dict(os.environ, HF_HOME=str(root/'cache'), HF_HUB_OFFLINE='1', TRANSFORMERS_OFFLINE='1', TEST_SUMMARY_REAL='1')
with tempfile.TemporaryFile(mode='w+') as log:
    server = subprocess.Popen([str(root/'venv/bin/python'),'-m','mlx_lm','server','--model','mlx-community/Qwen3.5-9B-4bit','--host','127.0.0.1','--port','12346','--prompt-cache-size','1','--decode-concurrency','1','--prompt-concurrency','1','--prefill-step-size','512'],env=env,stdout=log,stderr=log)
    try:
        deadline = time.monotonic()+90
        while True:
            if server.poll() is not None:
                log.seek(0); raise RuntimeError(log.read()[-3000:])
            try:
                with urllib.request.urlopen('http://127.0.0.1:12346/v1/models',timeout=2) as response:
                    if response.status == 200: break
            except OSError:
                if time.monotonic()>deadline: raise TimeoutError('Server readiness')
                time.sleep(0.5)
        subprocess.run([sys.executable,str(project/'tests/run.py')],env=env,check=True,timeout=360)
    finally:
        server.terminate()
        try: server.wait(timeout=15)
        except subprocess.TimeoutExpired: server.kill(); server.wait()
