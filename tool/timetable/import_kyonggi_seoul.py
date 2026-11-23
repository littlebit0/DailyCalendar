"""경기대 서울캠퍼스(주간) 2026-2 공개 강좌 → assets/timetable/kyonggi-seoul-2026-2.json

서울캠 학부 전체 시간표는 공개되어 있지 않다(KUTIS·sugang 로그인). 그래서 통합공지
(key=7520, bbsNo=1073)의 공식 공지 4건에 실린 서울 강좌만 모은 부분 자료다.

  625361 2026-2 교양·일반선택·교육학전공 1차 폐강 강좌 안내 (자유교양대학, 2026-08-18)
  625587 같은 2차 폐강 강좌 안내 (2026-08-27)
  625261 2026-2 교양/교육학전공/ROTC 변동 예정 강좌 안내 (2026-08-07)
  625952 교내이러닝·가상대학이러닝 합반 안내 첨부 '2026-2 이러닝 합반내역.pdf' (2026-09-10)

규칙
- 원문 행(캠퍼스 '서울' 또는 '서울주간')만 넣는다. 강좌명·과목번호·요일교시 원문은 그대로 둔다.
- 폐강 표기는 판단하지 않는다(스킬 0.1). 요일·교시가 있으면 scheduled.
- 교시: 학사안내 강의시간 안내(contents.do?key=8430) 서울캠퍼스(주간) 60분제
  1교시 09:00~09:50 … 9교시 17:00~17:50, 50분 수업+10분 휴식 → 슬롯 60분(n교시 = 08:00+60n분).
  같은 요일 연속 교시는 한 구간으로 합친다.
- 같은 공지 안에서 변경 전/후가 있으면 변경 후(최신 공식값), 변경 전은 비고에 둔다.
- 시각이 없는 행(이러닝 합반, 교육봉사)은 unscheduled.
- 학수코드·이수구분·학점은 서울 원문에 없다. 같은 학기 수원 공식 PDF(2026-2_교양.pdf·
  2026-2_전공.pdf, kyonggi-suwon-2026-2.json)에 같은 교과목명이 한 학수코드로만 있으면
  그 값을 쓰고 비고에 근거를 남긴다. 없으면 공지 머리의 구분 원문을 classification에 둔다.
- 교수·강의실은 원문에 없으므로 비운다.

실행(저장소 루트): python3 tool/timetable/import_kyonggi_seoul.py <원본 폴더>
원본 폴더에는 n625361.html, n625587.html, n625261.html, 988383_2026-2 이러닝 합반내역.pdf 가 있어야 한다.
PDF는 pdfplumber로 읽는다(development/pdf-venv).
"""
import hashlib
import html
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'assets/timetable/kyonggi-seoul-2026-2.json')
SUWON = os.path.join(ROOT, 'assets/timetable/kyonggi-suwon-2026-2.json')
BOARD = 'https://www.kyonggi.ac.kr/www/selectBbsNttView.do?key=7520&bbsNo=1073&nttNo='
PERIOD_URL = 'https://www.kyonggi.ac.kr/www/contents.do?key=8430'
WEEKDAYS = '월화수목금토일'
MERGED = {}  # 서울 과목번호 → 원문 합반 표기
TERM = {'startDate': '2026-09-01', 'endDate': '2026-12-14'}


def notice_text(path):
    t = open(path, encoding='utf-8').read()
    i = t.find('작성자')
    j = t.find('function replaceSpecialCharacters')
    body = re.sub(r'<script.*?</script>', '', t[i:j], flags=re.S)
    return re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', body)))


def meetings(day_periods):
    """'화789' / '화 789' → [(weekday, start, end)]; 모르는 표기는 ValueError."""
    m = re.fullmatch(r'([월화수목금토일])\s*([1-9]+)', day_periods.strip())
    if not m:
        raise ValueError(day_periods)
    periods = sorted(int(p) for p in m.group(2))
    if len(set(periods)) != len(periods):
        raise ValueError(day_periods)
    out = []
    for p in periods:
        start = 480 + 60 * p
        if out and out[-1][2] == start:
            out[-1] = (out[-1][0], out[-1][1], start + 60)
        else:
            out.append((WEEKDAYS.index(m.group(1)) + 1, start, start + 60))
    return out


def main(src):
    rows = []  # (reg, name, schedule or '', source key, remark)
    for ntt, label in [('625361', '1차 폐강 강좌 안내(2026-08-18)'), ('625587', '2차 폐강 강좌 안내(2026-08-27)')]:
        text = notice_text(os.path.join(src, f'n{ntt}.html'))
        for m in re.finditer(r'(수원|서울) (\d{4}) (\S+?)(?: ([월화수목금토일]\d+))?(?= 수원 | 서울 | 문의| \()', text):
            if m.group(1) != '서울':
                continue
            rows.append((m.group(2), m.group(3), m.group(4) or '', ntt,
                         f'공식 공지: 2026학년도 2학기 교양, 일반선택, 교육학전공 {label}에 폐강으로 게시'))
        if ntt == '625361':
            assert '서울 9129 교육봉사 (0571 수원 교육봉사로 합반)' in text
            MERGED['9129'] = '0571 수원 교육봉사로 합반'
    text = notice_text(os.path.join(src, 'n625261.html'))
    for m in re.finditer(r'(\S+?)\((\d{4})\) / 서울 / ([월화수목금토일] \d+): (폐강 예정)', text):
        rows.append((m.group(2), m.group(1), m.group(3), '625261',
                     f'공식 공지: 2026-2 교양/교육학전공/ROTC 변동 예정 강좌 안내(2026-08-07) "{m.group(4)}"'))
    m = re.search(r'관광교재연구및지도법\((9\d{3})\): 시간표 변경 예정\((화 567) -> (화 789)\)', text)
    assert m, 'expected 관광교재연구및지도법 change line'
    rows.append((m.group(1), '관광교재연구및지도법', m.group(3), '625261',
                 f'공식 공지: 2026-2 교양/교육학전공/ROTC 변동 예정 강좌 안내(2026-08-07) 교육학전공 '
                 f'"시간표 변경 예정({m.group(2)} -> {m.group(3)})", 8월 10일 반영 예정이라 변경 후 시각 사용'))

    import pdfplumber  # development/pdf-venv
    pdf = os.path.join(src, '988383_2026-2 이러닝 합반내역.pdf')
    with pdfplumber.open(pdf) as d:
        table = [r for p in d.pages for t in p.extract_tables() for r in t]
    name = merged = None
    for r in table[1:]:
        if r[1]:
            name, merged = r[1], r[4]
        elif r[2] == '서울주간':
            rows.append((r[3], name, '', '625952',
                         f'공식 공지: 교내이러닝 및 가상대학이러닝 과목 합반 안내(2026-09-10) 첨부 합반내역 "{merged}"'
                         ' · 이러닝 과목: 실시간 수업 시각 미게시'))

    suwon = json.load(open(SUWON, encoding='utf-8'))['courses']
    by_name = {}
    by_reg = {c['sourceId'].rsplit('-', 1)[1]: c for c in suwon}
    for c in suwon:
        by_name.setdefault(c['courseName'].strip(), set()).add(
            (c['courseCode'], c.get('classification') or '', c.get('credits')))

    seen = set()
    aliases = {}
    courses = []
    for reg, title, sched, ntt, remark in rows:
        if reg in seen:
            raise ValueError(f'duplicate registration {reg}')
        seen.add(reg)
        info = by_name.get(title, set())
        code, classification, credits = ('', '', None)
        notes = [f'수강신청 과목번호 {reg} · 서울캠퍼스(주간) · 분반 번호 미게시', remark]
        if reg in MERGED:
            notes.append(f'원문 비고: {MERGED[reg]} · 수업 시각 미게시')
        merged_into = re.search(r'(\d{4})(?:로 합반| 수원 교육봉사로 합반)', remark + ' ' + MERGED.get(reg, ''))
        if merged_into and merged_into.group(1) in by_reg:
            target = by_reg[merged_into.group(1)]
            other = target['courseName'].strip()
            assert re.sub(r'\W', '', other) == re.sub(r'\W', '', title), (reg, title, other)
            if other != title:
                aliases[reg] = [other]
            code, classification, credits = target['courseCode'], target.get('classification') or '', target.get('credits')
            notes.append(f'수원 {merged_into.group(1)} 강좌로 합반: 학수코드·이수구분·학점은 그 강좌(2026-2 수원 공식 PDF) 기준')
        elif len(info) == 1:
            code, classification, credits = next(iter(info))
            notes.append(f'학수코드·이수구분·학점: 같은 학기 수원 공식 PDF의 같은 교과목명 {code} 기준(서울 원문에는 없음)')
        elif title == '관광교재연구및지도법':
            classification = '교육학전공'
        else:
            classification = '교양/일반선택/교육학전공'
            notes.append('이수구분: 공지 제목의 구분 원문(과목별 구분 미게시)')
        if sched:
            try:
                ms = meetings(sched)
                status = 'scheduled'
            except ValueError:
                ms, status = [], 'unrecognized'
        else:
            ms = []
            status = 'unscheduled'
        course = {
            'sourceId': f'kyonggi-seoul-2026-2-registration-{reg}',
            'universityId': 'kyonggi', 'campus': 'seoul', 'academicYear': 2026, 'semester': '2',
            'courseCode': code, 'section': '', 'courseName': title, 'professor': '',
            'departments': [], 'departmentCredits': {}, 'departmentClassifications': {},
            'departmentRemarks': {}, 'classification': classification,
            'remarks': '\n'.join(notes), 'period': TERM,
            'sourceSchedule': sched if sched else ('이러닝' if ntt == '625952' else ''),
            'sourceClassroom': '', 'scheduleStatus': status,
            'schedules': [{'weekday': w, 'startMinute': s, 'endMinute': e, 'classroom': ''} for w, s, e in ms],
            'metadata': {'actualRegistrationNumber': reg, 'sourceNotice': BOARD + ntt},
        }
        if credits is not None:
            course['credits'] = credits
        if reg in aliases:
            course['courseNameAliases'] = aliases[reg]
        courses.append(course)
    courses.sort(key=lambda c: c['sourceId'])

    hashes = {}
    for f in ['n625361.html', 'n625587.html', 'n625261.html', '988383_2026-2 이러닝 합반내역.pdf']:
        hashes[f] = hashlib.sha256(open(os.path.join(src, f), 'rb').read()).hexdigest()
    counts = {}
    for c in courses:
        counts[c['scheduleStatus']] = counts.get(c['scheduleStatus'], 0) + 1
    data = {
        'schemaVersion': 2, 'universityId': 'kyonggi', 'campus': 'seoul', 'campusName': '서울캠퍼스',
        'academicYear': 2026, 'semester': '2', 'publishedDate': '2026-09-10',
        'sourceUrl': BOARD + '625361',
        'sourceNotice': '서울캠 학부 전체 시간표 비공개(KUTIS·수강신청 로그인). 통합공지 공식 공지 4건의 서울 강좌만 담은 부분 자료',
        'sourceNotices': [BOARD + n for n in ['625361', '625587', '625261', '625952']],
        'periodSourceUrl': PERIOD_URL,
        'periodEvidence': '서울캠퍼스(주간) 60분제: 1교시 09:00~09:50 … 9교시 17:00~17:50, 50분 수업/10분간 휴식',
        'sourceScope': 'Seoul daytime partial: official closure/change/e-learning merge notices only',
        'wholeUniversitySupportComplete': False, 'completionClaim': False, 'wholeOperatingVerified': False,
        'sourceRowCount': len(rows), 'courseScheduleStatusCounts': counts, 'sourceHashes': hashes,
        'courses': courses,
    }
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n')
    print(len(courses), counts)


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'work/tt-kyonggi-seoul/src'))
