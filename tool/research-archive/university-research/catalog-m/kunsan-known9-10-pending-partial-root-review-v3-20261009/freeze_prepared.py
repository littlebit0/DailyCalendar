import hashlib
import json
import pathlib

out = pathlib.Path(__file__).resolve().parent
files = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.iterdir())
    if p.is_file() and p.name != 'SHA256SUMS.json'}
(out / 'SHA256SUMS.json').write_text(json.dumps({'files': files, 'researchOnly': True,
    'completionClaim': False, 'productionApplied': False, 'sdkUsed': False,
    'actualDartVerification': 'PREPARED_NOT_RUN', 'pythonVerification': 'PASS',
    'native': 1718, 'scheduled': 1125, 'appointments': 22984, 'addedScheduled': 1,
    'addedAppointments': 13, 'otherWholePreserved': 1717}, ensure_ascii=False, indent=2) + '\n')
print(hashlib.sha256((out/'SHA256SUMS.json').read_bytes()).hexdigest())
