"""Current publicly posted planned timetable, with actual plan conflicts retained."""
import copy,datetime as dt,hashlib,json,pathlib,sys
from collections import Counter
ROOT=pathlib.Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT.parent/'catalog-g'))
from skku_inline_private_education_filter import filter_education
rows=json.loads((ROOT/'postech-2026-2-normalized-research.json').read_text())['courses']
plans={(x['code'],x['section']):x for x in json.loads((ROOT/'postech-2026-2-public-plan-audit.json').read_text())['reports']}
reviews={(x['code'],x['section']):x for x in json.loads((ROOT/'postech-operating-exceptions-manual-review.json').read_text())['reviews']}
start=dt.date(2026,9,7);end=dt.date(2026,12,24)
closures={'2026-09-18','2026-09-19','2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09','2026-12-03'}
# Explicit individual agreement, actual operating ambiguity or body/current conflict.
hold={'CSED199':'첫 소개 수업 시각 변경 가능 및 이후 개별 연구 일정 미게시',
      'CHEB199':'연구 일정 개별 합의, 공시 시각은 임시 기준',
      'PHYS199':'랩투어/연구참여 트랙별 일정 미게시',
      'AMSE199':'도입 수업 종료 시각 및 이후 개별 연구 일정 미게시',
      'MECH199':'현행 표지와 2026-1 본문 충돌, 실제 연구 운영 미확인',
      'CITE201':'현행 표지와 날짜·요일별 본문 충돌',
      'GEDU162':'별도 집중 운영 시간표 및 장소 공지 미확인',
      'SEMI323':'요일별 실습 장소·개별 온라인 시각 전환 별도 검토 필요',
      'MECH470':'녹화/실시간 Zoom 수업 구분 미게시',
      'MECH250':'주간 동영상 학습으로 운영, 별도 실시간 회의 미확인'}
vod={'EECE100','EECE490E','DISU101','DISU301'}
week_exclusions={'IMEN200':[8,16],'EECE276':[8,16],'GEDU186':[3,13],
 'MATH102':[6],'SEMI211':[8,16],'SOSC449B':[8,16]}
audit=[];out=[];privacy={'maskedTokens':0,'discardedPrivateLines':0}
for raw in rows:
 c=copy.deepcopy(raw);key=(c['courseCode'],c['section']);code=key[0];plan=plans[key]
 assert plan['identityMatches'] and plan['status']=='publicCurrentPlanMatched'
 c['sourceId']=f"postech-2026-2-{code}-{c['section'] or 'unpublished'}"
 safe={}
 for k,v in plan['publicOperatingSections'].items():
  text,m,l=filter_education(v);privacy['maskedTokens']+=m;privacy['discardedPrivateLines']+=l;safe[k]=text
 conditions=safe.get('4. 강의선수/수강필수사항','')
 # Preserve actual eligibility, operation and notes; no staff fields/private source.
 notes='\n'.join(v for k,v in safe.items() if k in ['4. 강의선수/수강필수사항','9. 수업운영','10. 학습법 소개 및 기타사항'] and v.strip())
 for d in c['departments']:
  base,m,l=filter_education(c['departmentRemarks'].get(d,''));privacy['maskedTokens']+=m;privacy['discardedPrivateLines']+=l
  c['departmentRemarks'][d]='\n'.join(filter(None,[base,notes]))
 c['period']={'startDate':start.isoformat(),'endDate':end.isoformat()}
 source_slots=copy.deepcopy(c['schedules']);excluded=set(reviews.get(key,{}).get('explicitNoClassDates',[]))
 weeks=week_exclusions.get(code,[])
 if code=='MATH102' and key[1]!='06':weeks=[]
 for week in weeks:
  excluded.update((start+dt.timedelta(days=(week-1)*7+i)).isoformat() for i in range(7))
 status='plannedRegularTimetable';reason='Current public clock/room, official term and closure policy; no claim of actual attendance.'
 if c['scheduleStatus']!='scheduled':
  status='publicTimeUnpublished' if c['scheduleStatus']=='unscheduled' else 'publishedClockRoomPairingUnresolved';reason='Actual source schedule retained; no clock/room pairing invented.'
 elif code in hold:
  status='individualOperatingUnresolved';reason=hold[code]
 elif code in vod:
  status='sourceVODWithoutRealtimeMeeting';reason='Current plan explicitly 100% VOD; official registration clock must be ignored.'
 dates=[]
 if status=='plannedRegularTimetable':
  for slot in source_slots:
   if code=='CHEB207' and slot['weekday']==2 and slot['startMinute']==1020:
    continue
   day=start
   while day<=end:
    ds=day.isoformat();week=(day-start).days//7+1
    valid=day.weekday()+1==slot['weekday'] and day.weekday()!=6 and ds not in closures and ds not in excluded
    if code=='SOSC419B':valid=valid and week<=7
    if code=='MECH280':valid=valid and week<=9
    if code=='MATH199':valid=valid and ds=='2026-09-10'
    if valid:dates.append(dict(slot,date=ds))
    day+=dt.timedelta(days=1)
  if code in ['SOSC419B','MECH280','MATH199']:
   status='plannedPartialTimetable';reason={'SOSC419B':'Only weeks1–7 explicit in-person; later VOD and separate exam not realtime clock.', 'MECH280':'Weeks1–9 normal posted slots; later A/B lab split/Break unresolved.', 'MATH199':'Only Sep10 introduction with actual posted Thursday clock; individual research/presentation clocks not invented.'}[code]
 c['schedules']=dates;c['scheduleStatus']='scheduled' if dates else ('unscheduled' if raw['scheduleStatus']=='unscheduled' or code in vod else 'unrecognized')
 if status!='plannedRegularTimetable':
  for d in c['departments']:c['departmentRemarks'][d]+='\n'+reason
 c['metadata']={'sourceDetailUrl':plan['sourceDetailUrl'],'sourcePlanUrl':plan['sourcePlanUrl'],'currentPlanHeader':plan['header'],
  'sourceOperatingSections':safe,'originalSourceSchedules':source_slots,'plannedTimetableDecision':status,'decisionReason':reason,
  'explicitNoClassDates':sorted(excluded),'excludedNoClassWeeks':weeks,'actualAttendanceConfirmed':False}
 audit.append({'code':code,'section':c['section'],'decision':status,'dateCount':len(dates),'reason':reason})
 out.append(c)
assert len(out)==418 and len({c['sourceId'] for c in out})==418
candidate={'schemaVersion':2,'universityId':'postech','campus':'main','academicYear':2026,'semester':'2',
 'publishedDate':'2026-10-08','publishedDateMeaning':'Public current list recheck; not an asserted administrative update timestamp',
 'sourceUrl':'https://plms.postech.ac.kr/local/ubion/course/lists.php?year=2026&semester=20&groupcode=U',
 'researchOnly':True,'actualAttendanceConfirmed':False,'courses':out}
fn='postech-main-2026-2.planned-audited-20261008-r1.json';data=(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n').encode();(ROOT/fn).write_bytes(data)
manifest={'researchOnly':True,'completionClaim':False,'file':fn,'sha256':hashlib.sha256(data).hexdigest(),'currentPublicOfferingCount':418,
 'scheduledCount':sum(bool(c['schedules']) for c in out),'dateCount':sum(len(c['schedules']) for c in out),
 'decisionCounts':dict(Counter(x['decision'] for x in audit)),'privacy':privacy,
 'regularTermEvidence':'Current2026-09-07 guideline defines class end as final-exam end; annual calendar Sep7 to Dec24',
 'sourceUrls':['https://www.postech.ac.kr/app/board/regulations/pdf/reg_3188.do','https://www.postech.ac.kr/app/board/regulations/pdf/reg_3194.do','https://www.postech.ac.kr/kor/college-life/academic_schedule.do?mode=list&selectedYear=2026&siteId=kor'],
 'closureDates':sorted(closures),'scopeRecheck':'postech-2026-2-current-scope-recheck-20261008.json',
 'cancellationBoundary':'Normal current public list exposes no cancellation status. No assertion of internal announcements completeness.',
 'sourceModes':'No source mode forced from room. All three user modes remain available for ordinary planned imports.',
 'reviews':audit}
(ROOT/'postech-planned-audited-20261008-r1-sha-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print({k:v for k,v in manifest.items() if k in ['sha256','scheduledCount','dateCount','decisionCounts','privacy']})
