"""Current twenty-offering review; literal dates and original numerical table words."""
import copy, datetime as dt, hashlib, json, re
from pathlib import Path
from sogang_public_education import same_educational_value
R=Path(__file__).parent
O=R/'sogang-additions-v14-20261008'
B=R/'sogang-additions-v13-20261008/sogang-unknown-2026-2.one-hundred-twenty-six-reviewed-20261008.json'
base=json.loads(B.read_text());out=copy.deepcopy(base);proofs=[];held=[]
configs={'SOC3011-01': (['09-24', '10-13', '10-15', '10-27', '12-08', '12-10', '12-17'],
                '현재Fall2026(Semester2)/SOC3011/TuThu16:30–17:45.9/24NoClass,10/13/15·12/8/10AssignedFieldwork/consultation '
                '실제현장시간·장소미확인 및10/27OpenClass출석운영미확인 보류.12/17finalclock미공개보류. '
                'source/native10/22중간75분D5041회와12/15FinalExamReview정규수업 포함. Requiredreading·현장실습조건 및정규교실D504보존.'),
 'STS2004-01': (['10-05', '12-21'],
                '현재2026-2/STS2004/월수10:30~11:45/전학년(1학년권장). 자연과학부·공학부제외학생대상 및선수고교수학I/II조건보존. '
                'pypdfCourseSchedule표제가1~4주뒤에나타난추출순서 원본날짜좌표와앞선교육표로독립대조. '
                'source/native10/26D402중간75분1,12/21finalclock미공개보류.10/5공휴일. 사캠공지확인·진도변경조건.'),
 'STS2004-05': (['09-22', '09-24', '10-20', '12-10', '12-15', '12-17'],
                '현재STS2004-05/화목13:30~14:45 전학년.4주추석연휴온라인운영시각미공개로22퀴즈/24두날짜보류. '
                'source/native10/22RA410중간75분1,10/20NoClass. source16주기말12/10표시 '
                'vs15주12/10정규주제충돌보류,15/17기말기간수업없음.11/17퀴즈 등실제일반강의날짜만.'),
 'STS2006-07': (['09-22', '09-24', '10-22', '12-10', '12-15', '12-17'],
                '현재2026-2/STS2006-07/화목15~16:15/전학년(1권장).4주온라인추석수업·퀴즈 시각/운영조건미확인두날짜held. source/native10/20중간75분J102: '
                'regularRA410과별도시험실 명시근거만1회.10/22NoClass. source16주final12/10 vs15주정규12/10충돌 및15/17NoClass보류. '
                '영상들은수업전선택학습이며VOD시간추정없음. 선수·좌석·부정행위·모바일금지조건보존.'),
 'STS2006-08': (['10-05', '12-21'],
                '현재2026-2/STS2006/월수16:30~17:45/전학년(1권장),선수미적분학I. 원본날짜좌표와표제앞1~2주교육표로9/2·7·9·14보존. '
                'source/native10/26K501중간75분1, regularK502와별도시험실.10/5공휴일,12/21finalclock미공개held. 사캠공지확인·진도변경조건보존.'),
 'STS2022-01': (['09-18', '09-25', '10-09', '11-20'],
                '현재2026-2/STS2022/수금09:00~10:15/학부전공무관1~4. nativePDF구분전공선택 원문별도보존 '
                'broad추정없음.9/18festival운영미확인·9/25/10/9공휴일·11/20교내휴강held. '
                '원문8주10/21/23MVP라이브시연·동료평가,16주12/16/18DemoDay프로젝트발표 실제정규75분범위. 개별팀시연순서미배정이고 별도시험추정없음. '
                '매주실습환경지참·3~4인팀참여·AI활용내역/작동검증책임조건.'),
 'HFS2002-02': (['10-05', '10-21', '10-26', '12-16', '12-21'],
                '현재nativeHFS2002-02/월수09:00–10:15/전학년. 원본32개날짜숫자좌표로9/2와9/7 '
                '등붙은추출을독립확인.10/5대체휴일NoClass,중간21/26·기말16/21추후공지조건held.15주12/9조별발표·12/14전체토론 '
                '실제날짜유지.자료읽기·토론결과제출/개인2쪽과제조건보존.')}
held_reasons={'BIO1106-01': 'Current2026-2 laboratory weekly ranges and public-holiday same-week rescheduling unallocated; '
               'nativeK213 vs sourceK213A, generic19:45 vs section-table19:15 and odd/even13:30–18:00 special '
               'experiments differ. Source exams Sat@10am/dateblank vs nativeOct17Sat16:00–17:30/two rooms unresolved. '
               'No laboratory dates/clocks/campus inferred.',
 'BIO1106-02': 'Current2026-2 laboratory weekly ranges and public-holiday same-week rescheduling unallocated; '
               'nativeK213 vs sourceK213A, generic19:45 vs section-table19:15 and odd/even13:30–18:00 special '
               'experiments differ. Source exams Sat@10am/dateblank vs nativeOct17Sat16:00–17:30/two rooms unresolved. '
               'No laboratory dates/clocks/campus inferred.',
 'BIO1106-03': 'Current published PDF calendar explicitly Sep2016, unrevised legacy operating document; no current2026 '
               'dates inferred.',
 'BIO1106-04': 'Current2026-2 laboratory weekly ranges and public-holiday same-week rescheduling unallocated; '
               'nativeK213 vs sourceK213A, generic19:45 vs section-table19:15 and odd/even13:30–18:00 special '
               'experiments differ. Source exams Sat@10am/dateblank vs nativeOct17Sat16:00–17:30/two rooms unresolved. '
               'No laboratory dates/clocks/campus inferred.',
 'BIO1106-05': 'Current2026-2 laboratory weekly ranges and public-holiday same-week rescheduling unallocated; '
               'nativeK213 vs sourceK213A, generic19:45 vs section-table19:15 and odd/even13:30–18:00 special '
               'experiments differ. Source exams Sat@10am/dateblank vs nativeOct17Sat16:00–17:30/two rooms unresolved. '
               'No laboratory dates/clocks/campus inferred.',
 'BIO1106-06': 'Current2026-2 laboratory weekly ranges and public-holiday same-week rescheduling unallocated; '
               'nativeK213 vs sourceK213A, generic19:45 vs section-table19:15 and odd/even13:30–18:00 special '
               'experiments differ. Source exams Sat@10am/dateblank vs nativeOct17Sat16:00–17:30/two rooms unresolved. '
               'No laboratory dates/clocks/campus inferred.',
 'BIO1106-07': 'Current2026-2 laboratory weekly ranges and public-holiday same-week rescheduling unallocated; '
               'nativeK213 vs sourceK213A, generic19:45 vs section-table19:15 and odd/even13:30–18:00 special '
               'experiments differ. Source exams Sat@10am/dateblank vs nativeOct17Sat16:00–17:30/two rooms unresolved. '
               'No laboratory dates/clocks/campus inferred.',
 'BIO1106-08': 'Current2026-2 laboratory weekly ranges and public-holiday same-week rescheduling unallocated; '
               'nativeK213 vs sourceK213A, generic19:45 vs section-table19:15 and odd/even13:30–18:00 special '
               'experiments differ. Source exams Sat@10am/dateblank vs nativeOct17Sat16:00–17:30/two rooms unresolved. '
               'No laboratory dates/clocks/campus inferred.',
 'BIO1106-09': 'Current2026-2 laboratory weekly ranges and public-holiday same-week rescheduling unallocated; '
               'nativeK213 vs sourceK213A, generic19:45 vs section-table19:15 and odd/even13:30–18:00 special '
               'experiments differ. Source exams Sat@10am/dateblank vs nativeOct17Sat16:00–17:30/two rooms unresolved. '
               'No laboratory dates/clocks/campus inferred.',
 'BIO1106-10': 'Current2026-2 laboratory weekly ranges and public-holiday same-week rescheduling unallocated; '
               'nativeK213 vs sourceK213A, generic19:45 vs section-table19:15 and odd/even13:30–18:00 special '
               'experiments differ. Source exams Sat@10am/dateblank vs nativeOct17Sat16:00–17:30/two rooms unresolved. '
               'No laboratory dates/clocks/campus inferred.',
 'MGT3001-01': 'All regular source weeks 온라인강의; live/recorded delivery and exact timing unallocated. Mid/final '
               'in-person two-day and two-room allocation unknown; all held.',
 'STS2005-01': 'Original source clock16:30–15:45 conflicts actual public16:30–17:45; no inferred typo correction.',
 'HFS2002-03': 'Printed source09:00–10:15 conflicts native10:30–11:45; section02 clock never copied/corrected for03.'}
for key,reason in held_reasons.items():
 s=json.loads((O/f'{key}.source-education.json').read_text());c=next(c for c in out['courses'] if c['courseCode']+'-'+c['section']==key);assert not c['schedules'];held.append({'offering':key,'reason':reason,'sourcePDFSHA256':s['fileSha256']})
geometry_keys={'HFS2002-02','STS2004-01','STS2006-08'}
for key,(excluded,note) in configs.items():
 s=json.loads((O/f'{key}.source-education.json').read_text());row=s['currentPublicRow'];text=(s['weeklyOperatingText']+'\n'+s.get('originalWeeklyPrefixEducationText','')).replace('\x00',' ');c=next(c for c in out['courses'] if c['courseCode']+'-'+c['section']==key);assert not c['schedules'];assert all(same_educational_value(k,row.get(k,''),v) for k,v in c['sourceEducationalMetadata'].items())
 clock=re.search(r'(\d{2}):(\d{2})~(\d{2}):(\d{2})',row['meetingText']);start=int(clock[1])*60+int(clock[2]);end=int(clock[3])*60+int(clock[4]);room_match=re.search(r'\[([^\]]+)\]',row['meetingText']);room=room_match[1] if room_match else '';assert end-start==75
 traces=[];date_sources={}
 if key in geometry_keys:
  g=json.loads((O/f'{key}.date-geometry.json').read_text());assert g['sourcePDFSha256']==s['fileSha256'];items=[(x['text'],x) for x in g['educationalDateTokens']]

 else:items=[(text,None)]
 for value,token in items:
  for match in re.finditer(r'(\d{1,2})\s*[/.]\s*(\d{1,2})(?!\d)(?:,\s*(\d{1,2})(?![/.\d]))?',value):
   month=int(match[1]);days=[int(match[2])]+([int(match[3])] if match[3] else [])
   if month not in {9,10,11,12}:continue
   for day in days:
    date=dt.date(2026,month,day);ds=date.isoformat();date_sources[ds]=True
    if token:traces.append({'date':ds,'numericHeaderToken':token,'geometryFile':f'{key}.date-geometry.json'})
 allowed=None
 holds=[];plans=[];weekdays={1,3} if key in {'HFS2002-02','STS2004-01','STS2006-08'} else ({3,5} if key=='STS2022-01' else {2,4});ex={'2026-'+x for x in excluded}|{'2026-09-24','2026-09-25','2026-10-05','2026-10-09','2026-11-20'}
 for ds in sorted(date_sources):
  date=dt.date.fromisoformat(ds)
  if ds in ex or (allowed is not None and ds not in allowed):holds.append({'date':ds,'reason':note});continue
  assert date.isoweekday() in weekdays and dt.date(2026,9,1)<=date<=dt.date(2026,12,21),(key,ds)
  plan={'date':ds,'weekday':date.isoweekday(),'startMinute':start,'endMinute':end,'classroom':room}
  exam_date={'SOC3011-01':'2026-10-22','STS2004-01':'2026-10-26','STS2004-05':'2026-10-22','STS2006-07':'2026-10-20','STS2006-08':'2026-10-26'}.get(key)
  if ds==exam_date:
   exam=re.fullmatch(r'(\d{2})\.(\d{2})\([^)]+\)(\d{2}):(\d{2})~(\d{2}):(\d{2})\[([^\]]+)\]',row['exam']);assert exam and ',' not in exam[7];assert int(exam[3])*60+int(exam[4])==start and int(exam[5])*60+int(exam[6])==end;assert ds==f'2026-{exam[1]}-{exam[2]}';plan['classroom']=exam[7]
  plans.append(plan)
 assert plans,key
 c.update(schedules=plans,scheduleStatus='scheduled',partialSchedule=True,period={'startDate':plans[0]['date'],'endDate':plans[-1]['date']},scheduleEvidence={'basis':'currentPublicPlanPrintedDates','count':len(plans),'attendanceConfirmed':False})
 if key=='STS2022-01':c['sourceNativeClassification']='전공선택'
 for dep in c['departmentRemarks']:c['departmentRemarks'][dep]+='\n'+note
 proofs.append({'offering':key,'sourcePdfSHA256':s['fileSha256'],'holds':holds,'meetings':plans,'addedPlans':len(plans),'nativeClock':row['meetingText'],'sourceDateGeometry':traces,'operatingNote':note});print(key,len(plans))
changed=[a['courseCode']+'-'+a['section'] for a,b in zip(base['courses'],out['courses']) if a!=b];assert len(changed)==7
count=sum(len(c['schedules']) for c in out['courses']);scheduled=sum(bool(c['schedules']) for c in out['courses']);assert scheduled==133
f=O/'sogang-unknown-2026-2.one-hundred-thirty-three-reviewed-20261008.json';f.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
a={'baseFile':str(B),'baseSHA256':hashlib.sha256(B.read_bytes()).hexdigest(),'candidateFile':f.name,'candidateSHA256':hashlib.sha256(f.read_bytes()).hexdigest(),'whole':1541,'reviewedNativeOfferings':20,'previousScheduled':126,'previousPlans':3117,'addedScheduled':7,'addedPlans':count-3117,'scheduled':scheduled,'plans':count,'changedOnly':changed,'proofs':proofs,'reviewedStillHeld':held,'otherOfferingsAndSourceIdsUnchanged':True,'productionEdited':False,'completionClaim':False};(O/'additions-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print(scheduled,count)
