import glob
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CHECKOUT = ROOT / 'checkout'
REGISTRY = 'lib/core/academic/academic_source_registry.dart'

def git(*args, check=True):
    return subprocess.run(['git', *args], cwd=CHECKOUT, text=True, capture_output=True, check=check)

def registry_parts(text):
    imports = re.findall(r'^import .*;$', text, re.M)
    start = text.index('const academicSourceRegistrations')
    end = text.index('];', start)
    blocks = re.findall(r'  AcademicSourceRegistration\(\n.*?^  \),\n', text[start:end], re.M | re.S)
    entries = {}
    for block in blocks:
        key = re.search(r"id: '([^']+)'", block)[1]
        assert key not in entries, key
        entries[key] = block
    return imports, text[text.index('/// Links'):start], entries, text[end:]

def resolve_registry(first, second):
    a = registry_parts(first)
    b = registry_parts(second)
    assert a[1] == b[1] and a[3] == b[3], 'Non-registration logic differs'
    entries = dict(b[2])
    for key, block in a[2].items():
        assert key not in entries or entries[key] == block, key
        entries[key] = block
    return ('\n'.join(sorted(set(a[0] + b[0]))) + '\n\n' + a[1]
            + 'const academicSourceRegistrations = <AcademicSourceRegistration>[\n'
            + ''.join(entries.values()) + a[3])

prs = {}
for filename in glob.glob(str(ROOT / 'batch-*.json')):
    for result in json.loads(Path(filename).read_text()):
        value = result['value']
        prs[value['n']] = value['p']

prepared = json.loads((ROOT / 'prepared.json').read_text())
(ROOT / 'prepared.json').write_text(json.dumps(prepared, indent=2))
for number in sorted(prs):
    if number <= prepared[-1]['n'] or number == 520:
        continue
    assert not git('status', '--porcelain', '--untracked-files=no').stdout.strip()
    previous = git('rev-parse', 'HEAD').stdout.strip()
    pr = prs[number]
    git('switch', '--detach', pr['head_sha'])
    result = git('merge', '--no-commit', '--no-ff', previous, check=False)
    conflicts = git('diff', '--name-only', '--diff-filter=U').stdout.splitlines()
    if conflicts:
        assert conflicts == [REGISTRY], (number, conflicts)
        first = git('show', 'HEAD:' + REGISTRY).stdout
        second = git('show', previous + ':' + REGISTRY).stdout
        (CHECKOUT / REGISTRY).write_text(resolve_registry(first, second))
        git('add', REGISTRY)
    else:
        assert result.returncode == 0, result.stderr
    git('diff', '--cached', '--check', '--', REGISTRY)
    git('commit', '-m', f'학사일정 등록부 병합 충돌 해결 (#{number})')
    head = git('rev-parse', 'HEAD').stdout.strip()
    git('update-ref', f'refs/heads/Cottlebit/academic-merge-{number}', head)
    prepared.append({'n': number, 'original': pr['head_sha'], 'head': head, 'branch': pr['head']})
    (ROOT / 'prepared.json').write_text(json.dumps(prepared, indent=2))
    print(number, head, flush=True)
