"""Parse the public Guest's actual 2026-2 undergraduate rows; never invent clocks."""
import collections, hashlib, json, pathlib, re
P = pathlib.Path(__file__).parent
source = json.loads((P/'hansei-guest-dom.json').read_text())
clock_source = json.loads((P/'hansei-guest-clock.json').read_text())
clocks = {float(k):int(v[:2])*60+int(v[3:]) for k,v in clock_source['rows'].items()}
# Current native course plan 15903-001 explicitly prints 8교시(16:00).
clocks[8.0] = 960
term = {'startDate':'2026-09-01','endDate':'2026-12-21'}
calendar_url = 'https://hansei.ac.kr/view.do?no=10302&dateY=2026&dateM=0&tab=lst'
graduate_url = 'https://graduate.hansei.ac.kr/view.do?no=2041&pgMode=show&pstSn=30650'
# Same current-semester undergraduate/graduate linked courses: exact native HH:MM,
# weekday, professor and room agree; no inferred correction for other 8-period rows.
linked = {
 ('음악과성악작품의이해Ⅱ','김정훈','화7 ,7.5 ,8 ,8.5(음113)'): [{'weekday':2,'startMinute':900,'endMinute':1020,'classroom':'음113'}],
 ('오페라클래스Ⅱ','이성우','목7 ,7.5 ,8 ,8.5(음113)'): [{'weekday':4,'startMinute':900,'endMinute':1020,'classroom':'음113'}],
}
rows = [row for faculty in source['faculties'] for row in faculty['rows']]
courses=[]
for row in rows:
 code,section = row['CRCL_NO'],row['SPRC_NO']
 raw = row['CLS_INFO']; remarks=row.get('ETBL_SPRC_RMRK','').strip()
 dept=row['ORGNZ_KOR_NM'].strip(); classification=row['CRCL_FNCS_NM'].strip()
 reasons=[]; meetings=[]; room_labels=[]
 # Undergraduate handbook explicitly defines consortium and IP credit exchange
 # as online study. Published Saturday slots must not become weekly classes.
 if re.search('사이버|컨소시엄|특허청 학점교류',remarks):
  reasons.append('공식 비고/수강편람상 원격수업 또는 온라인 학점교류: 주간 고정 수업시각 미확인')
 if '집중이수' in remarks:
  reasons.append('집중이수 운영 주차 표시가 있으나 실제 날짜별 강의계획 미확인')
 if '장기현장실습' in row['CRCL_NM']:
  reasons.append('현장기관의 14주/560시간 별도 운영: 일요일 배정 교시를 주간 수업으로 간주할 수 없음')
 segments = list(re.finditer(r'([월화수목금토일])\s*([0-9.,\s]+)\(([^()]*)\)',raw))
 remainder = re.sub(r'([월화수목금토일])\s*([0-9.,\s]+)\(([^()]*)\)','',raw).strip(' ,')
 if remainder or not segments: reasons.append('학교 원문 시간/강의실 문법을 명확히 해석할 수 없음')
 for segment in segments:
  weekday = '월화수목금토일'.index(segment[1])+1
  periods = [float(n.strip()) for n in segment[2].split(',') if n.strip()]
  room = segment[3].strip();room_labels.append(room)
  if room=='미배정' or not room: reasons.append('실제 강의실 미배정')
  if any(p not in clocks for p in periods): reasons.append('공식 교시확인표 밖의 교시')
  if not reasons:
   blocks=[]
   for period in periods:
    if blocks and period-blocks[-1][-1] == .5:
     blocks[-1].append(period)
    else:
     blocks.append([period])
   for block in blocks:
    start=clocks[block[0]];end=clocks[block[-1]]+30
    meetings.append({'weekday':weekday,'startMinute':start,'endMinute':end,'classroom':room})
 key=(row['CRCL_NM'],row['EDPS_NM'],raw)
 if key in linked and all('8/8.5' in reason for reason in reasons):
  reasons=[];meetings=linked[key]
 if reasons:meetings=[]
 c={'sourceId':f'hansei/main/2026/2/{code}/{section}','universityId':'hansei','campus':'main','academicYear':2026,'semester':'2',
    'courseCode':code,'courseName':row['CRCL_NM'],'section':section,'professor':row['EDPS_NM'],
    'credits':float(row['CRCL_CRDT']),'classification':classification,'departments':[dept] if dept else [],
    'departmentCredits':{dept:float(row['CRCL_CRDT'])} if dept else {},'departmentClassifications':{dept:classification} if dept else {},
    'departmentRemarks':{dept:remarks} if dept and remarks else {},'schedules':meetings,'period':term,
    'sourceSchedule':raw,'sourceClassroom':' / '.join(dict.fromkeys(room_labels)),'sourceEducation':row,
    'scheduleStatus':'unrecognized' if reasons else 'scheduled','remarks':remarks,
    'holdReasons':list(dict.fromkeys(reasons))}
 if key in linked and not reasons:
  c['nativeClockEvidence']={'sourceUrl':graduate_url,'attachmentFileSn':'24416','pdfPage':45,'scope':'2026-2 학석사연계 동일 과목/교수/요일/강의실 표기'}
 courses.append(c)
out={'schemaVersion':2,'universityId':'hansei','institutionId':'institution:academyinfo:0000201','campus':'main','campusName':'본교',
     'academicYear':2026,'semester':'2','sourceUrl':source['sourceUrl'],'retrievedDate':'2026-10-12','observedDate':'2026-10-12','publishedDate':'','publishedDateUnavailable':True,
     'dateBasis':'official Guest current semester source retrieval date; publication date unconfirmed',
     'clockCorrectionEvidence':{'courseCode':'15903','section':'001','field':'강의시간','nativeText':'월요일6교시(14:00),6.5교시(14:30),7교시(15:00),7.5교시(15:30),8교시(16:00),8.5교시(16:30)(이202)','sourceView':'Guest > IT학부 > 컴퓨터개론 > 강의계획서','sourceUrl':source['sourceUrl']},
     'periodSourceUrl':source['sourceUrl'],'termPeriodEvidence':{'start':term['startDate'],'endInclusive':term['endDate'],'sourceUrl':calendar_url},
     'sourceRowCount':len(rows),'courseScheduleStatusCounts':dict(collections.Counter(c['scheduleStatus']for c in courses)),
     'sourceHashes':{name:hashlib.sha256((P/name).read_bytes()).hexdigest()for name in ['hansei-guest-dom.json','hansei-guest-clock.json','hansei-guest-plan-clock.json','hansei-calendar-list.html','hansei-fall-guide.pdf','hansei-graduate-fall-guide.pdf']},
     'courses':courses,'completionClaim':False}
(P/'hansei-main-2026-2.candidate.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
print(out['courseScheduleStatusCounts'])
