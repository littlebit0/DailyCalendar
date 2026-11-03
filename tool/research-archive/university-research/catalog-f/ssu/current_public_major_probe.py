"""Current normal major controls; public educational table fields only."""
from pathlib import Path
from html.parser import HTMLParser
import json, re

ROOT = Path(__file__).resolve().parent
state = {'__file__': str(ROOT / 'current_public_chapel_identity_probe.py')}
exec((ROOT / 'current_public_chapel_identity_probe.py').read_text().split('tab=next')[0], state)

class Options(HTMLParser):
    def __init__(self, ident):
        super().__init__()
        self.ident, self.depth, self.items = ident, 0, []
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'div':
            if self.depth: self.depth += 1
            elif attrs.get('id') == self.ident: self.depth = 1
        if self.depth and attrs.get('ct') == 'LIB_I':
            self.items.append((attrs['data-itemkey'], attrs.get('data-itemvalue1', '')))
    def handle_endtag(self, tag):
        if tag == 'div' and self.depth: self.depth -= 1

def options(ident):
    parser = Options(ident)
    parser.feed(state['content'](state['b']))
    return parser.items

# These selectors are published on the current loaded anonymous form.
choices = {q['id']: q for q in state['controls'](state['b']) if q.get('ct') == 'CB'}
assert 'WD0103' in choices and 'WD0113' in choices
colleges = options('WD0104')
assert colleges
college, college_name = next((k, v) for k, v in colleges if v == '인문대학')
state['event']('ComboBox', 'Select', {'Id': 'WD0103', 'Key': college, 'ByEnter': 'false'})
departments = options('WD0114')
assert departments
department, department_name = next((k, v) for k, v in departments if '국어국문' in v)
state['event']('ComboBox', 'Select', {'Id': 'WD0113', 'Key': department, 'ByEnter': 'false'})
search = next(q for q in state['controls'](state['b']) if q.get('ct') == 'B' and "0:'검색'" in q.get('lsdata', ''))
state['event']('Button', 'Press', {'Id': search['id']})
rows = state['education'](state['b'])
allowed = ['이수구분(주전공)', '이수구분(다전공)', '공학인증', '과목번호', '과목명', '수강유의사항', '강좌유형정보', '분반', '교수명', '개설학과', '시간/학점(설계)', '강의시간(강의실)', '수강대상', '교과영역']
rows = [{k: v for k, v in row.items() if k in allowed} for row in rows]
out = {'retrievedDate': '2026-10-08', 'academicYear': 2026, 'semester': '2', 'collegeName': college_name, 'departmentName': department_name, 'rows': rows, 'anonymousFlowResponseHashes': state['requests'], 'normalPublicControlsOnly': True, 'rawSessionSaved': False}
(ROOT / 'ssu-current-public-korean-major-20261008.json').write_text(json.dumps(out, ensure_ascii=False, indent=2) + '\n')
print({'currentPublicMajorRows': len(rows), 'department': department_name})

if __name__ == '__main__':
    import subprocess
    from urllib.parse import urlsplit
    selected = {'2150465001', '2150465002', '2150523302', '2150523201'}
    buttons = []
    for raw in re.findall(r'<tr\b[^>]*>(.*?)</tr>', state['content'](state['b']), re.S):
        ident = re.search(r'(?<!\d)(\d{10})(?!\d)', raw)
        cells = re.findall(r'<td\b[^>]*role="gridcell"[^>]*>(.*?)</td>', raw, re.S)
        if ident and ident[1] in selected:
            buttons.append((ident[1], re.findall(r'id="([^"]+)"[^>]*ct="B"', cells[0])[0]))
    assert len(buttons) == 4
    plans = []
    for course_id, button in buttons:
        response = state['event']('Button', 'Press', {'Id': button})
        window_url = re.search(r'"url":"([^"]+)"', response)[1]
        window_url = re.sub(r'\\x([0-9a-fA-F]{2})', lambda m: chr(int(m[1], 16)), window_url)
        assert urlsplit(window_url).hostname == 'office.ssu.ac.kr'
        result = subprocess.run([
            '/Users/kimhwi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node',
            str(ROOT / 'public_report_headless_probe.cjs'),
        ], input=json.dumps([{'nativeCourseId': course_id, 'url': window_url}]), text=True, capture_output=True, timeout=90)
        if result.returncode:
            print({'stoppedNativeId': course_id, 'safeErrorClasses': [v for v in ['Missing educational field', 'Current identity mismatch', 'Protective response stop', 'Protected report stop', 'Timeout'] if v in result.stderr]}, flush=True)
            raise RuntimeError('Stopped at public report validation boundary')
        parsed = json.loads(result.stdout)
        plans.extend(parsed['publicTeachingFields'])
        (ROOT / 'ssu-current-public-korean-major-plans-20261008.json').write_text(json.dumps({'retrievedDate': '2026-10-08', 'normalPublicButtonsOnly': True, 'publicTeachingFields': plans, 'allFourSampledPlansReviewed': len(plans) == 4, 'sourceOperatingActivation': False}, ensure_ascii=False, indent=2) + '\n')
        print('Whitelisted current major teacher plan', course_id, flush=True)
