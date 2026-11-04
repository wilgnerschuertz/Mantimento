"""Benchmark the installed Mac runtime without changing user chats or preferences.
Usage: python3 tests/benchmark.py DATA_ROOT OUTPUT.json
Uses an isolated local server, cached weights only, and synthetic prompts.
"""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request

WORKER = r'''
import json, os, runpy, threading, time
import mlx.core as mx

def sample():
    with open(os.environ['BENCH_MEMORY'], 'w', buffering=1) as f:
        while True:
            f.write(json.dumps({'time':time.time(), 'active':mx.get_active_memory(),
                'cache':mx.get_cache_memory(), 'peak':mx.get_peak_memory()})+'\n')
            time.sleep(0.25)
threading.Thread(target=sample,daemon=True).start()
runpy.run_module('mlx_lm',run_name='__main__')
'''

def system_memory():
    return {key:subprocess.check_output(command,text=True).strip() for key,command in {
        'pressure':['memory_pressure','-Q'], 'swap':['sysctl','vm.swapusage']}.items()}

def main():
    root, output = map(Path, sys.argv[1:3])
    output.parent.mkdir(parents=True,exist_ok=True)
    with socket.socket() as sock:
        sock.bind(('127.0.0.1',0)); port = sock.getsockname()[1]
    endpoint = f'http://127.0.0.1:{port}'
    model = 'mlx-community/Qwen3.5-9B-4bit'
    versions = json.loads(subprocess.check_output([str(root/'venv/bin/python'),'-c',
        'import importlib.metadata,json; print(json.dumps({n:importlib.metadata.version(n) for n in ["mlx","mlx-lm","mlx-metal"]}))'],text=True))
    result = {'runtime_versions':versions, 'model':model,'hardware':subprocess.check_output(['sysctl','-n','machdep.cpu.brand_string'],text=True).strip(),
              'ram_bytes':int(subprocess.check_output(['sysctl','-n','hw.memsize'])),
              'before':system_memory(), 'requests':[]}
    with tempfile.TemporaryDirectory(prefix='mantimento-benchmark-') as temporary:
        folder = Path(temporary); memory = folder/'memory.jsonl'
        worker = folder/'worker.py'; worker.write_text(WORKER)
        env = dict(os.environ,HF_HOME=str(root/'cache'),HF_HUB_OFFLINE='1',TRANSFORMERS_OFFLINE='1',BENCH_MEMORY=str(memory))
        with (folder/'server.log').open('w') as log:
            server = subprocess.Popen([str(root/'venv/bin/python'),str(worker),'server','--model',model,
                '--host','127.0.0.1','--port',str(port),'--allowed-origins',endpoint,
                '--prompt-cache-size','1','--decode-concurrency','1','--prompt-concurrency','1','--prefill-step-size','512'],
                env=env,stdout=log,stderr=log)
            rss = []; done = threading.Event()
            def sample_rss():
                while not done.wait(0.5):
                    value = subprocess.run(['ps','-o','rss=','-p',str(server.pid)],capture_output=True,text=True).stdout.strip()
                    if value.isdigit(): rss.append({'time':time.time(),'bytes':int(value)*1024})
            observer = threading.Thread(target=sample_rss,daemon=True); observer.start()
            try:
                ready = time.monotonic()
                while True:
                    if server.poll() is not None: raise RuntimeError((folder/'server.log').read_text()[-3000:])
                    try:
                        with urllib.request.urlopen(endpoint+'/v1/models',timeout=2) as response:
                            if response.status == 200: break
                    except OSError:
                        if time.monotonic()-ready > 120: raise TimeoutError('Server readiness')
                        time.sleep(0.5)
                result['server_ready_seconds'] = time.monotonic()-ready
                prompt = 'Explique em português como organizar uma cópia offline de documentos importantes. Dê cinco passos concretos e explique cada um.'
                cases = [('first_request',prompt,160),('warm_repeat',prompt,160),('crud','Escreva um exemplo mínimo em Python e SQLite com funções para criar, listar, atualizar e excluir tarefas. Use somente a biblioteca padrão e mostre o código.',256)]
                for name,prompt,limit in cases:
                    payload = {'model':'default_model','messages':[{'role':'system','content':'Responda em português de forma clara e útil.'},{'role':'user','content':prompt}],
                        'temperature':0,'max_tokens':limit,'stream':True,'stream_options':{'include_usage':True},'chat_template_kwargs':{'enable_thinking':False}}
                    req = urllib.request.Request(endpoint+'/v1/chat/completions',data=json.dumps(payload).encode(),headers={'Content-Type':'application/json'})
                    start_wall = time.time(); start = time.monotonic(); first = None; text = ''; usage = {}; finish = None
                    with urllib.request.urlopen(req,timeout=600) as response:
                        for line in response:
                            if not line.startswith(b'data:'): continue
                            data = line[5:].strip()
                            if data == b'[DONE]': break
                            event = json.loads(data)
                            if 'error' in event: raise RuntimeError(event['error'])
                            if event.get('usage'): usage = event['usage']
                            for choice in event.get('choices',[]):
                                chunk = choice.get('delta',{}).get('content') or ''
                                if chunk:
                                    if first is None: first = time.monotonic()-start
                                    text += chunk
                                finish = choice.get('finish_reason') or finish
                    elapsed = time.monotonic()-start
                    assert first is not None and usage.get('completion_tokens',0)>0, 'Missing response or usage'
                    samples = [json.loads(line) for line in memory.read_text().splitlines() if line.endswith('}')]
                    samples = [x for x in samples if x['time'] >= start_wall]
                    entry = {'name':name,'first_text_seconds':first,'total_seconds':elapsed,'usage':usage,'finish_reason':finish,
                        'decode_tokens_per_second_approx':max(0,usage['completion_tokens']-1)/max(0.001,elapsed-first),
                        'rss_peak_bytes':max((x['bytes'] for x in rss if x['time']>=start_wall),default=0),
                        'mlx_active_peak_bytes':max((x['active'] for x in samples),default=0),
                        'mlx_cache_peak_bytes':max((x['cache'] for x in samples),default=0),
                        'mlx_allocator_peak_bytes':max((x['peak'] for x in samples),default=0), 'answer':text}
                    result['requests'].append(entry)
                    output.write_text(json.dumps(result,ensure_ascii=False,indent=2))
                    print(json.dumps({k:v for k,v in entry.items() if k!='answer'},ensure_ascii=False),flush=True)
                result['loaded_idle'] = system_memory()
            finally:
                stop = time.monotonic(); server.terminate()
                try: server.wait(timeout=15)
                except subprocess.TimeoutExpired: server.kill(); server.wait()
                done.set(); observer.join(timeout=2)
                result['shutdown_seconds'] = time.monotonic()-stop
                result['server_exited'] = server.poll() is not None
                result['after_shutdown'] = system_memory()
                output.write_text(json.dumps(result,ensure_ascii=False,indent=2))
    print('Saved:',output,flush=True)

if __name__ == '__main__': main()
