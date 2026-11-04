"""Build an isolated visual fixture. Launch its .app through Finder/Codex UI.
Usage: python3 tests/layout_preview.py [fresh|chat]
No user chats, model server or real environment is used.
"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

project = Path(__file__).resolve().parents[1]
mode = sys.argv[1] if len(sys.argv) > 1 else 'chat'
assert mode in ('fresh','chat')
app = project/'dist/LayoutPreview.app'
resources = app/'Contents/Resources'; resources.mkdir(parents=True,exist_ok=True)
macos = app/'Contents/MacOS'; macos.mkdir(exist_ok=True)
data = Path(tempfile.mkdtemp(prefix='mantimento-visual-fixture-'))
with tempfile.TemporaryDirectory() as temporary:
    build = Path(temporary)
    source = (project/'source/App.swift').read_text().split('@main struct MantimentoApp:')[0]
    source = source.replace('let dataDir = StoragePaths.dataDirectory()', 'let dataDir = URL(fileURLWithPath:'+json.dumps(str(data))+')')
    (build/'Store.swift').write_text(source)
    fixture = '''
import SwiftUI
import AppKit
@main struct PreviewApp:App {
    @StateObject var store = Store()
    var body:some Scene { WindowGroup("Mantimento · revisão visual") {
        ContentView(store:store).onAppear {
            NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps:true)
            NSApp.windows.first?.setContentSize(NSSize(width:720,height:560))
            store.messages = []; store.conversations = []
            FIXTURE
        }
    }.defaultSize(width:720,height:560) }
}
'''
    if mode == 'chat':
        fixture = fixture.replace('FIXTURE','''
            store.modelID = "mlx-community/Modelo-com-nome-muito-longo-para-testar-a-interface-4bit"
            store.messages = [Message(role:"user",content:"Quero organizar meus documentos locais e criar um projeto com uma descrição muito longa para verificar a leitura."),
                Message(role:"assistant",content:(1...35).map { "## Etapa \\($0)\\nLeia e revise os arquivos locais antes de seguir. Mantenha uma cópia dos seus documentos e confira cada proposta.\\n" }.joined() + "\\n```swift\\nlet caminho = \\"Um exemplo de linha de código longa para conferir a rolagem horizontal sem empurrar a janela\\"\\n```",modelName:"Llama 3.2 3B")]
            store.save(); store.agentEnabled = true
            store.input = String(repeating:"Uma mensagem longa para conferir o crescimento do campo.\\n",count:12)
        ''')
    else:
        fixture = fixture.replace('FIXTURE','store.modelID = "mlx-community/Qwen3.5-2B-4bit"')
    (build/'Preview.swift').write_text(fixture)
    subprocess.run(['swiftc','-parse-as-library',str(build/'Store.swift'),str(project/'source/Agent.swift'),str(project/'source/AgentViews.swift'),str(project/'source/ChatViews.swift'),str(project/'source/SettingsView.swift'),str(build/'Preview.swift'),'-o',str(macos/'LayoutPreview')],check=True)
(app/'Contents/Info.plist').write_text('''<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>LayoutPreview</string><key>CFBundleIdentifier</key><string>local.mantimento.layout-preview</string><key>CFBundleName</key><string>LayoutPreview</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>''')
subprocess.run(['codesign','--force','--deep','--sign','-',str(app)],check=True)
print(app)
