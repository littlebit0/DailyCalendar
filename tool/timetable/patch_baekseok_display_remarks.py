#!/usr/bin/env python3
"""백석대 강좌의 일정 설명(remarks)을 화면이 보여 주는 학과별 비고(departmentRemarks)에도 붙인다(PR 1167 리뷰).

UniversityCourse.remarks는 departmentRemarks가 비어 있지 않으면 그것만 보여 준다. 그래서 교시 시각 근거,
'사' 구간·주차 제한·시간 미정 사유 같은 top-level remarks가 화면에 나오지 않았다. 원래 학과 비고는 그대로 두고
그 뒤에 한 줄 띄워 같은 설명을 붙인다.

    python3 tool/timetable/patch_baekseok_display_remarks.py   # 다시 실행해도 결과 동일
"""
import json
from pathlib import Path

ASSET = Path('assets/timetable/baekseok-unknown-2026-2.json')


def main():
    d = json.loads(ASSET.read_text(encoding='utf-8'))
    changed = 0
    for c in d['courses']:
        note = (c.get('remarks') or '').strip()
        if not note or not c.get('departmentRemarks'):
            continue
        new = {k: v if note in v else (v.rstrip() + '\n' + note if v.strip() else note)
               for k, v in c['departmentRemarks'].items()}
        if new != c['departmentRemarks']:
            c['departmentRemarks'] = new
            changed += 1
    ASSET.write_text(json.dumps(d, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print(json.dumps({'changed': changed}))


if __name__ == '__main__':
    main()
