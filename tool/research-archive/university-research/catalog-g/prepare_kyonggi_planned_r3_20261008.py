"""Apply current common IA002 special weeks without asserting whole intensive duration."""
import copy,json,pathlib,hashlib
R=pathlib.Path(__file__).resolve().parent
base=json.loads((R/'kyonggi-suwon-2026-2.planned-audited-20261008-r2.json').read_text())
draft={c['actualRegistrationNumber']:c for c in json.loads((R/'kyonggi-source-clock-candidate-draft-20261008.json').read_text())['rows']}
regular={'0553','0554','0555','0556','0557','0558','0559','1636','1637'}
intensive={'1638','1639','1640','1633','1634','1635'}
partial_dates=['2026-09-02','2026-09-09','2026-09-16','2026-09-23','2026-10-14','2026-10-21']
changed=[]
for c in base['courses']:
 if c['courseCode']!='IA002': continue
 n=c['metadata']['actualRegistrationNumber'];f=draft[n]['actualEducationalFields']
 proof={'currentWorkbookTarget':'2026-2 유형Ⅰ 자유전공학부(수원·서울), 유형Ⅱ 단과대학통합선발','actualPublishedCohort':c['remarks'].splitlines()[1],'week5Source':'https://www.kyonggi.ac.kr/www/selectBbsNttView.do?key=7520&bbsNo=1073&nttNo=626208','week6Source':'https://www.kyonggi.ac.kr/www/selectBbsNttView.do?key=7520&bbsNo=1073&nttNo=626215','actualWeek5Date':'2026-09-30','actualWeek6Date':'2026-10-07','wholeIntensiveEndDateNotConfirmed':True,'wholeUniversitySupportComplete':False}
 before=copy.deepcopy(c['schedules'])
 if n in regular:
  c['schedules']=[m for m in c['schedules'] if m['date'] not in ['2026-09-30','2026-10-07']]
  proof['decision']='ordinaryPostedTermExceptExplicitCommonSpecialWeeks';proof['removedRegularDates']=['2026-09-30','2026-10-07']
 elif n in intensive:
  assert f['weekday']=='수' and f['period'] in ['주4 5','주5 6']
  start,end=(720,830) if f['period']=='주4 5' else (780,890)
  c['schedules']=[{'weekday':3,'startMinute':start,'endMinute':end,'classroom':f['classroom'],'date':date} for date in partial_dates]
  c['scheduleStatus']='scheduled';c['metadata']['decision']='partialPublishedWorkbookWeeksWithCurrentAnchor'
  c['remarks']=c['remarks'].replace('집중수업 실제 개별 기간 미게시. 정규 학기 전체 반복 미생성.','집중수업: 현행 공통 워크북 1~8주 중 일반 수업 주차 1~4·7~8만 공시 원교시로 계획 반영. 전체 집중기간·종료일 확정 주장이 아니며 8주 이후 반복은 미생성.')
  proof['decision']='partialCurrentPublishedCurriculumWeeks';proof['supportedOrdinaryWeeks']=[1,2,3,4,7,8];proof['supportedPlanningDates']=partial_dates
 else:
  assert n in {'1647','1648','1649'};proof['decision']='nativeClockUnpublishedRemainHeld'
 c['remarks']+='\n현재 공통 전공설계세미나 5주차(9/30)는 기존 교실이 아닌 학생 희망전공별 선배특강으로 대체됩니다. 수원 특강의 개인 고정 시각 미게시. 6주차(10/7)는 실내체육관(제3강의동) 직무 Festival에서 현직자 2명 이상 멘토링 참여가 과제 조건이며 10:00~16:00 전체 운영시간을 개인 수업시간으로 생성하지 않습니다. 이 두 날짜는 일반 공시회의를 생성하지 않으며 담당교수 안내를 확인하세요.'
 c['metadata']['currentIA002OperatingEvidence']=proof
 changed.append({'registrationNumber':n,'cohort':proof['actualPublishedCohort'],'originalMeetingCount':len(before),'newMeetingCount':len(c['schedules']),'decision':proof['decision']})
assert len(changed)==18
fn='kyonggi-suwon-2026-2.planned-audited-20261008-r3.json';p=R/fn
assert not p.exists(),'immutable candidate already exists'
b=(json.dumps(base,ensure_ascii=False,indent=2)+'\n').encode();p.write_bytes(b)
m={'researchOnly':True,'completionClaim':False,'file':fn,'sha256':hashlib.sha256(b).hexdigest(),'sourceRows':len(base['courses']),'scheduledCount':sum(bool(c['schedules']) for c in base['courses']),'dateCount':sum(len(c['schedules']) for c in base['courses']),'changedIA002Rows':changed,'unchangedOtherCourseObjects':1622,'sourceScope':'Suwon daytime only','intensiveWholePeriodComplete':False,'explicitCommonSpecialWeeksAppliedToAllActualTypeIAndIIPublishedIA002Targets':True,'actualAttendanceConfirmed':False,'evidenceFiles':['kyonggi-current-workbook-operating-evidence-20261008.json','kyonggi-current-5week-attachment-audit-20261008.json','kyonggi-current-6week-attachment-audit-20261008.json','kyonggi-current-intensive-target-context-20261008.json'],'remaining':['Seoul/night whole source','42 actual clock-table gaps','3 IA002 clocks unpublished','Intensive whole duration after confirmed curriculum not claimed','19 asynchronous untimed and other actual individual/external activity']}
(R/'kyonggi-planned-audited-20261008-r3-sha-manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n');print(m['sha256'],m['scheduledCount'],m['dateCount'])
