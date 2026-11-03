"""Continue current published Korean-major plan coverage without changing frozen v2."""
from pathlib import Path
from urllib.parse import urlsplit
import runpy, re, json, subprocess, hashlib

ROOT = Path(__file__).resolve().parent
context = runpy.run_path(str(ROOT / 'current_public_major_probe.py'))
state, rows = context['state'], context['rows']
previous = {'2150465001', '2150465002', '2150523302', '2150523201'}
selected = {r['과목번호'] for r in rows if r['강의시간(강의실)'] and r['과목번호'] not in previous}
assert len(selected) == 20
buttons = []
for raw in re.findall(r'<tr\b[^>]*>(.*?)</tr>', state['content'](state['b']), re.S):
    native = re.search(r'(?<!\d)(\d{10})(?!\d)', raw)
    cells = re.findall(r'<td\b[^>]*role="gridcell"[^>]*>(.*?)</td>', raw, re.S)
    if native and native[1] in selected:
        buttons.append((native[1], re.findall(r'id="([^"]+)"[^>]*ct="B"', cells[0])[0]))
assert len(buttons) == 20
path = ROOT / 'ssu-current-public-korean-major-next20-plans-20261008.json'
plans = []
out = {'retrievedDate': '2026-10-08', 'normalAnonymousPublishedButtonsOnly': True, 'rawStateOrParametersSaved': False, 'publicTeachingFields': plans, 'all20RequestedPlansReviewed': False, 'sourceOperatingActivation': False}
for native, button in buttons:
    response = state['event']('Button', 'Press', {'Id': button})
    window_url = re.search(r'"url":"([^"]+)"', response)[1]
    window_url = re.sub(r'\\x([0-9a-fA-F]{2})', lambda m: chr(int(m[1], 16)), window_url)
    assert urlsplit(window_url).hostname == 'office.ssu.ac.kr'
    rendered = subprocess.run([
        '/Users/kimhwi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node',
        str(ROOT / 'public_report_headless_probe.cjs'),
    ], input=json.dumps([{'nativeCourseId': native, 'url': window_url}]), text=True, capture_output=True, timeout=90)
    if rendered.returncode:
        out['stoppedNativeId'] = native
        out['safeErrorClasses'] = [v for v in ['Missing educational field', 'Current identity mismatch', 'Protective response stop', 'Protected report stop', 'Timeout', 'Whitelist privacy violation'] if v in rendered.stderr]
        path.write_text(json.dumps(out, ensure_ascii=False, indent=2) + '\n')
        print({'stoppedNativeId': native, 'safeErrorClasses': out['safeErrorClasses']}, flush=True)
        raise RuntimeError('Stop at published report validation boundary')
    plan = json.loads(rendered.stdout)['publicTeachingFields']
    assert len(plan) == 1 and plan[0]['nativeCourseId'] == native
    plans.extend(plan)
    out['all20RequestedPlansReviewed'] = len(plans) == 20
    out['anonymousFlowResponseHashes'] = state['requests']
    path.write_text(json.dumps(out, ensure_ascii=False, indent=2) + '\n')
    print('Verified public current plan', native, flush=True)
print({'newPublicPlans': len(plans), 'educationSHA256': hashlib.sha256(path.read_bytes()).hexdigest(), 'frozenCandidateModified': False})
