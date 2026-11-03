"""Published public plan buttons only, ephemeral viewer parameters, teaching whitelist."""
import runpy, re, json, hashlib, subprocess
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent
query = runpy.run_path(str(ROOT / 'current_public_chapel_identity_probe.py'))
text = query['content'](query['b'])
buttons = []
for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>', text, re.S):
    course_id = re.search(r'(?<!\d)(21500785\d{2})(?!\d)', row)
    cells = re.findall(r'<td\b[^>]*role="gridcell"[^>]*>(.*?)</td>', row, re.S)
    if not course_id or not cells:
        continue
    public_button = re.findall(r'id="([^"]+)"[^>]*ct="B"', cells[0])
    assert len(public_button) == 1
    buttons.append((course_id[1], public_button[0]))
assert len(buttons) == 12

# Follow each button immediately, matching the normal public viewer lifecycle.
# Generating a batch of report windows first can invalidate the prior window.
plans = []
for course_id, button in buttons:
    response = query['event']('Button', 'Press', {'Id': button})
    window_url = re.search(r'"url":"([^"]+)"', response)[1]
    window_url = re.sub(r'\\x([0-9a-fA-F]{2})', lambda m: chr(int(m[1], 16)), window_url)
    assert urlsplit(window_url).hostname == 'office.ssu.ac.kr'
    result = subprocess.run([
        '/Users/kimhwi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node',
        str(ROOT / 'public_report_headless_probe.cjs'),
    ], input=json.dumps([{'nativeCourseId': course_id, 'url': window_url}]), text=True, capture_output=True, timeout=90)
    if result.returncode:
        safe_categories = [v for v in ['Missing educational field', 'Current identity mismatch', 'Protective response stop', 'Protected report stop', 'Timeout', 'Whitelist privacy violation'] if v in result.stderr]
        print({'stoppedNativeId': course_id, 'failureCategories': safe_categories}, flush=True)
        raise RuntimeError('Public viewer failed; no raw renderer result saved')
    out = json.loads(result.stdout)
    assert len(out['publicTeachingFields']) == 1
    plans.extend(out['publicTeachingFields'])
    print('Whitelisted current teaching plan', course_id, flush=True)
    checkpoint = {'retrievedDate': '2026-10-08', 'normalPublicControlsOnly': True, 'rawViewerOrSessionSaved': False, 'publicTeachingFields': plans, 'wholeRequested12Complete': len(plans)==12}
    (ROOT/'ssu-current-public-chapel-plans-progress-20261008.json').write_text(json.dumps(checkpoint,ensure_ascii=False,indent=2)+'\n')
out['publicTeachingFields'] = plans
assert len(plans) == 12
out['retrievedDate'] = '2026-10-08'
out['publicEntryUrl'] = query['URL']
out['currentHeaderAndIdentityValidated'] = True
out['anonymousFlowResponseHashes'] = query['requests']
out['privateFieldsExcluded'] = ['contact', 'office', 'staff identifiers', 'report parameters', 'session', 'raw canvas/report', 'screenshots']
path = ROOT / 'ssu-current-public-chapel-plans-20261008.json'
path.write_text(json.dumps(out, ensure_ascii=False, indent=2) + '\n')
print({'currentPublicTeacherPlans': 12, 'educationalEvidenceSHA256': hashlib.sha256(path.read_bytes()).hexdigest(), 'productionModified': False})
