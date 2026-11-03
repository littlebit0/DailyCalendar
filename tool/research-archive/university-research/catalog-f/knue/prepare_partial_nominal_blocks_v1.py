"""Current fifteen weekly source rows: only directly supported FAQ reservation blocks."""
from pathlib import Path
import json,hashlib,collections,datetime,re
R=Path(__file__).resolve().parent
src=R/'knue-whole742-current-weekly-education-review-pending.json';whole=json.loads(src.read_text())
KNOWN={1:(540,600),2:(600,660),3:(660,720),4:(720,780),6:(840,900),7:(900,960),8:(960,1020)}
CLOSED={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09','2026-10-31'}
NOTE='학교 공시 주차별 수업 예약 시간표입니다. 표시 시각은 학교 FAQ의 정각 예약 블록이며 실제 출석 확인 기록이 아닙니다. 학사 규정의 수업 단위는 50분이고 일부 강의는 75분으로 운영될 수 있습니다. 0·5·9~15교시 시각과 별도 보강 시각은 확인 중이며 해당 부분은 추가하지 않았습니다.'
counts=collections.Counter();courses=[];cases=[]
for c in whole['courses']:
 rows=c['publishedWeeks'];first=rows[0]['originalPublicEducation'];departments=c['nativeDepartments'];meetings=[];unknown=[];omitted=[]
 for w in rows:
  for p in w['datedNativePeriodParts']:
   if p['date'] in CLOSED or not ('2026-08-31'<=p['date']<='2026-12-11'):
    omitted.append(dict(p,week=w['week'],reason='schoolRegularClosure' if p['date'] in CLOSED else 'outsideCurrentTeachingTerm'));continue
   missing=[n for n in p['nativePeriods'] if n not in KNOWN]
   if missing:unknown.append(dict(p,week=w['week'],unresolvedNativePeriods=missing))
   valid=[n for n in p['nativePeriods'] if n in KNOWN];runs=[]
   for n in valid:
    if runs and KNOWN[runs[-1][-1]][1]==KNOWN[n][0]:runs[-1].append(n)
    else:runs.append([n])
   for run in runs:
    meetings.append({'date':p['date'],'weekday':p['weekday'],'startMinute':KNOWN[run[0]][0],'endMinute':KNOWN[run[-1]][1],'classroom':p['location'],'deliveryMode':'inPerson'})
    cases.append({'courseId':c['courseId'],'week':w['week'],'nativePeriods':run,'date':p['date'],'classroom':p['location'],'originalSchedule':w['originalPublicEducation']['SIGANPYO2']})
 # Preserve separate week-specific facts, not flatten them into a recurring meeting.
 assert len({json.dumps(m,sort_keys=True) for m in meetings})==len(meetings)
 rawremarks={d:[] for d in departments};classes={};credits={}
 for w in rows:
  q=w['originalPublicEducation'];d=q['JEONGONG_NM'];classes[d]=q['ISU_GB_NM'];credits[d]=float(q['HAKJEOM'])
  if q['BIGO'] and q['BIGO'] not in rawremarks[d]:rawremarks[d].append(q['BIGO'])
 remarks={d:'\n'.join(rawremarks[d]+[NOTE]) for d in departments}
 unknownnote='; '.join(dict.fromkeys(f"{q['week']}주차 {q['date']} {q['location']} {','.join(map(str,q['unresolvedNativePeriods']))}교시" for q in unknown))
 if unknownnote:
  for d in remarks:remarks[d]+='\n시각 미확인: '+unknownnote
 course={'sourceId':f"knue/main/2026-2/{c['courseId']}",'campus':'main','academicYear':2026,'semester':'2','courseCode':c['code'],'courseName':first['GWAMOK_NM'],'courseNameAliases':[t for t in c['nativeTitles'] if t!=first['GWAMOK_NM']],'section':c['section'],'professor':' / '.join(c['nativeProfessors']),'classification':first['ISU_GB_NM'],'departmentClassifications':classes,'credits':float(first['HAKJEOM']),'departmentCredits':credits,'departments':departments,'departmentRemarks':remarks,'sourceSchedule':'\n'.join(dict.fromkeys(w['originalPublicEducation']['SIGANPYO2'] for w in rows)),'sourceClassroom':' / '.join(sorted(set(p['location'] for w in rows for p in w['datedNativePeriodParts']))),'scheduleStatus':'scheduled' if meetings else 'unrecognized','schedules':meetings,'period':{'startDate':'2026-08-31','endDate':'2026-12-11'},'sourceEducation':{'basis':'publishedWeeklyNominalReservationBlocks','actualAttendanceIndividuallyConfirmed':False,'actual50Or75MinuteTeachingEndConfirmed':False,'partialSchedule':True,'allPublishedWeeklyEducation':rows,'weeklyScheduleChanges':c['weeklyScheduleChanges'],'unresolvedNativeMeetingParts':unknown,'excludedSourceParts':omitted,'FAQClockSource':'https://www.knue.ac.kr/english/contents.do?key=1115','currentRuleProof':'current-rule-period-classification-authority-20261008.json','normalPublicUIProof':'public-ui-path-proof.json','legalInstructionUnitMinutes':50,'possibleAlternativeInstructionUnitMinutes':75,'unseenSyllabusReviewed':False,'campusProof':'Single institution academyinfo:0000031 본교; no separate native campus field.'}}
 courses.append(course);counts['scheduled' if meetings else 'blocked']+=1;counts['meetings']+=len(meetings);counts['unknownParts']+=len(unknown);counts['excludedParts']+=len(omitted)
 assert course['courseCode']==first['GWAMOK_CD'] and course['section']==first['BUNBAN']
 assert course['sourceEducation']['allPublishedWeeklyEducation']==c['publishedWeeks']
x={'schemaVersion':2,'universityId':'knue','campus':'main','campusName':'본교','academicYear':2026,'semester':'2','publishedDate':'2026-10-08','sourceUrl':'https://haksa.knue.ac.kr/checkMenu.jsp?p0=P0mR43tX7RX1813o','institutionId':'institution:academyinfo:0000031','courses':courses,'wholeCurrentMetadataRetained':True,'wholeSemanticReviewComplete':False,'wholeUniversitySupportComplete':False,'completionClaim':False,'verificationScope':'All742 native identities/9966 weekly educational rows retained; only FAQ nominal reservation blocks1..4/6..8; current teaching dates and school closure boundaries; other periods and actual instructional50/75 duration unresolved.'}
p=R/'knue-main-2026-2.whole742-partial-nominal-blocks-v1.json';p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
a={'wholeCourseCount':742,'wholeWeeklyRows':9966,'wholeNativeEducationUnchanged':True,'weeklyChangesPreserved':183,'sourceSHA256':hashlib.sha256(src.read_bytes()).hexdigest(),'candidateSHA256':hashlib.sha256(p.read_bytes()).hexdigest(),'counts':dict(counts),'knownReservationBlocks':KNOWN,'schoolRegularClosures':sorted(CLOSED),'nationalClosureSource':'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=B000000000010&nttId=B000000001860Pe2zT3','schoolAnniversarySource':'academic-2026-short-rows.json','cases':cases,'allSourceRowsDateSpecific':True,'unknownPeriodsMapped':False,'wholeSupportComplete':False,'completionClaim':False}
(R/'knue-partial-nominal-blocks-v1-candidate-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n')
print({k:v for k,v in a.items() if k!='cases'})
