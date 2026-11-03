"""Current public educational census retained; operating dates stay held."""
import collections
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).parent
SOURCE = ROOT.parents[1] / 'catalog-d'
sys.path.insert(0, str(ROOT.parents[1] / 'catalog-g'))
from skku_inline_private_education_filter import filter_education

def read(path):
    return json.loads(path.read_text())

def save(name, value):
    (ROOT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

source_path = SOURCE / 'hanyang-cached-educational-scope-20261008.json'
source = read(source_path)
by_id = {c['classId']: c for c in source['courses']}
plans = []
fields = {'suupYear','suupTerm','suupNo','haksuNo','gwamokNm','gwamokEnm',
          'campusCd','isuGbCd','jucha','hoicha','subject','subjectEnm','hwaldong',
          'hwaldongEnm','wschedule','wscheduleEnm','wschedule2','wscheduleEnm2',
          'hyuilNm','hyuilNotice','suupViewtype','hakjeom','ironSigan','silsSigan',
          'suupTimeStr','suupTimeStrEnm','slgSosokNm','gnjSosokNm'}
for path in sorted((SOURCE / 'hanyang-2026-2-intensive-plans-raw').glob('*.json')):
    original = read(path)
    educational = {}
    for dataset in ['DS_L_COURSE_JEONGBO','DS_SUUPGG11TTM01','DS_L_COURSE_PLAN_WEEK']:
        rows = original[dataset][0]['list']
        educational[dataset] = [{k:filter_education(v)[0] if isinstance(v,str) else v
                                for k,v in row.items() if k in fields} for row in rows]
    head = educational['DS_L_COURSE_JEONGBO'][0]
    alias = by_id[path.stem]['officialAliases'][0]
    assert (head['suupNo'],head['suupYear'],head['suupTerm'],head['haksuNo'],head['gwamokNm']) == (
        path.stem,'2026','20',alias['haksuNo'],alias['gwamokNm'])
    plans.append(dict(classId=path.stem, sourceSha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                      sourcePath=str(path.relative_to(ROOT.parents[3])), educationalDatasets=educational,
                      actualCourseDatesConfirmed=False))
assert len(plans) == 22
save('hanyang-intensive-education-proof-v1.json',dict(plans=plans,actualDatesConfirmed=False,
     scope='Native current class/title/code/year/term verified; week numbers and holiday labels do not prove calendar dates'))

clock = re.compile(r'([월화수목금토일])\((\d{2}):(\d{2})-(\d{2}):(\d{2})\)')
campuses = collections.defaultdict(list)
stats = collections.defaultdict(collections.Counter)
notes = ('공개 원문 강좌 자료이며 일반학기 전체 예약은 시험·보강 날짜 확인까지 보류합니다. '
         '실제 등교·집중이수/온라인 운영 날짜 미확인. 2026학년도2학기 공식 개강9월1일·종강12월21일은 확인했으나 '
         '개별 중간·기말시험/보강일을 추측하지 않습니다. 12월22일은 보강가능일이며 실제 개별 보강 예약을 생성하지 않습니다. '
         '수업번호는 실제 강좌 식별자, 학수번호는 과목코드이며 원문 분반00을 보존합니다. '
         '학과의 학년·반번호는 강좌 분반으로 바꾸지 않았습니다. 현재 전체 변경·폐강 상태는 미확인입니다. '
         '공개 조회 입구가 현재 대기 제어를 사용하므로 새 전체 조회는 중단했습니다. 방식은 미지정으로 사용자 선택을 유지합니다. ')
for c in source['courses']:
    aliases = c['officialAliases']; first = aliases[0]
    assert all(a['suupYear']=='2026' and a['suupTerm']=='20' and a['hakwiGb']=='1' for a in aliases)
    for field in ['haksuNo','bunbanNo','campusCd','gwamokNm','hakjeom','suupTimes','suupRoomNms','gyogangsaNms']:
        assert len({str(a.get(field)) for a in aliases}) == 1
    campus = 'seoul' if first['campusCd']=='H' and first['campusNm']=='서울' else 'erica'
    assert first['campusCd'] == ('H' if campus=='seoul' else 'Y')
    assert first['campusNm'] == ('서울' if campus=='seoul' else 'ERICA')
    departments = list(dict.fromkeys(a['banSosokNm'] for a in aliases))
    categories = {d:next(a['isuGbNm'] for a in aliases if a['banSosokNm']==d) for d in departments}
    assert all(len({a['isuGbNm'] for a in aliases if a['banSosokNm']==d})==1 for d in departments)
    credits = {d:first['hakjeom'] for d in departments}
    raw_time = first['suupTimes'] or ''; raw_room = first['suupRoomNms'] or ''
    matches = list(clock.finditer(raw_time))
    full_clock = bool(matches) and not clock.sub('',raw_time).replace(',','').strip()
    rooms = [r.strip() for r in raw_room.split(',')]
    spans = []; gaps = list(c['operatingGaps'])
    if first['silsSigan']:
        gaps.append('laboratoryOrPracticumActualOperatingDatesUnconfirmed')
    if re.search(r'SMART-|E-러닝|온라인|원격|HY-LIVE|HY-FLEX|온.?오프|집중',first['teuksuNm'] or ''):
        gaps.append('specialDeliveryOrIntensiveActualOperatingAllocationUnconfirmed')
    correct_room = len(rooms)==len(matches) and all(r.startswith(first['campusNm']+' ') for r in rooms)
    if full_clock and correct_room:
        for m,room in zip(matches,rooms):
            start=int(m[2])*60+int(m[3]); end=int(m[4])*60+int(m[5])
            assert 0<=start<end<=1440
            spans.append(dict(weekday='월화수목금토일'.index(m[1])+1,startMinute=start,endMinute=end,classroom=room))
    else:
        gaps.append('exactPhysicalCampusClockRoomPairingUnconfirmed')
    if any(s['weekday']>5 for s in spans):
        gaps.append('weekendActualOperatingDatesUnconfirmed')
    gaps.append('individualExamMakeupAndTeachingDatesUnconfirmed')
    gaps=list(dict.fromkeys(gaps))
    restriction_text=' / '.join(json.dumps(r,ensure_ascii=False,separators=(',',':')) for r in c['restrictions'])
    global_notes=notes+f"원문 수업번호:{c['classId']} / 학수번호:{first['haksuNo']} / 강좌 분반:{first['bunbanNo']} / 원문 강의시각:{raw_time} / 원문 강의실:{raw_room} / "
    global_notes += '수강 제한 원문:'+restriction_text if restriction_text else '수강제한 세부 자료가 없는 것은 무제한 수강을 뜻하지 않습니다.'
    department_remarks={}
    for department in departments:
        department_rows=[a for a in aliases if a['banSosokNm']==department]
        department_remarks[department]=global_notes+' / 학과별 원문 교육조건: '+' / '.join(json.dumps(a,ensure_ascii=False,separators=(',',':')) for a in department_rows)
    row=dict(sourceId=f"hanyang/{campus}/2026-2/{c['classId']}",campus=campus,academicYear=2026,
        semester='2',courseCode=first['haksuNo'],courseName=first['gwamokNm'],section=first['bunbanNo'],
        professor=first['gyogangsaNms'] or first['daepyoGangsaNm'] or '',classification=first['isuGbNm'],
        credits=first['hakjeom'],departments=departments,departmentCredits=credits,
        departmentClassifications=categories,departmentRemarks=department_remarks,
        sourceSchedule=raw_time,sourceClassroom=raw_room,remarks=global_notes,
        scheduleStatus='unrecognized',schedules=[],period=dict(startDate='2026-09-01',endDate='2026-12-21'),
        metadata=dict(originalEducationalRecord=c,nativeEnrollmentNumber=c['classId'],nativeSubjectCode=first['haksuNo'],
            nativeSection=first['bunbanNo'],referenceKind='nativeSubjectCode',
            verifiedUndatedPublishedClockRoomSlots=spans,physicalCampusProof='Native campusCd/campusNm retained; clock-room pairing only when each room explicitly starts with matching 서울 or ERICA',
            operatingGaps=gaps,currentWholeClosureVerified=False,actualAttendanceConfirmed=False,
            actualCourseDatesConfirmed=False,deliveryModeStatus='unknown-user-choice',researchOnly=True))
    campuses[campus].append(row)
    stats[campus]['native']+=1;stats[campus]['aliases']+=len(aliases);stats[campus]['restrictionRows']+=len(c['restrictions'])
    stats[campus]['exactUndatedClockRoomPairs']+=len(spans)
    stats[campus]['exactUndatedClockRoomClasses']+=bool(spans)
    stats[campus]['departmentCategoryVariation']+=len(set(categories.values()))>1
    stats[campus].update(gaps)
for campus,rows in campuses.items():
    save(f'hanyang-{campus}-2026-2.held-v1.json',dict(schemaVersion=2,universityId='hanyang',campus=campus,
        campusName='서울' if campus=='seoul' else 'ERICA',academicYear=2026,semester='2',publishedDate='2026-10-07',
        publishedDateMeaning='Cached normal public catalog acquisition day, not original publication or freshOctober8 census',
        sourceUrl=source['source'],researchOnly=True,completionClaim=False,courses=rows))
save('hanyang-held-v1-audit.json',dict(campuses=stats,nativeTotal=len(by_id),sourceDisplayedAliases=7790,
    detailedRestrictionRows=6325,scheduledRows=0,datedMeetings=0,intensivePlanCount=22,
    sourceEducationalSha256=hashlib.sha256(source_path.read_bytes()).hexdigest(),
    fullThreeModeDatedDriveProof='Deferred: no source-confirmed individual teaching date; no fabricated nonempty proof',
    completionClaim=False,productionChange=False))
print(json.dumps(dict(stats),ensure_ascii=False))
