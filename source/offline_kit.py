"""Export a self-contained kit; omit secrets, logs and personal data by default."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time


def export(root, destination, app, personal=False):
    root, destination, app = map(lambda p: Path(p).resolve(), (root, destination, app))
    if destination == root or root in destination.parents:
        raise ValueError('Salve o kit fora da pasta de dados do Mantimento.')
    required = ['tools/uv', 'python', 'offline-wheels/requirements-macos-arm64.txt']
    for name in required:
        if not (root / name).exists():
            raise ValueError('Prepare o ambiente e os pacotes offline antes de exportar: ' + name)
    if not list((root / 'offline-wheels').glob('*.whl')):
        raise ValueError('Pacotes offline ausentes.')
    subprocess.run([str(root / 'tools/uv'), 'pip', 'install', '--dry-run', '--reinstall',
                    '--offline', '--no-index', '--find-links', str(root / 'offline-wheels'),
                    '--python', str(root / 'venv/bin/python'), '-r',
                    str(Path(__file__).with_name('requirements-macos-arm64.txt'))], check=True)
    names = ['tools', 'python', 'offline-wheels', 'cache/hub']
    if personal:
        names += ['conversations.json', 'history.json', 'Workspaces']
    sources = [root / n for n in names if (root / n).exists()] + [app]
    # Reject external/broken links. Python's internal links are copied as files so
    # the managed interpreter remains relocatable within the kit.
    total = 0
    for source in sources:
        for p in ([source] if source.is_file() else source.rglob('*')):
            if p.is_symlink() and (not p.resolve().is_relative_to(source.resolve()) or (source.name == 'hub' and os.path.isabs(os.readlink(p)))):
                raise ValueError('Link externo não pode entrar no kit: ' + p.name)
            if p.is_file():
                total += p.stat().st_size
    if shutil.disk_usage(destination).free < total + 512 * 1024**2:
        raise ValueError('Espaço insuficiente para exportar o kit.')
    kit = destination / ('Mantimento-offline-' + time.strftime('%Y%m%d-%H%M%S'))
    kit.mkdir()
    (kit / 'INCOMPLETO').write_text('Não use antes de concluir a exportação.')
    for name in names:
        source, target = root / name, kit / 'data' / name
        if not source.exists():
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        print('Copiando ' + name, flush=True)
        if source.is_dir():
            shutil.copytree(source, target, symlinks=(name == 'cache/hub'), ignore=shutil.ignore_patterns('*.lock', '*.incomplete', '.locks', '.DS_Store'))
        else:
            shutil.copy2(source, target)
    shutil.copytree(app, kit / 'Mantimento.app', symlinks=True)
    shutil.copy2(Path(__file__).with_name('restore_offline.sh'), kit / 'restaurar.sh')
    (kit / 'LEIA-ME.txt').write_text(
        'Kit para Mac Apple Silicon. Sem Python pré-instalado.\n'
        'No Terminal: bash restaurar.sh\n'
        'O destino padrão é ~/Library/Application Support/Mantimento e deve estar ausente.\n'
        'Opcional: bash restaurar.sh "/caminho/novo"\n'
        'O script verifica hashes e recria o ambiente a partir dos wheels locais.\n'
        'Copie Mantimento.app para Aplicativos após restaurar.\n'
        'Conversas e Workspaces incluídos: ' + str(personal) + '\n'
        'Documentos em pastas externas não estão incluídos. Caminhos antigos de conversas podem precisar ser escolhidos novamente.\n'
        'Não redistribua modelos sem observar suas licenças. Este kit não é criptografado.\n')
    (kit / 'manifest.json').write_text(json.dumps({'format':1, 'personal':personal, 'platform':'macOS-arm64'}, indent=2))
    with (kit / 'SHA256SUMS').open('w') as output:
        for p in sorted(kit.rglob('*')):
            if p.is_file() and p.name not in ('SHA256SUMS', 'INCOMPLETO'):
                if '\n' in str(p.relative_to(kit)) or '\r' in str(p.relative_to(kit)):
                    raise ValueError('Nome de arquivo não suportado no manifesto.')
                with p.open('rb') as source:
                    digest = hashlib.file_digest(source, 'sha256').hexdigest()
                output.write(digest + '  ' + str(p.relative_to(kit)) + '\n')
    (kit / 'INCOMPLETO').unlink()
    print('Kit concluído: ' + str(kit), flush=True)
    return kit


if __name__ == '__main__':
    try:
        export(os.environ['MANTIMENTO_DATA'], os.environ['MANTIMENTO_KIT'], os.environ['MANTIMENTO_APP'], os.environ.get('MANTIMENTO_PERSONAL') == '1')
    except Exception as error:
        print('Falha ao exportar kit: ' + str(error), flush=True)
        raise SystemExit(1)
