# coding: utf-8
"""계명대 2026-2: 실습·집중수업 적용 기간 미확정으로 보류한 강좌를 원문 시각으로 확정한다.

근거: 같은 공식 개설강좌 원문(sourceUrl)의 수업시간 표기 'HH:mm~HH:mm'.
원문이 시각을 직접 적으므로 교시표를 쓰지 않고 그 시각 그대로 주간 반복으로 둔다
(2026-11-23 사용자 결정: 운영 기간이 불명확해도 공식 시각으로 확정).
원문 기간(period) 표기는 없으므로 날짜 지정 예외는 만들지 않는다.
'원격수업(...)'처럼 시각이 없는 강좌는 unscheduled 그대로 둔다.

먼저 기존 scheduled 강좌 전부를 import_kmu.meetings로 다시 계산해 기존 schedules와
같은지 확인한다. 재실행해도 결과가 같다.

사용: 저장소 루트에서 python3 tool/timetable/apply_kmu_official_times.py
"""
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('kmu', ROOT / 'tool/timetable/import_kmu.py')
kmu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kmu)

OLD = '실제 실습·집중수업 적용 기간 미확정: 원문 시각을 학기 전체에 반복하지 않음'
NEW = kmu.CONFIRMED


def apply(data):
    confirmed = 0
    for c in data['courses']:
        if c['scheduleStatus'] == 'scheduled':
            assert kmu.meetings(c['sourceSchedule']) == c['schedules'], c['sourceId']
        elif c['scheduleStatus'] == 'unrecognized':
            slots = kmu.meetings(c['sourceSchedule'])  # 파싱 실패 시 예외: 시각을 만들지 않음
            if not slots:
                continue
            c['scheduleStatus'], c['schedules'] = 'scheduled', slots
            c['departmentRemarks'] = {d: r.replace(OLD, NEW)
                                      for d, r in c['departmentRemarks'].items()}
            confirmed += 1
        else:
            assert not kmu.meetings(c['sourceSchedule'] or None), c['sourceId']
    return confirmed


if __name__ == '__main__':
    for path in sorted((ROOT / 'assets/timetable').glob('kmu-*-2026-2.json')):
        text = path.read_text(encoding='utf-8')
        data = json.loads(text)
        n = apply(data)
        out = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
        path.write_text(out + ('\n' if text.endswith('\n') else ''), encoding='utf-8')
        print(path.name, 'confirmed', n)
