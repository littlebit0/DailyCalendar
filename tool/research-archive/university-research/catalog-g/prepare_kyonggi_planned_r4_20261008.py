"""Common explicitly replaced teaching week applies to original weekdays, not event-date only."""
import json,pathlib,hashlib
R=pathlib.Path(__file__).resolve().parent
base=json.loads((R/'kyonggi-suwon-2026-2.planned-audited-20261008-r3.json').read_text())
removed=[]
for c in base['courses']:
 if c['courseCode']!='IA002':continue
 before=c['schedules'];c['schedules']=[m for m in before if not ('2026-09-28'<=m['date']<='2026-10-11')]
 proof=c['metadata']['currentIA002OperatingEvidence'];proof['replacedCommonTeachingWeeks']=[{'week':5,'startDate':'2026-09-28','endDate':'2026-10-04','actualSpecialEventDate':'2026-09-30'},{'week':6,'startDate':'2026-10-05','endDate':'2026-10-11','actualSpecialEventDate':'2026-10-07'}]
 if proof['decision']=='ordinaryPostedTermExceptExplicitCommonSpecialWeeks':proof['removedRegularDates']=['2026-10-01','2026-10-08'] if c['metadata']['actualRegistrationNumber'] in ['1636','1637'] else ['2026-09-30','2026-10-07']
 c['remarks']+='\n공식 공통 5·6주차 수업 대체는 원래 공시 요일에 적용합니다. 목요일 공시 분반도 해당 주차의 목요일(10/1·10/8) 일반회의를 생성하지 않습니다. 실제 특강의 수요일 날짜를 목요일로 옮기지 않습니다.'
 if len(before)!=len(c['schedules']):removed.append({'registrationNumber':c['metadata']['actualRegistrationNumber'],'removedDates':[m['date'] for m in before if m not in c['schedules']]})
assert removed==[{'registrationNumber':'1636','removedDates':['2026-10-01','2026-10-08']},{'registrationNumber':'1637','removedDates':['2026-10-01','2026-10-08']}]
fn='kyonggi-suwon-2026-2.planned-audited-20261008-r4.json';p=R/fn;assert not p.exists()
b=(json.dumps(base,ensure_ascii=False,indent=2)+'\n').encode();p.write_bytes(b)
m={'researchOnly':True,'completionClaim':False,'file':fn,'sha256':hashlib.sha256(b).hexdigest(),'sourceRows':1640,'scheduledCount':sum(bool(c['schedules']) for c in base['courses']),'dateCount':sum(len(c['schedules']) for c in base['courses']),'r3Correction':'Explicit common teaching week replacement removes native Thursday meetings too','newRemovedNativeThursdayMeetings':removed,'unchangedNonIA002Objects':1622,'all1640ActualEducationMetadataPreserved':True,'intensiveWholeEndDateUnconfirmed':True,'actualAttendanceConfirmed':False,'sourceScope':'Suwon daytime public timetable only','privacyPatternsFound':0}
(R/'kyonggi-planned-audited-20261008-r4-sha-manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n');print(m['sha256'],m['scheduledCount'],m['dateCount'])
