"""Compile tests against the actual Store and tools, using an isolated data folder."""
import os
from pathlib import Path
import subprocess
import tempfile

project = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='qwen-agent-test-') as temporary:
    root = Path(temporary)
    store = (project/'source/App.swift').read_text().split('struct MessageView: View {')[0]
    store = store.replace('FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("QwenLocal")', 'URL(fileURLWithPath:ProcessInfo.processInfo.environment["TEST_DATA"]!)')
    store = store.replace('http://127.0.0.1:12345','http://127.0.0.1:12346')
    agent = (project/'source/Agent.swift').read_text()
    agent = agent.replace('guard let script = Bundle.main.url(forResource:"command_runner",withExtension:"py") else { throw LocalTools.failure("Executor ausente no aplicativo.") }', 'let script = URL(fileURLWithPath:ProcessInfo.processInfo.environment["TEST_RUNNER"]!)')
    agent = agent.replace('dataDir.appendingPathComponent("venv/bin/python")', 'URL(fileURLWithPath:ProcessInfo.processInfo.environment["TEST_PYTHON"]!)')
    (root/'Store.swift').write_text(store)
    (root/'Agent.swift').write_text(agent)
    binary = root/'test'
    subprocess.run(['swiftc','-parse-as-library',str(root/'Store.swift'),str(root/'Agent.swift'),str(project/'tests/TestMain.swift'),'-o',str(binary)],check=True)
    env = dict(os.environ,TEST_DATA=str(root/'data'),TEST_RUNNER=str(project/'source/command_runner.py'),TEST_PYTHON='/usr/bin/python3')
    subprocess.run([str(binary)],env=env,check=True,timeout=300)
