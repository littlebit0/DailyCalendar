#!/usr/bin/env python3
"""동국대 WISE에서 같은 학과 라벨이 두 단과대에 공개된 경우 강좌별 개설 단위로 나눈다.

공식 조회(종합강의시간표, 학부(WISE) 2026-2)는 '창의융합공학부'를 과학기술대학과 글로컬에너지대학
두 곳에 싣는다. 라벨 매핑은 캠퍼스·라벨만 보고 붙으므로 두 단과대가 모든 강좌에 함께 붙는다(PR 1242 리뷰).
그래서 이 라벨의 캠퍼스 매핑을 courseOwners로 옮기고, 강좌마다 원문 개설대학(departments[0])과
같은 단과대 단위만 둔다.

    python3 tool/timetable/patch_dongguk_wise_ambiguous_departments.py   # 다시 실행해도 결과 동일
"""
import json
from pathlib import Path

ORG = Path('assets/timetable/organizations/dongguk.json')
ASSET = Path('assets/timetable/dongguk-wise-2026-2.json')


def split(org, courses):
    labels = {}
    for m in org['mappings']:
        if m.get('campus') == 'wise' and m.get('department'):
            labels.setdefault(m['sourceLabel'], []).append(m)
    ambiguous = {k: v for k, v in labels.items() if len({m['college'] for m in v}) > 1}
    org['mappings'] = [m for m in org['mappings']
                       if not (m.get('campus') == 'wise' and m.get('sourceLabel') in ambiguous)]
    owners = {o['sourceId']: o for o in org['courseOwners']}
    for c in courses:
        for label, units in ambiguous.items():
            if label not in c['departments']:
                continue
            unit = [u for u in units if u['college'] == c['departments'][0]]
            assert len(unit) == 1, (c['sourceId'], c['departments'])
            entry = owners.setdefault(c['sourceId'], {'sourceId': c['sourceId'], 'units': []})
            if unit[0] not in entry['units']:
                entry['units'].append(unit[0])
    org['courseOwners'] = sorted(owners.values(), key=lambda o: o['sourceId'])
    return sorted(ambiguous)


def main():
    org = json.loads(ORG.read_text(encoding='utf-8'))
    courses = json.loads(ASSET.read_text(encoding='utf-8'))['courses']
    labels = split(org, courses)
    ORG.write_text(json.dumps(org, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print(json.dumps({'ambiguousLabels': labels, 'courseOwners': len(org['courseOwners'])}, ensure_ascii=False))


if __name__ == '__main__':
    main()
