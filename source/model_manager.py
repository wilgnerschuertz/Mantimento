"""Download/cache operations. No execution of repository Python code."""
import json
import os
from pathlib import Path
import re
import shutil
import sys
import threading
import time


def emit(**event):
    print('MANTIMENTO_EVENT ' + json.dumps(event), flush=True)


def repo_path(root, model):
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*', model):
        raise ValueError('Identificador inválido: use organização/modelo.')
    hub = root / 'cache/hub'
    repo = hub / ('models--' + model.replace('/', '--'))
    if hub.is_symlink() or repo.is_symlink():
        raise ValueError('Cache com link simbólico não pode ser gerenciado.')
    return repo


def download(root, model):
    from huggingface_hub import HfApi, snapshot_download
    repo = repo_path(root, model)
    # Fetch a revision once and pin both the size check and actual download to it.
    info = HfApi().model_info(model, files_metadata=True, token=False)
    expected = sum(f.size or 0 for f in info.siblings)
    existing = sum(p.stat().st_size for p in (repo / 'blobs').glob('*') if p.is_file())
    free = shutil.disk_usage(root).free
    if expected and free < max(0, expected - existing) + 512 * 1024**2:
        raise RuntimeError('Espaço insuficiente. Libere espaço e tente novamente.')
    done = threading.Event()
    def monitor():
        while not done.is_set():
            size = sum(p.stat().st_size for p in (repo / 'blobs').glob('*') if p.is_file())
            emit(kind='download', received=size, total=expected,
                 detail='Bytes no cache; verificação final ao concluir')
            done.wait(0.7)
    thread = threading.Thread(target=monitor, daemon=True)
    thread.start()
    try:
        snapshot_download(model, revision=info.sha, token=False)
        refs = repo / 'refs'
        if refs.is_symlink():
            raise ValueError('Referência de cache inválida.')
        refs.mkdir(parents=True, exist_ok=True)
        temporary = refs / 'main.mantimento'
        temporary.write_text(info.sha)
        os.replace(temporary, refs / 'main')
    finally:
        done.set()
        thread.join()
    emit(kind='complete', detail='Modelo baixado. Pronto para testar.')


def remove(root, model):
    repo = repo_path(root, model)
    if repo.exists():
        # New HF versions link per-repo blobs into a shared store. Materialize
        # those links first so restoring the folder from Trash remains valid.
        hub = (root / 'cache/hub').resolve()
        for blob in (repo / 'blobs').glob('*'):
            if blob.is_symlink():
                target = blob.resolve(strict=True)
                if not target.is_relative_to(hub):
                    raise ValueError('Link externo no cache; remoção recusada.')
                temporary = blob.with_name(blob.name + '.mantimento-copy')
                try:
                    os.link(target, temporary)
                except OSError:
                    shutil.copy2(target, temporary)
                os.replace(temporary, blob)
        # Trash is recoverable. Shared cache may remain; never purge unrelated blobs.
        trash = Path.home() / '.Trash'
        trash.mkdir(exist_ok=True)
        destination = trash / (repo.name + '-Mantimento-' + str(time.time_ns()))
        shutil.move(str(repo), str(destination))
    emit(kind='complete', detail='Modelo movido para a Lixeira do Mac.')


if __name__ == '__main__':
    try:
        root = Path(os.environ['MANTIMENTO_DATA'])
        {'download': download, 'remove': remove}[sys.argv[1]](root, sys.argv[2])
    except Exception as error:
        emit(kind='error', detail=str(error))
        sys.exit(1)
