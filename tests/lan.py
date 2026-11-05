"""Loopback-only integration of the native LAN gateway and real Store coordination.
Default uses a mock model; --real DATA_ROOT uses an installed model.
User chats/preferences are isolated and all listeners bind loopback.
"""
import concurrent.futures
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request

project = Path(__file__).resolve().parents[1]
started = threading.Event()
received = []
class Model(BaseHTTPRequestHandler):
    def log_message(self,*args): pass
    def do_POST(self):
        obj = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        received.append(obj); started.set(); time.sleep(0.8)
        data = json.dumps({'model':'/private/internal/path','choices':[{'message':{'role':'assistant','content':'Resposta local de teste','tool_calls':[{'fake':True}]},'finish_reason':'stop'}],'usage':{'completion_tokens':5}}).encode()
        try:
            self.send_response(200); self.send_header('Content-Type','application/json'); self.send_header('Content-Length',str(len(data))); self.end_headers(); self.wfile.write(data)
        except BrokenPipeError: pass

model = None; engine = None
if '--real' in sys.argv:
    data_root = Path(sys.argv[sys.argv.index('--real')+1])
    with socket.socket() as probe:
        probe.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
        probe.bind(('127.0.0.1',12346))
    engine = subprocess.Popen([str(data_root/'venv/bin/python'),'-m','mlx_lm','server','--model','mlx-community/Qwen3.5-9B-4bit','--host','127.0.0.1','--port','12346','--prompt-cache-size','1','--decode-concurrency','1','--prompt-concurrency','1','--prefill-step-size','512'],env=dict(os.environ,HF_HOME=str(data_root/'cache'),HF_HUB_OFFLINE='1',TRANSFORMERS_OFFLINE='1'),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
else:
    model = ThreadingHTTPServer(('127.0.0.1',12346),Model)
    threading.Thread(target=model.serve_forever,daemon=True).start()
try:
    with tempfile.TemporaryDirectory(prefix='mantimento-lan-test-') as temporary:
        root = Path(temporary)
        app = root/'LANTest.app/Contents'; (app/'MacOS').mkdir(parents=True); (app/'Resources').mkdir()
        for name in ['web.html','web.js']: (app/'Resources'/name).write_bytes((project/'source'/name).read_bytes())
        (app/'Info.plist').write_text('<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>LANTest</string><key>CFBundleIdentifier</key><string>local.mantimento.lan-test</string></dict></plist>')
        store = (project/'source/App.swift').read_text().split('final class Delegate:')[0]
        store = store.replace('StoragePaths.dataDirectory()', 'URL(fileURLWithPath:ProcessInfo.processInfo.environment["TEST_DATA"]!)')
        store = store.replace('let current = UserDefaults.standard','let current = UserDefaults(suiteName:"mantimento-lan-test-" + ProcessInfo.processInfo.environment["TEST_DATA"]!)!')
        store = store.replace('http://127.0.0.1:12345','http://127.0.0.1:12346')
        (root/'Store.swift').write_text(store)
        binary = app/'MacOS/LANTest'
        subprocess.run(['swiftc','-parse-as-library',str(root/'Store.swift'),str(project/'source/Agent.swift'),str(project/'source/LANServer.swift'),str(project/'source/LANStore.swift'),str(project/'tests/LANMain.swift'),'-o',str(binary)],check=True)
        ready = root/'ready.json'
        with (root/'test.log').open('w+') as log:
            proc = subprocess.Popen([str(binary)],env=dict(os.environ,TEST_DATA=str(root/'data'),TEST_READY=str(ready)),stdout=log,stderr=log)
            try:
                deadline = time.monotonic()+20
                while not ready.exists():
                    if proc.poll() is not None or time.monotonic()>deadline:
                        log.seek(0); raise RuntimeError(log.read())
                    time.sleep(0.1)
                token = json.loads(ready.read_text())['key']
                if engine is not None:
                    deadline = time.monotonic()+90
                    while True:
                        if engine.poll() is not None: raise RuntimeError('Model server failed')
                        try:
                            with urllib.request.urlopen('http://127.0.0.1:12346/v1/models',timeout=2) as response:
                                if response.status == 200: break
                        except OSError:
                            if time.monotonic()>deadline: raise TimeoutError('Model server readiness')
                            time.sleep(0.5)
                    payload = {'model':'mantimento','messages':[{'role':'user','content':'Responda apenas com o número: quanto é 2 + 2?'}],'max_tokens':32,'stream':False}
                    req = urllib.request.Request('http://127.0.0.1:18765/v1/chat/completions',data=json.dumps(payload).encode(),headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'})
                    with urllib.request.urlopen(req,timeout=180) as response: answer = json.load(response)
                    assert '4' in answer['choices'][0]['message']['content']
                    assert answer['model']=='mantimento'
                    print('PASSOU: API autenticada nativa com Qwen3.5 9B real: '+answer['choices'][0]['message']['content'],flush=True)
                    if '--preview' not in sys.argv: sys.exit(0)
                if '--preview' in sys.argv:
                    print('PREVIEW_READY '+str(ready),flush=True)
                    time.sleep(900)
                    sys.exit(0)

                def request(path,body=None,key=token,headers=None):
                    h={'Authorization':'Bearer '+key,'Content-Type':'application/json'}
                    if headers: h.update(headers)
                    req=urllib.request.Request('http://127.0.0.1:18765'+path,data=json.dumps(body).encode() if body is not None else None,headers=h)
                    try: response=urllib.request.urlopen(req,timeout=10)
                    except urllib.error.HTTPError as error: response=error
                    return response.status,response.read(),response.headers
                def raw(value):
                    with socket.create_connection(('127.0.0.1',18765),timeout=5) as conn:
                        conn.sendall(value); result=b''
                        while True:
                            data=conn.recv(65536)
                            if not data: return result
                            result+=data
                for path in ['/api/status','/v1/models','/v1/chat/completions']:
                    assert request(path,key='invalid')[0]==401
                assert request('/api/status',headers={'Origin':'http://evil.example'})[0]==403
                assert request('/api/status',headers={'Host':'evil.example:18765'})[0]==403
                assert request('/api/status')[0]==200
                assert request('/v1/models')[0]==200
                code,html,headers=request('/',key='')
                assert code==200 and b'web.js' in html and 'no-store' in headers['Cache-Control']
                assert 'frame-ancestors' in headers['Content-Security-Policy'] and b'<script>' not in html
                assert request('/web.js',key='')[0]==200
                assert request('/../../etc/passwd')[0]==404
                payload={'model':'mantimento','messages':[{'role':'user','content':'Teste'}],'max_tokens':32,'stream':False}
                invalid=[dict(payload,tools=[]),dict(payload,stream=True),dict(payload,max_tokens=3000),dict(payload,max_tokens=True),dict(payload,model=3),dict(payload,messages=[{'role':'tool','content':'x'}]),dict(payload,messages=[{'role':'user','content':'🌱'*5000}])]
                for body in invalid: assert request('/v1/chat/completions',body)[0]==400
                assert request('/v1/chat/completions',payload,headers={'Content-Type':'text/plain'})[0]==415
                assert b'400 Bad Request' in raw(b'POST /v1/chat/completions HTTP/1.1\r\nHost: 127.0.0.1:18765\r\nContent-Length: 2\r\nContent-Length: 2\r\n\r\n{}')
                assert b'400 Bad Request' in raw(b'POST /v1/chat/completions HTTP/1.1\r\nHost: 127.0.0.1:18765\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n\r\n')
                assert b'400 Bad Request' in raw(b'POST /v1/chat/completions HTTP/1.1\r\nHost: 127.0.0.1:18765\r\nContent-Length: 999999999\r\n\r\n')
                request('/test/local-busy')
                assert request('/v1/chat/completions',payload)[0]==409
                request('/test/local-idle'); request('/test/off')
                assert request('/v1/chat/completions',payload)[0]==503
                request('/test/on'); started.clear()
                with concurrent.futures.ThreadPoolExecutor() as pool:
                    pending=pool.submit(request,'/v1/chat/completions',payload)
                    assert started.wait(3)
                    assert request('/v1/chat/completions',payload)[0]==409
                    assert json.loads(request('/test/assert-local-blocked')[1])['blocked']
                    code,data,_=pending.result()
                    result=json.loads(data)
                    assert code==200 and result['model']=='mantimento' and 'tool_calls' not in result['choices'][0]['message']
                assert received[-1]['model']=='default_model' and not received[-1]['stream'] and 'tools' not in received[-1]
                assert not json.loads(request('/api/status')[1])['busy']
                # Client disconnect must keep the inference lease until the backend finishes.
                started.clear(); body=json.dumps(payload).encode()
                conn=socket.create_connection(('127.0.0.1',18765),timeout=5)
                conn.sendall((f'POST /v1/chat/completions HTTP/1.1\r\nHost: 127.0.0.1:18765\r\nAuthorization: Bearer {token}\r\nContent-Type: application/json\r\nContent-Length: {len(body)}\r\n\r\n').encode()+body)
                assert started.wait(3); conn.close()
                assert json.loads(request('/api/status')[1])['busy']
                time.sleep(1)
                assert not json.loads(request('/api/status')[1])['busy']
                for _ in range(65): last=request('/api/status')[0]
                assert last==429
                print('PASSOU: autenticação, origem/host, recursos offline, rotas, limites, HTTP malformado, modelo desligado, exclusão mútua local/remota, desconexão, sanitização e rate limit.')
            finally:
                proc.terminate(); proc.wait(timeout=10)
finally:
    if model is not None: model.shutdown(); model.server_close()
    if engine is not None:
        engine.terminate()
        try: engine.wait(timeout=15)
        except subprocess.TimeoutExpired: engine.kill(); engine.wait()
