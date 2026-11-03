"""Only individually paired current undergraduate cells with explicit 1-3 clocks."""
import json,re,datetime as dt,hashlib
from pathlib import Path
R=Path(__file__).parent
rows=json.loads((R.parent/'catalogs/gnu-public-course-rows.json').read_text())
grid=json.loads((R/'gnu-car-current-education-grid-20261008.json').read_text())
s=grid['sheets'][0];norm=lambda x:re.sub(r'\s+','',x)
proof=[]
for r0,r1,c0,c1 in s['actualMergedRanges']:
 if (r0,r1)!=(3,6) and (r0,r1)!=(16,19):continue
 cell=s['cells'][r0][c0]
 if not cell:continue
 day=1 if r0==3 and 2<=c0<11 else 2 if r0==3 and 11<=c0<20 else 3 if r0==3 and 20<=c0<29 else 4 if r0==16 and 2<=c0<11 else None
 if day is None:continue
 hits=[r for r in rows if r['method']=='대면수업' and ('자동차' in r['department']) and norm(r['title']) in norm(cell) and r['professor'] in cell and r['schedule'].startswith('월화수목금토일'[day-1]+'1,2,3[')]
 if len(hits)!=1:continue
 r=hits[0]
 assert not r['closedFirstAnnouncement'] and not r['closedSecondAnnouncement']
 proof.append((r,day,{'nativeCoordinates':{'rowStart':r0+1,'rowEnd':r1,'columnStart':c0+1,'columnEnd':c1},'actualCell':cell,'actualTitleProfessorWeekdayPeriodsMatchUniqueOriginalCodeSection':True}))
assert len(proof)==8,len(proof)
assert len({(r['code'],r['section']) for r,_,_ in proof})==8
image=json.loads((R/'gnu-car-current-educational-notices-20261008.json').read_text())[1]
calendar=image['visuallyVerifiedEducationOnly']
exclude=set(calendar['holidayToMakeup'])|{'2026-12-09'}
courses=[]
for r,day,p in proof:
 classroom=re.search(r'\[([^\]]+)\]',r['schedule']).group(1)
 meetings=[];date=dt.date(2026,9,1);end=dt.date.fromisoformat(calendar['teachingDayEndpoints'][str(day)])
 while date<=end:
  if date.isoweekday()==day and date.isoformat() not in exclude:meetings.append({'weekday':day,'startMinute':540,'endMinute':710,'classroom':classroom,'date':date.isoformat(),'deliveryMode':'inPerson'})
  date+=dt.timedelta(days=1)
 assert len(meetings)==15
 dep=r['department'];notes=r['remarks']+'\n공식 현재 학과 시간표 교육 셀과 원 개설코드·분반·교수·교시를 대조한 부분 지원. 원 학교 공시예정시간표이며 개별 출석·시험시각 확정이 아님. 변경 시 학교 통합서비스 확인 필요.'
 c={'sourceId':f"gnu/gajwa/2026/2/{r['code']}/{r['section']}",'universityId':'gnu','campus':'gajwa','academicYear':2026,'semester':'2','courseCode':r['code'],'section':r['section'],'courseName':r['title'],'professor':r['professor'],'credits':float(r['credits']),'sourceSchedule':r['schedule'],'sourceClassroom':classroom,'scheduleStatus':'scheduled','schedules':meetings,'departments':[dep],'departmentCredits':{dep:float(r['credits'])},'departmentClassifications':{dep:r['category']},'departmentRemarks':{dep:notes},'period':{'startDate':'2026-09-01','endDate':'2026-12-21'},'metadata':{'originalPublicEducationalRow':r,'actualCurrentDepartmentCell':p,'currentDepartmentFileUrl':grid['sourceUrl'],'currentDepartmentNoticeUrl':grid['publishedNoticeUrl'],'currentDepartmentFileSHA256':grid['fileSHA256'],'absoluteUndergraduateClockAuthority':'https://www.gnu.ac.kr/car/na/ntt/selectNttInfo.do?mi=5865&nttSn=2220620','absoluteClocksExplicitlyPrinted':['09:00–09:50','10:00–10:50','11:00–11:50'],'holidayMakeupAuthority':image['sourceUrl'],'currentDepartmentFilePrintedCode':False,'nativeSectionFromUniqueCurrentTitleProfessorWeekdayClockJoinNotInvented':True,'actualAttendanceConfirmed':False,'wholeCurrentSnapshotVerified':False}}
 courses.append(c)
d={'schemaVersion':2,'universityId':'gnu','campus':'gajwa','academicYear':2026,'semester':'2','sourceUrl':grid['publishedNoticeUrl'],'publishedDate':'2026-07-24','researchOnly':True,'completionClaim':False,'sourceScope':'8 individually paired current department undergraduate courses only; whole post-July latest snapshot requires normal authenticated school source','courses':courses}
name='gnu-gajwa-2026-2.planned-audited-20261008-r1.json';path=R/name;assert not path.exists();data=(json.dumps(d,ensure_ascii=False,indent=2)+'\n').encode();path.write_bytes(data)
m={'file':name,'sha256':hashlib.sha256(data).hexdigest(),'courseCount':8,'scheduledCount':8,'dateCount':120,'wholeSource4842NotClaimedLatest':True,'remaining':['whole latest course changes normal SSO boundary','other campus absolute undergraduate clocks','other periods beyond explicit 1-3','remote asynchronous actual examination vs recurrent attendance','intensive/clinical/individual meeting dates','current other departments']}
(R/'gnu-planned-audited-20261008-r1-sha-manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n');print(m)
