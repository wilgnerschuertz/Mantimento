"""Deterministic SSE integration test; requires no model or external network."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import os
import subprocess
import threading
import time

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_POST(self):
        payload = json.loads(self.rfile.read(int(self.headers.get('Content-Length', 0))))
        time.sleep(0.35)  # Model load/prefill delay must count toward first text latency.
        if not payload.get('stream'):
            failure = '__SUMMARY_ERROR__' in json.dumps(payload)
            self.send_response(503 if failure else 200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            answer = {'choices':[{'message':{'role':'assistant','content':'Objetivo: CRUD offline. Decisão: SQLite. Pendente: testar backup. Releia os arquivos antes de editar.'},'finish_reason':'stop'}]}
            if '__SUMMARY_TRUNCATED__' in json.dumps(payload): answer['choices'][0]['finish_reason'] = 'length'
            if '__SUMMARY_OVERSIZE__' in json.dumps(payload): answer['choices'][0]['message']['content'] = 'x'*6001
            try:
                self.wfile.write(json.dumps(answer).encode())
            except BrokenPipeError:
                pass
            return
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.end_headers()
        for _ in range(200):
            event = {'choices': [{'delta': {'content': 'á'}, 'finish_reason': None}]}
            self.wfile.write(('data: ' + json.dumps(event) + '\n\n').encode())
            self.wfile.flush()
            time.sleep(0.001)
        self.wfile.write(b'data: [DONE]\n\n')
        self.wfile.flush()

server = ThreadingHTTPServer(('127.0.0.1', 12346), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    subprocess.run(['/usr/bin/python3', str(Path(__file__).with_name('run.py'))],
                   env=dict(os.environ, TEST_STREAM='1'), check=True, timeout=120)
finally:
    server.shutdown()
    server.server_close()
