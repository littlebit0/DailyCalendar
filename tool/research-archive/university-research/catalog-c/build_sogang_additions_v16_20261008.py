"""Current original educational plans only; literal week-date heads, no second-day inference."""
import copy, datetime as dt, hashlib, json, re
from pathlib import Path
from sogang_public_education import same_educational_value
R=Path(__file__).parent;O=R/'sogang-additions-v16-20261008';B=R/'sogang-additions-v15-20261008/sogang-unknown-2026-2.one-hundred-forty-nine-reviewed-20261008.json'
base=json.loads(B.read_text());out=copy.deepcopy(base);proofs=[];held=[]
configs={'CSE4022-01': (['10-21', '12-16'],
                None,
                '원문현재수요일15:00~20:50 연속350분예약범위 그대로;구간별휴게/실제강의배정미확인.10/21개인조사발표 중간대체 '
                'vsnative75분시험충돌·12/16최종보고서제출만 held. ANCHOR·Claude/DevOps 실습/팀데모조건.'),
 'ETU4001-01': ([],
                '10-20',
                '원문은 매주화요일날짜만직접명시하므로 목요일날짜추정없음. source/native10/20중간75분X426;12/15기말은 원문정확날짜+수업시간에실시 '
                '명시로정규75분범위보존. 현재첨부2026-2행/원문학기2·교육날짜 및토론/예습조건.'),
 'EUR3231-01': (['10-02', '10-09', '10-16', '10-21'],
                None,
                '원문매주수요일날짜만·월요일배정추정없음.14/15/16주원문10/2·9·16은native월수와다른금요일/기간충돌 held;12월로오타교정없음. '
                'source10/21중간 vsnative10/26시험날짜충돌 두날짜held. 독일문학사읽기·질의토론조건.'),
 'GIS1004-01': (['09-18', '09-25', '10-09', '11-20', '12-18'],
                '10-23',
                '현재GIS1004_01 원문분반별칭. 원문10/23 보강+시험 중native12:00~13:15 K406 정확시험75분만보존;보강개별시각/실 '
                '미배정held. regular10:30~13:15 GA402와구분.12/18보강+시험미배정held. '
                '국제학생전공한국어·자료사전준비/출결감점·녹음복제금지조건.'),
 'GIS2001-01': (['12-16'],
                '10-21',
                '원문수요일만명시 월요일추정없음. source10/21대면중간시험/native75분K304 실제1회 '
                'inPerson,regularK212와구분.12/16대면기말실제시각미공개held. 매주읽기·슬라이드예습/토론조건.'),
 'GIS2001-02': (['12-16'],
                '10-21',
                '원문수요일만명시 월요일추정없음. source10/21대면중간/native75분K305 '
                '실제1회inPerson.12/16기말실제시각미공개held.01분반12시와02분반13:30원문독립보존.'),
 'GIS2002-01': (['09-18', '09-25', '10-09', '11-20', '12-18'],
                '10-23',
                '현재회계학금10:30~13:15 K507. source/native10/23중간75분K507. 추석·한글날보강 날짜미배정·12/18기말시각미공개held. '
                '예습PPT·중간/기말리뷰세션·과제조건.'),
 'GME4004-01': (['09-22'],
                None,
                '원문화요일날짜만: 목요일추정없음(native10/22시험도원문날짜미확인held).9/22홍대/신촌 현장관찰학습 '
                '개별장소시각미배정held.10/20중간발표·12/15기말프로젝트발표 직접정규75분범위. UI/UX팀활동·개별피드백·자료예습조건.'),
 'HLU4006-01': (['09-24', '10-22', '10-29', '12-17'],
                None,
                '현재HLU4006-01 요가 원문110분·native체육관방음실 실기수업이용 장소 보존, '
                'campus미추정.9/10개강미사에도정상수업명시.10/22원문실기수업110 vsnative75시험충돌·10/29중간/12/17기말+보강 '
                '실제시험시각미확인held. 실기자세·과제·준비조건 실제대면실기.'),
 'HLU4014-01': (['10-05', '10-26', '12-21'],
                None,
                '원문학기2/월12~13:50/native운동장이용 실제장소와110분보존·campusunknown.10/5온라인동영상미배정,10/26실기중간 '
                'native시험실빈값·12/21실기기말미배정held. 실제조별실기/경기는inPerson. 우천변경·규칙과제조건.'),
 'HSS3002-01': (['09-18',
                 '09-25',
                 '10-09',
                 '10-23',
                 '10-30',
                 '11-06',
                 '11-13',
                 '11-20',
                 '11-27',
                 '12-04',
                 '12-18'],
                None,
                '원문자유선택교과(2)·1~4학년50명·SU. 공개수업110분 MA206 '
                '오리엔테이션/특강/10/16강의/12/11성찰나눔만.8~14·16주봉사는개인이요일/시간선택해실시 실제배정미공개held. '
                '사전승인·30시간/6일이상·9/4~12/18봉사인정·12/22결과제출기한조건;봉사전체시간지원주장없음.'),
 'HSS3005-01': (['10-20'],
                None,
                '원문현재26-2 수어화13:00~15:50(CU12) 실제15차시9/1~12/8명시,170분범위보존. '
                'header1::00표기는본문1:00와native13:00별도명시도직접확인.10/20원문수어강의170 vsnative75시험충돌 held. '
                '대상학년전체·한국수어시범·복습/출석·SU원문평가조건. 다른대학CU달력사용없음.'),
 'HSS3026-01': (['09-10', '09-24', '10-22', '12-03'],
                None,
                '현재2026-2 SOFEX native목17~19:50/source정확170분.9/3·17강의실대면inPerson.9/10개별온라인 vs9월대면원칙 '
                'source내부충돌held.10월이후공동수업은온라인공동강의17:00모임→주제강의/질의/소그룹토론→19:50성찰정리 시간표와camera/micON조건 명시 '
                'liveOnline.교환방문9/18~20/27년1/8~11 '
                '개별시각미배정held·기말기간추정없음.성찰과성장선수·사전선발·졸업직전협의·양교교류참여·자비항공조건.'),
 'KOR3204-01': (['09-18', '09-25', '10-09', '11-20'],
                '10-23',
                '현재2026-2금165분J217. source/native10/23중간75분J217.12/18과제계획피드백/기말과제제출 실제피드백정규범위165분 포함, '
                '별도시험미추정. 공휴일·축제·11/20휴강held. 문화문학읽기·개별발표조건.'),
 'KOR4504-01': (['09-18', '09-25', '10-09', '10-23', '10-31', '11-13', '11-20', '12-18'],
                None,
                '원문10/31토요일 vsnative금요일 충돌held,10/30으로교정없음.10/23자료수집/전시기획 '
                '중간대체·12/18도록제출실제시간미배정held.10/9·11/13사이버캠퍼스영상보강미배정. 실제발표/지정토론/현장피드백165분만. '
                '전시비평문·개별발표·1~50자료도록제출조건.')}
held_reasons={'EEE3150-01': 'Current original headerSaturday18:00–20:45 but all weekly explicit datesFriday; '
               'laboratory clock/date/room allocation unconfirmed. No Friday clock copied fromSaturday '
               'or weekday correction.',
 'HISG104-01': 'Source explicitlyHIS5104 graduate/HISG104 undergraduate cross-list valid, but '
               'original13:30–16:30 vsnative13:30–16:15 differs; whole actual clock conflict held.',
 'HLU4013-01': 'Actual original prints1학기, current2학기 native and September dates contradict source '
               'semester; no silent semester repair.',
 'HSS3025-01': 'Source header50minutes and native50minutes but operating policy expressly2시간1학점; actual '
               'operating duration inconsistent. Whole held pending original-source clarification, no '
               'dismissal as typo.',
 'HSS3031-01': 'Current attached original title2025학년도1학기, contradicts current2026-2 row. Field '
               'trips/online/PBL places not inferred; whole held.'}
for key,reason in held_reasons.items():
 s=json.loads((O/f'{key}.source-education.json').read_text());c=next(c for c in out['courses'] if c['courseCode']+'-'+c['section']==key);assert not c['schedules'];held.append({'offering':key,'reason':reason,'sourcePDFSHA256':s['fileSha256']})
head=re.compile(r'(?<!\d)(?:Week\s*\d+|\d+\s*(?:주[차자]|차시)|주차\s*\d+)(?!\d)',re.I)
for key,(excluded,exam_day,note) in configs.items():
 s=json.loads((O/f'{key}.source-education.json').read_text());row=s['currentPublicRow'];text=s['weeklyOperatingText'].replace('\x00',' ');c=next(c for c in out['courses'] if c['courseCode']+'-'+c['section']==key);assert not c['schedules'];assert all(same_educational_value(k,row.get(k,''),v) for k,v in c['sourceEducationalMetadata'].items())
 clock=re.search(r'(\d{2}):(\d{2})~(\d{2}):(\d{2})',row['meetingText']);start=int(clock[1])*60+int(clock[2]);end=int(clock[3])*60+int(clock[4]);room_match=re.search(r'\[([^\]]+)\]',row['meetingText']);room=room_match[1] if room_match else {'HLU4006-01':'체육관 방음실','HLU4014-01':'운동장'}[key];assert end-start in {50,75,110,165,170,350}
 markers=list(head.finditer(text));date_sources={};traces=[]
 for i,m in enumerate(markers):
  block=text[m.start():markers[i+1].start() if i+1<len(markers) else len(text)]
  dm=re.search(r'\(\s*(\d{1,2})\s*[/.]\s*(\d{1,2})\s*\)',block[:160])
  if not dm and key=='HSS3026-01' and '12주차' in block[:30]:dm=re.search(r'\(\s*(11)\s*/\s*(19)\s*\)',block)
  if not dm:continue
  date=dt.date(2026,int(dm[1]),int(dm[2]));date_sources[date.isoformat()]=block
 g=json.loads((O/f'{key}.date-geometry.json').read_text());assert g['sourcePDFSha256']==s['fileSha256'];assert g['educationalDateTokens']
 holds=[];plans=[];ex={'2026-'+x for x in excluded}|{'2026-09-24','2026-09-25','2026-10-05','2026-10-09','2026-11-20'}
 for ds,block in sorted(date_sources.items()):
  date=dt.date.fromisoformat(ds)
  if ds in ex:holds.append({'date':ds,'reason':note,'originalWeekBlock':block});continue
  assert dt.date(2026,9,1)<=date<=dt.date(2026,12,21),(key,ds)
  expectedweekday={'월':{1,3},'화':{2,4},'수':{3},'목':{4},'금':{5}}[row['meetingText'][0]];assert date.isoweekday() in expectedweekday,(key,ds)
  plan={'date':ds,'weekday':date.isoweekday(),'startMinute':start,'endMinute':end,'classroom':room}
  if exam_day and ds=='2026-'+exam_day:
   exam=re.fullmatch(r'(\d{2})\.(\d{2})\([^)]+\)(\d{2}):(\d{2})~(\d{2}):(\d{2})\[([^\]]+)\]',row['exam']);assert exam and ',' not in exam[7];assert ds==f'2026-{exam[1]}-{exam[2]}' and re.search(r'중간|Mid',block);plan.update(startMinute=int(exam[3])*60+int(exam[4]),endMinute=int(exam[5])*60+int(exam[6]),classroom=exam[7]);assert plan['endMinute']-plan['startMinute']==75
  if key in {'GIS2001-01','GIS2001-02'} and ds=='2026-10-21':
   assert '대면 중간시험' in block;plan['deliveryMode']='inPerson'
  if key in {'HLU4006-01','HLU4014-01'}:plan['deliveryMode']='inPerson'
  if key=='HSS3026-01':
   if ds in {'2026-09-03','2026-09-17'}:assert '강의실 대면' in block;plan['deliveryMode']='inPerson'
   else:assert '온라인 비대면' in block;plan['deliveryMode']='liveOnline'
  plans.append(plan);matches=[t for t in g['educationalDateTokens']+g.get('educationalVisualDateTokens',[]) if re.search(rf'0?{date.month}\s*[/.]\s*0?{date.day}(?!\d)',t['text'])];assert matches,(key,ds);traces.append({'date':ds,'numericHeaderToken':matches[0],'geometryFile':f'{key}.date-geometry.json','originalWeekBlock':block})
 assert plans,key
 c.update(schedules=plans,scheduleStatus='scheduled',partialSchedule=True,period={'startDate':plans[0]['date'],'endDate':plans[-1]['date']},scheduleEvidence={'basis':'currentPublicPlanPrintedDates','count':len(plans),'attendanceConfirmed':False})
 if key=='HSS3002-01':c['sourceNativeClassification']='자유선택교과'
 c['sourcePublishedReservationNote']='공개 시작·끝 연속 수업 예약범위 보존; 휴게·구간별 실제 운영 미확인. 원문에 한 요일의 날짜만 있으면 다른 요일을 추정하지 않음.'
 for dep in c['departmentRemarks']:c['departmentRemarks'][dep]+='\n'+note+'\n'+c['sourcePublishedReservationNote']
 proofs.append({'offering':key,'sourcePdfSHA256':s['fileSha256'],'holds':holds,'meetings':plans,'addedPlans':len(plans),'nativeClock':row['meetingText'],'actualExamDate':'2026-'+exam_day if exam_day else None,'sourceDateGeometry':traces,'operatingNote':note});print(key,len(plans))
changed=[a['courseCode']+'-'+a['section'] for a,b in zip(base['courses'],out['courses']) if a!=b];assert len(changed)==15
count=sum(len(c['schedules']) for c in out['courses']);scheduled=sum(bool(c['schedules']) for c in out['courses']);assert scheduled==164
f=O/'sogang-unknown-2026-2.one-hundred-sixty-four-reviewed-20261008.json';f.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
a={'baseFile':str(B),'baseSHA256':hashlib.sha256(B.read_bytes()).hexdigest(),'candidateFile':f.name,'candidateSHA256':hashlib.sha256(f.read_bytes()).hexdigest(),'whole':1541,'reviewedNativeOfferings':20,'previousScheduled':149,'previousPlans':3490,'addedScheduled':15,'addedPlans':count-3490,'scheduled':scheduled,'plans':count,'changedOnly':changed,'proofs':proofs,'reviewedStillHeld':held,'otherOfferingsAndSourceIdsUnchanged':True,'productionEdited':False,'completionClaim':False};(O/'additions-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print(scheduled,count)
