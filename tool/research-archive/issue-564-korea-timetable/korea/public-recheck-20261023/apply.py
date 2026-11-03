import json, sys
RES, WT = sys.argv[1], sys.argv[2]
FIELDS = ['COUR_CD', 'COUR_CLS', 'DEPARTMENT', 'ISU_NM', 'COUR_NM', 'PROF_NM', 'TIME', 'TIME_ROOM', 'CREDIT', 'APPLY_DEPT', 'FLEXIBLE_SCHOOL_YN', 'FLEXIBLE_FR_DT', 'FLEXIBLE_TO_DT', 'MOOC_YN', 'NEMO_YN']
CHANGES = {('ARDE157', '00'): 'PROF_NM', ('NRSG288', '01'): 'PROF_NM', ('NRSG288', '02'): 'PROF_NM', ('SEDU309', '04'): 'PROF_NM', ('GESO157', '00'): 'COUR_NM'}
camp = {'1': 'seoul', '2': 'sejong'}
queries = []
fresh = {}
for line in open(RES):
    q = json.loads(line)
    c = camp[q['form']['pCampus']]
    f = q['form']
    queries.append({'campus': c, 'pCourDiv': f['pCourDiv'], 'pCol': f.get('pCol', ''), 'pDept': f.get('pDept', ''), 'pGroupCd': f.get('pGroupCd', ''), 'label': q['label'], 'rows': len(q['rows'])})
    for r in q['rows']:
        fresh[(c, r['COUR_CD'], r['COUR_CLS'])] = r
path = f'{WT}/assets/timetable/korea-seoul-2026-2.json'
data = json.load(open(path, encoding='utf-8'))
records = []
for o in data['courses']:
    k = (o['courseCode'], o['section'])
    if k not in CHANGES: continue
    r = fresh[('seoul',) + k]
    m = o['sourceEducationalMetadata']
    if CHANGES[k] == 'PROF_NM':
        before = o['professor']; after = r['PROF_NM']
        o['professor'] = after; m['PROF_NM'] = after
        field = 'professor'
    else:
        before = o['courseName']; after = r['COUR_NM']
        o['courseName'] = after
        first, sep, rest = m['COUR_NM'].partition('\n')
        assert first.strip() == before
        m['COUR_NM'] = after + sep + rest
        field = 'courseName'
    records.append({'sourceId': o['sourceId'], 'field': field, 'nativeField': CHANGES[k], 'before': before, 'after': after})
assert len(records) == 5
with open(path, 'w', encoding='utf-8') as fp:
    fp.write(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
packet = {
    'capturedAt': '2026-10-23',
    'sourceUrl': 'https://sugang.korea.ac.kr/p/v/lectList?lang=ko',
    'endpoint': 'POST https://sugang.korea.ac.kr/d/v/lectHakbu',
    'method': '공개 개설과목 조회를 화면과 같은 조건(2026년 2학기, 대학 과정, 캠퍼스·이수구분·단과대·학과 또는 교양영역별)으로 조회. 조회마다 NetFunnel 대기열에 정상 진입(5101)·통과 후 결과를 받고 반환(5004)함. 대기열 우회 없음.',
    'excludedNativeIdentities': {
        'reason': '기존 범위 결정(군사 관련 학과 제외)에 따라 사이버국방학과 전공 조회와 사이버국방학과 전용 교양 분반은 넣지 않음',
        'seoul': sorted(f'{c}-{s}' for (cp, c, s) in fresh if cp == 'seoul' and (c.startswith('CYDF') or (c, s) in {('GEKS008', 'RS'), ('GEKS008', 'RT'), ('GEKS008', 'RU'), ('GEWR002', '18')})),
    },
    'queries': queries,
    'changes': records,
    'rows': {c: [{k: r[k] for k in FIELDS} for (cp, _, _), r in sorted(fresh.items()) if cp == c] for c in ['seoul', 'sejong']},
}
with open(sys.argv[3], 'w', encoding='utf-8') as fp:
    fp.write(json.dumps(packet, ensure_ascii=False, indent=1) + '\n')
print(json.dumps(records, ensure_ascii=False, indent=1))
