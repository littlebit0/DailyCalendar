"""Audit published 2026-2 undergraduate catalog files; does not enable Daily.
Requires the already bundled openpyxl. Every published row is retained.
"""
from collections import Counter
import json
from pathlib import Path
import re
import openpyxl

ROOT = Path(__file__).resolve().parent

def sheet(name, skip):
    book = openpyxl.load_workbook(ROOT / name, data_only=True)
    if len(book.worksheets) != 1:
        raise ValueError('Unexpected official workbook sheet count')
    return list(book.active.values)[skip:]

def text(value):
    return '' if value is None else str(value).strip()

def closed_keys(name):
    return {(str(int(r[2])), str(int(r[4]))) for r in sheet(name, 4)}

closed1 = closed_keys('kangwon-samcheok-closed1-0.xlsx')
closed2 = closed_keys('kangwon-samcheok-closed2-0.xlsx')
courses = []
for row in sheet('kangwon-chuncheon-2026-2.xlsx', 5):
    courses.append(dict(campus='chuncheon', code=text(row[3]), section=text(row[4]),
        name=text(row[5]), classification=text(row[2]), hours=text(row[6]),
        department=text(row[11]), major=text(row[12]), professor=text(row[13]),
        sourceSchedule=text(row[14]), classroomEmbedded=True,
        target=text(row[8]), remote=row[15]=='Y', remarks=text(row[17]),
        closed=row[18]=='Y', source='kangwon-chuncheon-2026-2.xlsx'))
for row in sheet('kangwon-gangneung-wonju-2026-2.xlsx', 4):
    if row[2] not in {'강릉', '원주'}:
        raise ValueError('Unexpected campus')
    courses.append(dict(campus={'강릉':'gangneung','원주':'wonju'}[row[2]],
        code=text(row[6]), section=text(row[7]), name=text(row[8]),
        classification=text(row[5]), credits=row[10], hours=text(row[11]),
        department=text(row[3]), professor=text(row[13]), sourceSchedule=text(row[14]),
        classroom=text(row[15]), classroomEmbedded=False, target=text(row[9]),
        remote=row[16]=='Y', remarks=text(row[17]), closed=row[18]=='Y',
        publishedClockType=text(row[12]), source='kangwon-gangneung-wonju-2026-2.xlsx'))
for row in sheet('kangwon-samcheok-full-0.xlsx', 4):
    if row[18] not in {'Y','N'}:
        raise ValueError('Unexpected Dogye classification')
    key=(text(row[2]),text(row[3]))
    courses.append(dict(campus='dogye' if row[18]=='Y' else 'samcheok',
        code=key[0], section=key[1], name=text(row[4]), classification=text(row[1]),
        hours=text(row[5]), department=text(row[10]), major=text(row[11]),
        professor=text(row[12]), sourceSchedule=text(row[14]), classroomEmbedded=True,
        target=text(row[7]), remote=row[16]=='Y', remarks=text(row[17]),
        closed=key in closed1 | closed2, source='kangwon-samcheok-full-0.xlsx'))
seen=set()
for c in courses:
    identity=(c['campus'],c['code'],c['section'])
    if identity in seen or not re.fullmatch(r'\d{8}',c['code']) or not re.fullmatch(r'[A-Za-z0-9]{1,2}',c['section']):
        raise ValueError('Invalid or duplicate course identity: ' + str(identity))
    seen.add(identity)
summary={}
for campus in sorted({c['campus'] for c in courses}):
    rows=[c for c in courses if c['campus']==campus]
    active=[c for c in rows if not c['closed']]
    summary[campus]={'publishedRows':len(rows), 'closedRows':len(rows)-len(active),
        'activeRows':len(active), 'emptyScheduleRows':sum(not c['sourceSchedule'] for c in active),
        'remoteRows':sum(c['remote'] for c in active)}
unknown=[{k:c[k] for k in ['campus','code','section','name','sourceSchedule']} for c in courses
    if c['campus'] in {'gangneung','wonju'} and re.search(r'(?<!\d)15(?!\d)',c['sourceSchedule'])]
manifest={'year':2026,'semester':'2','officialWorkbookRowCount':len(courses),
    'uniqueCampusCourseSectionCount':len(seen), 'campusCounts':summary,
    'completePublishedCampusCollection':True,'fullEnablingSafe':False,
    'unverified15PeriodCourses':unknown,
    'blockers':['15 period not defined by current official clocks',
        'Clinical placement/concentrated course exact date ranges not yet verified',
        'Some source room strings contain nested parentheses and multiple distinct classrooms; parse fully',
        'Check updated Gangneung/Wonju closures and live public enrollment query if available'],
    'noticeUrls':{'chuncheon':'https://kangwon.ac.kr/ko/bbs/720/detail.do?pstSn=2536',
        'gangneungWonju':'https://www.kangwon.ac.kr/ko/bbs/720/detail.do?pstSn=2545',
        'samcheokDogye':'https://www.kangwon.ac.kr/ko/bbs/720/detail.do?pstSn=2534',
        'samcheokClosed1':'https://www.kangwon.ac.kr/ko/bbs/720/detail.do?pstSn=2573',
        'samcheokClosed2':'https://www.kangwon.ac.kr/ko/bbs/720/detail.do?pstSn=2581',
        'gangneungWonjuGuide':'https://www.kangwon.ac.kr/ko/bbs/720/detail.do?pstSn=2553',
        'clock':'https://www.kangwon.ac.kr/ko/conts/465/web.do'}}
(ROOT/'kangwon-public-course-rows.json').write_text(json.dumps(courses,ensure_ascii=False,indent=2)+'\n')
(ROOT/'kangwon-catalog-audit.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'counts':summary,'total':len(courses),'unknown15':len(unknown)},ensure_ascii=False))
