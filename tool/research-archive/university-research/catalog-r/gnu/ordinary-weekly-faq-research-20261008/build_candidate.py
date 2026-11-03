import copy,datetime,hashlib,json,re
from pathlib import Path
root=Path(__file__).parent
prior=Path('work/university-research/catalog-r/gnu')
read=lambda p:json.loads(p.read_text())
raw=read(Path('work/university-research/catalogs/gnu-public-course-rows.json'))
calendar=read(Path('work/university-research/catalog-p/gnu-car-current-educational-notices-20261008.json'))[1]
(root/'own-term-makeup-education.json').write_text(json.dumps(calendar,ensure_ascii=False,indent=2)+'\n')
makeup=calendar['visuallyVerifiedEducationOnly']['holidayToMakeup']
clock={}
for row in read(root/'cele-public-undergraduate-period-faq.json')['educationalTable'][1:]:
 for i in (0,2):
  n=int(re.match(r'\d+',row[i])[0]);a,b=re.findall(r'\d{2}:\d{2}',row[i+1]);minute=lambda x:int(x[:2])*60+int(x[3:]);clock[n]=[minute(a),minute(b)]
assert clock=={n:[480+60*n,530+60*n] for n in range(12)}
held=[];added=[];old=[];files=[]
pattern=re.compile(r'([월화수목금토일])(\d+(?:,\d+)*)\[([^\]]+)\]')
for p in sorted(prior.glob('gnu-*-2026-2.industry-actual-planned-v3.json')):
 baseline=root/('baseline-'+p.name)
 if not baseline.exists():baseline.write_bytes(p.read_bytes())
 d=read(baseline)
 for c in d['courses']:
  original=copy.deepcopy(c);r=c['metadata']['originalEducationalFields']
  assert r in raw
  if c['schedules']:old.append(c['sourceId']);continue
  reason=None
  if r['closedFirstAnnouncement'] or r['closedSecondAnnouncement']:reason='publishedClosure'
  elif c['campus'] not in ('gajwa','chilam'):reason='campusClockScopeUnconfirmed'
  elif c['metadata'].get('currentPublishedNativeIdentityConflict'):reason='currentNativeIdentityConflict'
  elif r['method']!='대면수업' or r['remoteType']:reason='remoteOrMixedOperation'
  elif '집중' in r['remarks']:reason='explicitIntensiveOperation'
  elif '야간' in r.get('dayNight','')+r['remarks'] or r['department']=='산업경영학과':reason='nightOrIndustrySpecialClock'
  elif not r['schedule']:reason='noNativeWeeklyTime'
  matches=list(pattern.finditer(r['schedule']))
  if reason is None and (not matches or re.sub(r'[,\s]+','',pattern.sub('',r['schedule']))):reason='nativeRoomOrSyntaxUnresolved'
  geometries=[]
  if reason is None:
   for m in matches:
    day='월화수목금토일'.index(m[1])+1;periods=list(map(int,m[2].split(',')));room=m[3]
    if any(n not in clock for n in periods):reason='periodOutsidePublished0Through11';break
    if len(set(periods))!=len(periods) or periods!=sorted(periods):reason='nativePeriodOrderConflict';break
    if any(x in room for x in ('미정','추후','동영상','온라인','원격')):reason='roomOrOperationUnresolved';break
    blocks=[]
    for n in periods:
     if blocks and n==blocks[-1][-1]+1:blocks[-1].append(n)
     else:blocks.append([n])
    for block in blocks:geometries.append({'nativeWeekday':day,'nativePeriods':block,'startMinute':clock[block[0]][0],'endMinute':clock[block[-1]][1],'classroom':room})
  if reason:
   held.append({'sourceId':c['sourceId'],'reason':reason,'originalEducationalFields':r});continue
  meetings=[]
  for g in geometries:
   date=datetime.date(2026,9,1)
   while date<=datetime.date(2026,12,7):
    iso=date.isoformat()
    if date.isoweekday()==g['nativeWeekday'] and iso!='2026-10-03':
     actual=makeup.get(iso,iso);ad=datetime.date.fromisoformat(actual)
     meetings.append({'date':actual,'weekday':ad.isoweekday(),'startMinute':g['startMinute'],'endMinute':g['endMinute'],'classroom':g['classroom']})
    date+=datetime.timedelta(days=1)
  meetings.sort(key=lambda m:(m['date'],m['startMinute'],m['classroom']))
  assert len(meetings)==len({json.dumps(x,sort_keys=True) for x in meetings})
  c['schedules']=meetings;c['scheduleStatus']='scheduled'
  note='2026-07-24 공개 원본의 요일·교시·강의실과 현재 공식 학부 FAQ 일반 교시표(0~11교시)에 따른 정규 주간 예약 계획입니다. 가좌·칠암에만 적용하며 현재 물리 캠퍼스는 원본 값을 보존합니다. 실제 개별 출석일 확정 자료가 아니며 최신 변경은 통합서비스에서 확인해야 합니다. 공식 2026-2 학기 범위는 9월 1일~12월 21일입니다. 공개 지정보강일은 원래 휴강일의 시각·실로 예약하고, 12월 15~21일 기말시험의 개별 시각 및 10월 3일 토요일의 개별 보강은 미확정으로 추가하지 않았습니다. 연속 교시 사이 쉬는 시간은 예약 블록에 포함됩니다. 원본 대면수업 방식은 보존하되 예약 방식은 사용자가 선택합니다. '
  c['remarks']=note+r['remarks']
  c['metadata'].update({'holdReason':None,'clockSecondSemesterApplicabilityConfirmed':True,'reservationBasis':'nativeWeeklyPlanWithOfficialTermAndCurrentUndergraduateFAQ','actualAttendanceConfirmed':False,'wholeLatestChangesConfirmed':False,'clockSource':'cele-public-undergraduate-period-faq.json' if c['campus']=='gajwa' else 'landscape-public-undergraduate-period-faq.json'})
  added.append({'sourceId':c['sourceId'],'nativeEducationalFields':r,'nativeGeometry':geometries,'meetingCount':len(meetings)})
 out=root/p.name.replace('industry-actual-planned-v3','ordinary-weekly-faq-v4');out.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');files.append(out.name)
assert len(old)==18
report={'researchOnly':True,'completionClaim':False,'wholeLatestChangesConfirmed':False,'nativeRows':4842,'preservedOld18':old,'oldMeetings':238,'newScheduledRows':len(added),'newMeetings':sum(x['meetingCount'] for x in added),'scheduledRows':len(old)+len(added),'heldRows':len(held),'newCases':added,'heldCases':held,'candidateFiles':files,'clock':clock,'semesterBounds':['2026-09-01','2026-12-21'],'regularReservationThrough':'2026-12-07','makeup':makeup,'examIndividualTimesNotInvented':True,'eligibleCampuses':['gajwa','chilam']}
(root/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
from collections import Counter
print({k:report[k] for k in ['nativeRows','newScheduledRows','newMeetings','scheduledRows','heldRows']});print(Counter(x['reason'] for x in held))
