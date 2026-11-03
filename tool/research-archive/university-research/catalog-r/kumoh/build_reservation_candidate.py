"""Current educational whitelist only; no auth/session/staff identifiers."""
import collections,datetime as dt,json,re
from pathlib import Path
R=Path(__file__).parent;M=R.parent.parent/'catalog-m'
rows=json.loads((M/'kumoh-current-educational-recheck-20261008.json').read_text());closure=json.loads((M/'kumoh-closure-normalized.json').read_text());closed={r[4]+'-'+r[5] for r in closure}
clock={str(i):((8+i)*60,(8+i)*60+50) for i in range(10)};clock.update({p:(1080+i*55,1130+i*55) for i,p in enumerate('ABCDE')})
verified={'T','TB','D','DB','G','GB','에디슨','그린'};groups=collections.defaultdict(list);why=collections.Counter()
notes='공개 예약 계획, 실제 등교·집중이수/온라인 운영 날짜 미확인. 2026년 10월 8일 정상 공개 재확인 학부 개설강좌의 원래 과목코드·분반·이수구분·수업운영방법·수강대상·교수·강의실·교시를 보존합니다. 원문 대면수업 표시만으로 개별 날짜의 실제 등교를 확정하지 않습니다. 방식은 미지정으로 사용자가 선택한 방식을 유지합니다. 집중이수 강의는 15주보다 짧게 운영될 수 있어 현재 개별 강의계획 기간을 확인해야 합니다. 공식 9월 1일 개강과 12월 22일 동계방학 사이의 12월 21일을 학기 경계로 사용하며 이는 인쇄된 종강일이 아닙니다. 보강 전 12월 7일까지 일반 예약을 만들고 공휴일을 제외합니다. 보강12월 8일~14일과 기말15일~21일은 개별 일정 근거 없어 생성하지 않습니다.'
for r in rows:
 raw=r['TIME_LCTRM_INFO'] or '';reason='';spans=[];prefixes=set();ident=r['SBJCT_CD_DCLSS']
 if ident in closed:reason='현재 공식 폐강·합반'
 elif r['DEPT_SE_NM']!='학부':reason='학부 범위 미확인'
 elif r['LSN_OPER_MTHD_NM']!='대면수업':reason='원격·플립러닝 개별 운영 날짜 미확인'
 elif any(s in r['SBJCT_NM'] for s in ['집중','현장실습','인턴','봉사','군복무']):reason='집중·현장 등 개별 운영 기간 미확인'
 elif not raw:reason='원문 시간·강의실 미공개'
 else:
  for part in raw.split(','):
   m=re.fullmatch(r'([월화수목금토일])([0-9A-E]+)/(.+)',part)
   if not m:reason='원문 교시·강의실 대응 미확인';break
   day='월화수목금토일'.index(m[1])+1;room=m[3];prefix=re.match(r'([^0-9]+)',room)
   prefixes.add(prefix[1] if prefix else '')
   if day>5:reason='주말 개별 운영 날짜 미확인';break
   for p in m[2]:
    if p not in clock:reason='공식 시각 범위 밖';break
    start,end=clock[p];spans.append(dict(weekday=day,startMinute=start,endMinute=end,classroom=room))
 prefixes={re.match(r'([^0-9]+)',x)[1] for x in re.findall(r'/([^,]+)',raw) if re.match(r'([^0-9]+)',x)}
 campus='yangho' if prefixes and prefixes<=verified else 'unknown'
 # Unknown campus rows stay educational references; do not assign physical site.
 if not reason and campus=='unknown':reason='원문 강의실 실제 캠퍼스 대응 미확인'
 meetings=[]
 if not reason:
  d=dt.date(2026,9,1)
  while d<=dt.date(2026,12,7):
   if d.isoformat() not in ['2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09']:
    meetings += [dict(s,date=d.isoformat()) for s in spans if s['weekday']==d.isoweekday()]
   d+=dt.timedelta(days=1)
 else:why[reason]+=1
 dep=r['CRCLM_NM'];cl=r['SBJCT_KND_SE_NM'];credit=r['CRD']
 groups[campus].append(dict(sourceId=f'kumoh/{campus}/2026-2/{ident}',campus=campus,academicYear=2026,semester='2',courseCode=r['SBJCT_CD'],courseName=r['SBJCT_NM'],section=r['DCLSS_NO'],professor=r['EMPNM'] or '',classification=cl,credits=credit,departments=[dep],departmentCredits={dep:credit},departmentClassifications={dep:cl},sourceSchedule=raw,sourceClassroom=' / '.join(dict.fromkeys(s['classroom'] for s in spans)),scheduleStatus='scheduled' if meetings else 'unrecognized',schedules=meetings,period=dict(startDate='2026-09-01',endDate='2026-12-21'),remarks=notes+' 원문 운영방법: '+str(r['LSN_OPER_MTHD_NM'])+'; 이수선택: '+str(r['CPL_SE_NM'])+'; 수강대상 학년/학과: '+str(r['CPL_TRGT_SCGD'])+'/'+str(r['TLT_DEPT_INFO'])+(' 예약 보류: '+reason if reason else ''),metadata=dict(originalEducationalFields=r,nativeIdentity=ident,sourceDeliveryMode=r['LSN_OPER_MTHD_NM'],deliveryModeStatus='unknown-user-choice',researchOnly=True,actualAttendanceConfirmed=False,actualPhysicalDatesConfirmed=False,concentratedOperatingPlanVerified=False,campusScope='Exact current guide room prefixes matched official Yangho buildings' if campus=='yangho' else 'Unknown campus educational reference only',currentClosureListMatched=ident in closed,heldReason=reason)))
counts={}
for campus,cs in groups.items():
 d=dict(schemaVersion=2,universityId='kumoh',campus=campus,campusName='양호동' if campus=='yangho' else '캠퍼스 미확인',academicYear=2026,semester='2',publishedDate='2026-10-08',sourceUrl='https://www.kumoh.ac.kr/ko/sub06_01_01_01.do?mode=view&articleNo=572943',researchOnly=True,completionClaim=False,courses=cs)
 (R/f'kumoh-{campus}-2026-2.reservation-planned-v1.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');counts[campus]=dict(rows=len(cs),scheduled=sum(bool(c['schedules']) for c in cs),appointments=sum(len(c['schedules']) for c in cs))
print(json.dumps(dict(counts=counts,held=why),ensure_ascii=False))
