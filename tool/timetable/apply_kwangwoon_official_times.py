"""광운대 2026-2 시간표의 요일·교시 원문을 공식 교시표로 시각 확정한다(재실행 가능).

근거
- 학사안내 수업안내 '주,야간 수업시간 편성 안내'
  https://www.kw.ac.kr/ko/life/bachelor_info03.jsp (2026-11-23 curl 조회):
  주간(1교시 75분제, 15분 휴식) 1교시 09:00~10:15 ... 6교시 16:30~17:45,
  야간(1교시 45분제, 5분 휴식) 7교시 18:00~18:45 ... 11교시 21:20~22:05,
  0교시연강 08:00~.
- 강의시간표 안내 https://www.kw.ac.kr/ko/life/bachelor_info13.jsp:
  '강의시간(교시)는 주간수업은 1 ~ 6교시, 야간수업은 7 ~ 11교시로 운영'.
- 기존 scheduled 강좌의 슬롯(PR 577, 수업 운영에 관한 규정 [4-3-32] 별표1 + 쉬는 시간 포함)
  을 그대로 쓰고, 이 스크립트는 기존 scheduled 강좌 전부를 다시 계산해 같은지 assert 한다.

규칙(2026-11-23 사용자 결정)
- 공식 요일·교시가 있으면 원격·사전녹화·집중이수 등 운영 방식과 관계없이 그 시각으로 확정.
- 교시 슬롯 = 그 교시 시작~다음 교시 시작 직전. 같은 날·같은 강의실이고 간격 60분 미만이면 합침.
- 표 밖 교시(12교시 이후)는 야간 슬롯 길이 50분으로 11교시 슬롯 끝(22:20)부터 이어 계산하되,
  24:00을 넘는 번호(토 17~99 같은 원격 강좌 배정 번호)는 시각이 아니므로 만들지 않고 보류.
- 날짜: 강좌 period 안의 해당 요일, 공휴일(추석 9/24~26, 개천절 10/3, 대체공휴일 10/5,
  한글날 10/9) 제외 — 기존 scheduled 강좌의 날짜와 같다(assert).
- 비고 '1~11주차 운영'은 개강 주(8/31 주)부터 11주차(11/15)까지만 넣는다.
"""
import collections
import datetime as dt
import json
import re
import sys

F = 'assets/timetable/kwangwoon-unknown-2026-2.json'
SLOT = {0: (480, 540), 1: (540, 630), 2: (630, 720), 3: (720, 810), 4: (810, 900),
        5: (900, 990), 6: (990, 1080), 7: (1080, 1130), 8: (1130, 1180),
        9: (1180, 1230), 10: (1230, 1280), 11: (1280, 1340)}
NIGHT = 50
WD = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7}
HOLIDAYS = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05', '2026-10-09'}
WEEK1 = dt.date(2026, 8, 31)


def slot(p):
    if p in SLOT:
        return SLOT[p]
    if p < 0:
        raise ValueError(f'교시 {p}')
    s = SLOT[11][1] + (p - 12) * NIGHT
    if s + NIGHT > 1440:
        raise ValueError(f'교시 번호 {p}는 하루(24:00) 안에 들지 않음')
    return s, s + NIGHT


def dates(period, wd, last_week):
    d = dt.date.fromisoformat(period['startDate'])
    end = dt.date.fromisoformat(period['endDate'])
    out = []
    while d <= end:
        if d.isoweekday() == wd and d.isoformat() not in HOLIDAYS and (
                last_week is None or (d - WEEK1).days // 7 + 1 <= last_week):
            out.append(d.isoformat())
        d += dt.timedelta(days=1)
    return out


def convert(c):
    last_week = None
    for r in c['departmentRemarks'].values():
        m = re.search(r'1~(\d+)주차 운영', r)
        if m:
            last_week = int(m.group(1))
    out = []
    for sg in c['sourceSchedule'].split(';'):
        m = re.match(r'\s*(\S) ([\d,]+) \[([^\]]*)\]\s*$', sg)
        if not m or m.group(1) not in WD:
            raise ValueError(f'표기 해석 불가: {sg.strip()}')
        wd = WD[m.group(1)]
        ps = [slot(int(x)) for x in m.group(2).split(',')]
        for day in dates(c['period'], wd, last_week):
            for s, e in ps:
                out.append((day, wd, m.group(3), s, e))
    out.sort(key=lambda x: (x[0], x[2], x[3]))
    res = []
    for day, wd, room, s, e in out:
        if res and res[-1]['date'] == day and res[-1]['classroom'] == room and s - res[-1]['endMinute'] < 60:
            res[-1]['endMinute'] = max(res[-1]['endMinute'], e)
            continue
        res.append({'weekday': wd, 'startMinute': s, 'endMinute': e, 'classroom': room, 'date': day})
    res.sort(key=lambda x: (x['date'], x['startMinute'], x['classroom']))
    if not res:
        raise ValueError('기간 안에 수업일 없음')
    return res


def main():
    raw = open(F, encoding='utf-8').read()
    d = json.loads(raw)
    stats = collections.Counter()
    unresolved = {}
    for c in d['courses']:
        if c['scheduleStatus'] == 'scheduled':
            assert convert(c) == c['schedules'], c['sourceId']
            stats['scheduledRecheck'] += 1
            continue
        assert c['scheduleStatus'] in ('unrecognized', 'unscheduled'), c['sourceId']
        try:
            c['schedules'] = convert(c)
        except ValueError as e:
            # 교시로 해석할 수 없는 번호(예: 토 42)는 시각을 만들지 않고 시간 미정으로 둔다
            # (2026-11-23 사용자 결정). 원문은 sourceSchedule에 그대로 남는다.
            unresolved[c['sourceId']] = str(e)
            c['schedules'] = []
            c['scheduleStatus'] = 'unscheduled'
            continue
        c['scheduleStatus'] = 'scheduled'
        stats['confirmed'] += 1
    d['periodEvidence'] = {
        'urls': ['https://www.kw.ac.kr/ko/life/bachelor_info03.jsp',
                 'https://www.kw.ac.kr/ko/life/bachelor_info13.jsp'],
        'checkedOn': '2026-11-23',
        'rule': '주간 1~6교시 75분+15분, 야간 7~11교시 45분+5분(수업안내 수업시간 편성), '
                '0교시 08:00, 12교시 이후 50분 이어 계산, 원격·사전녹화 등 운영 방식은 대면으로 간주, '
                '교시로 해석할 수 없는 번호(unresolved)는 시간 미정',
        'unresolved': unresolved,
    }
    stats['unresolved'] = len(unresolved)
    print(dict(stats), collections.Counter(re.sub(r'\d+', 'N', v) for v in unresolved.values()))
    if '--write' in sys.argv:
        end = raw[len(raw.rstrip('\n')):]
        open(F, 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False, separators=(',', ':')) + end)


if __name__ == '__main__':
    main()
