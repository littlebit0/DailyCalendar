"""경상국립대 2026-2 시각 보류(unrecognized) 강좌를 공식 요일·교시로 확정한다.

근거
- 교시표: 2026학년도 2학기 수강신청 안내 '6. 교시별 수업시간'
  (공지 https://www.gnu.ac.kr/biomat/na/ntt/selectNttInfo.do?mi=3071&nttSn=7841806 ,
  첨부 fileKey=080773c8495c5ebd2cc635ace7e24806, sha256 620e9e92...5910).
  0~11교시 = 08:00+60n분 시작, 50분 수업. 캠퍼스별 조건 없음("수강신청 시 캠퍼스 제한하지 않음").
- 지정보강일·학기 범위: 기존 자료와 같은 makeup 표(아래 MAKEUP).

규칙(2026-11-23 사용자 결정)
- 교시 슬롯 = 시작 ~ 다음 교시 시작(쉬는 시간 포함, 60분). 표 밖 교시(12교시 이후)와 토요일도 같은 60분 슬롯으로 이어 계산.
- 연속 교시는 한 구간, 같은 날·같은 강의실이고 간격 60분 미만이면 합친다.
- 운영 방식(원격·혼합·집중·야간 등)이 무엇이든 공식 요일·교시가 있으면 확정. 원문이 '실시간 원격 화상강좌'로 명시한 강좌는
  기존 자료 선례대로 deliveryMode=liveOnline.
- 폐강 공고 여부는 판단하지 않는다.
- 원문 필드(courseName, professor, sourceSchedule 등)는 바꾸지 않는다.

2차(2026-11-23): 학과 수정 공지와 코드·분반·명칭이 엇갈린 4강좌(currentPublishedNativeIdentityConflict)를 가장 최신 공식 자료로 정한다.
- 최신 자료 = 산업경영학과 '2026학년도 2학기 학부생 수강신청 안내[수정: 2026.7.29.]'
  (https://www.gnu.ac.kr/industry/na/ntt/selectNttInfo.do?mi=6231&bbsId=2222&nttSn=7834125) 첨부
  '2026-2학기 강의개설(공지용)_수정(20260729).hwp'. 더 새 공개 시간표는 없다(통합서비스 my.gnu.ac.kr 수업시간표 조회는 로그인).
- 공지의 코드 표기는 오기다: 학과 교육과정(https://www.gnu.ac.kr/industry/cm/cntnts/cntntsView.do?cntntsId=3443&mi=6229)에서
  11002308=재테크관리, 11002309=소비자행동의이해이고, 11020698은 같은 공지의 경제학개론(005) 코드다. 공지 행의 교과목명·교수·요일·교시는
  원문 11026184-002·11002308-001과 같다. 그래서 원문 코드를 유지하고 공지의 시각을 쓴다.
  재테크관리 토7,8,9 = 공지 토요일 실제 시각 14:00~16:00(같은 공지의 다른 토7,8,9 강좌와 같음).
  스마트재테크 토3,4 = 학과·학부 교시표 3교시 11:00, 4교시 12:00(슬롯 끝 13:00). 공지의 3·4·5교시 블록 11:00~13:00과도 같다.
- 11020698-002 경제학개론(경제학부)·11022792-001 조직행동론(경영학부)은 공지 오기 코드·같은 이름의 다른 학과 강좌(11002310-001)와 겹쳐
  표시됐을 뿐 공지 대상이 아니다. 2026-07-24 원문 요일·교시를 일반 교시표로 확정한다.
- 가좌 11006946-001 수요일 10~12교시: 표 밖 12교시를 같은 60분 슬롯(20:00~21:00)으로 이어 계산해 채운다.

일관성 검사: 기존 scheduled 강좌 전부를 같은 변환기로 다시 계산해 기존 schedules와 같은지 assert한다
(산업경영학과 2026-07-29 수정 공지 강좌는 그 공지의 시계 구간으로 검사).
저장소 루트에서 실행: python3 tool/timetable/apply_gnu_official_times.py
"""
import datetime as dt
import json
import re
from pathlib import Path

CAMPUSES = ['gajwa', 'chilam', 'tongyeong', 'changwon', 'naedong', 'unknown']
DAYS = '월화수목금토일'
SEGMENT = re.compile(r'([월화수목금토일])(\d+(?:,\d+)*)(?:\[([^\]]*)\])?')
MAKEUP = {
    '2026-10-20': '2026-12-08', '2026-09-25': '2026-12-09', '2026-09-24': '2026-12-10',
    '2026-10-09': '2026-12-11', '2026-09-26': '2026-12-12', '2026-10-05': '2026-12-14',
}
INDUSTRY_HOLD = '2026-07-29 산업경영학과 수정 공지의 실제 시각 계획'
INDUSTRY_SAT = {'0,1,2': (540, 660), '3,4,5': (660, 780), '7,8,9': (840, 960), '10,11,12': (960, 1080)}
BASIS = 'nativeWeeklyPeriodsOfficialClockUserDecision20261123'
CLOCK_SOURCE = 'remaining-campus-clock-followup-v5-20261008/current2026-2-university-undergraduate-clock-education.json'
OLD_TAIL = ('. 토요일 실제 시각은 수정 공지의 0·1·2교시=09:00~11:00, 3·4·5교시=11:00~13:00, 7·8·9교시=14:00~16:00, '
            '10·11·12교시=16:00~18:00을 적용했습니다. 금요일 야간 11~13교시는 학과 학부 교시표의 19:00~21:25(각 45분) '
            '공개 예약 블록입니다. 실제 출석 기록이 아닙니다. 10월 3일 토요일 개천절의 개별 보강 시각 및 12월 15~21일 '
            '기말시험의 개별 시각은 확인되지 않아 추가하지 않았습니다. ')
OLD_HEAD = '2026-07-24 공개 원본과 2026-07-29 산업경영학과 수정 공지에 따른 계획이며 최신 변경은 통합서비스에서 확인해야 합니다. '
NOTE = ('2026-07-24 공개 원본의 요일·교시·강의실과 2026-2 공식 학부 수강신청 안내의 교시표(n교시 08:00+60n분 시작)에 따른 '
        '정규 주간 예약 계획입니다. 공식 요일·교시 기준 확정(운영 방식 미표기·원격 표기는 대면으로 간주, 폐강 공고 여부는 판단하지 않음)이며, '
        '표에 없는 12교시 이후와 토요일도 같은 60분 슬롯으로 이어 계산했습니다. 실제 개별 출석일 확정 자료가 아니며 최신 변경은 '
        '통합서비스에서 확인해야 합니다. 공식 2026-2 학기 범위는 9월 1일~12월 21일입니다. 공개 지정보강일은 원래 휴강일의 시각·실로 '
        '예약하고, 12월 15~21일 기말시험의 개별 시각 및 10월 3일 토요일의 개별 보강은 추가하지 않았습니다. '
        '연속 교시 사이 쉬는 시간은 예약 블록에 포함됩니다. ')
LIVE_NOTE = '원문이 실시간 원격 화상강좌로 명시하여 예약의 개별 방식은 실시간 비대면으로 보존합니다. '
RESOLVED_BASIS = 'identityConflictResolvedLatestOfficialNotice20261123'
NOTICE_URL = 'https://www.gnu.ac.kr/industry/na/ntt/selectNttInfo.do?mi=6231&bbsId=2222&nttSn=7834125'
# 공지 행이 원문과 같은 강좌(코드만 오기)면 공지 시각, 공지 대상이 아니면 원문 교시표.
NOTICE_SAME_COURSE = {'gnu/gajwa/2026-2/11026184-002', 'gnu/gajwa/2026-2/11002308-001'}
RESOLVED_NOTE = {
    True: ('2026-07-29 산업경영학과 수정 공지(가장 최신 공개 자료)의 같은 교과목명·교수·요일·교시 행으로 확정했습니다. '
           '공지의 교과목 코드는 학과 교육과정과 다른 오기라 원문 코드를 유지합니다. '),
    False: ('2026-07-29 산업경영학과 수정 공지의 오기 코드·같은 이름 다른 학과 강좌와 겹쳐 보류했으나, 이 강좌는 그 공지 대상이 아니므로 '
            '2026-07-24 공개 원본의 요일·교시로 확정했습니다. '),
}
WED_OLD = '수요일10–12교시는12교시 끝시각 미게시로 전체 수요일 구간을 보류하고 금요일2–4교시만 제공합니다.'
WED_NEW = '수요일 10~12교시는 표에 없는 12교시를 같은 60분 슬롯으로 이어 계산해 18:00~21:00으로 제공합니다.'


def blocks_for(schedule, skip_beyond_11=False):
    """원문 '요일교시[,교시][강의실]' 목록 → (요일, 시작분, 끝분, 강의실). 해석 못 하면 ValueError."""
    matches = list(SEGMENT.finditer(schedule))
    if not matches or re.sub(r'[,\s]+', '', SEGMENT.sub('', schedule)):
        raise ValueError('unparsed schedule: ' + schedule)
    slots = []
    for m in matches:
        periods = sorted(set(map(int, m[2].split(','))))  # '월1,1,2,2' 같은 중복 표기는 같은 교시
        if skip_beyond_11 and periods[-1] > 11:
            continue
        for n in periods:
            slots.append((DAYS.index(m[1]) + 1, m[3] or '', 480 + 60 * n, 540 + 60 * n))
    merged = []
    for day, room, start, end in sorted(slots):
        last = merged[-1] if merged else None
        if last and last[0] == day and last[3] == room and start - last[2] < 60:
            last[2] = max(last[2], end)
        else:
            merged.append([day, start, end, room])
    return [tuple(b) for b in merged]


def meetings_for(blocks, extra=None):
    out = []
    for day, start, end, room in blocks:
        date = dt.date(2026, 9, 1)
        while date <= dt.date(2026, 12, 7):
            iso = date.isoformat()
            if date.isoweekday() == day and iso != '2026-10-03':
                actual = MAKEUP.get(iso, iso)
                row = {'date': actual, 'weekday': dt.date.fromisoformat(actual).isoweekday(),
                       'startMinute': start, 'endMinute': end, 'classroom': room}
                row.update(extra or {})
                out.append(row)
            date += dt.timedelta(days=1)
    out.sort(key=lambda r: (r['date'], r['startMinute'], r['classroom']))
    return out


def expected_existing(c):
    m = c['metadata']
    if m.get('holdReason') == INDUSTRY_HOLD:
        s = m['currentPublishedEducationalRow']['schedule']
        g = re.fullmatch(r'([금토])([0-9,]+)\[(.*)\]', s)
        start, end = INDUSTRY_SAT[g[2]] if g[1] == '토' else {'11,12,13': (1140, 1290)}[g[2]]
        return meetings_for([(DAYS.index(g[1]) + 1, start, end, g[3])], {'deliveryMode': 'inPerson'})
    basis = m.get('reservationBasis')
    extra = {'deliveryMode': 'liveOnline'} if (basis == 'nativeExplicitSynchronousOnline' or (
        basis == BASIS and m['originalEducationalFields']['remoteType'] == '실시간 원격 화상강좌')) else None
    return meetings_for(blocks_for(m['originalEducationalFields']['schedule'],
                                   skip_beyond_11=basis == 'exactFridayOnlyOtherDayClockHeld'), extra)


def resolve_identity_conflict(c):
    """학과 수정 공지와 코드·분반·명칭이 엇갈린 강좌를 최신 공식 자료로 확정한다(docstring 2차 참고)."""
    m = c['metadata']
    raw = m['originalEducationalFields']
    [row] = m['currentPublishedNativeIdentityConflict']
    head = OLD_HEAD + m['holdReason'] + OLD_TAIL
    assert m['holdReason'] == '학과 수정 공지의 교과목 코드·분반·명칭 불일치 확인 중' and c['remarks'].startswith(head)
    rest = c['remarks'][len(head):]
    same = c['sourceId'] in NOTICE_SAME_COURSE
    if same:  # 공지 행이 같은 강좌: 이름·교수·요일·교시(강의실 공백 제외)가 원문과 같아야 한다.
        assert (row['title'], row['professor'], row['schedule']) == (
            c['courseName'], c['professor'], c['sourceSchedule'].replace(' ', '')), c['sourceId']
        assert row['courseCode'] != c['courseCode'], c['sourceId']
    else:  # 공지 대상 아님: 공지 행은 이름이나 코드만 겹치는 다른 강좌다.
        assert row['title'] != c['courseName'] or row['professor'] != c['professor'], c['sourceId']
    periods = re.fullmatch(r'토([0-9,]+)\[.*\]', row['schedule'])
    industry = same and periods and periods[1] in INDUSTRY_SAT
    m.update(priorHoldReason=m['holdReason'], holdReason=INDUSTRY_HOLD if industry else None,
             reservationBasis=RESOLVED_BASIS, clockSource=CLOCK_SOURCE,
             clockSecondSemesterApplicabilityConfirmed=True,
             identityConflictResolution={
                 'latestSource': NOTICE_URL, 'noticeRowIsSameCourse': same,
                 'clock': '공지 토요일 실제 시각' if industry else '일반 학부 교시표(n교시 08:00+60n분, 60분 슬롯)',
                 'decision': '2026-11-23 사용자 지시: 모순은 가장 최신 공식 자료로 정한다'})
    if industry:
        m['currentPublishedEducationalRow'] = row
        m['actualSaturdayClockOverridesNominal'] = True
        c['remarks'] = head.replace(m['priorHoldReason'], INDUSTRY_HOLD) + RESOLVED_NOTE[True] + rest
    else:
        c['remarks'] = NOTE + RESOLVED_NOTE[same] + rest
    c['schedules'] = expected_existing(c)
    c['scheduleStatus'] = 'scheduled'
    assert c['schedules']


def main():
    stats = {'checkedExisting': 0, 'confirmed': 0, 'held': [], 'conflictResolved': []}
    for campus in CAMPUSES:
        path = Path(f'assets/timetable/gnu-{campus}-2026-2.json')
        text = path.read_text(encoding='utf-8')
        data = json.loads(text)
        for c in data['courses']:
            m = c['metadata']
            if m.get('reservationBasis') == 'exactFridayOnlyOtherDayClockHeld':
                assert WED_OLD in c['remarks'], c['sourceId']
                c['remarks'] = c['remarks'].replace(WED_OLD, WED_NEW)
                m.pop('omittedNativeClockScopes')
                m['reservationBasis'] = BASIS
                c['schedules'] = expected_existing(c)
                stats['wednesdayFilled'] = c['sourceId']
            if c['scheduleStatus'] == 'scheduled':
                assert c['schedules'] == expected_existing(c), c['sourceId']
                stats['checkedExisting'] += 1
                continue
            if c['scheduleStatus'] != 'unrecognized':
                continue
            raw = m['originalEducationalFields']
            assert raw['schedule'] == c['sourceSchedule'], c['sourceId']
            if m.get('currentPublishedNativeIdentityConflict'):
                resolve_identity_conflict(c)
                stats['conflictResolved'].append(c['sourceId'])
                continue
            try:
                blocks = blocks_for(raw['schedule'])
            except ValueError as error:
                stats['held'].append((c['sourceId'], str(error)))
                continue
            live = raw['remoteType'] == '실시간 원격 화상강좌'
            head = OLD_HEAD + m['holdReason'] + OLD_TAIL
            assert c['remarks'].startswith(head), c['sourceId']
            rest = c['remarks'][len(head):]
            assert rest.startswith(raw['remarks']), c['sourceId']
            c['schedules'] = meetings_for(blocks, {'deliveryMode': 'liveOnline'} if live else None)
            c['scheduleStatus'] = 'scheduled'
            c['remarks'] = NOTE + (LIVE_NOTE if live else '') + rest
            m.update(priorHoldReason=m['holdReason'], holdReason=None, reservationBasis=BASIS,
                     clockSource=CLOCK_SOURCE, clockSecondSemesterApplicabilityConfirmed=True,
                     actualAttendanceConfirmed=False, wholeLatestChangesConfirmed=False)
            assert c['schedules'] == expected_existing(c)
            stats['confirmed'] += 1
        data['periodEvidence'] = {
            'notice': 'https://www.gnu.ac.kr/biomat/na/ntt/selectNttInfo.do?mi=3071&nttSn=7841806',
            'attachmentFileKey': '080773c8495c5ebd2cc635ace7e24806',
            'attachmentSha256': '620e9e92e56b5e4f0498713530ad928352c6720dd4494ff786399a64e3ae5910',
            'heading': '6. 교시별 수업시간',
            'rule': 'n교시 08:00+60n분 시작, 슬롯 60분(쉬는 시간 포함), 표 밖 교시·토요일도 같은 슬롯',
            'decision': '2026-11-23 사용자 결정: 운영 방식 무관 공식 요일·교시 확정, 폐강 판단 안 함',
            'identityConflictLatestSource': NOTICE_URL,
            'identityConflictCurriculum': 'https://www.gnu.ac.kr/industry/cm/cntnts/cntntsView.do?cntntsId=3443&mi=6229',
        }
        out = json.dumps(data, ensure_ascii=False, separators=(',', ':')) + ('\n' if text.endswith('\n') else '')
        path.write_text(out, encoding='utf-8')
    print(json.dumps(stats, ensure_ascii=False, indent=1))


if __name__ == '__main__':
    main()
