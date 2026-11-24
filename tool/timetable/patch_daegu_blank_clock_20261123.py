"""대구대 공식 수업시간표(종합)에서 강의시간이 공란인 미확정 강좌를 시간 미정으로 둔다.

2026-11-23 지시: 원문에 요일·교시 자체가 공란인 강좌는 다른 공개 공식 경로를 끝까지 찾고,
그래도 시각이 없으면 unscheduled(시간 미정)로 두고 비고에 근거를 남긴다.
원문 강의시간이 있는 강좌는 건드리지 않는다(assert).

    python3 tool/timetable/patch_daegu_blank_clock_20261123.py   # 다시 실행해도 결과 동일
"""
import json
from pathlib import Path

ASSET = Path('assets/timetable/daegu-main-2026-2.json')
HEAD = ' / 2026-11-23 확인: 공식 수업시간표(종합)의 강의시간이 공란이고, '
TAIL = '에도 요일·시각이 없어 요일·시각이 없는 강좌로 둡니다.'
SCHOOL = (
    '수업시간표(종합) 28쪽("2026-2학기 학교현장실습 기간: 2026. 10. 05.(월) ~ 10. 30.(금) [4주]", '
    '실습학교 개별 섭외)과 사범대학 공지 「2026학년도 제2학기 학교현장실습 배정 통지 및 유의사항 안내」'
    '(https://teacher.daegu.ac.kr/article/table_01/detail/225495, "실습기간: 4주(실습학교별 실습시작일 상이함)")'
)
NURSE = (
    '간호학과 「2026학년도 2학기 전산 및 운영 시간표 안내」 첨부 시간표(2026-10-20 최종, '
    'https://nursing.daegu.ac.kr/article/table_01/detail/226897)와 간호학과 공지 게시판'
)
FIELD = '학과 홈페이지 공지 게시판(lovept·duot·rehabcp·animal·ecse·mecha·emergency.daegu.ac.kr)'
OTHER = '개설 학과 홈페이지 공지 게시판(realty·familywelfare·du-huss.daegu.ac.kr)'


def evidence(c):
    if c['courseName'].startswith('학교현장실습'):
        return SCHOOL
    if c['publicEducationRows'][0]['education']['수강학과'] == '간호':
        return NURSE
    if c['sourceClassroom'] in ('현장실습', '임상실습'):
        return FIELD
    return OTHER


def main():
    asset = json.loads(ASSET.read_text(encoding='utf-8'))
    moved = []
    for c in asset['courses']:
        if c['scheduleStatus'] != 'unrecognized':
            continue
        assert not c['sourceSchedule'].strip() and not c['schedules'], c['courseCode']
        note = HEAD + evidence(c) + TAIL
        c['scheduleStatus'] = 'unscheduled'
        c['remarks'] += note
        c['departmentRemarks'] = {k: v + note for k, v in c['departmentRemarks'].items()}
        moved.append(c['courseCode'])
    ASSET.write_text(json.dumps(asset, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'moved': len(moved), 'codes': moved}, ensure_ascii=False))


if __name__ == '__main__':
    main()
