# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet026-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={711: [(2, 630, 705, '호502'), (4, 630, 705, '호502')], 716: [(2, 900, 1065, '호501')], 717: [(2, 900, 1065, '호301')], 718: [(5, 720, 885, '호502')], 719: [(2, 720, 885, '호303')], 720: [(4, 900, 1065, '호303')], 721: [(3, 900, 1065, '호403')], 722: [(3, 540, 705, '호703')], 726: [(5, 540, 705, '호301')], 727: [(5, 720, 885, '호302')], 728: [(2, 630, 795, '호302')], 730: [(6, 540, 705, '호701')], 733: [(6, 540, 705, '호702')], 734: [(6, 960, 1125, '호302')], 736: [(1, 1170, 1305, '호503')], 737: [(6, 960, 1125, '호402')], 738: [(6, 540, 770, '호103')]}
weeks={711: [1, 2, 3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 716: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 717: [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15], 718: [1, 2, 3, 5, 7, 8, 12, 13, 14], 719: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15], 720: [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15], 721: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 722: [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 16], 726: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 727: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 728: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 730: [1, 2, 3, 6, 7, 9, 10, 11, 12, 13, 14, 15], 733: [1, 2, 3, 6, 7, 9, 10, 11, 12, 13], 734: [1, 2, 3, 6, 7, 9, 10, 11, 13, 14], 736: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 737: [1, 2, 3, 6, 7, 9, 10, 11, 13, 14], 738: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}
reasons={711: '자체 화목10:30–11:45호502 기본대면.4주전체추석휴강8/16시험 제외.자료PPT/e-campus는수업원격아님.', 716: '자체 화15–17:45호501 이론강의/토의 기본.전시현장운영은학습주제,실제견학은가능·별도공지 조건부.8/16시험제외.', 717: '자체 화15–17:45호301 대면원칙.비실시간온라인은상황조건부, TED시청은과제·수업에서는기법분석.8주발표수업 정상명시10/20만시험기간정규예외,9중간16공란제외.', 718: '자체 금12–14:45호502 Face-to-face default.4휴강6개별답사·보고서출결9–11중간발표15특강orReading16시험제외.8주Lecture/Group Discussion 명시10/23정규예외.영어제한전체보존.', 719: '자체 화12–14:45호303 대면원칙.13주개별식음업장답사/e-campus제출은미확정HH이므로제외, 제출마감을수업으로만들지않음.8/16시험제외.', 720: '자체 목15–17:45호303 대면수업.9주현장학습혹은특강 배정불명제외.8중간16기말기간과제제외.', 721: '자체 수15–17:45호403 대면기본,필요시live/VOD온라인조건부.8/16시험제외,각주정규교육/발표보존.', 722: '자체 수09–11:45호703 Face to face.9FieldTrip15필요시보강배정불명 제외,8중간 제외.16주명시Wrap-up Lecture/Group Presentation 정상12/16만기말기간정규예외.전체영어/절대평가보존.', 725: '자체1:1또는소그룹/주1회이상대면 독립심화.수13:30–16:15호406native창구와개인배정전체시각동일근거미확인보류.', 726: '자체 금09–11:45호301 대면원칙/조건부VOD,4추석6한글날8/16시험제외.읽기자료/과제를원격운영으로오해하지않음.', 727: '자체 금12–14:45호302 대면원칙.6주온라인강의live/VOD미확정및학교휴일 제외.4휴강8/16시험제외.전공자외수강불허유지.', 728: '자체 화10:30–13:15호302 각정규주차명시대면수업.8/16대면시험제외,부분영어·푸드비즈니스마이크로디그리보존.', 729: 'Registry plan0을원문미확인으로오해하지않고 currentOperatingCorrection의실제캐시1bff43997c6273a57f0a 전체별도읽음.대면단어와별도온라인선택만있어datedlive/VOD배정불명,이전정정유지.', 730: '자체 토09–11:45호701 대면기본,일부온라인가능조건부.4휴강5유튜브대체live시각없음8/16시험제외.전문가특강은기본수업장소변경근거없고실제현장방문은과제임.', 731: '자체 대면단어/일반강의기법과별도온라인선택만으로날짜별동기/영상배정미확인.15보강배정도불명,원문미확정으로보류.', 733: '자체 토09–11:45호702 주차별PPT중심대면강의명시.4/15동영상주차vs과제5/14주차상충양원문보존:4/5/14/15전부제외,8/16시험제외.어느표현도임의선택하지않음.', 734: '자체 토16–18:45호302 각현재literal MMDD별이론/질의응답.4/5명시영상12논술면접시휴강or영상15보강미확정8/16시험제외.', 736: '자체 월19:30–21:45호503 대면우선/법정공휴일온라인대체.10/5학교휴일제외,8중간15기말16Make-up미배정제외.이수학년/전공제한유지.', 737: '자체 토16–18:45호402 대면기본.4휴강보강방식미결정5온라인12논술휴강온라인15대면or녹화미확정제외,8/16시험제외.', 738: '자체 토09–12:50호103 대면원칙+실습중심20/80및조리복착용/매주실습단계의실물운영근거.4/5학교휴일8중간15실기시험16공란제외.자격실기시험토픽을실제시험날짜로전파하지않음.', 739: '자체이론대면이라도본문실제온라인강의명시·날짜별운영배정미확인.전체정규시간으로가정하지않고보류.', 740: '자체대면및비실시간온라인둘다명시,이론33/실습67만으로주차별모드추정불가.시연/실습주제만으로대면날짜확정하지않고보류.', 712: '해당자체현재0학점졸업논문·교수/코드 확인,교육·운영·주차·clock공란 보류.졸업/편제/학년제한 전체보존하고 다른논문지도차용0.', 713: '해당자체현재0학점졸업논문·교수/코드 확인,교육·운영·주차·clock공란 보류.졸업/편제/학년제한 전체보존하고 다른논문지도차용0.', 714: '해당자체현재0학점졸업논문·교수/코드 확인,교육·운영·주차·clock공란 보류.졸업/편제/학년제한 전체보존하고 다른논문지도차용0.', 715: '해당자체현재0학점졸업논문·교수/코드 확인,교육·운영·주차·clock공란 보류.졸업/편제/학년제한 전체보존하고 다른논문지도차용0.', 723: '해당자체현재0학점졸업논문·교수/코드 확인,교육·운영·주차·clock공란 보류.졸업/편제/학년제한 전체보존하고 다른논문지도차용0.', 724: '해당자체현재0학점졸업논문·교수/코드 확인,교육·운영·주차·clock공란 보류.졸업/편제/학년제한 전체보존하고 다른논문지도차용0.', 732: '해당자체현재0학점졸업논문·교수/코드 확인,교육·운영·주차·clock공란 보류.졸업/편제/학년제한 전체보존하고 다른논문지도차용0.', 735: '해당자체현재0학점졸업논문·교수/코드 확인,교육·운영·주차·clock공란 보류.졸업/편제/학년제한 전체보존하고 다른논문지도차용0.'}
allowedWeekdays={};exceptDates={};examExceptions={717:{'2026-10-20'},718:{'2026-10-23'},722:{'2026-12-16'}};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
allowedNativeGroups={}
calendarPlan={}
assert len(HH)==17 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-711];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
 assert native and not re.sub(r'[\s,]','',slot.sub('',c['sourceSchedule']))
 assert [('월화수목금토일'.index(m[1])+1,int(m[2])*60+int(m[3]),int(m[4])*60+int(m[5]),m[6].strip()) for m in native]==HH[n] or False,(n,c['sourceSchedule'],HH[n])
 if False:
  native=native[1:]
  assert [('월화수목금토일'.index(m[1])+1,int(m[2])*60+int(m[3]),int(m[4])*60+int(m[5]),m[6].strip()) for m in native]==HH[n]
 for plan,z in zip(plans,x['plans']):
  assert plan['campus']=={'seoul':'서울','global':'국제'}[c['campus']];assert plan['header']==['2026학년도 2학기 강의계획서'] and plan['lectureCode']==c['sourceEducationalVariants'][0]['lecture_cd']
  assert plan['queriedProfessorName'] in [v['teach_na'] for v in c['sourceEducationalVariants']]
  basic=next(s['rows'] for s in plan['educationalSections'] if s['section']=='기본정보');assert [r[1] for r in basic if r[0]=='학수번호']==[plan['lectureCode']]
  clocks=[r[1] for r in basic if r[0]=='강의시간강의실']
  normal=re.sub(r'\s+','',clocks[0] if clocks else '')
  if re.search(r"[월화수목금토일]\d{2}:\d{2}-",normal):
   for i,m in enumerate(native):
    if n in allowedNativeGroups and i not in allowedNativeGroups[n]:continue
    assert m[1]+m[2]+':'+m[3]+'-'+m[4]+':'+m[5] in normal and re.sub(r'\s+','',m[6]) in normal,(n,normal)
  shas[z['file']]=hashlib.sha256(pathlib.Path(z['file']).read_bytes()).hexdigest()
 rows=next(s['rows'] for s in plans[calendarPlan.get(n,0)]['educationalSections'] if s['section']=='주별강의내용');own={int(r[0][:-1]):r for r in rows if r and re.fullmatch(r'\d+주',r[0])};spans=[]
 for w in ws:
  r=own[w];a,b,z,d=map(int,re.fullmatch(r'(\d+)/(\d+)\s*~\s*(\d+)/(\d+)',r[1]).groups());spans.append((dt.date(2026,a,b),dt.date(2026,z,d),r))
 def permitted(day):
  if day.isoformat() in exceptDates.get(n,set()) or (day.isoformat() in closed and day.isoformat() not in holidayExceptions.get(n,set())):return False
  if n in explicitDates and day.isoformat() not in explicitDates[n]:return False
  return day.isoformat() in examExceptions.get(n,set()) or (not dt.date(2026,10,20)<=day<=dt.date(2026,10,26) and not dt.date(2026,12,15)<=day<=dt.date(2026,12,21))
 def actualRoom(r,base):
  w=int(r[0][:-1]);room=roomOverride.get(n,{}).get(w,base)
  if w in roomOverride.get(n,{}):assert room in ' '.join(r),(n,w,room)
  if any(k[0] in roomUnconfirmedWeekdays.get(n,set()) and k[3]==base for k in HH[n]):room=''
  return room
 meetings=[];independent=[]
 for ni,m in enumerate(native):
  if n in allowedNativeGroups and ni not in allowedNativeGroups[n]:continue
  if n in allowedWeekdays and ('월화수목금토일'.index(m[1])+1) not in allowedWeekdays[n]:continue
  wd='월화수목금토일'.index(m[1])+1
  for a,b,r in spans:
   day=a
   while day<=b:
    if day.isoweekday()==wd and permitted(day):meetings.append({'date':day.isoformat(),'weekday':wd,'startMinute':int(m[2])*60+int(m[3]),'endMinute':int(m[4])*60+int(m[5]),'classroom':actualRoom(r,m[6].strip())})
    day+=dt.timedelta(days=1)
 for a,b,r in spans:
  for ni,(wd,st,en,room) in enumerate(HH[n]):
   if n in allowedNativeGroups and ni not in allowedNativeGroups[n]:continue
   if n in allowedWeekdays and wd not in allowedWeekdays[n]:continue
   day=a+dt.timedelta(days=(wd-a.isoweekday())%7)
   while day<=b:
    if permitted(day):independent.append((day.isoformat(),wd,st,en,actualRoom(r,room)))
    day+=dt.timedelta(days=7)
 assert len(set(independent))==len(meetings);assert set(independent)=={(r['date'],r['weekday'],r['startMinute'],r['endMinute'],r['classroom']) for r in meetings}
 selected[c['sourceId']]=meetings;count+=len(meetings)
 proof.append({'packetOrdinal':n,'sourceId':c['sourceId'],'wholePlans':plans,'nativeClock':c['sourceSchedule'],'ownCampus':plans[0]['campus'],'literalNativeHH':HH[n],'allowedPhysicalWeeksLiteral':ws,'physicalRowsLiteral':[r for a,b,r in spans],'semanticReason':reasons[n],'explicitUnscheduledDatesLiteral':sorted(exceptDates.get(n,set())),'independentDates':sorted({k[0] for k in independent}),'literalIndependentMeetings':[list(k) for k in sorted(independent)],'ownExamNormalExceptionsLiteral':sorted(examExceptions.get(n,set())),'ownHolidayNormalExceptionsLiteral':sorted(holidayExceptions.get(n,set())),'ownExplicitDatesLiteral':sorted(explicitDates.get(n,set())),'ownRoomOverridesLiteral':roomOverride.get(n,{}),'roomUnconfirmedWeekdaysLiteral':sorted(roomUnconfirmedWeekdays.get(n,set())),'allowedWeekdaysLiteral':sorted(allowedWeekdays.get(n,set())),'allowedNativeGroupsLiteral':sorted(allowedNativeGroups.get(n,set(range(len(native))))),'calendarPlanIndex':calendarPlan.get(n,0),'newDateCount':len(meetings),'previousResearchDepartmentRemarks':c['departmentRemarks'],'remoteHoursGenerated':0})
for campus in ['seoul','global']:
 old=json.load(open(P.parent/'packet025-reviewed30'/f'khu-{campus}-2026-2.packet025-physical-groups-prepared.json'));(P/f'packet026-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside026'}
 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet026-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet026-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2768,'baselineDates':51862,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2768+len(selected),'totalDates':51862+count})
