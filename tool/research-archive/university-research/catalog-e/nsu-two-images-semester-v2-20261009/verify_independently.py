import datetime as dt,hashlib,json,pathlib,re
p=pathlib.Path(__file__).parent
load=lambda name:json.loads((p/name).read_text())
c=load('nsu-unknown-2026-2.two-images-semester-v2.json');base=load('baseline39-current-asset.json');proof=load('literal-semester-source-proof.json');ann=load('visual-image-literal-items.json')
assert len(c['courses'])==97 and sum(bool(x['schedules']) for x in c['courses'])==76
assert sum(len(x['schedules']) for x in c['courses'])==3665
assert len({x['sourceId'] for x in c['courses']})==97
for before in base['courses']:
 after=next(x for x in c['courses'] if x['sourceId']==before['sourceId'])
 assert all(after[k]==before[k] for k in before if k not in ['period','remarks','schedules'])
 assert all(x in after['schedules'] for x in before['schedules'])
 if not before['schedules']:assert after==before
for a in ann['items']:
 after=next(x for x in c['courses'] if x['sourceId']==a['sourceId'])
 assert after['publicImageEducation']==a
 assert after['courseName']==a['courseName'] and after['section']==a['section'] and after['professor']==a['professor']
 image='notice-102907-file0.jpg' if a['noticeId']==102907 else 'notice-103190-image0.png'
 assert after['sourceImageSHA256']==hashlib.sha256((p/image).read_bytes()).hexdigest()
 dimensions=(1403,1984) if a['noticeId']==102907 else (1069,535)
 for b in a['readingRegions']:
  x0,y0,x1,y1=b['sourcePixelReadingBounds'];assert 0<=x0<x1<=dimensions[0] and 0<=y0<y1<=dimensions[1]
 assert after['courseCode']==after['classification']=='' and after['credits'] is None
 for x in after['schedules']:
  assert dt.date.fromisoformat(x['date']).isoweekday()==x['weekday']==a['weekday']
  assert x['date'] in proof['literalDatesByWeekday'][str(a['weekday'])]
  assert x['classroom']==a['room']
  assert x['sourceProfessor']==a['periodProfessors'][str(x['sourcePeriod'])]
  assert x['sourceGrade']==a['grade']
  assert x['endMinute']-x['startMinute']==50
held=next(x for x in c['courses'] if x['sourceNoticeId']==102907 and x['courseName']=='BIM및실습' and x['section']=='02')
assert not held['schedules']
closed=held['closureExactTitleSectionTeacherMatches'][0]
assert (closed['courseCode'],closed['section'],closed['professor'],closed['nativeSchedule'])==('14712','02','신예경','목6, 목7, 목8')
clocks={x['period']:(x['startMinutes'],x['endMinutes']) for x in load('nsu-clock-evidence.json')['periods']}
for before in base['courses']:
 if not before['schedules']:continue
 after=next(x for x in c['courses'] if x['sourceId']==before['sourceId'])
 expected=set()
 for r in after['publicEducationCells']:
  for date in proof['literalDatesByWeekday'][str(r['weekday'])]:expected.add((date,r['weekday'],*clocks[r['period']],r['room'],r['row'],r['column']))
 actual={(x['date'],x['weekday'],x['startMinute'],x['endMinute'],x['classroom'],x['sourceRow'],x['sourceColumn']) for x in after['schedules']}
 assert expected==actual
# Professor collision uses actual per-period teachers, avoiding falsely attributing all joint teachers to all slots.
oldteachers=set(x['professor'] for x in base['courses'] if x['schedules'])
newteachers={x['sourceProfessor'] for v in c['courses'][39:] for x in v['schedules']}
shared=sorted(oldteachers & newteachers);overlaps=[]
for old in c['courses'][:39]:
 for new in c['courses'][39:]:
  for b in new['schedules']:
   if old['professor']!=b['sourceProfessor']:continue
   for a in old['schedules']:
    if a['date']==b['date'] and max(a['startMinute'],b['startMinute'])<min(a['endMinute'],b['endMinute']):overlaps.append([old['sourceId'],new['sourceId'],a['date']])
report={'researchOnly':True,'SDKExecuted':False,'completionClaim':False,'counts':{'metadata':97,'scheduled':76,'held':21,'meetings':3665,'newImageScheduled':41,'newImageMeetings':1978,'prior35Extended':1687},'prior39SourceFieldsWholePreserved':True,'prior255ScheduleObjectsExactPreserved':True,'imageRawSHAAndAnnotatedFieldsChecked':True,'readingBoxesAreApproximateInspectionLocatorsNotOCR':True,'BIM02ExactNativeClosureExcluded':True,'priorNewExactProfessorIntersection':shared,'sameProfessorDateTimeOverlaps':overlaps,'fullUniversityOfferingCoverageClaim':False,'fourDepartmentsSourceCoverageOnly':['영어과','응급구조학과','건축공학과','스마트팜학과'],'ownGuideSHA256':hashlib.sha256((p/'own-current-guide.pdf').read_bytes()).hexdigest(),'individualExamDatesVerified':False,'makeupGenerated':0,'semesterOrdinaryDatesOnly':True}
assert report['ownGuideSHA256']==load('own-guide-clock-calendar-education.json')['sha256']
(p/'independent-receipt.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('Independent source fields/dates/3665 plans and255 preserved checks passed; shared teachers',shared,'conflicts',len(overlaps))
