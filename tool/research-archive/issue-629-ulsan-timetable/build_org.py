"""Build assets/timetable/organizations/ulsan.json from the official uwins MCB07S
대학 > 학부 > 소속 tree (only labels that appear in the dataset)."""
import json, sys
tree = json.load(open(sys.argv[1]))
data = json.load(open(sys.argv[2]))
used = {l for c in data['courses'] for l in c['departments']}
URL = 'https://uwins.ulsan.ac.kr/LESN/B/MCB07S.aspx?MenuID=MCB07S!1&frame=oebu'
maps, seen = [], set()
for t in tree:
    college, hagbu = t['daehag'][1], t['hagbu'][1]
    for code, name in t['sosog']:
        if name not in used or (college, name) in seen:
            continue
        seen.add((college, name))
        path = f"'{college}' > '{hagbu}' > '{name}'"
        maps.append({
            'college': college, 'department': name, 'sourceLabel': name,
            'sourceUrl': URL,
            'evidence': f'공식 강의시간및수업계획서조회(2026-2) 대학·학부·소속 선택 목록: {path} (소속 코드 {code}). 원명 보존.',
            'sourceFile': 'work/issue-629-ulsan-timetable/crawl/tree.json',
            'isOfferingUnit': False, 'campus': '*', 'collegeKnown': True,
            'affiliationSourceUrl': URL,
            'affiliationSourceFile': 'work/issue-629-ulsan-timetable/crawl/tree.json',
            'affiliationEvidence': f'공식 시간표 학과 트리 {path}',
        })
units = {
    '대학(공통)': ('https://cge.ulsan.ac.kr/boardDownload.do?no=344571',
                 "교양대학 공지 '2026-2학기 교양 강좌 수강신청 안내'(2026-07-31) 붙임1 '2026-2학기 교양 강좌 개설 현황' 개설소속 열 '대학(공통)'; 공식 강의시간및수업계획서조회 영역별 행의 개설 소속 코드 10000.",
                 'work/full-timetable-audit-20261012/ulsan-new-public-cge/native-education-rows.json'),
    '미래라이프융합시민대학': (URL,
                 "공식 강의시간및수업계획서조회(2026-2) 대학 선택 목록의 '미래라이프융합시민대학'(코드 12084)이 영역별 행의 개설 소속으로 표시됨.",
                 'work/issue-629-ulsan-timetable/crawl/colleges.json'),
}
for label, (url, ev, src) in units.items():
    if label in used:
        maps.append({'college': label, 'department': None, 'sourceLabel': label,
                     'sourceUrl': url, 'evidence': ev, 'sourceFile': src,
                     'isOfferingUnit': True, 'campus': '*', 'collegeKnown': True})
missing = used - {m['sourceLabel'] for m in maps}
if missing:
    raise SystemExit(f'labels without tree entry: {sorted(missing)}')
out = {'schemaVersion': 1, 'university': 'ulsan', 'mappings': maps, 'courseOwners': []}
open(sys.argv[3], 'w').write(json.dumps(out, ensure_ascii=False, indent=2) + '\n')
print(len(maps), 'mappings')
