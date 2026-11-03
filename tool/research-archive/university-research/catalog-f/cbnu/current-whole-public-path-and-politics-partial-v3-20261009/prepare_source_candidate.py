import copy
import datetime
import hashlib
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[5]
OUT = pathlib.Path(__file__).resolve().parent
BASE = ROOT / 'work/university-research/catalog-f/cbnu'
def read(p):
    return json.loads(p.read_text())
def write(name, data):
    (OUT / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()
asset = ROOT / 'assets/timetable/cbnu-main-2026-2.json'
prior = read(asset)
candidate = copy.deepcopy(prior)
closures = {(r['courseCode'], r['section']) for r in read(BASE / 'cbnu-current-closure-education-20261008.json')['closedCourses']}
calendar = read(BASE / 'cbnu-korean-track-partial-v1-audit.json')
rows = [
    {'courseCode':'5666079','section':'01','title':'세계외교사','professor':'','sourceProfessorPrinted':True,'sourceProfessorConfidence':'unconfirmed-small-image-teacher-field','weekday':1,'nativePeriods':[2,3,4],'classroom':'N15-242(57-242)','classification':'전공필수'},
    {'courseCode':'0912002','section':'09','title':'글쓰기와 발표','professor':'전소영','weekday':2,'nativePeriods':[1,2,3],'classroom':'N13-502(59-502)','classification':'교양필수: 개신기초교양(의사소통)'},
    {'courseCode':'0914011','section':'05','title':'AI 사고력 기르기','professor':'홍민숙','weekday':3,'nativePeriods':[5,6,7],'classroom':'N23-103(교양강의실-6)','classification':'교양필수: 개신기초교양(정보문해)'},
]
existing = {(c['courseCode'],c['section']) for c in prior['courses']}
assert len(rows) == len({(r['courseCode'],r['section']) for r in rows}) == 3
assert not existing.intersection((r['courseCode'],r['section']) for r in rows)
assert not closures.intersection((r['courseCode'],r['section']) for r in rows)
clock = {p:{'startMinute':480+60*p,'endMinute':530+60*p} for p in range(10)}
new = []
for r in rows:
    schedules = []
    day = datetime.date(2026,9,1)
    while day <= datetime.date(2026,12,6):
        if day.isoweekday() == r['weekday'] and day.isoformat() not in calendar['excludedHolidays']:
            for period in r['nativePeriods']:
                schedules.append({'date':day.isoformat(),'weekday':r['weekday'],**clock[period],'classroom':r['classroom']})
        day += datetime.timedelta(days=1)
    note = '수강 대상: 정치외교학과 2026-2 신입생 대리수강신청 지정 강좌. 공개 주간 예약 계획, 실제 운영/날짜 미확인. 학교 현재 학부 안내문의 50분 교시를 적용했으며 10분 휴식은 유지합니다. 학교 휴업일과 12/7~18 기말시험 권장 기간은 보류했습니다. 개별 원격/집중/휴일 예외·보강·최신 변경은 미확인입니다. 원문 강의실 표기를 그대로 보존하며 개별 물리 캠퍼스는 문서에 명시되지 않았습니다.'
    if not r['professor']:
        note += ' 원문에 교수 표기가 있으나 작은 이미지의 판독이 불확실하여 이름을 채우지 않았습니다. 원본 교육 시간표를 함께 보존합니다.'
    c = {'sourceId':f"cbnu/main/2026-2/{r['courseCode']}-{r['section']}",'campus':'main','academicYear':2026,'semester':'2',
         'courseCode':r['courseCode'],'courseName':r['title'],'section':r['section'],'professor':r['professor'],
         'classification':r['classification'],'departmentClassifications':{'정치외교학과':r['classification']},
         'credits':None,'departmentCredits':{},'departments':['정치외교학과'],'departmentRemarks':{'정치외교학과':note},'remarks':note,
         'sourceSchedule':'월화수목금토일'[r['weekday']-1]+' '+','.join(f'{p:02d}' for p in r['nativePeriods']),
         'sourceClassroom':r['classroom'],'scheduleStatus':'scheduled','schedules':schedules,'period':copy.deepcopy(prior['courses'][0]['period']),
         'metadata':{'researchOnly':True,'actualAttendanceConfirmed':False,'actualDeliveryConfirmed':False,'wholeLatestChangesConfirmed':False,
                     'sourceNoticeUrl':'https://politics.chungbuk.ac.kr/post/957','sourceAttachmentUrl':'https://politics.chungbuk.ac.kr/postact/download/1034',
                     'originalEducationalFields':copy.deepcopy(r),'nativeClockUnitMinutes':50,'physicalCampusIndividuallyPrinted':False,
                     'sourceCreditsPublished':False,'sourceProfessorMethod':'Manual visual read of PDF embedded educational table; raw OCR inaccuracies not used as canonical values.'}}
    new.append(c)
candidate['courses'].extend(new)
candidate.update({'candidateRevision':'current-whole-public-path-and-politics-partial-v3-20261009','researchOnly':True,'productionIntegrationEnabled':False,'completionClaim':False,'wholeSchoolCourseCoverageComplete':False})
assert candidate['courses'][:11] == prior['courses']
assert len(candidate['courses']) == 14
assert sum(len(c['schedules']) for c in prior['courses']) == 435
for c in new:
    for s in c['schedules']:
        d=datetime.date.fromisoformat(s['date'])
        assert d.isoweekday() == c['metadata']['originalEducationalFields']['weekday']
        assert s['endMinute']-s['startMinute']==50
        assert s['classroom']==c['sourceClassroom']
        assert d <= datetime.date(2026,12,6)
        assert s['date'] not in calendar['excludedHolidays']
write('cbnu-main-2026-2.politics-partial-v3.json',candidate)
write('prior11-current-asset-snapshot.json',prior)
write('current-undergraduate-clock-and-politics-education.json',{
    'researchOnly':True,'completionClaim':False,'impossibleClaim':False,
    'currentGuide':{'sourceNoticeUrl':'https://www.chungbuk.ac.kr/www/selectBbsNttView.do?bbsNo=8&key=815&nttNo=168509&pageIndex=1&pageUnit=10&searchCnd=all&searchCtgry=학사/장학',
                    'noticeTitle':'2026학년도 2학기 수강신청 일정 안내','publishedDate':'2026-07-15',
                    'observedDownloadUrl':'https://www.chungbuk.ac.kr/www/downloadBbsFile.do?atchmnflNo=361676','normalStatus':200,'bytes':76800,
                    'downloadSha256':'31f1b623fadb84d0aa3ecf2dcda7ff8517afb478247ac7744b3ec4e045203d70',
                    'nativeHeading':'2026학년도 제2학기 수강신청 안내 (학부생)','fiftyMinutePeriods0Through9':clock,
                    'seventyFiveMinuteScope':'수·금 A1–A6 only; not used for the three native integer-period offerings.',
                    'nativeCorrespondenceExamples':['수02:10:00–10:50','수A2:10:30–11:45'],
                    'generalizationBoundary':'Only exact current printed0–9 and 수/금A1–A6. No invented10+ clock; older11 supported objects remain untouched.'},
    'politicsSource':{'sourceUrl':'https://politics.chungbuk.ac.kr/post/957','sourceTitle':'2026-2학기 정치외교학과 신입생 대리수강신청 안내','publishedDate':'2026-07-29',
                     'observedAttachmentUrl':'https://politics.chungbuk.ac.kr/postact/download/1034','normalStatus':200,'bytes':54624,
                     'attachmentSha256':'1a4136621c314b02b2ef0f5cec5a9db4c0a1a36dc2fd5d06e7e962eba9d164d0',
                     'nativePdfHeading':'2026-2학기 정치외교학과 신입생 일괄 수강신청 시간표','rows':rows,
                     'fieldScope':'Entire three offering education grid; nativecode/section/title/professor/weekday/period/classroom; per-coursecredits absent. Freshman-only designated allocation, not all political-science offerings.',
                     'sourceImageSha256':sha(OUT/'politics-current-education-table.jpg'),'visualInspection':'Full PDF embedded table + enlarged read-only inspection for professor/room; all are educational fields, no student/contact data.'},
    'union':{'oldNative':11,'newNative':3,'totalNative':14,'oldAppointments':435,'newAppointments':sum(len(c['schedules']) for c in new),'totalAppointments':sum(len(c['schedules']) for c in candidate['courses']),
             'nativeOverlap':0,'knownClosureOverlap':0,'prior11WholeObjectsExact':True,'sourceIdentityFieldsUnchanged':True},
    'inputSha256':{'currentAsset':sha(asset),'priorOwnCalendarAudit':sha(BASE/'cbnu-korean-track-partial-v1-audit.json'),'closureEducation':sha(BASE/'cbnu-current-closure-education-20261008.json')},
    'verification':{'pythonDateClockRoomAndUnionAssertions':'PASS','actualModelThreeModeDriveTest':'NOT_RUN_SDK_FORBIDDEN','productWrites':False,'wholeSourceClaim':False}
})
print('PASS',len(candidate['courses']),sum(len(c['schedules']) for c in new),sum(len(c['schedules']) for c in candidate['courses']))
