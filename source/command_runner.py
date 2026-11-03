"""Run one local agent command with bounded captured output and group cancellation."""
import json
import os
import signal
import subprocess
import sys
import threading

child = None

def stop(*_):
    if child and child.poll() is None:
        try:
            os.killpg(child.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    raise SystemExit(130)


def main():
    global child
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    args = json.load(sys.stdin)
    env = dict(os.environ)
    env['PATH'] = os.path.dirname(sys.executable) + os.pathsep + env.get('PATH', '/usr/bin:/bin')
    child = subprocess.Popen(
        ['/bin/zsh', '-c', args['command']], cwd=args['workspace'], env=env,
        stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    captured = bytearray()

    def drain():
        while True:
            data = child.stdout.read(4096)
            if not data:
                return
            remaining = 16000 - len(captured)
            if remaining > 0:
                captured.extend(data[:remaining])

    reader = threading.Thread(target=drain, daemon=True)
    reader.start()
    timed_out = False
    try:
        child.wait(timeout=min(int(args.get('timeout', 60)), 120))
    except subprocess.TimeoutExpired:
        timed_out = True
        os.killpg(child.pid, signal.SIGKILL)
        child.wait()
    # Commands are finite jobs; clean up background processes in this group.
    try:
        os.killpg(child.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    reader.join(timeout=3)
    print(json.dumps({'exit_code': child.returncode, 'timeout': timed_out,
                      'output': captured.decode('utf-8', errors='replace')}))

if __name__ == '__main__':
    main()
