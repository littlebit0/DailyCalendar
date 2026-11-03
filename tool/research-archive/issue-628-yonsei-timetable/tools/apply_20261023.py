"""2026-10-23 재조회 결과를 연세 시간표 자산에 반영한다.
- 새로 폐강(rmvlcYn=1)된 강좌 제거
- 바뀐 강좌는 원문 필드(sourceEducation·교수·학점·시간·강의실·유의사항)를 새 원문으로 교체
- 일정: 시간·강의실·수업유형이 바뀐 강좌만 다시 판정. 강의실만 바뀌면 같은 날짜·시각에 새 강의실,
  수업유형이 대면 → 블랜디드(동영상)로 바뀌면 기존 규칙대로 보류(빈 일정). 해석으로 새 일정을 만들지 않는다.
- 모든 강좌의 자료 기준일 문구를 재조회 날짜로 갱신
"""
import collections, json, sys
from pathlib import Path
WT = Path(sys.argv[1]); RAW = Path(sys.argv[2]); DIFF = json.loads(Path(sys.argv[3]).read_text())
FIELDS = ['sysinstDivCd','orgSysinstDivCd','campsBusnsCd','campsDivNm','subjtnb','corseDvclsNo','prctsCorseDvclsNo','subjtnbCorsePrcts','subjtNm','subjtEngNm','cgprfNm','cgprfEngNm','cdt','hy','rcognHrs','subsrtDivNm','estblDeprtNm','subjtClNm','srclnLctreLangDivNm','lctreTimeNm','lecrmNm','atntnMattrDesc','lessnSessnDivNm','rmvlcYn','rmvlcYnNm','syy','smtDivCd']
OLD_DATE = '2026-10-07 정상 공개 조회의 자료이며 이후 전체 변경은 미확인입니다.'
NEW_DATE = '2026-10-07 정상 공개 조회 자료를 2026-10-23 재조회로 전체 대조했으며 이후 변경은 미확인입니다.'
MIXED = '온라인·혼합 수업의 개별 운영 날짜를 확인하지 못했습니다.'
new = collections.defaultdict(list)
for s in json.loads((RAW/'scopes.json').read_text()):
    for r in json.loads((RAW/f"{s['campus']}-{s['collegeCode']}-{s['departmentCode'] or 'all'}.json").read_text())['dsSles251']:
        new[(r['sysinstDivCd'], r['subjtnb'], r['corseDvclsNo'], r['prctsCorseDvclsNo'])].append({k: r.get(k) for k in FIELDS})
closed = {tuple(k) for k in DIFF['removed']}
changed = {tuple(k) for ks in DIFF['changed'].values() for k in ks}
seen_closed, seen_changed, log = set(), set(), []
def fix_note(text, old, new_row):
    o, n = old.get('atntnMattrDesc') or '', new_row.get('atntnMattrDesc') or ''
    assert text.startswith(o), text[:80]
    text = n + text[len(o):]
    text = text.replace(f"수업 유형: {old['subjtClNm'] or '미공개'};", f"수업 유형: {new_row['subjtClNm'] or '미공개'};")
    return text
for campus in ['sinchon', 'international', 'mirae', 'unknown']:
    p = WT/f'assets/timetable/yonsei-{campus}-2026-2.json'
    d = json.loads(p.read_text())
    d['publishedDate'] = '2026-10-23'
    out = []
    for c in d['courses']:
        e = c['sourceEducation'][0]
        key = (e['sysinstDivCd'], e['subjtnb'], e['corseDvclsNo'], e['prctsCorseDvclsNo'])
        if key in closed:
            assert new[key][0]['rmvlcYn'] == '1'
            seen_closed.add(key); log.append(f'폐강 제거 {campus} {"/".join(key)} {c["courseName"]} ({c["scheduleStatus"]})'); continue
        if key in changed:
            seen_changed.add(key)
            old, rows = e, new[key]
            assert len(rows) == len(c['sourceEducation']) and {r['estblDeprtNm'] for r in rows} == {x['estblDeprtNm'] for x in c['sourceEducation']}
            first = rows[0]
            c['sourceEducation'] = rows
            c['professor'] = first['cgprfNm'] or ''
            c['credits'] = first['cdt']
            c['departmentCredits'] = {k: first['cdt'] for k in c['departmentCredits']}
            c['sourceSchedule'] = first['lctreTimeNm'] or ''
            c['sourceClassroom'] = first['lecrmNm'] or ''
            c['remarks'] = fix_note(c['remarks'], old, first)
            c['departmentRemarks'] = {k: fix_note(v, old, first) for k, v in c['departmentRemarks'].items()}
            if c['schedules']:
                if old['subjtClNm'] != first['subjtClNm'] or old['lctreTimeNm'] != first['lctreTimeNm']:
                    assert (first['subjtClNm'] or '').strip() not in {'대면강의', '비대면(실시간)'}
                    c['schedules'] = []; c['scheduleStatus'] = 'unrecognized'
                    c['remarks'] += '\n일정 보류: ' + MIXED
                    c['departmentRemarks'] = {k: v + '\n일정 보류: ' + MIXED for k, v in c['departmentRemarks'].items()}
                elif old['lecrmNm'] != first['lecrmNm']:
                    assert '/' not in old['lecrmNm'] and '/' not in first['lecrmNm']
                    for m in c['schedules']:
                        assert m['classroom'] == old['lecrmNm']; m['classroom'] = first['lecrmNm']
            log.append(f'변경 {campus} {"/".join(key)} {c["courseName"]} -> {c["scheduleStatus"]}, 일정 {len(c["schedules"])}')
        for k in ['remarks']:
            assert OLD_DATE in c[k]; c[k] = c[k].replace(OLD_DATE, NEW_DATE)
        c['departmentRemarks'] = {k: v.replace(OLD_DATE, NEW_DATE) for k, v in c['departmentRemarks'].items()}
        # 바뀌지 않은 강좌의 원문은 재조회와 완전히 같아야 한다.
        if key not in changed:
            assert sorted(map(lambda x: json.dumps(x, sort_keys=True, ensure_ascii=False), c['sourceEducation'])) == \
                   sorted(map(lambda x: json.dumps(x, sort_keys=True, ensure_ascii=False), new[key])), key
        out.append(c)
    d['courses'] = out
    p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + '\n')
assert seen_closed == closed and seen_changed == changed, (closed - seen_closed, changed - seen_changed)
print('\n'.join(log))
