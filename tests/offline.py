"""Integration test: export and restore a prepared root, with networking denied.
Usage: prepared-venv/bin/python tests/offline.py DATA_ROOT APP_PATH
Creates a temporary restore target; never modifies the source root.
"""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile

project = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('kit', project/'source/offline_kit.py')
kit_module = importlib.util.module_from_spec(spec); spec.loader.exec_module(kit_module)
root, app = map(Path, sys.argv[1:3])
with tempfile.TemporaryDirectory(prefix='mantimento-offline-test-') as temporary:
    base = Path(temporary)
    kit = kit_module.export(root,base,app)
    assert not (kit/'data/conversations.json').exists()
    assert not (kit/'data/cache/token').exists()
    assert not (kit/'data/venv').exists()
    restored = base/'restaurado com espaços'
    sandbox = ['sandbox-exec','-p','(version 1)(allow default)(deny network*)']
    subprocess.run(sandbox+['bash',str(kit/'restaurar.sh'),str(restored)],check=True)
    env = dict(os.environ,HF_HOME=str(restored/'cache'),HF_HUB_OFFLINE='1',TRANSFORMERS_OFFLINE='1')
    for model in ['mlx-community/Llama-3.2-3B-Instruct-4bit','mlx-community/Phi-4-mini-instruct-4bit']:
        subprocess.run(sandbox+[str(restored/'venv/bin/python'),str(project/'tests/inference.py'),model],env=env,check=True)
    # An existing destination is refused without changing it.
    result = subprocess.run(sandbox+['bash',str(kit/'restaurar.sh'),str(restored)])
    assert result.returncode != 0
    # Tampering is rejected before any target is created.
    (kit/'LEIA-ME.txt').write_text('alterado')
    second = base/'não deve existir'
    result = subprocess.run(sandbox+['bash',str(kit/'restaurar.sh'),str(second)])
    assert result.returncode != 0 and not second.exists()
    print('PASSOU: exportação sem dados pessoais, hashes, restauração sem rede, inferência dos dois modelos, destino protegido e adulteração recusada.')
