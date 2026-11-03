"""Five additional official current plans; conflicting operations stay held."""
import copy,datetime as dt,hashlib,json,re
from pathlib import Path
from sogang_public_education import same_educational_value
R=Path(__file__).parent;O=R/'sogang-additions-v11-20261008';B=R/'sogang-additions-v10-20261008/sogang-unknown-2026-2.ninety-reviewed-20261008.json'
base=json.loads(B.read_text());out=copy.deepcopy(base);proofs=[]
config=[('ENG3224-01',28,['2026-09-24','2026-10-20','2026-12-15','2026-12-17'],'현재Fall2026·과목ENG3224·J217·13:30~14:45 일치. 원문직접 일반27회 및 공시일치10/22중간시험1회만 반영. NoClass9/24·10/20·12/15와12/17기말clock미공개 보류. 2~4학년·한국어수업가능자/과제시험영어, 읽기자료하드카피·저작권·AI부정행위·후속공지조건 보존.'),('MGT3007-01',24,['2026-09-10','2026-09-24','2026-10-13','2026-10-15','2026-10-20','2026-10-22','2026-12-15','2026-12-17'],'현재2026Fall·MGT3007sec01·MA104·12:00~13:15일치. 원문일반강의·토론·팀발표24회만 반영. 원문NoClass9/10·9/24와시험주 제외. 7주header10/13·15 vs 본문Review midterm-Apr16 월조건충돌은 해당두날짜 보류. 중간10/20공시MA104/MA201개별배정미공개 및 기말12/15·17clock미공개 보류. 발표·토론·변경조건 보존.'),('MGT4102-01',27,['2026-09-24','2026-10-20','2026-12-15'],'현재2026-2·MGT4102·native12:00~13:15MA208로 직접날짜일반27회만 반영. source교실TBA는 현재public확정MA208값사용, 추정없음. source10/20NoClass·중간팀프로젝트제출 vs current시험배정 충돌은held.9/24NoClass및12/15기말clock미공개 held. 8주10/22미인쇄 날짜생성없음. 사례팀발표·퀴즈·계획후속변경조건 보존.'),('GME3000-01',25,['2026-09-24','2026-12-07','2026-12-09'],'현재2026-2·GME3000·화목12:00~13:15일치, public실J609. 날짜원문강의·토론·발표·수업활동25회만 반영.9/24추석 제외. 마지막source12/7(화)·12/9(목)는 실제월·수와충돌하여 둘다held,12/8·10으로고치지 않음. 중간·기말기간은 시험일clock미공개 생성없음.2~4학년·한국어운영·후속상황변경 조건 보존.'),('JAS4015-01',26,[],'현재Fall2026·JAS4015·화목16:30~17:45와 nativeGA403사용. 원문직접 일반강의·상영·토론·학생발표26회만 반영.9/22~24추석NoClass,10/20~22중간NoClass,12/15~17기말NoClass배정없음. Zoom all meetings는 Office Hours 면담 항목이므로 강의mode로적용하지 않음. 수업자료·보고서/기말과제제출·발표·이메일공지 조건 보존.')]
for key,expected,excluded,note in config:
 s=json.loads((O/f'{key}.source-education.json').read_text());row=s['currentPublicRow'];t=s['weeklyOperatingText'];c=next(c for c in out['courses'] if c['courseCode']+'-'+c['section']==key)
 assert not c['schedules'] and s['currentBytesEqualPrior'];assert all(same_educational_value(k,row.get(k,''),v) for k,v in c['sourceEducationalMetadata'].items())
 clock=re.search(r'(\d{2}):(\d{2})~(\d{2}):(\d{2})',row['meetingText']);start=int(clock[1])*60+int(clock[2]);end=int(clock[3])*60+int(clock[4]);room=re.search(r'\[([^\]]+)\]',row['meetingText'])[1];assert end-start==75
 if key=='ENG3224-01':dates=re.findall(r'(0?[1-9]|1[012])/(0?[1-9]|[12]\d|3[01])\s*\([TR]\)',t)
 elif key=='JAS4015-01':dates=re.findall(r'(0?[1-9]|1[012])/(0?[1-9]|[12]\d|3[01])\s*\((?:Tu|Th)\)',t)
 elif key=='GME3000-01':dates=re.findall(r'[화목](?:추석연휴)?(\d{1,2})/(\d{1,2})',re.sub(r'\s+','',t))
 else:dates=re.findall(r'(0?[1-9]|1[012])/(0?[1-9]|[12]\d|3[01])(?!\d)',t)
 dates=[dt.date(2026,int(m),int(d)) for m,d in dates];assert len(set(dates))==len(dates)
 plans=[];holds=[]
 for date in dates:
  ds=date.isoformat()
  if ds in excluded:holds.append({'date':ds,'reason':'source NoClass, source date/weekday/month conflict, unpublished individual exam allocation or final clock'});continue
  assert date.isoweekday() in {2,4} and dt.date(2026,9,1)<=date<=dt.date(2026,12,21),(key,ds)
  plans.append({'date':ds,'weekday':date.isoweekday(),'startMinute':start,'endMinute':end,'classroom':room})
 assert len(plans)==expected,(key,len(plans),expected)
 if key=='ENG3224-01':assert row['exam']=='10.22(목)13:30~14:45[J217]'
 if key=='JAS4015-01':assert 'Office Hours' in s['officeHoursModeContext'] and 'via Zoom' in s['officeHoursModeContext']
 plans.sort(key=lambda m:m['date']);c.update(schedules=plans,scheduleStatus='scheduled',partialSchedule=True,period={'startDate':plans[0]['date'],'endDate':plans[-1]['date']},scheduleEvidence={'basis':'currentPublicPlanPrintedDates','count':expected,'attendanceConfirmed':False})
 for dep in c['departmentRemarks']:c['departmentRemarks'][dep]+='\n'+note
 proofs.append({'offering':key,'sourcePdfSHA256':s['fileSha256'],'holds':holds,'meetings':plans,'addedPlans':expected,'nativeClock':row['meetingText']})
changed=[a['courseCode']+'-'+a['section'] for a,b in zip(base['courses'],out['courses']) if a!=b];assert len(changed)==5
assert sum(bool(c['schedules']) for c in out['courses'])==95;assert sum(len(c['schedules']) for c in out['courses'])==2321
f=O/'sogang-unknown-2026-2.ninety-five-reviewed-20261008.json';f.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
a={'baseFile':str(B),'baseSHA256':hashlib.sha256(B.read_bytes()).hexdigest(),'candidateFile':f.name,'candidateSHA256':hashlib.sha256(f.read_bytes()).hexdigest(),'whole':1541,'previousScheduled':90,'previousPlans':2191,'addedScheduled':5,'addedPlans':130,'scheduled':95,'plans':2321,'changedOnly':changed,'proofs':proofs,'otherOfferingsAndSourceIdsUnchanged':True,'productionEdited':False,'completionClaim':False};(O/'additions-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print('95/2321; +5/130')
