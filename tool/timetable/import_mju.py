#!/usr/bin/env python3
"""Myongji University (mju) 2026-2 from the official 개설강좌현황표 xlsx.

Source: 입학처 게시글 「2026-2학기 개설강좌현황표_20260812(학생 참고용).xlsx」
https://iphak.mju.ac.kr/pages/?p=1&b=B_1_1&bn=30276&m=read&nPage=1&cate=%EC%8B%9C%EA%B0%84%EC%A0%9C
file https://iphak.mju.ac.kr/_common/new_download_file.php?menu=boardfile&file_no=10702

  python3 tool/timetable/import_mju.py <xlsx> <repository root> <closures.json>

<closures.json> is the official 2026-09-09 「2026-2학기 최종폐강 강좌 내역」
(https://www.mju.ac.kr/bbs/mjukr/143/180492/download.do, includes 1차 폐강),
frozen as work/university-research/catalog-f/mju/mju-current-final-closure-education-20261008.json
in the source-audit fixtures. Closure is not judged (2026-11-23 사용자 결정): a row
on that list stays a course like every other row, and only a remark notes the
listing. A closure whose 교과목명 differs from the spreadsheet row stops the import.

Writes assets/timetable/mju-{humanities,natural}-2026-2.json and
assets/timetable/organizations/mju.json as compact JSON.

Every row is one course (강좌번호 is unique; 분반 is not published). 수업시간 cells
are printed clock times ("1100 - 1150"), so they become weekly meetings as
printed. A 비고 saying the course does not meet every week (집중이수제, D-학기제,
n주, 상·하반기 …) or 자율수강제 does not hold the printed clock: it is kept as a weekly
in-person meeting (2026-11-23 사용자 결정). A printed slot starting before 06:00
("0000 - 0300") is an online placeholder: rows on the official 2026-08-24 원격강좌
list (REMOTE_PLACEHOLDER, 100% 녹화 동영상 수업) become `unscheduled` without that
clock; any other such row is held as `unrecognized`. Rows without any 요일 are
`unscheduled`, except the 계약학과·BCC rows whose times the 미래융합대학 timetable
(CONTRACT_TIMETABLE) prints.

The spreadsheet prints no 이수구분. 전공필수 comes from the latest-admission table
「5. 전공필수 2025학번 이후」 of 「2026-2학기 학사안내문(v1.17).hwp」
(https://www.mju.ac.kr/bbs/mjukr/1725/181422/download.do): a course whose name
equals a listed subject of its own 학과명 gets departmentClassifications '전공필수'.
Subjects listed only as a choice (택 1·택 2), for a sub-group (외국인학생·편입생·
전공에 한함), as 교양, as 폐지 or under "필수해제 신청" are not marked. Every other
course keeps an empty classification (no 전공선택 source).

Semester period: 명지대학교 2026 학사일정 (https://www.mju.ac.kr/mjukr/262/subview.do,
yearSchdul.do year=2026): 09.01 「학기 개시일, 2학기 개강」 through 12.15~12.18
「공휴일로 인한 수업보강(기말고사) 기간」 (기말고사 12.08~12.14).
"""
import hashlib
import json
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

NOTICE = ('https://iphak.mju.ac.kr/pages/?p=1&b=B_1_1&bn=30276&m=read&nPage=1'
          '&cate=%EC%8B%9C%EA%B0%84%EC%A0%9C')
FILE_URL = 'https://iphak.mju.ac.kr/_common/new_download_file.php?menu=boardfile&file_no=10702'
FILE_NAME = '2026-2학기 개설강좌현황표_20260812(학생 참고용).xlsx'
PERIOD = {'startDate': '2026-09-01', 'endDate': '2026-12-18'}
CAMPUS = {'인문': ('humanities', '인문캠퍼스'), '자연': ('natural', '자연캠퍼스')}
WEEKDAY = {'월요일': 1, '화요일': 2, '수요일': 3, '목요일': 4, '금요일': 5, '토요일': 6, '일요일': 7}
NOT_WEEKLY = re.compile(r'D-학기제|D-프로젝트|집중|\d+\s*주|상반기|하반기|자율수강제')
NOT_WEEKLY_NOTE = ('시각 확정: 비고가 매주 수업이 아님을 표시(집중이수·D-학기제·주차 한정·자율수강제 등)하지만 '
                   '원문 요일·시각을 매주 대면 수업으로 둠(2026-11-23 사용자 결정)')
CLOSURE_NOTE = '2026-09-09 「2026-2학기 최종폐강 강좌 내역」에도 실린 강좌(폐강 여부는 판단하지 않음, 2026-11-23 사용자 결정)'
GUIDE_URL = 'https://www.mju.ac.kr/bbs/mjukr/1725/181422/download.do'
# 「2026-2학기 학사안내문(v1.17).hwp」 Ⅲ-5 「전공필수 2025학번 이후」 (최신 입학 학번 기준).
# Only subjects required of every student of the 학과·전공; see the module docstring.
MAJOR_REQUIRED = {
    '인문콘텐츠학부 국어국문학전공': ['현대문학사', '고전문학사', '국어사'],
    '인문콘텐츠학부 영어영문학전공': ['영문학개론', '영어학개론', '중급영어회화'],
    '인문콘텐츠학부 미술사·역사학전공': ['미술사이해', '역사사료이해'],
    '아시아·중동어문학부 중어중문학전공': ['중국문학개론', '중국어문법', '중국고문의이해'],
    '아시아·중동어문학부 일어일문학전공': ['일어학의이해', '일문학의이해', '중급일본어회화2'],
    '아시아·중동어문학부 아랍지역학전공': ['기초아랍어', '아랍어문법1', '초급아랍어회화2', '중급아랍어회화1', '시사아랍어'],
    '공공인재학부 행정학전공': ['사회조사방법론Ⅰ', '정부예산의이해'],
    '공공인재학부 정치외교학전공': ['정치학개론', '비교정치론', '국제정치론'],
    '경상·통계학부 경제학전공': ['미시경제학', '거시경제학', '경제통계'],
    '경상·통계학부 국제통상학전공': ['국제통상원론'],
    '경상·통계학부 응용통계학전공': ['통계학1', '통계학2', '수리통계학1', '수리통계학2', '회귀분석'],
    '법학과': ['형법총론1', '형법총론2', '헌법1', '행정법1', '민법총칙', '채권총론', '상법총칙'],
    '디지털미디어학부': ['미디어조사방법론', '커뮤니케이션이론'],
    '경영학부 경영학전공': ['회계원리', '마케팅원론', '운영관리', '재무관리', '인적자원관리', '재무회계', '경영전략론'],
    '경영정보학과': ['경영정보', '컴퓨터프로그래밍', '프로그래밍기초', '회계원리', '운영관리'],
    '융합소프트웨어학부 응용소프트웨어전공': ['패턴중심사고와프로그래밍', 'DB설계 및 구현1'],
    '융합소프트웨어학부 데이터사이언스전공': ['인공지능수학', '데이터사이언스개론', '머신러닝', '캡스톤디자인1'],
    '디지털콘텐츠디자인학과': ['졸업연구'],
    '멀티디자인학과': ['졸업프로젝트1', '졸업프로젝트2'],  # 2026학번부터 전공필수
    '기계시스템공학부 기계공학전공': ['정역학', '고체역학', '열역학', '유체역학', '기계공학실험1', '기계공학실험2', '캡스톤디자인1', '캡스톤디자인2'],
    '스마트인프라공학부 건설환경공학전공': ['건설환경공학개론', '정역학', '구조역학1', '재료역학', '유체역학1', '수문학', '토질역학1및실험', '콘크리트및실험', '콘크리트구조설계'],
    '스마트인프라공학부 환경시스템공학전공': ['환경화학', '생물학적폐수처리', '대기오염제어공학', '폐기물처리공학', '환경영향평가'],
    '화공신소재공학부 화학공학전공': ['화학공학개론', '화공양론', '화공인공지능', '열역학', '유기화학', '물리화학', '공정유체역학', '열및물질전달', '화학반응공학'],
    '화공신소재공학부 신소재공학전공': ['재료과학및공학1', '재료과학및공학2', '신소재실험1', '신소재실험2', '신소재실험3', '신소재실험4', '캡스톤디자인1', '캡스톤디자인2'],
    '반도체공학부': ['반도체과학', '반도체공학', '프로그래밍', '산학프로젝트1', '산학프로젝트2', '반도체세미나'],
    '전기전자공학부 전기공학전공': ['전기회로실험1', '전기회로실험2', '디지털논리회로실험', '캡스톤디자인1', '캡스톤디자인2'],
    '전기전자공학부 전자공학전공': ['회로이론', '디지털논리회로', '전자기학', '기초전자회로', '지능형센서응용', '반도체공학', '디지털시스템', '신호및시스템', '고급C언어', '회로실험', '캡스톤디자인1'],
    '컴퓨터정보통신공학부 컴퓨터공학전공': ['C언어', '객체지향프로그래밍1', '자료구조', '컴퓨터하드웨어', '운영체제', '소프트웨어공학', '알고리즘', '캡스톤디자인'],
    '컴퓨터정보통신공학부 정보통신공학전공': ['캡스톤디자인1', '캡스톤디자인2'],
    '스포츠학부(체육학전공, 스포츠산업학전공)': ['산악훈련'],
    '아트앤멀티미디어음악학부 건반음악전공': ['전공실기1', '전공실기2', '전공실기3', '전공실기4', '전공실기5(피아노)', '전공실기6(피아노)(D-프로젝트)', '전공실기7(피아노)', '연주프로젝트-캡스톤디자인'] + [f'공연연주발표실습{n}' for n in range(1, 7)] + ['건반초견및화성실습1', '건반초견및화성실습2', '반주법1', '반주법2', '건반악기문헌연구1', '건반악기문헌연구2', '실내악앙상블', '피아노교수법', '현대피아노음악연구'],
    '아트앤멀티미디어음악학부 보컬뮤직전공': ['전공실기1', '전공실기2', '전공실기3', '전공실기4', '전공실기5(성악)', '전공실기6(성악)(D-프로젝트)', '전공실기7(성악)', '전공실기8(성악-리사이틀캡스톤디자인)'] + [f'공연연주발표실습{n}' for n in range(1, 7)] + ['시창', '청음'],
    '아트앤멀티미디어음악학부 작곡전공': ['전공실기1(조성음악기초작곡)', '전공실기2(미디작곡)', '전공실기3(영상음악기초작곡)', '전공실기4(조성음악심화작곡)', '전공실기5(보컬음악작곡)', '전공실기6(현대음악작곡)(D-프로젝트)', '전공실기7(오케스트라작곡)', '전공실기8(졸업작품작곡-캡스톤디자인)'] + [f'공연연주발표실습{n}' for n in range(1, 7)],
    '공연예술학부 연극·영화전공': ['한국영화사', '세계영화사', '사운드기초', '사운드디자인', '시나리오개발워크샵', '영상기초워크샵1', '영상기초워크샵2', '영화제작워크샵1', '영화제작워크샵2', '영화제작프로젝트1(캡스톤디자인)', '영화제작프로젝트2(캡스톤디자인)(D-프로젝트)', '졸업프로젝트1(캡스톤디자인)', '졸업프로젝트2(캡스톤디자인)'],
    '공연예술학부 뮤지컬공연전공': ['종합뮤지컬제작실습1', '종합뮤지컬제작실습2', '종합뮤지컬제작실습3', '뮤지컬제작실습4', '째즈', '클래식발레', '합창1', '합창2', '뮤지컬개론', '기초연기1', '기초연기2', '기초음악이론1', '기초음악이론2', '중급연기1', '중급연기2'],
    '건축학부 건축학전공': ['건축유형과계획', '건축설계와조형', '건축설계1', '건축설계2', '건축구조의이해', '건축과문화', '대지조성계획', '건축CAD', '근현대건축사', '건축재료및구법', '건축설계3', '건축설계4', '건축구조시스템', '환경시스템1', '환경시스템2', '도시주거환경계획', '건축시공', '건축법규', '건축설계5', '건축설계6', '건축설계실무와창업', '건축종합설계1', '건축종합설계2'],
    '건축학부 전통건축학전공': ['건축유형과계획', '건축설계와조형', '건축설계1', '건축설계2', '건축구조의이해', '건축과문화', '대지조성계획', '건축CAD', '근현대건축사', '건축재료및구법', '건축설계3', '건축설계4', '건축구조시스템', '환경시스템1', '환경시스템2', '도시주거환경계획', '건축시공', '건축법규', '건축설계5', '건축설계6', '건축설계실무와창업', '건축종합설계1', '건축종합설계2', '한옥실습', '동양건축사', '목구조', '건축문화유산론', '한옥설계', '하이브리드목구조시스템'],
    '공간디자인학과': ['건축유형과계획', '건축설계와조형', 'CAD', '공간디자인1', '공간디자인2', '색채와재료', '컴퓨터그래픽스', '공간디자인사', '건축구조의이해', '공간디자인3', '공간디자인4', '디지털디자인', '한국의공간문화', '공간디자인방법론', '공간환경과건축설비', '공간디자인5', '공간디자인6', '공간디자인세미나', '경관디자인론', '공간실시설계', '건축법규', '공간디자인실무', '공간디자인7', '공간디자인8'],
}


def subject_key(name):
    return re.sub(r'\s', '', name)


REQUIRED_KEYS = {dept: {subject_key(n) for n in names} for dept, names in MAJOR_REQUIRED.items()}
HOLD_PLACEHOLDER = '시각 보류: 06:00 이전 시작 시각 표기(원격강좌 자리표시 시각으로 보임)'
ONLINE_NOTICE = 'https://www.mju.ac.kr/bbs/mjukr/143/234634/artclView.do'
ONLINE_LIST = 'https://www.mju.ac.kr/bbs/mjukr/143/179821/download.do'
# 「[붙임 2.] 2026-2학기 온라인 수업, 블렌디드러닝 교과목 리스트.pdf」 원격강좌 rows whose
# 개설강좌현황표 slot is a pre-06:00 placeholder (list 2026-08-24, checked 2026-11-23).
REMOTE_PLACEHOLDER = {'0663', '5786', '6006', '6018', '6021', '6034', '6048', '6072', '6082',
                      '6084', '6092', '6093', '6151', '6152', '6153', '6156', '6157', '6158', '6244'}
REMOTE_NOTE = ('시간 없음(원격): 학사공지 「2026학년도 2학기 정규 온라인 수업 안내 (원격수업 및 블렌디드 러닝)」'
               f'(2026-08-24, {ONLINE_NOTICE}) "교내 원격수업 … 15주 모두 녹화 동영상(100%)로 수업"; '
               f'붙임 2 교과목 리스트({ONLINE_LIST})에 인터넷강좌 "원격강좌"로 실림. '
               '06:00 이전 원문 시각은 수업 시각이 아닌 자리표시로 보고 일정에서 뺌(원문은 위에 보존, 조회 2026-11-23)')
CONTRACT_NOTICE = ('https://bizhrd.mju.ac.kr/default/notice/sub1.php?com_board_basic=read_form'
                   '&com_board_idx=751&com_board_id=15')
# 미래융합대학 「2026학년도 2학기 계약학과&BCC과정 수업시간표 및 수강신청내역 안내」(2026-08-24)
# 첨부 시간표의 강의 칸: rows the 개설강좌현황표 prints with no 요일 and 교강사 "추후 업로드 예정".
CONTRACT_TIMETABLE = {
    '6142': ('우희철', [('토요일', '1100 - 1350', 'S3215', 660, 830)], '2026-2 계약학과 시간표 최종.pdf 9쪽 [스포츠산업경영학과] 3·4학년 토'),
    '6143': ('강제호', [('월요일', '1400 - 1650', 'S10223', 840, 1010)], '2026-2 계약학과 시간표 최종.pdf 9쪽 [스포츠산업경영학과] 1학년 월'),
    '6144': ('송여원', [('월요일', '1100 - 1350', 'S10223', 660, 830)], '2026-2 계약학과 시간표 최종.pdf 9쪽 [스포츠산업경영학과] 1학년 월'),
    '6165': ('김경미', [('토요일', '0900 - 1130', 'S1533', 540, 690)], '2026-2 계약학과 시간표 최종.pdf 6쪽 [복지상담경영학과A] 4학년(편) 토'),
    '6296': ('이진아', [('화요일', '0900 - 1150', 'S10215', 540, 710)], '2026-2 BCC 시간표 최종.pdf 9쪽 [뷰티비지니스학과 1학년] 화'),
}
NS = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
COLLEGE_ROW = '대학'  # 단과대 "대학" rows print the college itself in 학과명.
PROGRAM_GROUPS = {'융합전공'}  # 단과대 열에 전공제도 이름이 인쇄된 묶음


def rows(path):
    """First sheet of an xlsx as lists of strings (shared and inline strings)."""
    z = zipfile.ZipFile(path)
    shared = []
    if 'xl/sharedStrings.xml' in z.namelist():
        for si in ET.fromstring(z.read('xl/sharedStrings.xml')).findall('m:si', NS):
            shared.append(''.join(t.text or '' for t in si.iter('{%s}t' % NS['m'])))
    out = []
    sheet = ET.fromstring(z.read('xl/worksheets/sheet1.xml'))
    for r in sheet.iter('{%s}row' % NS['m']):
        row = {}
        for c in r.findall('m:c', NS):
            col = 0
            for ch in re.match(r'[A-Z]+', c.get('r')).group(0):
                col = col * 26 + ord(ch) - 64
            v = c.find('m:v', NS)
            if c.get('t') == 's' and v is not None:
                row[col - 1] = shared[int(v.text)]
            elif c.get('t') == 'inlineStr':
                row[col - 1] = ''.join(x.text or '' for x in c.iter('{%s}t' % NS['m']))
            elif v is not None:
                row[col - 1] = v.text
        if row:
            out.append([(row.get(i) or '').strip() for i in range(max(row) + 1)])
    return out


def slots(r):
    """(weekday text, time text, room, parsed minutes or None) for each printed slot."""
    out = []
    for k in '123':
        day, time, room = r[f'요일{k}'], r[f'수업시간{k}'], r[f'강의실{k}']
        if not day and time in ('', '-'):
            continue
        m = re.fullmatch(r'(\d\d)(\d\d) - (\d\d)(\d\d)', time)
        if day not in WEEKDAY or not m:
            raise ValueError(f"{r['강좌번호']}: unexpected slot {day!r} {time!r}")
        a, b, c, d = map(int, m.groups())
        start, end = a * 60 + b, c * 60 + d
        if b > 59 or d > 59 or not 0 <= start < end <= 1440:
            raise ValueError(f"{r['강좌번호']}: invalid clock {time!r}")
        out.append((day, time, room, start, end))
    return out


def closed_rows(path):
    data = json.loads(Path(path).read_text(encoding='utf-8'))
    if data.get('nativeHeading') != '2026-2학기 최종폐강 강좌 내역':
        raise ValueError('unexpected closure list')
    return {(c['campus'], c['nativeLectureNumber']): c for c in data['closedCourses']
            if c['status'] == '폐강'}, data


def build(src, root, closures_path):
    data = rows(src)
    closed, closure_doc = closed_rows(closures_path)
    listed = 0
    sha = hashlib.sha256(Path(src).read_bytes()).hexdigest()
    head = [re.sub(r'\s+', '', h) for h in data[0]]
    table = [dict(zip(head, r + [''] * (len(head) - len(r)))) for r in data[1:]]
    by_campus = {cid: [] for cid, _ in CAMPUS.values()}
    labels = {}
    for r in table:
        if (r['년도'], r['학기']) != ('2026', '2'):
            raise ValueError(f"{r['강좌번호']}: not 2026-2")
        campus, _ = CAMPUS[r['캠퍼스']]
        code, dept, college = r['강좌번호'], r['학과명'], r['단과대']
        if not (code and dept and college and r['교과목명']):
            raise ValueError(f'missing key cell: {r}')
        closure = closed.get((r['캠퍼스'], code))
        if closure:
            if re.sub(r'\s', '', closure['courseName']) != re.sub(r'\s', '', r['교과목명']):
                raise ValueError(f'{code}: closure name {closure["courseName"]} != {r["교과목명"]}')
            listed += 1
        labels.setdefault(dept, (campus, college, code))
        if labels[dept][:2] != (campus, college):
            raise ValueError(f'{dept}: printed under two campuses/colleges')
        found = slots(r)
        remark = r['비고']
        hold = None
        note = []
        professor = r['교강사명']
        if code in CONTRACT_TIMETABLE:
            if found or professor != '추후 업로드 예정':
                raise ValueError(f'{code}: 계약학과 시간표 override no longer matches the row')
            professor, found, where = CONTRACT_TIMETABLE[code]
            note.append(f'시각 확정: 미래융합대학 「2026학년도 2학기 계약학과&BCC과정 수업시간표 및 수강신청내역 안내」'
                        f'(2026-08-24, {CONTRACT_NOTICE}) {where} 칸 "{r["교과목명"]}({code}) / {professor} / '
                        f'{found[0][2]}" {found[0][1]} (조회 2026-11-23; 현황표 교강사 "추후 업로드 예정")')
        if any(s[3] < 360 for s in found):
            if code in REMOTE_PLACEHOLDER and r['인터넷강좌'] == '원격강좌':
                found = []
                note.append(REMOTE_NOTE)
            else:
                hold = HOLD_PLACEHOLDER
        elif found and NOT_WEEKLY.search(remark):
            note.append(NOT_WEEKLY_NOTE)
        if closure:
            note.append(CLOSURE_NOTE)
        required = subject_key(r['교과목명']) in REQUIRED_KEYS.get(dept, ())
        status = 'unscheduled' if not found else 'unrecognized' if hold else 'scheduled'
        text = ' / '.join(f'{h} {v}' for h, v in r.items() if v and v != '-')
        credits = float(r['학점'])
        course = {
            'sourceId': f'mju/{campus}/2026/2/{code}',
            'campus': campus, 'academicYear': 2026, 'semester': '2',
            'courseCode': code, 'section': '', 'courseName': r['교과목명'],
            'professor': professor, 'classification': '', 'credits': credits,
            'departments': [dept], 'departmentCredits': {dept: credits},
            'departmentClassifications': {dept: '전공필수'} if required else {},
            'sourceSchedule': ', '.join(f'{s[0]} {s[1]}' for s in found),
            'sourceClassroom': ', '.join(s[2] for s in found if s[2]),
            'remarks': f'2026-2학기 개설강좌현황표(2026. 8. 12.) 원문: {text}'
                       + (f' | {hold}' if hold else '') + ''.join(f' | {n}' for n in note)
                       + (f' | 전공필수: 「2026-2학기 학사안내문(v1.17)」 전공필수 2025학번 이후 표({GUIDE_URL})' if required else ''),
            'period': PERIOD, 'scheduleStatus': status,
            'schedules': [] if status != 'scheduled' else [
                {'weekday': WEEKDAY[s[0]], 'startMinute': s[3], 'endMinute': s[4], 'classroom': s[2]}
                for s in found
            ],
        }
        if hold:
            course['holdReasons'] = [hold.removeprefix('시각 보류: ')]
        by_campus[campus].append(course)
    ids = [c['courseCode'] for cs in by_campus.values() for c in cs]
    assert len(ids) == len(set(ids)) == len(table), 'duplicate 강좌번호'
    root = Path(root)
    summary = {}
    for code_name, (campus, name) in CAMPUS.items():
        courses = by_campus[campus]
        counts = {}
        for c in courses:
            counts[c['scheduleStatus']] = counts.get(c['scheduleStatus'], 0) + 1
        dataset = {
            'schemaVersion': 2, 'universityId': 'mju', 'campus': campus, 'campusName': name,
            'academicYear': 2026, 'semester': '2', 'publishedDate': '2026-08-12',
            'sourceUrl': NOTICE,
            'sourceNotice': f'입학처 게시 「{FILE_NAME}」({FILE_URL}) 캠퍼스 열 "{code_name}" 행. '
                            '학생 참고용 자료이며 분반·이수구분은 공개되지 않았습니다.',
            'sourceHashes': {FILE_NAME: sha}, 'sourceRowCount': len(courses),
            'courseScheduleStatusCounts': counts,
            'closureListing': {'sourceUrl': closure_doc['sourceUrl'],
                               'publishedDate': closure_doc['publishedDate'],
                               'courseCodes': [c['courseCode'] for c in courses
                                               if CLOSURE_NOTE in c['remarks']]},
            'researchOnly': False, 'productionIntegrationEnabled': True,
            'completionClaim': False, 'wholeOperatingVerified': False,
            'courses': courses,
        }
        write(root / f'assets/timetable/mju-{campus}-2026-2.json', dataset)
        summary[campus] = counts
    mappings = []
    for dept, (campus, college, code) in labels.items():
        evidence = f'{FILE_NAME} 단과대 열 "{college}", 학과명 열 "{dept}" (강좌번호 {code})'
        base = {'sourceLabel': dept, 'sourceUrl': NOTICE, 'evidence': evidence,
                'sourceFile': FILE_URL, 'campus': campus, 'collegeKnown': True}
        if college == COLLEGE_ROW:
            mappings.append({'college': dept, 'department': None, **base,
                             'isOfferingUnit': True, 'affiliationStatus': 'verified'})
        elif college in PROGRAM_GROUPS:
            mappings.append({'group': college, 'department': dept, **base,
                             'isOfferingUnit': False, 'affiliationStatus': 'officialProgramSystem'})
        else:
            mappings.append({'college': college, 'department': dept, **base,
                             'isOfferingUnit': False, 'affiliationStatus': 'verified'})
    write(root / 'assets/timetable/organizations/mju.json',
          {'schemaVersion': 1, 'university': 'mju', 'mappings': mappings, 'courseOwners': []})
    result = {'rows': len(table), 'closureListed': listed,
              'required': sum(1 for cs in by_campus.values() for c in cs if c['departmentClassifications']),
              'status': summary, 'mappings': len(mappings)}
    print(json.dumps(result, ensure_ascii=False))
    return result


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')


if __name__ == '__main__':
    build(sys.argv[1], sys.argv[2], sys.argv[3])
