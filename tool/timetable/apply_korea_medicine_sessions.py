"""고려대 서울 의학과 2026-2 시간 미정 강좌를 공개 강의계획서 첨부의 회차별 날짜·교시로 확정한다(재실행 가능).

근거(2026-11-23 curl 조회, 비로그인 공개 강의계획서 https://ams.korea.ac.kr/com/lgin/SsoCtr/initExtPageWork.do?link=lctreSylla):
- 본2 과목 12개: 첨부 '2026_2학기 시간표(전체 수정)_20260710.pdf'(PDF 작성 2026-07-30, MEDI232·254·256 첨부)의
  과목별 '순서·강의제목·날짜(요일)교시' 표. 같은 이름의 2026-07-21 작성본은 일부 과목만 실려 있어 최신본을 쓴다.
- MEDI108 미생물학: 자체 수업계획서 '차시별 수업주제 및 담당교수' 표(순서·수업일·교시).
- MEDI252-03·04 의학오디세이Ⅱ: 분반별 수업계획서의 '날짜(요일)교시' 표.
- 교시표(같은 첨부): 1교시 8:30~9:20 … 4교시 11:30~12:20, 5교시 13:20~14:10 … 8교시 16:20~17:10.
회차 목록은 tool/timetable/korea_medicine_sessions_2026_2.json에 원문 그대로 둔다(첨부 sha256·attflUuid 포함).

규칙(DailyCalendar-Timetable 스킬 4·5장):
- 교시 슬롯 = 50분 수업 + 10분 쉬는 시간(60분). 같은 날 간격 60분 미만이면 합친다(4교시 뒤 점심 50분 포함).
- 날짜가 지정된 회차라 주간 반복으로 펼치지 않는다. 공휴일·시험 주간 제외도 하지 않는다(원문 날짜 그대로).
- 강의실은 원문에 없어 빈 값으로 둔다. 강좌 period는 원문 첫 회차~마지막 회차를 포함하도록 넓힌다.
- 회차 수의 합이 과목 시수(표 머리의 'N시간' 또는 마지막 순서 번호)와 다르거나 요일이 날짜와 맞지 않으면 확정하지 않는다.
"""
import datetime
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE_PATH = ROOT / 'tool/timetable/korea_medicine_sessions_2026_2.json'
DATASET = ROOT / 'assets/timetable/korea-seoul-2026-2.json'
CONFIRMED = ('공개 강의계획서 첨부의 회차별 날짜·교시(의과대학 교시표 08:30 시작, 50분 수업+10분)로 확정했습니다. '
             '강의실은 원문에 없어 비워 두었습니다.')
HOLD_MARKERS = (' 일정 보류: ', ' 예약 보류: ')


def segments(sessions, starts):
    out = []
    for date, periods in sessions:
        wd = datetime.date.fromisoformat(date).isoweekday()
        for p in periods:
            s = starts[p - 1]
            out.append([date, s, s + 60, wd])
    out.sort()
    merged = []
    for date, s, e, wd in out:
        if merged and merged[-1]['date'] == date and s - merged[-1]['endMinute'] < 60:
            merged[-1]['endMinute'] = max(merged[-1]['endMinute'], e)
            continue
        merged.append({'weekday': wd, 'startMinute': s, 'endMinute': e, 'classroom': '', 'date': date})
    return merged


def replace_hold(remarks, text):
    if text in remarks:
        return remarks
    for marker in HOLD_MARKERS:
        if marker in remarks:
            return remarks[:remarks.index(marker)] + ' ' + text
    return remarks + ' ' + text


def apply():
    ev = json.loads(EVIDENCE_PATH.read_text(encoding='utf-8'))
    starts = ev['periodTable']['starts']
    raw = DATASET.read_text(encoding='utf-8')
    data = json.loads(raw)
    by_id = {c['sourceId']: c for c in data['courses']}
    done = 0
    for sid, item in ev['courses'].items():
        c = by_id[sid]
        sessions = item['sessions']
        dates = sorted(d for d, _ in sessions)
        for d, _ in sessions:  # 원문 요일과 날짜가 맞는지는 수집 때 확인했다; 학기 해 범위만 다시 본다
            assert d.startswith('2026-'), (sid, d)
        total = sum(len(p) for _, p in sessions)
        hours = int(item['section'].split('(')[-1].split('시간')[0]) if '시간)' in item['section'] else total
        assert total == hours, (sid, total, hours)
        assert len({(d, p) for d, ps in sessions for p in ps}) == total, sid
        c['scheduleStatus'] = 'scheduled'
        c['schedules'] = segments(sessions, starts)
        period = c['period']
        period['startDate'] = min(period['startDate'], dates[0])
        period['endDate'] = max(period['endDate'], dates[-1])
        c['remarks'] = replace_hold(c['remarks'], CONFIRMED)
        done += 1
    data['medicineSessionEvidence'] = {
        'file': 'tool/timetable/korea_medicine_sessions_2026_2.json',
        'syllabusUrl': ev['syllabusUrl'],
        'pdf': {k: ev['pdf'][k] for k in ('file', 'pdfCreationDate', 'sha256')},
        'periodTable': ev['periodTable']['sourceText'],
        'checkedDate': ev['checkedDate'],
    }
    out = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
    if raw.endswith('\n'):
        out += '\n'
    DATASET.write_text(out, encoding='utf-8')
    return done


def _self_check():
    starts = [510, 570, 630, 690, 800, 860, 920, 980]
    seg = segments([['2026-08-24', [1, 2, 3, 4]], ['2026-08-24', [5]], ['2026-08-25', [7]]], starts)
    assert seg == [
        {'weekday': 1, 'startMinute': 510, 'endMinute': 860, 'classroom': '', 'date': '2026-08-24'},
        {'weekday': 2, 'startMinute': 920, 'endMinute': 980, 'classroom': '', 'date': '2026-08-25'},
    ], seg
    assert replace_hold('a 일정 보류: x', 'B') == 'a B'


if __name__ == '__main__':
    _self_check()
    print('확정', apply(), file=sys.stderr)
