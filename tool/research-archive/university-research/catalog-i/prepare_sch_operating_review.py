"""Educational-only SCH current-source review; no inferred clocks or delivery."""
import hashlib
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).parent
SOURCE = ROOT / 'sch-2026-2-public-all.json'
FIELDS = (
    'YY', 'SMT', 'CORS_NO', 'CLS_NO', 'SBJT_ID', 'SBJT_KOR_NM',
    'CDT', 'TM_CNT', 'CORS_ST_DIV', 'CORS_ST_DIV_NM', 'OPEN_UNIV_CD',
    'OPEN_UNIV_NM', 'OPEN_ORGN', 'OPEN_ORGN_NM', 'OPEN_SHYR',
    'OPEN_SHYR_NM', 'DAY_TM_NM', 'LECT_ROOM_NM', 'DOM_DIV',
    'DOM_DIV_NM', 'ENG_LECT_YN', 'EMP_NM',
)


def main():
    source = json.loads(SOURCE.read_text())
    online = json.loads((ROOT / 'sch-2026-2-online-followup-audit.json').read_text())
    cyber = set(online['cyberIds'])
    ocu = set(online['ocuIds'])
    human_notice = json.loads((ROOT / 'sch-current-tourism-liberal-operating-notice-20261008.json').read_text())
    human_ids = {row['CORS_NO'] for row in human_notice['humanLoveSourceCrosscheck']}
    assert len(human_ids) == 13 and human_notice['all13MatchOfficialVirtualQuery']
    rows = []
    for raw in source:
        assert raw['YY'] == '2026' and raw['SMT'] == '21'
        row = {key: raw.get(key) for key in FIELDS}
        code = raw['CORS_NO']
        if code in ocu:
            scope = 'official-OCU-query'
        elif code in cyber:
            scope = 'official-internal-virtual-query'
        elif not raw.get('DAY_TM_NM'):
            scope = 'no-published-time-operating-mode-unresolved'
        elif raw.get('OPEN_SHYR') in {'4', '5'} and raw.get('CORS_ST_DIV_NM') != '교양':
            scope = 'fourth-fifth-year-individual-hyflex-mode-needs-review'
        else:
            scope = 'ordinary-clock-and-individual-plan-review-pending'
        row['operatingReviewScope'] = scope
        row['clockVerified'] = False
        row['actualDatesVerified'] = False
        row['planRemarksVerified'] = False
        row['sourceCampus'] = None
        row['productionReady'] = False
        if code in human_ids:
            row['educationalOperatingNotes'] = [
                {
                    'text': '2026학년도 2학기 인간사랑 총13분반은 학내가상 강의로 진행; 첫 주 강의 누락 주의',
                    'sourceURL': human_notice['sourceURL'],
                    'publishedAt': human_notice['publishedAt'],
                    'mode': 'official-internal-virtual',
                    'note': '원표 일13은 실제 대면 일요일 수업시각으로 승인하지 않음; 실시간/동영상 세부형태 미확인',
                }
            ]
        rows.append(row)
    assert len(rows) == len({(r['CORS_NO'], r['CLS_NO']) for r in rows}) == 2598
    assert all('EMP_NO' not in r and 'CAPA' not in r for r in rows)
    output = ROOT / 'sch-2026-2-educational-operating-review-20261008.json'
    data = {
        'schoolId': 'sch', 'year': 2026, 'term': '2026-2',
        'sourceCount': 2598, 'productionReady': False,
        'source': 'https://st.sch.ac.kr/?sch001',
        'sourceAcquisitionDate': '2026-10-07',
        'reviewDate': '2026-10-08',
        'sourceSHA256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'publicCourseMetadata': rows,
        'scopeCounts': dict(Counter(r['operatingReviewScope'] for r in rows)),
        'classificationCounts': dict(Counter(r['CORS_ST_DIV_NM'] for r in rows)),
        'notes': [
            'This is current-source educational metadata review, not a timed dataset approval.',
            'Fourth/fifth-year scope identifies review need only, not proof all these rows use hyflex.',
            'Known OCU/virtual identities come from the actual published query subsets.',
            'No employee identifiers, capacities, session values or full syllabi retained.',
            'No clock mapping borrowed from another institution; no inferred campus.',
            'Plans have not yet been checked for restrictions, actual dates or weekly operating exceptions.',
        ],
    }
    output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    for original, projected in zip(source, rows):
        assert all(projected[key] == original.get(key) for key in FIELDS)
    print(json.dumps({'count': len(rows), 'scopeCounts': data['scopeCounts'],
                      'metadataMismatch': 0, 'employeeIdPersisted': 0,
                      'scheduledApproved': 0,
                      'sha256': hashlib.sha256(output.read_bytes()).hexdigest()}))


if __name__ == '__main__':
    main()
