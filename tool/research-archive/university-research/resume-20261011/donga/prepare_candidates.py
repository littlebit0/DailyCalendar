# -*- coding: utf-8 -*-
import json,pathlib,hashlib,copy,datetime
P=pathlib.Path('work/university-research/resume-20261011/donga')
inputs=json.loads(pathlib.Path('work/university-research/resume-batch-20261010/source-inputs.json').read_text());cur={};sources=[]
for x in inputs:
 if 'assets/timetable/donga-' not in x['target']:continue
 p=pathlib.Path(x['target']);d=json.loads(p.read_text());cur.update({c['sourceId']:c for c in d['courses']});s=json.loads(pathlib.Path(x['source']).read_text());sm={c['sourceId']:c for c in s['courses']};tm={c['sourceId']:c for c in d['courses']}
 sources.append({'asset':str(p),'assetSHA256':hashlib.sha256(p.read_bytes()).hexdigest(),'source':x['source'],'sourceSHA256':hashlib.sha256(pathlib.Path(x['source']).read_bytes()).hexdigest(),'heldRows':sum(not c.get('schedules') for c in d['courses']),'lostPreparedSchedules':[sid for sid,c in sm.items() if c.get('schedules') and not tm[sid].get('schedules')]})
guide=pathlib.Path('work/university-research/catalog-e/donga-2026-sem2-guide.txt');text=guide.read_text();calendarText=text[text.index('[ 2026학년도 제2학기 보강기간 안내 ]'):text.index('- 2 -')]
raw=pathlib.Path('work/university-research/catalog-c/donga-current-20261008/public-education-37448.json');rawSHA=hashlib.sha256(raw.read_bytes()).hexdigest();weeks=[]
for w in range(1,15):
 a=datetime.date(2026,9,1)+datetime.timedelta(days=7*(w-1));weeks.append({'week':w,'startDate':str(a),'endDate':str(a+datetime.timedelta(days=6))})
calendar={'sourceUrl':'https://www.donga.ac.kr/attach/CONTENTS/PDF/ContentMgr/PDFViewer/2026/9/ca9ab32162b54ff484d1ac7ccda6a571.PDF','sourceTextFile':str(guide),'sourceTextSHA256':hashlib.sha256(guide.read_bytes()).hexdigest(),'printedPage':2,'nativeCalendarText':calendarText,'nativeWeekRanges':weeks,'interpretation':'Own printed week mapping used directly, not generic semester week assumption. No makeup dates inferred for these partial week groups.'}
(P/'own-calendar-education.json').write_text(json.dumps(calendar,ensure_ascii=False,indent=2)+'\n')
holidays={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'};midterm={str(datetime.date(2026,10,20)+datetime.timedelta(days=i)) for i in range(7)}
configs=[('01HMC407',range(1,11),[3,4],990,1080),('01HMC301',range(1,6),[1],810,990),('01HEM403',range(1,15),[5],540,720)];candidates=[]
for code,allowedWeeks,days,start,end in configs:
 old=cur['donga-2026-2-'+code+'-01'];plans=[];included=[];excluded=[]
 for w in allowedWeeks:
  a=datetime.date.fromisoformat(weeks[w-1]['startDate'])
  for wd in days:
   d=a+datetime.timedelta(days=(wd-a.isoweekday())%7)
   if str(d) in holidays or str(d) in midterm:
    excluded.append({'week':w,'date':str(d),'reason':'Published public holiday' if str(d) in holidays else 'Own published midterm period; class-specific normal instruction not confirmed'});continue
   if code=='01HMC407':room='S17-0106' if wd==3 else 'S09-0203'
   elif code=='01HMC301':room='S07-0413'
   elif w==1:room='S06-0207-1'
   elif w in [2,3,4,5,8,9,12,15]:room='S22-0102'
   else:room='S06-0205'
   plans.append({'date':str(d),'weekday':wd,'startMinute':start,'endMinute':end,'classroom':room});included.append({'week':w,'date':str(d),'weekday':wd,'room':room})
 new=copy.deepcopy(old);new['schedules']=plans;new['scheduleStatus']='scheduled';new['sourcePartialCoverage']=True
 note='원문 자체 주차·요일·직접시각·승학 강의실이 일치하는 부분 예약만 복원했습니다. 원문 예약창은 휴식 포함 가능하며 실제 연속 수업분량 확인을 뜻하지 않습니다.75분으로 임의 단축하지 않습니다. 공휴일·중간시험·별도 보강·미확정 집중 운영·기말기간은 추가하지 않았습니다. 남은 원자료와 교수 담당주차는 그대로 보존합니다.'
 new['reservationProof']={'kind':'directPublishedReservationWindow','sourcePartialCoverage':True,'actualInstructionMinutesConfirmed':False,'actualAttendanceConfirmed':False,'restMayBeIncluded':True,'modeOverrideApplied':False,'sourceRows':[{'sheet':r['sheet'],'row':r['row']} for r in old['publicEducationRows']],'calendarSourceFile':str(P/'own-calendar-education.json'),'retainedWeeks':list(allowedWeeks)}
 new['remarks']=old.get('remarks','').split('; 일정 미생성:')[0]+'; '+note
 new['departmentRemarks']={k:v.split('; 일정 미생성:')[0]+'; '+note for k,v in old['departmentRemarks'].items()}
 candidates.append({'sourceId':old['sourceId'],'asset':'assets/timetable/donga-seunghak-2026-2.json','originalWholeObject':old,'proposedWholeObject':new,'sourceRows':old['publicEducationRows'],'sourceEducationFile':str(raw),'sourceEducationSHA256':rawSHA,'sourceUrl':json.loads(raw.read_text())['url'],'originalWorkbookSHA256':json.loads(raw.read_text())['originalSha256'],'calendarProof':calendar,'includedGroups':included,'excludedGroups':excluded,'newMeetings':len(plans),'heldRemaining':'No external/intensive or makeup groups restored; published partial operation only. Original schedules were empty. Native period blocks left unchanged and not used for instruction-minute calculation.'})
(P/'partial-clock-candidates.json').write_text(json.dumps(candidates,ensure_ascii=False,indent=2)+'\n')
receipt={'sourceOnly':True,'productOrSharedFileChanges':False,'SDKTestsBuildsVerificationRuns':0,'completionClaim':False,'inputAssets':sources,'currentNativeCourses':len(cur),'heldTotal':sum(not c.get('schedules') for c in cur.values()),'candidateCourses':len(candidates),'candidateMeetings':sum(c['newMeetings'] for c in candidates),'lostPreparedSchedules':0,'roomOnlyOmissions':0,'excludedBoundary':'Unknown42 include Dongseo external operation and online/CELL sources;13Seunghak hold rows include6theory-single-day75minute contradictions,3explicit-week partial candidates and4other unresolved allocations. HEM407 mixed operation contains inconsistent published week6 LMS allocation and remains held. No online/BL guessing.','pendingAcceptance':'Parent integration plus combined verification required. Candidates preserve original full objects; no whole university completion.'}
(P/'receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'candidates':[(c['sourceId'],c['newMeetings']) for c in candidates],'heldTotal':receipt['heldTotal']},ensure_ascii=False))
