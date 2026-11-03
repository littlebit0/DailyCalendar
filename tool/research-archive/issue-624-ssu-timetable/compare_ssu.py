# 재수집한 zcmw2100 결과(raw/)를 자산 ssu-main-2026-2.json과 대조한다.
import re, html, json, sys, collections
from pathlib import Path

RAW = Path(sys.argv[1]); ASSET = Path(sys.argv[2]); OUT = Path(sys.argv[3])
index = json.loads((RAW / 'index.json').read_text())
rows, queries = [], []
for q in index:
    s = (RAW / q['file']).read_text()
    table = re.search(r'ct="ST" lsdata="\{2:(\d+),3:(\d+)', s)
    if not table:
        queries.append({**q, 'reported': 0, 'received': 0}); continue
    count, columns = map(int, table.groups())
    headers = []
    for raw in re.findall(r'<th\b[^>]*role="columnheader"[^>]*>(.*?)</th>', s, re.S):
        t = re.search(r'ct="CP"[^>]*>(.*?)</span>', raw, re.S)
        headers.append(html.unescape(re.sub('<[^>]+>', ' ', t[1] if t else raw)).strip())
    assert len(headers) == columns, (q['file'], headers)
    mine = []
    for raw in re.findall(r'<tr\b[^>]*>(.*?)</tr>', s, re.S):
        cells = re.findall(r'<td\b[^>]*role="gridcell"[^>]*>(.*?)</td>', raw, re.S)
        values = [html.unescape(re.sub('<[^>]+>', ' ', x)).replace('\xa0', ' ').strip() for x in cells]
        if len(values) == columns:
            r = dict(zip(headers, values))
            if re.fullmatch(r'\d{10}', r.get('과목번호', '')):
                r['_tab'] = q['tab']; r['_query'] = q.get('name', ''); mine.append(r)
    assert len(mine) == count, (q['file'], len(mine), count)
    rows += mine
    queries.append({**q, 'reported': count, 'received': len(mine)})

by = collections.defaultdict(list)
for r in rows: by[r['과목번호']].append(r)
asset = json.loads(ASSET.read_text())
courses = {c['sourceId'].rsplit('/', 1)[1]: c for c in asset['courses']}
new_ids, old_ids = set(by), set(courses)
FIELDS = ['과목명', '교수명', '강의시간(강의실)', '개설학과', '이수구분(주전공)', '강좌유형정보']
changed = []
for i in sorted(new_ids & old_ids):
    old = courses[i]['sourceEducation']['allPublicQueryEducation']
    for f in FIELDS:
        a = sorted({r.get(f, '') for r in by[i]}); b = sorted({r.get(f, '') for r in old})
        if a != b: changed.append({'id': i, 'field': f, 'now': a, 'asset': b})
tabs = collections.Counter(r['_tab'] for r in rows)
report = {
    'queries': len(queries), 'rows': len(rows), 'uniqueNow': len(new_ids), 'asset': len(old_ids),
    'onlyNow': sorted(new_ids - old_ids), 'onlyAsset': sorted(old_ids - new_ids),
    'onlyNowDetail': [{k: by[i][0].get(k) for k in ['과목번호', '과목명', '개설학과', '강의시간(강의실)', '_tab', '_query']} for i in sorted(new_ids - old_ids)],
    'onlyAssetDetail': [{'id': i, 'name': courses[i]['courseName'], 'dept': courses[i]['departments']} for i in sorted(old_ids - new_ids)],
    'rowsByTab': tabs, 'changedFieldCount': collections.Counter(c['field'] for c in changed), 'changed': changed,
    'teamRows': {t: sorted({(r['_tab'], r['_query']) for r in rows if r.get('개설학과') == t})
                 for t in ['AI교육팀', '교육혁신팀', '진로취업팀', '창업교육지원팀', '현장실습지원팀']},
    'emptyQueries': [q['file'] for q in queries if q['reported'] == 0],
}
OUT.write_text(json.dumps(report, ensure_ascii=False, indent=1, default=list) + '\n')
print({k: (v if not isinstance(v, list) or len(v) < 15 else len(v)) for k, v in report.items() if k not in ('changed', 'onlyNowDetail', 'onlyAssetDetail')})
