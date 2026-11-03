import json
from pathlib import Path

base = Path('work/all-university-completion-20261012')
path = base / 'program-groups-root.json'
packet = json.loads(path.read_text())
entries = {(r['university'], r['campus'], r['sourceLabel'], r['department']): r for r in packet['entries']}
asset = json.loads(Path('assets/timetable/organizations/hanyang.json').read_text())
admin = 'work/college-major-filters-20261012/sources-a/hanyang-admin.html'
web = str(base / 'root-sources/hanyang-remaining-web.json')
proofs = {
    '간호학과': ('간호대학', None, 'https://site.hanyang.ac.kr/web/academic/-38', admin, '공식 대학별 학과 표: 간호대학 아래 간호학과·간호학과(야).'),
    '경제금융학부': ('경제금융대학', None, 'https://site.hanyang.ac.kr/web/academic/-38', admin, '공식 대학별 학과 표: 경제금융대학 아래 경제금융학부.'),
    '의학과': ('의과대학', None, 'https://site.hanyang.ac.kr/web/academic/-38', admin, '공식 대학별 학과 표: 의과대학 아래 의예과·의학과.'),
    '한양인터칼리지학부': (None, '한양YK인터칼리지', 'https://site.hanyang.ac.kr/web/academic/-38', admin, '공식 독립 편제 한양YK인터칼리지 아래 정확한 한양인터칼리지학부. 가상 단과대 생성 없음.'),
    '데이터사이언스전공': ('공과대학', None, 'https://hyds.hanyang.ac.kr/front/grs/deg', str(base / 'root-sources/hanyang-data-degrees.html'), '학부 전공 표와 학부 학위 설명이 데이터사이언스학부의 데이터사이언스전공을 명시. 대학별 공식 표의 공과대학 데이터사이언스학부와 결합.'),
    '심리뇌과학전공': ('공과대학', None, 'https://hyds.hanyang.ac.kr/front/grs/deg', str(base / 'root-sources/hanyang-data-degrees.html'), '학부 전공 표와 학부 학위 설명이 데이터사이언스학부의 심리뇌과학전공을 명시. 대학별 공식 표의 공과대학 데이터사이언스학부와 결합.'),
    '인문공공행정전공': (None, '융합전공', 'https://academic.hanyang.ac.kr/-10', str(base / 'root-sources/hanyang-program-table.png'), '공식 융합전공 명 표의 미래인문학융합학부 인문공공행정전공. 관장대학 열은 소속으로 치환하지 않음. 신규모집 중단과 원시간표 존재를 구분.'),
    '통상한국어커뮤니케이션전공': (None, '융합전공', 'https://academic.hanyang.ac.kr/-10', str(base / 'root-sources/hanyang-program-table.png'), '공식 융합전공 명 표의 미래인문학융합학부 통상한국어커뮤니케이션전공. 관장대학 열은 소속으로 치환하지 않음.'),
    '약학과': ('약학대학', None, 'https://goerica.hanyang.ac.kr/upload/GUIDES/2025/2025_%EC%95%BD%ED%95%99%EB%8C%80%ED%95%99.pdf', str(base / 'root-sources/hanyang-chinese-pharmacy-web.json'), 'ERICA 공식 약학대학 안내책자에 약학대학 / 약학과가 함께 직접 명시.'),
    '중국경제통상전공': (None, '융합전공', 'https://www.hanyang.ac.kr/documents/portlet_file_entry/20122/(%EB%B6%99%EC%9E%841)2025-2%ED%95%99%EA%B8%B0%2B%EB%8B%A4%EC%A0%84%EA%B3%B5(%EB%B6%80_%EB%8B%A4%EC%A4%91_%EB%B3%B5%EC%88%98%EC%A0%84%EA%B3%B5)%2B%EC%84%A0%EB%B0%9C%EC%9D%B8%EC%9B%90%2B%EB%B0%8F%2B%EB%A9%B4%EC%A0%91%EC%95%88%EB%82%B4%EB%AC%B8.pdf/b43acf71-02da-6376-8213-2fcd5a49418b?download=true&status=0', str(base / 'root-sources/hanyang-chinese-pharmacy-web.json'), '공식 2025-2 다전공 선발표 2쪽에 융합전공대학 중국경제통상전공 exact 원명. 최신 이미지의 중국경제통상융합전공으로 이름을 임의 변경하지 않음.'),
}
readmission = json.loads((base / 'root-sources/hanyang-2026-readmission-evidence.json').read_text())
for fact in readmission['facts']:
    proofs[fact['department']] = (fact['college'], None, readmission['sourceUrl'], str(base / 'root-sources/hanyang-2026-readmission-evidence.json'), '공식 2026-2 재입학 안내 3쪽 재적생 편제 표의 정확한 구전공/대학. 현재 남아 있는 원시간표 명칭과 기존 학년 소속을 보존하며 신학과명으로 교체하지 않음. ' + fact['scope'])
for row in asset['mappings']:
    if row['department'] not in proofs:
        continue
    college, group, url, source_file, evidence = proofs[row['department']]
    entry = {'university': 'hanyang', 'campus': row['campus'], 'sourceLabel': row['sourceLabel'], 'department': row['department'], 'college': college, 'kind': 'college' if college else 'programGroup' if group == '융합전공' else 'universityDirect', 'sourceUrl': url, 'sourceFile': source_file, 'evidence': evidence}
    if group:
        entry['group'] = group
    entries[('hanyang', row['campus'], row['sourceLabel'], row['department'])] = entry
packet['entries'] = list(entries.values())
packet['final'] = False
packet['completionClaim'] = False
path.write_text(json.dumps(packet, ensure_ascii=False, indent=2) + '\n')
print({'hanyangExactRows': sum(r['university'] == 'hanyang' for r in entries.values()), 'verificationPending': True})
