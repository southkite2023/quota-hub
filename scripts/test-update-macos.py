import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time

archive, installer = map(lambda p: str(Path(p).resolve()), sys.argv[1:])
root = Path(tempfile.mkdtemp(prefix='astracct-update-test-'))
installed = root / 'Installed App With Spaces.app'
unpacked = root / 'source'
subprocess.run(['/usr/bin/ditto', '-x', '-k', archive, str(unpacked)], check=True)
shutil.copytree(unpacked / 'Astracct.app', installed, symlinks=True)
marker = installed / 'Contents/Resources/old-bundle-marker.txt'
marker.write_text('old bundle')
waiter = subprocess.Popen(['/bin/sleep', '2'])
threading.Thread(target=waiter.wait, daemon=True).start()
subprocess.run(['/bin/sh', installer, archive, str(installed), str(waiter.pid), '1.3.0'], check=True, timeout=80)
assert not marker.exists()
backups = list(root.glob('Installed App With Spaces.app.previous-*'))
assert len(backups) == 1 and (backups[0] / 'Contents/Resources/old-bundle-marker.txt').exists()
time.sleep(3)
def pids_for_app():
    data = subprocess.check_output(['/bin/ps', '-axo', 'pid=,command='], text=True)
    return [int(line.strip().split(None,1)[0]) for line in data.splitlines() if str(installed / 'Contents/MacOS/Astracct') in line]
pids = pids_for_app()
assert pids, 'Updated app did not remain running'
for pid in pids: os.kill(pid, signal.SIGTERM)
time.sleep(1)
# Inject a move failure after backup to test the actual rollback branch in isolation.
marker.write_text('preserve on failure')
bin_dir = root / 'bin'; bin_dir.mkdir()
shim = bin_dir / 'mv'
shim.write_text('#!/bin/sh\ncase "$1" in */unpacked/Astracct.app) exit 11;; esac\nexec /bin/mv "$@"\n')
shim.chmod(0o755)
waiter = subprocess.Popen(['/bin/sleep','2'])
threading.Thread(target=waiter.wait, daemon=True).start()
result = subprocess.run(['/bin/sh', installer, archive, str(installed), str(waiter.pid), '1.3.0'], env={**os.environ,'PATH':str(bin_dir)+':'+os.environ['PATH']}, timeout=80)
assert result.returncode != 0
assert marker.read_text() == 'preserve on failure'
time.sleep(1)
for pid in pids_for_app(): os.kill(pid, signal.SIGTERM)
print('ASTRACCT_MACOS_UPDATE_PASS: identity/version, spaces in path, replacement, backup, relaunch, rollback')
