"""Recheck the actual published public form; keep only education data."""
import hashlib
import json
import pathlib
import time
import urllib.parse
import urllib.request

P = pathlib.Path(__file__).resolve().parent
BASE = 'https://welcome.dgist.ac.kr/ucs/ucsqProfRespSbjtInq/'
ALLOWED = {key for curriculum in ['2020', '2024', '2014']
           for row in json.loads((P / f'dgist2026-2-{curriculum}-curriculum-rows.json').read_text())
           for key in row}
ALLOWED -= {'PROF_NO', 'EMP_NO', 'CHRG_NO', 'USER_ID', 'EMAIL', 'TEL', 'PROF_ID'}
audit = []
for curriculum in ['2020', '2024', '2014']:
    form = {
        'pageNum': '1', 'pageSize': '99999',
        'commonProgramId': 'UcsqProfRespSbjtInq',
        'searchOrgnClsfDcd': 'CMN12.03', 'searchLang': 'ko',
        'selectYearTerm': '2026CMN17.20', 'searchCuriShyy': curriculum,
        'searchCors': '', 'searchSust': '', 'searchCptnDcd': '',
        'searchSbjtDetaDcd': '', 'searchSbNo': '', 'searchProfNm': '',
    }
    time.sleep(0.7)
    request = urllib.request.Request(BASE + 'list.do', data=urllib.parse.urlencode(form).encode())
    with urllib.request.urlopen(request, timeout=35) as response:
        data = json.loads(response.read())
    rows = data['user']
    assert int(data['records']) == len(rows) and int(data['total']) <= 1
    assert all(str(row['SHYY']) == '2026' and row['SHTM_DCD'] == 'CMN17.20' for row in rows)
    safe = [{k: v for k, v in row.items() if k in ALLOWED} for row in rows]
    old = json.loads((P / f'dgist2026-2-{curriculum}-curriculum-rows.json').read_text())
    before = {(x['SBJT_NO'], x['CLSS_NO']): x for x in old}
    after = {(x['SBJT_NO'], x['CLSS_NO']): x for x in safe}
    assert len(after) == len(safe)
    file = P / f'dgist2026-2-{curriculum}-current-recheck-20261008.json'
    file.write_text(json.dumps(safe, ensure_ascii=False, indent=2))
    audit.append({
        'curriculum': curriculum, 'publicForm': form, 'sourceUrl': BASE + 'list.do',
        'currentCount': len(safe), 'previousCount': len(old),
        'added': sorted(set(after) - set(before)), 'removed': sorted(set(before) - set(after)),
        'changedEducationalRows': [list(key) for key in sorted(set(after) & set(before)) if after[key] != before[key]],
        'path': file.name, 'sha256': hashlib.sha256(file.read_bytes()).hexdigest(),
        'actualAttendanceVerified': False, 'completionClaim': False,
    })
    print(curriculum, len(safe), 'changes', len(audit[-1]['changedEducationalRows']), flush=True)
(P / 'dgist-current-recheck-audit-20261008.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2))
