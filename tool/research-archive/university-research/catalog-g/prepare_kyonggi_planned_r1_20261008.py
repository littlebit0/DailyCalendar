"""Immutable research candidate from actual public PDF operators and current closures."""
import copy,datetime as dt,hashlib,json,pathlib,re
from collections import Counter
R=pathlib.Path(__file__).resolve().parent
from skku_inline_private_education_filter import filter_education
source=json.loads((R/'kyonggi-source-clock-candidate-draft-20261008.json').read_text())
native=json.loads((R/'kyonggi-public-coordinate-fixture.json').read_text())
pageby={(d['file'],p['page']):p for d in native for p in d['rows']}
start=dt.date(2026,9,1);end=dt.date(2026,12,14)
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09','2026-11-08'}
out=[];privacy=[0,0]
for r in source['rows']:
 f=copy.deepcopy(r['actualEducationalFields']);assert re.fullmatch(r'[A-Z]{2,4}\d{3,4}',r['actualCourseCode'])
 for field,val in f.items():
  safe,m,l=filter_education(val);f[field]=safe;privacy[0]+=m;privacy[1]+=l
 page=pageby[(r['sourcePDF'],r['sourcePage'])]
 header=''.join(x['text'] for x in sorted([x for x in page['cells'] if 300<=x['y']<430],key=lambda z:z['x']))
 date_slots=[]
 if r['sourceTimetableDecision']=='postedRegularClockCandidate':
  for slot in r['parsedNativeMeetings']:
   day=start
   while day<=end:
    if day.isoweekday()==slot['weekday'] and day.isoformat() not in closed:date_slots.append(dict(slot,date=day.isoformat()))
    day+=dt.timedelta(days=1)
 decision=r['sourceTimetableDecision'];note='\n'.join(filter(None,[f"수강신청 과목번호 {r['actualRegistrationNumber']} · 분반 번호 미게시",f"공개 표 편성 구분: {header}",f['remarks']]))
 if not f['classroom'] and date_slots:note+='\n강의실 미게시'
 if decision=='explicitPublishedCancellation':note+='\n공식 2026-2 폐강 공지 확인. 시간표 추가 대상 제외.'
 elif decision=='concentratedDatesUnpublished':note+='\n집중수업 실제 개별 기간 미게시. 정규 학기 전체 반복 미생성.'
 elif decision=='periodClockNotPublished':note+='\n공개 교시 시각표 범위 밖의 교시 포함. 실제 시각 확인 전 반복 미생성.'
 elif decision=='asynchronousSourceNoRealtimeClock':note+='\n이러닝 과목: 실제 실시간 수업 시각 미게시.'
 elif decision!='postedRegularClockCandidate':note+='\n별도 운영 또는 실제 주간 시각 미게시.'
 title=f['title'];assert title
 c={'sourceId':r['sourceStableId'],'universityId':'kyonggi','campus':'suwon','academicYear':2026,'semester':'2',
    'courseCode':r['actualCourseCode'],'section':'','courseName':title,'professor':f['professor'],
    'credits':float(f['credits']) if re.fullmatch(r'\d+(?:\.\d+)?',f['credits']) else None,
    'departments':[],'departmentCredits':{},'departmentClassifications':{},'departmentRemarks':{},
    'classification':f['classification'],'remarks':note,'period':{'startDate':start.isoformat(),'endDate':end.isoformat()},
    'sourceSchedule':f['weekday']+' / '+f['period'],'sourceClassroom':f['classroom'],
    'scheduleStatus':'scheduled' if date_slots else ('unscheduled' if decision in ['asynchronousSourceNoRealtimeClock','timeRowPairingUnresolved'] else 'unrecognized'),
    'schedules':date_slots,'metadata':{'actualRegistrationNumber':r['actualRegistrationNumber'],'nativeSectionUnpublished':True,'sourcePDF':r['sourcePDF'],'sourcePDFSHA256':r['sourceSHA256'],'sourcePage':r['sourcePage'],'actualOperatorEducationalFields':f,'actualNativeTimeRows':r['nativeTimeRows'],'originalParsedMeetings':r['parsedNativeMeetings'],'decision':decision,'actualAttendanceConfirmed':False,'unknownDepartmentNotFabricated':True}}
 out.append(c)
fn='kyonggi-suwon-2026-2.planned-audited-20261008-r1.json'
d={'schemaVersion':2,'universityId':'kyonggi','campus':'suwon','academicYear':2026,'semester':'2','publishedDate':'2026-07-15','sourceUrl':'https://www.kyonggi.ac.kr/www/selectBbsNttView.do?key=7520&bbsNo=1073&nttNo=624913','researchOnly':True,'wholeUniversitySupportComplete':False,'sourceScope':'Suwon daytime public timetable only','courses':out}
data=(json.dumps(d,ensure_ascii=False,indent=2)+'\n').encode();(R/fn).write_bytes(data)
m={'researchOnly':True,'completionClaim':False,'file':fn,'sha256':hashlib.sha256(data).hexdigest(),'sourceRows':1640,'scheduledCount':sum(bool(c['schedules']) for c in out),'dateCount':sum(len(c['schedules']) for c in out),'decisions':dict(Counter(c['metadata']['decision'] for c in out)),'privacyMaskedTokens':privacy[0],'privacyDiscardedLines':privacy[1],'allActualCodesPreserved':True,'registrationNumberNotMisrepresentedAsSection':True,'allNativeSectionsEmpty':True,'stableIdentityUsesActualRegistrationNumber':True,'actualPublishedDateRetained':True,'currentFileSHARecheck':'kyonggi-current-whole-file-recheck-20261008.json','semesterClockAudit':'kyonggi-current-period-clock-source-audit-20261008.json','commonClosures':sorted(closed),'remaining':['Seoul/night whole scope missing','Latest KUTIS private current changes not accessed; normal public PDF unchanged and known public19 cancellations applied','42 outside actual clock table periods unconfirmed','6 concentrated periods missing','Untimed individual/external activity and19 asynchronous offerings','Exact user enrollment eligibility and special per-course plan overrides not completely published here'],'actualAttendanceConfirmed':False}
(R/'kyonggi-planned-audited-20261008-r1-sha-manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in m.items() if k in ['sha256','scheduledCount','dateCount','privacyMaskedTokens','privacyDiscardedLines']})
