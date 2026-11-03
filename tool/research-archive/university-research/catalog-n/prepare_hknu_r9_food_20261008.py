"""Current food-biotechnology actual public educational slots; no guessed lab shifts."""
import json,pathlib,hashlib,copy,datetime as dt
R=pathlib.Path(__file__).resolve().parent
helper=(R/'prepare_hknu_r5_architecture_20261008.py').read_text();exec(helper[helper.index('ends={'):helper.index('files=[];audits=[]')])
# Exact native original codes join unique current title/day-night cells. Room numbers kept literal.
basic=[('0000300028',4,'강지훈','212'),('0000300030',1,'신임','201'),('0000300042',4,'신임','201'),('0000300096',3,'손종연','201'),('1000280015',5,'서승만','212'),('2002330007',1,'강지훈','202'),('2002330012',5,'박현주','202'),('2002330014',3,'라채훈','212'),('2002330019',1,'라채훈','212'),('2002330021',4,'서승만','202')]
records={}
for code,wd,prof,room in basic:
 records[(code,'A01')]=(prof,[(wd,900 if code=='2002330012' else 840,1070 if code=='2002330012' else 1010,room)])
 records[(code,'B01')]=('신임' if code=='0000300096' else prof,[(wd,1080,1220,room)])
records.update({('2002330004','A01'):('강지훈 / 서승만',[(1,630,810,'101')]),('0000033330','A01'):('라채훈',[(5,540,830,'201')]),('0000300100','A01'):('심재용',[(2,840,1010,'212 / 102'),(3,600,650,'212')]),('0000300100','B01'):('심재용',[(2,1080,1265,'212 / 102')]),('0000300130','A01'):('강지훈',[(3,840,1070,'202 / 103')]),('0000300130','B01'):('강지훈',[(3,1080,1265,'202 / 103')])})
assert len(records)==26
source='https://www.hknu.ac.kr/bbs/hkfoodbio/255/97231/artclView.do';files=[];audit=[]
for campus in ['anseong','pyeongtaek']:
 original=json.loads((R/f'hknu-{campus}-2026-2.planned-audited-20261008-r8.json').read_text());d=copy.deepcopy(original)
 for c in d['courses']:
  if c['departments'][0]!='식품생명공학전공':continue
  c['metadata']['currentFoodPublishedEducationSource']={'sourceUrl':source,'pdfUrl':'https://www.hknu.ac.kr/bbs/hkfoodbio/255/113524/download.do','readDate':'2026-10-08','sourceTitle':'2026-2 강의시간표(식품생명공학전공)','sourceEvidence':'hknu-current-food-biotechnology-education-grid-coordinates-20261008.json','nativeCodeSectionLinkedFromUniqueOriginalOpeningDepartmentTitleDayNightOffering':True}
  if '인성교육및상담' in c['courseName']:assert not c['schedules'];continue
  prof,slots=records[(c['courseCode'],c['section'])];weekly=[{'weekday':wd,'startMinute':start,'endMinute':end,'classroom':room} for wd,start,end,room in slots]
  c['professor']=prof;c['schedules']=dated(weekly);c['scheduleStatus']='scheduled';c['sourceClassroom']=' / '.join(dict.fromkeys(s['classroom'] for s in weekly));c['sourceSchedule']=' / '.join('('+['월','화','수','목','금','토','일'][s['weekday']-1]+') '+f"{s['startMinute']//60:02}:{s['startMinute']%60:02}~{s['endMinute']//60:02}:{s['endMinute']%60:02}" for s in weekly)
  c['metadata']['publishedWeeklyMeetingsUsedForPlan']=weekly;c['metadata']['currentFoodDirectCellEducation']=[{'nativeWeekday':wd,'actualClockStartMinute':start,'actualClockEndMinute':end,'actualRoomLiteral':room,'actualProfessorLiteral':prof} for wd,start,end,room in slots];c['metadata']['originalRawEducationUnchanged']=True
  c['departmentRemarks'][c['departments'][0]]+='\n현재 식품생명공학 공식 셀의 공시 예정시각·교수·방 적용. 신임 표기는 원문 미확정 교수 표기이며 실제 이름 추정 안 함. 야간 시간은 이 개별 현행표의 실제 integer 교시10–12/13만 사용하고 전교 소수 교시로 일반화하지 않음.'
  if c['courseCode'] in ['0000300100','0000300130']:
   c['metadata']['multiplePublishedRoomNoTemporalPairingInvention']=True;c['departmentRemarks'][c['departments'][0]]+='\n강의·실습방 두 곳은 해당 현재 셀 원문에 함께 게시됨. 어느 분에 방을 옮기는지 미게시여서 임의 회의 분할·방 시각 배정하지 않음.'
  if c['courseCode']=='2002330004':c['metadata']['currentHalfPeriodCellCorroboratedByUnchangedOriginal2_5Through5']=True
  audit.append({'sourceId':c['sourceId'],'currentMeetings':len(c['schedules']),'currentProfessorLiteral':prof,'actualCellMeetings':weekly})
 for a,b in zip(original['courses'],d['courses']):
  if a['departments'][0]!='식품생명공학전공':assert a==b
  for key in ['courseCode','section','sourceId','departments','departmentClassifications','departmentCredits']:assert a[key]==b[key]
 name=f'hknu-{campus}-2026-2.planned-audited-20261008-r9.json';p=R/name;assert not p.exists();data=(json.dumps(d,ensure_ascii=False,indent=2)+'\n').encode();p.write_bytes(data);files.append({'file':name,'sha256':hashlib.sha256(data).hexdigest(),'courseCount':len(d['courses']),'scheduledCount':sum(bool(c['schedules']) for c in d['courses']),'dateCount':sum(len(c['schedules']) for c in d['courses'])})
assert len(audit)==26
m=json.loads((R/'hknu-planned-audited-20261008-r8-sha-manifest.json').read_text());m['files']=files;m['totalScheduledCount']=sum(x['scheduledCount'] for x in files);m['totalDateCount']=sum(x['dateCount'] for x in files);m['currentFoodWhole26RegularOrProject6IndividualCounselingAudited']=True;m['currentFoodActualMeetingAudit']=audit
(R/'hknu-planned-audited-20261008-r9-sha-manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n');print(files)
