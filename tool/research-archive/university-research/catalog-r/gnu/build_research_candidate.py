import json,re,datetime,hashlib,collections
from pathlib import Path
root=Path('work/university-research/catalog-r/gnu')
rows=json.loads(Path('work/university-research/catalogs/gnu-public-course-rows.json').read_text())
grid=json.loads(Path('work/university-research/catalog-p/gnu-car-current-education-grid-20261008.json').read_text())
proof=json.loads(Path('work/university-research/catalog-p/gnu-car-current-educational-notices-20261008.json').read_text())[1]['visuallyVerifiedEducationOnly']
# Explicitly limited to native identities independently matching the merged CAR grid.
matched={('11025364','001'):(3,10),('11023661','001'):(3,18),('11023661','002'):(3,27),('11022593','001'):(16,9),('11026929','001'):(3,25),('11023667','001'):(3,22),('11026925','001'):(3,4)}
campuses={'가좌캠퍼스':'gajwa','칠암캠퍼스':'chilam','통영캠퍼스':'tongyeong','창원캠퍼스':'changwon','내동캠퍼스':'naedong','':'unknown'}
source='https://www.gnu.ac.kr/main/na/ntt/selectNttInfo.do?mi=1127&bbsId=1029&nttSn=7823022'
weekday={'월':1,'화':2,'수':3,'목':4,'금':5,'토':6}
makeup=proof['holidayToMakeup']; scheduled=0; count=0; datasets={}; cases=[]
for r in rows:
 campus=campuses[r['campus']]; key=(r['code'],r['section']); schedules=[]
 reason='시각·현재 운영 변경 확인 중'
 if not r['schedule']: reason='공개 수업 시각 없음'
 if r['closedFirstAnnouncement'] or r['closedSecondAnnouncement']: reason='공개 폐강 공고 대상'
 if key in matched and not(r['closedFirstAnnouncement'] or r['closedSecondAnnouncement']):
  assert r['campus']=='가좌캠퍼스' and r['method']=='대면수업' and not r['remoteType']
  m=re.fullmatch(r'([월화수목금토])1,2,3\[(.*?)\]',r['schedule']); assert m
  cell=grid['sheets'][0]['cells'][matched[key][0]][matched[key][1]]
  assert r['title'].replace(' ','') in cell.replace('\n','').replace(' ','')
  expected_room={'601-0211':'컴퓨터실','601-0213':'강의실 중','601-0220':'강의실 대'}[m[2]]
  assert expected_room in cell
  date=datetime.date(2026,9,1)
  while date<=datetime.date(2026,12,7):
   if date.isoweekday()==weekday[m[1]]:
    text=date.isoformat(); actual=makeup.get(text,text)
    d=datetime.date.fromisoformat(actual)
    schedules.append({'date':actual,'weekday':d.isoweekday(),'startMinute':540,'endMinute':710,'classroom':m[2],'deliveryMode':'inPerson'})
   date+=datetime.timedelta(days=1)
  schedules.sort(key=lambda x:x['date']); assert len(schedules)==14
  scheduled+=1;count+=len(schedules); reason='일부 학과 공개 계획: 2026년 1학기 안내의 1~3교시 시각 적용 범위 확인 필요'
 note=('2026-07-24 공개 원본이며 최신 변경은 통합서비스에서 확인해야 합니다. '+reason+'. '
       '1~3교시 시각은 미래자동차공학과 2026년 1학기 학부 안내에 공개된 09:00~09:50, 10:00~10:50, 11:00~11:50입니다. '
       '2학기 적용 및 실제 운영 확인은 미완료입니다. 표시 블록은 교시 사이 휴식을 포함합니다. '
       '12월 15~21일 기말시험의 개별 시각은 확인되지 않아 추가하지 않았습니다. '+r['remarks'])
 c={'sourceId':f"gnu/{campus}/2026-2/{r['code']}-{r['section']}",'campus':campus,'academicYear':2026,'semester':'2','courseCode':r['code'],'courseName':r['title'],'section':r['section'],'professor':r['professor'],'classification':r['category'],'credits':float(r['credits']),'departmentCredits':{r['department']:float(r['credits'])},'departments':[r['department']],'departmentClassifications':{r['department']:r['category']},'remarks':note,'sourceSchedule':r['schedule'],'scheduleStatus':'scheduled' if schedules else ('unscheduled' if not r['schedule'] else 'unrecognized'),'schedules':schedules,'period':{'startDate':'2026-09-01','endDate':'2026-12-21'},'metadata':{'originalEducationalFields':r,'researchOnly':True,'actualAttendanceConfirmed':False,'wholeLatestChangesConfirmed':False,'clockSecondSemesterApplicabilityConfirmed':False,'holdReason':reason}}
 if key in matched: c['metadata']['independentDepartmentGrid']={'row':matched[key][0],'column':matched[key][1],'cell':cell,'mergedRange':[x for x in grid['sheets'][0]['actualMergedRanges'] if x[0]<=matched[key][0]<x[1] and x[2]<=matched[key][1]<x[3]]}
 datasets.setdefault(campus,{'schemaVersion':2,'universityId':'gnu','campus':campus,'campusName':r['campus'] or '미지정','academicYear':2026,'semester':'2','publishedDate':'2026-07-24','sourceUrl':source,'researchOnly':True,'completionClaim':False,'courses':[]})['courses'].append(c)
 if schedules: cases.append({'sourceId':c['sourceId'],'nativeCode':r['code'],'nativeSection':r['section'],'sourceSchedule':r['schedule'],'meetings':schedules})
manifest={}
for campus,dataset in datasets.items():
 path=root/f'gnu-{campus}-2026-2.research-clock-applicability-held-v1.json';path.write_text(json.dumps(dataset,ensure_ascii=False,indent=2)+'\n');manifest[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
audit={'researchOnly':True,'publishReady':False,'completionClaim':False,'permanentlyImpossible':False,'nativeRows':len(rows),'scheduledResearchRows':scheduled,'datedResearchMeetings':count,'heldOrUntimedRows':len(rows)-scheduled,'clockSourceUrl':'https://www.gnu.ac.kr/car/na/ntt/selectNttInfo.do?mi=5865&nttSn=5629794','clockEvidenceScope':'2026-1 CAR undergraduate only; 2026-2 applicability still unconfirmed','knownExactClockPeriods':[1,2,3],'makeup':makeup,'noIndividualExamClocksInvented':True,'cases':cases,'sha256':manifest}
(root/'gnu-research-clock-applicability-held-v1-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print({k:audit[k] for k in ['nativeRows','scheduledResearchRows','datedResearchMeetings','heldOrUntimedRows']})
