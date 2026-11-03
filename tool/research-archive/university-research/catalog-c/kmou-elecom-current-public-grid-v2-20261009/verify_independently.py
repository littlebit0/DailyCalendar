import datetime as dt
import hashlib
import json
import pathlib
import re

p = pathlib.Path(__file__).parent
old = p.parent / 'kmou-current-20261008'
load = lambda name: json.loads((p / name).read_text())
base = load('prior13-current-asset-snapshot.json')
candidate = load('kmou-unknown-2026-2.elecom-partial-v2.json')
raw = load('current2026-2-revised-grid.hwp.tables.json')[0]
receipt = load('independent-educational-receipt.json')
assert candidate['courses'][:13] == base['courses']
assert len(base['courses']) == 13
assert sum(len(c['schedules']) for c in base['courses']) == 179
# This literal independent weekday/date list is not read from candidate plans.
dates = {1: ['2026-09-21','2026-09-28','2026-10-12','2026-10-19'],
         2: ['2026-09-15','2026-09-22','2026-09-29','2026-10-06','2026-10-13'],
         3: ['2026-09-16','2026-09-23','2026-09-30','2026-10-07','2026-10-14'],
         4: ['2026-09-17','2026-10-01','2026-10-08','2026-10-15']}
clocks = {1:(540,590),2:(600,650),3:(660,710),4:(720,770),5:(780,830),6:(840,890),7:(900,950),8:(960,1010),9:(1020,1070),10:(1080,1130)}
assert len(candidate['courses'][13:]) == 17
all_meetings = []
for course, proof in zip(candidate['courses'][13:], receipt['literalProofs']):
    education = course['sourceEducation']
    table = raw['tables'][education['table']]
    cell = next(v for v in table['cells'] if (v['row'],v['column']) == (education['row'],education['column']))
    assert cell['paragraphs'] == education['nativeParagraphs']
    assert course['professor'] in cell['paragraphs']
    assert course['sourceId'] == proof['sourceId']
    assert proof['literalDates'] == dates[education['column']]
    assert raw['paragraphs'][education['table']*2]['text'] == education['nativeYearHeading']
    assert '2026-2' in education['nativeYearHeading']
    assert course['courseCode'] == course['section'] == course['classification'] == ''
    assert course['credits'] is None and course['campus'] == 'unknown'
    expected = []
    for date in dates[education['column']]:
        assert dt.date.fromisoformat(date).isoweekday() == education['column']
        for native in education['nativeClockPeriods']:
            header = next(v for v in table['cells'] if (v['row'],v['column']) == (native['period'],0))
            assert ' / '.join(header['paragraphs']) == native['clockText']
            nums = [int(v) for v in re.findall(r'\d+', native['clockText'])]
            offset = 720 if native['period'] >= 5 else 0
            hh = (nums[1]*60+nums[2]+offset, nums[3]*60+nums[4]+offset)
            assert hh == clocks[native['period']]
            assert native['classroom'] in '\n'.join(cell['paragraphs'])
            expected.append({'date':date,'weekday':education['column'],'startMinute':hh[0], 'endMinute':hh[1], 'classroom':native['classroom'],'sourceTable':education['table'],'sourceRow':native['period'],'sourceColumn':education['column']})
    assert expected == course['schedules']
    all_meetings.extend(expected)
assert len(all_meetings) == 247
# No source can independently guarantee final active sections without native code join.
closure = json.loads((old/'closure-education.json').read_text())
normalize = lambda s: re.sub(r'\s+', '', s)
assert len(closure['courses']) == 59
for c in candidate['courses'][13:]:
    assert not [v for v in closure['courses'] if normalize(v['courseName']) == normalize(c['courseName'])]
prior_professors = sorted({c['professor'] for c in base['courses']})
new_professors = sorted({c['professor'] for c in candidate['courses'][13:]})
shared = sorted(set(prior_professors) & set(new_professors))
conflicts = []
checked_pairs = 0
for a in base['courses']:
    for b in candidate['courses'][13:]:
        checked_pairs += 1
        if a['professor'] != b['professor']:
            continue
        for x in a['schedules']:
            for y in b['schedules']:
                if x['date'] == y['date'] and max(x['startMinute'],y['startMinute']) < min(x['endMinute'],y['endMinute']):
                    conflicts.append([a['sourceId'],b['sourceId'],x,y])
assert not conflicts and not shared
calendar = json.loads((old/'calendar-operating-education.json').read_text())
expected_mapping = [('2026-09-24','2026-12-10'),('2026-09-25','2026-12-11'),('2026-10-05','2026-12-14'),('2026-10-09','2026-12-08'),('2026-11-05','2026-12-09')]
assert [(v['original'],v['makeup']) for v in calendar['makeupMapping']] == expected_mapping
assert not any(x['date'] in dict(expected_mapping) for x in all_meetings)
report = {
'researchOnly':True,'productionIntegrationEnabled':False,'completionClaim':False,
'newDocumentItems':17,'newLiteralMeetings':247,'priorWholeObjectsEqual':True,'priorItems':13,'priorMeetings':179,'totalItems':30,'totalMeetings':426,
'window': {'kind':'conservative candidate meeting window; NOT semester start/end; NOT makeup notice period', 'startDate':'2026-09-15','endDate':'2026-10-19','startReason':'after 2026-09-14 final closure publication','endReason':'before 2026-10-20 midterm exams','postMidtermRegularMeetingsGenerated':False,'makeupMeetingsGenerated':False},
'ownCalendarLiteral': {'semesterOpeningAndClassStart':'2026-09-01','courseChange':['2026-09-01','2026-09-07'],'midtermExam':['2026-10-20','2026-10-26'],'makeup':['2026-12-08','2026-12-14'],'finalExam':['2026-12-15','2026-12-21'],'winterVacationStarts':'2026-12-22','semesterAdministrativeEndNotInferred':True,'maritimeGrade3and4GradeEntry':['2026-12-30','2027-01-08'],'maritimeSpecialCalendarNotApplied':True,'sourceURL':calendar['sourceUrl'],'sourcePDF_SHA256':calendar['sha256']},
'nonMaritimeSourceScope':{'noticeURL':'https://www.kmou.ac.kr/elecom/na/ntt/selectNttInfo.do?nttSn=10377148','noticeTitle':'2026학년도 2학기 전자정보통신공학전공 수강신청 유의사항 안내','published':'2026-07-23','collegeFromNoticeMenu':'해양과학기술융합대학','majorFromNoticeHeader':'전자전기정보공학부 전자정보통신공학전공','collegeHeadingLine':1061,'majorUnderCollegeLine':1072,'noticeSHA256':hashlib.sha256((p/'notice.html').read_bytes()).hexdigest(),'grade4TableHasNoCourseEntries':True},
'makeupMappingLiteral':calendar['makeupMapping'],'candidateExcludedHolidays':['2026-09-24','2026-09-25','2026-10-05','2026-10-09'],'outsideWindowHolidayNotScheduled':'2026-11-05','literalDatesByWeekday':dates,
'closure':{'nativeRows':59,'normalizedExactTitleMatches':0,'codeSectionJoinVerified':False,'finalActiveOfferingGuarantee':False,'noticeDate':'2026-09-14'},
'priorNewProfessorOverlap':{'comparedCoursePairs':checked_pairs,'priorProfessors':prior_professors,'newProfessors':new_professors,'exactSharedProfessors':shared,'sameProfessorSameDateTimeConflicts':conflicts,'priorReusedOrOverwritten':False,'sameTitleWithoutNativeIdentityNeverMerged':True},
'cachedSources': {str(old/name):hashlib.sha256((old/name).read_bytes()).hexdigest() for name in ['calendar-operating-education.json','closure-education.json','notice-education-conditions.json']},
'all247LiteralDateWeekdayClockRoomChecksPassed':True,'SDKExecuted':False,'fixturePreparedOnly':True}
(p/'final-independent-proof.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('Independent proof passed: 17/247; prior13/179 exact; 221 pairs, professor conflicts0; total30/426')
