import json
import os
import re
import signal
import subprocess
import time
import urllib.parse
import urllib.request
from pathlib import Path

os.umask(0o077)
out = Path(__file__).resolve().parent
executable = str(Path.home() / 'Applications/Daily Test.app/Contents/MacOS/Daily Test')
processes = subprocess.check_output(['ps', '-axo', 'pid=,args='], text=True)
for line in processes.splitlines():
    entry = line.strip().split(None, 1)
    if len(entry) == 2 and entry[1] == executable:
        os.kill(int(entry[0]), signal.SIGTERM)
time.sleep(1)
started = time.monotonic()
log = out / 'mac-runtime.log'
with log.open('w') as stream:
    process = subprocess.Popen([executable], stdout=stream, stderr=stream, start_new_session=True)
(out / 'mac-pid').write_text(str(process.pid))
base = None
while time.monotonic() - started < 45:
    match = re.search(r'http://127\.0\.0\.1:\d+/[^\s]+/', log.read_text(errors='replace'))
    if match:
        base = match[0]
        break
    if process.poll() is not None:
        raise RuntimeError('Mac test app exited before VM inspection')
    time.sleep(0.5)
if base is None:
    raise RuntimeError('VM inspection endpoint unavailable; runtime log kept private')
(out / 'vm-uri').write_text(base)

def rpc(method, **params):
    with urllib.request.urlopen(base + method + '?' + urllib.parse.urlencode(params), timeout=5) as response:
        data = json.load(response)
    if 'error' in data:
        raise RuntimeError('VM read operation failed: ' + method)
    return data['result']

isolate = next(x['id'] for x in rpc('getVM')['isolates'] if x['name'] == 'main')
def obj(ref):
    return rpc('getObject', isolateId=isolate, objectId=ref)

def fields(instance):
    return {x['decl']['name']: x['value'] for x in instance.get('fields', [])}

def value(field):
    return field.get('valueAsString', field.get('kind'))

classes = rpc('getClassList', isolateId=isolate)['classes']
def instances(name):
    matches = [x for x in classes if x['name'] == name]
    return [obj(i['id']) for c in matches for i in rpc('getInstances', isolateId=isolate, objectId=c['id'], limit=5).get('instances', [])]

samples = []
while time.monotonic() - started < 120:
    statuses = instances('GoogleDriveSyncService')
    gates = instances('_StartupSyncGateState')
    if statuses and gates:
        status_ref = fields(obj(fields(statuses[0])['statusNotifier']['id']))['_value']['id']
        status = fields(obj(status_ref))
        gate = fields(gates[0])
        sample = {
            'elapsedSeconds': round(time.monotonic() - started, 2),
            'syncing': value(status['syncing']),
            'hasError': status['error'].get('kind') != 'Null',
            'gateReady': value(gate['_ready']),
            'message': value(status['message']),
        }
        samples.append(sample)
        if sample['gateReady'] == 'true' and sample['syncing'] == 'false':
            break
    time.sleep(1)
report = {
    'pid': process.pid,
    'authorizedExistingAccountStartup': True,
    'newLoginOrAccountChange': False,
    'final': samples[-1] if samples else None,
    'samples': samples,
}
(out / 'mac-live-verification.json').write_text(json.dumps(report, indent=2, ensure_ascii=False))
print(json.dumps({k: v for k, v in report.items() if k != 'samples'}, ensure_ascii=False))
