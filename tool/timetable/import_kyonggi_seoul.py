"""경기대 서울캠퍼스(주간) 2026-2 공개 강좌 → assets/timetable/kyonggi-seoul-2026-2.json

서울캠 학부 전체 시간표는 공개되어 있지 않다(KUTIS·sugang 로그인). 그래서 통합공지
(key=7520, bbsNo=1073)의 공식 공지 4건에 실린 서울 강좌만 모은 부분 자료다.

  625361 2026-2 교양·일반선택·교육학전공 1차 폐강 강좌 안내 (자유교양대학, 2026-08-18)
  625587 같은 2차 폐강 강좌 안내 (2026-08-27)
  625261 2026-2 교양/교육학전공/ROTC 변동 예정 강좌 안내 (2026-08-07)
  625952 교내이러닝·가상대학이러닝 합반 안내 첨부 '2026-2 이러닝 합반내역.pdf' (2026-09-10)
  625108 2026-2 교양/일반선택 이수요건 및 수강신청 안내 첨부 PDF (자유교양대학, 2026-07-31)
         p.12 '교양 및 일반선택 영역별 교양 그룹번호 (서울)': 그룹명에 요일·교시가 있다.
  625109 같은 날 '교양 및 일반선택 교과목 동일·유사과목 지정 및 재수강 안내' 붙임1·2 PDF
         (2026 교양 교육과정 학수코드)

규칙
- 원문 행(캠퍼스 '서울' 또는 '서울주간')만 넣는다. 강좌명·과목번호·요일교시 원문은 그대로 둔다.
- 폐강 표기는 판단하지 않는다(스킬 0.1). 요일·교시가 있으면 scheduled.
- 교시: 학사안내 강의시간 안내(contents.do?key=8430) 서울캠퍼스(주간) 60분제
  1교시 09:00~09:50 … 9교시 17:00~17:50, 50분 수업+10분 휴식 → 슬롯 60분(n교시 = 08:00+60n분).
  같은 요일 연속 교시는 한 구간으로 합친다.
- 같은 공지 안에서 변경 전/후가 있으면 변경 후(최신 공식값), 변경 전은 비고에 둔다.
- 시각이 없는 행(이러닝 합반, 교육봉사)은 unscheduled.
- 학수코드·이수구분·학점은 서울 원문에 없다. 공지가 수원 강좌와 합반(같은 수업)이라고 밝힌
  행만 그 수원 강좌(kyonggi-suwon-2026-2.json, 2026-2 수원 공식 PDF) 값을 쓰고 비고에 근거를 남긴다.
  교과목명만 같은 강좌에서는 가져오지 않는다. 그 밖의 행은 공지의 구분 원문을 classification에 두고
  학수코드는 비우며 학점 필드는 생략한다.
- 서울 교양 그룹 중 한 과목만 있는 영역(진성애인성·지역문제의창의적해결·사고와표현·대학영어·
  소프트웨어기초·컴퓨팅사고)은 그룹 = 그 과목의 그 요일·교시 강좌로 넣는다(sourceId ...-group-NN).
  여러 과목이 있는 영역(핵심교양·외국어영역·일반선택)은 과목명이 없어 넣지 않는다.
  같은 과목(명칭 접두 일치)·같은 요일교시의 공지 강좌가 이미 있으면 그 그룹은 중복이라 넣지 않는다.
  그룹 안 분반 수·과목번호는 원문에 없다.
- 625109 붙임1·2가 '2026 교양 교육과정' 학수코드를 적은 과목은 그 코드를 쓴다(CURRICULUM의 원문 줄을
  PDF에서 확인). 학점은 붙임 원문이 밝힌 것만: 붙임2 'AS395 대학영어(3학점)', 붙임1은 '동일과목,
  유사과목은 학점이 같은 경우만 지정됩니다'라고 했으므로 지정 근거가 된 폐지 과목 학점.
- 교수·강의실은 원문에 없으므로 비운다.

실행(저장소 루트): python3 tool/timetable/import_kyonggi_seoul.py <원본 폴더>
원본 폴더에는 n625361.html, n625587.html, n625261.html, 988383_2026-2 이러닝 합반내역.pdf 와
SOURCE_PDFS의 세 PDF가 있어야 한다(기본: work/tt1a-reopen/kyonggi/seoul-src).
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
GUIDE_PDF = '987011_2026-2 교양 이수요건 및 수강신청 안내.pdf'
SAME_PDF = '986953_붙임1 교양 및 일반선택 동일 및 유사과목 지정현황.pdf'
ENGLISH_PDF = '986954_붙임2 대학영어 및 제2외국어 재수강 안내.pdf'
TEACHER_HTML = 'u_teacher_contents_key7041.html'  # 교직학부 교직과목(https://www.kyonggi.ac.kr/u_teacher/contents.do?key=7041)
SOURCE_PDFS = [GUIDE_PDF, SAME_PDF, ENGLISH_PDF, TEACHER_HTML]
# 학점만 원문에 있는 과목: 과목명 → (학점, 원문 줄). ②는 필수 2학점 표기.
CREDIT_ONLY = {'교육철학및교육사': (2.0, '교육철학및교육사 ②')}
# 서울 교양 그룹명 머리 → 과목명 (한 과목만 있는 영역)
GROUP_COURSES = {'인성-진성애인성': '진성애인성', '인성-지역문제의창의적해결': '지역문제의창의적해결',
                 '사고-사고와표현': '사고와표현', '대학영어': '대학영어',
                 'SW-소프트웨어기초': '소프트웨어기초', 'SW-컴퓨팅사고': '컴퓨팅사고'}
# 과목명 → (2026 학수코드, 학점, PDF, 원문 줄). 학점은 동일·유사과목 '학점이 같은 경우만 지정' 규칙의 폐지 과목 학점.
CURRICULUM = {
    '대학영어5(시사영어)': ('AS364', 3.0, SAME_PDF, 'AS042 시사영어 3학점 외영 AS364 대학영어5(시사영어)'),
    '데이터와통계': ('AS446', 3.0, SAME_PDF, 'CB005 컴퓨터경영통계 3학점 융합 AS446 데이터와통계'),
    '경제학이해하기': ('AS407', 3.0, SAME_PDF, 'AS685 경제학원론 3학점 사회 AS407 경제학이해하기'),
    '디지털콘텐츠로만나는세계의교육': ('AT039', 3.0, SAME_PDF, 'AS993 글로컬시대의대학교육 3학점 역사 AT039 디지털콘텐츠로만나는세계의교육'),
    '에피소드로읽는서양철학의인물과사상': ('AT017', 3.0, SAME_PDF, 'AS886 철학과영화 3학점 인간 AT017 에피소드로읽는서양철학의인물과사상'),
    '테마로보는미술': ('AS420', 3.0, SAME_PDF, 'AS834 미술사 3학점 심미 AS420 테마로보는미술'),
    '소셜리빙랩과지역혁신': ('AT025', 3.0, SAME_PDF, 'AT005 지역문제해결과소셜리빙랩 3 사회 AT025 소셜리빙랩과지역혁신'),
    '이공계학부생들을위한바이오기술의이해': ('AT049', 3.0, SAME_PDF, 'AS945 바이오테크놀러지,A에서Z까지 3 과학 AT049 이공계학부생들을위한바이오기술의이해'),
    '지역문제의창의적해결': ('AT101', 3.0, SAME_PDF, 'AS379 창의적문제해결 3 인성 AT101 지역문제의창의적해결'),
    '사고와표현': ('AS371', 3.0, SAME_PDF, 'AS794 글쓰기 3학점 사고 AS371 사고와표현'),
    '대학영어': ('AS395', 3.0, ENGLISH_PDF, "2024년 개설되는 ‘AS395 대학영어(3학점)’"),
}


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


def pdf_text(path):
    import pdfplumber  # development/pdf-venv
    with pdfplumber.open(path) as d:
        return [p.extract_text() or '' for p in d.pages]


def seoul_groups(src):
    """625108 첨부 p.12 서울 교양 그룹 → [(번호, 그룹명, 과목명, 요일교시, 영역)]"""
    pages = pdf_text(os.path.join(src, GUIDE_PDF))
    page = pages[11]
    assert '교양 및 일반선택 영역별 교양 그룹번호 (서울)' in page
    out = []
    for m in re.finditer(r'(\d\d)\.([^\s(]+)\(([월화수목금토])(\d+)(?:,\s*([A-Za-z-]+))?\)', page):
        no, head, day, periods, level = m.groups()
        if head not in GROUP_COURSES:
            continue
        area = '인성교양' if int(no) <= 13 else '기초교양'
        out.append((no, m.group(0)[3:], GROUP_COURSES[head], day + periods, area, level or ''))
    # 진성애인성 4 + 지역문제 8 + 사고와표현 4 + 대학영어 7 + 소프트웨어기초 4 + 컴퓨팅사고 4
    assert len(out) == 31 and len({g[0] for g in out}) == 31, len(out)
    return out


def main(src):
    flat = {}
    for f in (SAME_PDF, ENGLISH_PDF):
        flat[f] = re.sub(r'\s+', ' ', ' '.join(pdf_text(os.path.join(src, f))))
    for title, (code, _, f, line) in CURRICULUM.items():
        assert line in flat[f], (title, line)
    teacher = re.sub(r'\s+', ' ', html.unescape(
        re.sub(r'<[^>]+>', ' ', open(os.path.join(src, TEACHER_HTML), encoding='utf-8').read())))
    for title, (_, line) in CREDIT_ONLY.items():
        assert line in teacher, (title, line)
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

    def norm(x):
        return re.sub(r'\W', '', x)
    taken = {(norm(t), norm(s)) for _, t, s, _, _ in rows if s}
    skipped_groups = []
    for no, group, title, sched, area, level in seoul_groups(src):
        if any(n.startswith(norm(title)) and s == norm(sched) for n, s in taken):
            skipped_groups.append(group)
            continue
        rows.append((f'G{no}', title, sched, '625108',
                     f'공식 공지: 2026학년도 2학기 교양/일반선택 이수요건 및 수강신청 안내(2026-07-31) 첨부 p.12 '
                     f'교양 그룹번호(서울) "{no}.{group}" · {area}'
                     + (f' · 수준 {level}' if level else '')
                     + ' · 그룹 안 분반 수·과목번호·교수·강의실 미게시'))

    suwon = json.load(open(SUWON, encoding='utf-8'))['courses']
    by_reg = {c['sourceId'].rsplit('-', 1)[1]: c for c in suwon}

    seen = set()
    aliases = {}
    courses = []
    for reg, title, sched, ntt, remark in rows:
        if reg in seen:
            raise ValueError(f'duplicate registration {reg}')
        seen.add(reg)
        code, classification, credits = ('', '', None)
        group = reg.startswith('G')
        notes = [remark] if group else [f'수강신청 과목번호 {reg} · 서울캠퍼스(주간) · 분반 번호 미게시', remark]
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
        elif group:
            classification = '인성교양' if '인성교양' in remark else '기초교양'
            notes.append(f'이수구분: 첨부 p.12 영역 원문 "{classification}"')
        elif ntt == '625261':
            # 공지 본문의 구분 머리('*교양 교과목' / '*교육학전공') 원문
            classification = '교육학전공' if title == '관광교재연구및지도법' else '교양'
            notes.append(f'이수구분: 공지 본문 구분 원문 "{classification}"')
        else:
            classification = '교양/일반선택/교육학전공'
            notes.append('이수구분: 공지 제목의 구분 원문(과목별 구분 미게시)')
        if not code and title in CURRICULUM:
            code, credits, f, line = CURRICULUM[title]
            label = '붙임1 교양 및 일반선택 교과목 중 동일 및 유사과목 지정현황' if f == SAME_PDF else '붙임2 대학영어 및 제2외국어 재수강 안내'
            notes.append(f'학수코드·학점: 625109 {label}(2026 교양 교육과정) "{line}"'
                         + (' · 동일·유사과목은 학점이 같은 경우만 지정' if f == SAME_PDF else ''))
        if credits is None and title in CREDIT_ONLY:
            credits, line = CREDIT_ONLY[title]
            notes.append(f'학점: 교직학부 교직과목 안내(u_teacher contents.do?key=7041) 교직이론 "{line}"(② 필수 2학점) · 학수코드 미게시')
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
            'sourceId': f'kyonggi-seoul-2026-2-group-{reg[1:]}' if group else f'kyonggi-seoul-2026-2-registration-{reg}',
            'universityId': 'kyonggi', 'campus': 'seoul', 'academicYear': 2026, 'semester': '2',
            'courseCode': code, 'section': '', 'courseName': title, 'professor': '',
            'departments': [], 'departmentCredits': {}, 'departmentClassifications': {},
            'departmentRemarks': {}, 'classification': classification,
            'remarks': '\n'.join(notes), 'period': TERM,
            'sourceSchedule': sched if sched else ('이러닝' if ntt == '625952' else ''),
            'sourceClassroom': '', 'scheduleStatus': status,
            'schedules': [{'weekday': w, 'startMinute': s, 'endMinute': e, 'classroom': ''} for w, s, e in ms],
            'metadata': ({'seoulGeneralEducationGroup': reg[1:]} if group else {'actualRegistrationNumber': reg})
            | {'sourceNotice': BOARD + ntt},
        }
        if credits is not None:
            course['credits'] = credits
        if reg in aliases:
            course['courseNameAliases'] = aliases[reg]
        courses.append(course)
    courses.sort(key=lambda c: c['sourceId'])

    hashes = {}
    for f in ['n625361.html', 'n625587.html', 'n625261.html', '988383_2026-2 이러닝 합반내역.pdf'] + SOURCE_PDFS:
        hashes[f] = hashlib.sha256(open(os.path.join(src, f), 'rb').read()).hexdigest()
    counts = {}
    for c in courses:
        counts[c['scheduleStatus']] = counts.get(c['scheduleStatus'], 0) + 1
    data = {
        'schemaVersion': 2, 'universityId': 'kyonggi', 'campus': 'seoul', 'campusName': '서울캠퍼스',
        'academicYear': 2026, 'semester': '2', 'publishedDate': '2026-09-10',
        'sourceUrl': BOARD + '625361',
        'sourceNotice': '서울캠 학부 전체 시간표 비공개(KUTIS·수강신청 로그인). 통합공지 공식 공지(폐강·변동·이러닝 합반·교양 그룹번호)의 서울 강좌만 담은 부분 자료',
        'sourceNotices': [BOARD + n for n in ['625361', '625587', '625261', '625952', '625108', '625109']],
        'periodSourceUrl': PERIOD_URL,
        'periodEvidence': '서울캠퍼스(주간) 60분제: 1교시 09:00~09:50 … 9교시 17:00~17:50, 50분 수업/10분간 휴식',
        'sourceScope': 'Seoul daytime partial: official closure/change/e-learning merge notices and single-course general-education group slots only',
        'wholeUniversitySupportComplete': False, 'completionClaim': False, 'wholeOperatingVerified': False,
        'sourceRowCount': len(rows), 'courseScheduleStatusCounts': counts, 'sourceHashes': hashes,
        'courses': courses,
    }
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n')
    print(len(courses), counts, 'skipped groups:', skipped_groups)


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'work/tt1a-reopen/kyonggi/seoul-src'))
