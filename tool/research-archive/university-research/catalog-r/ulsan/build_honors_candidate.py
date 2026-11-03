"""Native final public HWPX coordinates; no invented code/section/category."""
import collections,datetime as dt,hashlib,json,re,zipfile,xml.etree.ElementTree as E
from pathlib import Path
R=Path(__file__).parent;ns={'hp':'http://www.hancom.co.kr/hwpml/2011/paragraph'}
books=[]
for no in [345514,345515]:
 b=Path(f'/private/tmp/daily-ulsan-honors-{no}.hwpx').read_bytes();z=zipfile.ZipFile(__import__('io').BytesIO(b));root=E.fromstring(z.read('Contents/section0.xml'));head=E.fromstring(z.read('Contents/header.xml'));fills={}
 for x in head.iter():
  if x.tag.endswith('}borderFill'):
   fills[x.attrib['id']]=next((w.attrib.get('faceColor') for w in x.iter() if w.tag.endswith('}winBrush')),None)
 tables=[]
 for ti,t in enumerate(root.findall('.//hp:tbl',ns)):
  cells=[]
  for c in t.findall('./hp:tr/hp:tc',ns):
   a=c.find('hp:cellAddr',ns).attrib;sp=c.find('hp:cellSpan',ns).attrib;text=' '.join(''.join(x.itertext()) for x in c.findall('.//hp:t',ns)).strip();cells.append(dict(row=int(a['rowAddr']),column=int(a['colAddr']),rowSpan=int(sp['rowSpan']),columnSpan=int(sp['colSpan']),text=text,sourceFill=fills.get(c.attrib.get('borderFillIDRef'))))
  tables.append(dict(tableIndex=ti,rowCount=int(t.attrib['rowCnt']),columnCount=int(t.attrib['colCnt']),cells=cells))
 text='\n'.join(''.join(x.itertext()) for x in root.findall('.//hp:t',ns));books.append(dict(attachmentNumber=no,sourceUrl=f'https://honors.ulsan.ac.kr/boardDownload.do?no={no}',sourceSha256=hashlib.sha256(b).hexdigest(),sourceNativeText=text,tables=tables))
proof=dict(noticeUrl='https://honors.ulsan.ac.kr/honors/6289?action=view&no=279631',publishedNoticeDate='2026-07-16',reviewDate='2026-10-08',attachments=books,productionChange=False)
(R/'ulsan-honors-current-native-education-proof-v1.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n')
groups=collections.defaultdict(list)
for table in books[1]['tables']:
 grid={(rr,cc):c for c in table['cells'] for rr in range(c['row'],c['row']+c['rowSpan']) for cc in range(c['column'],c['column']+c['columnSpan'])}
 assert table['columnCount']==10 and table['rowCount']==12
 for col in range(1,10):
  assert grid[(0,col)]['text']==str(col);assert grid[(1,col)]['text']==f'{8+col:02d}:00~{8+col:02d}:50'
 for row in range(2,12,2):
  day='월화수목금'.index(grid[(row,0)]['text'])+1
  for col in range(1,10):
   c=grid[(row,col)];raw=c['text']
   if not raw:continue
   m=re.fullmatch(r'(.*?)\((\d{2})\)',raw);title=m[1].strip() if m else raw;section=m[2] if m else ''
   profraw=grid[(row+1,col)]['text'];rooms=re.findall(r'5-\d{3}',profraw);prof=re.sub(r'5-\d{3}|[()]','',profraw).strip()
   groups[(title,section)].append(dict(tableIndex=table['tableIndex'],row=row,column=col,nativeCourseCell=c,nativeProfessorRoomCell=grid[(row+1,col)],weekday=day,startMinute=(8+col)*60,endMinute=(8+col)*60+50,classroom=rooms[0] if len(set(rooms))==1 else '',professor=prof))
notes='공개 예약 계획, 실제 등교·집중이수/온라인 운영 날짜 미확인. 현재 공개 2026-2 자율전공학부 학년별 시간표(최종)의 실제 표 위치·과목명·분반·교수·강의실·교시를 보존합니다. 과목코드는 미공개이며 임의 코드를 만들지 않았습니다. 내부 식별자는 공개 문서·표 위치로 구분하며 공식 강좌번호가 아닙니다. 학점과 개별 이수구분도 확인되지 않은 칸은 비워 둡니다. 색상 범례는 원문 보존하며 개별 이수구분을 추측하지 않습니다. 7월 공지 이후 전체 폐강·변경은 미확인입니다. 방식은 미지정으로 사용자의 선택을 유지합니다. 공식 9월 1일 개강부터 대체수업주 전 12월 7일까지 일반 예약을 생성하되 중간고사10월20~26일과 공휴일은 제외합니다. 대체수업12월8~14일/기말15~21일의 개별 일정은 만들지 않습니다. 12월21일 학기 경계는 공식12월22일겨울방학 전날을 사용했으며 인쇄된 종강일은 아닙니다.'
cs=[];held=collections.Counter()
for (title,section),native in groups.items():
 first=native[0];sid=f"ulsan/main/2026-2/honors-345515-t{first['tableIndex']}-r{first['row']}-c{first['column']}";reason='';spans=[]
 if title=='트랙 탐색 및 진로 설정' and section=='01':reason='동시 공개 통합표5-205 / 학년별 최종표5-201 강의실 불일치'
 elif any(not x['classroom'] or not x['professor'] for x in native):reason='원문 교수·강의실 대응 미확인'
 # Different duplicated page group assertions can be distinct room/prof teaching
 # sections. Preserve them as evidence and hold conflict rather than merging.
 elif len({x['professor'] for x in native})!=1:reason='같은 제목·원문 분반 교수 불일치'
 elif len({(x['weekday'],x['startMinute']) for x in native})!=len({(x['weekday'],x['startMinute'],x['classroom']) for x in native}):reason='같은 제목·원문 분반 동일 시각 강의실 불일치'
 else:
  seen=set()
  for x in native:
   key=(x['weekday'],x['startMinute'],x['endMinute'],x['classroom'])
   if key not in seen:spans.append(dict(weekday=x['weekday'],startMinute=x['startMinute'],endMinute=x['endMinute'],classroom=x['classroom']));seen.add(key)
 appointments=[]
 if not reason:
  d=dt.date(2026,9,1)
  while d<=dt.date(2026,12,7):
   if not(dt.date(2026,10,20)<=d<=dt.date(2026,10,26)) and d.isoformat() not in ['2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09']:
    appointments += [dict(s,date=d.isoformat()) for s in spans if s['weekday']==d.isoweekday()]
   d+=dt.timedelta(days=1)
 else:held[reason]+=1
 cs.append(dict(sourceId=sid,campus='main',academicYear=2026,semester='2',courseCode='',courseName=title,section=section,professor=first['professor'],classification='',credits=None,departments=['자율전공학부'],departmentCredits={},departmentClassifications={},sourceSchedule=' / '.join(f"표{x['tableIndex']+1}: {'월화수목금'[x['weekday']-1]}{x['column']}" for x in native),sourceClassroom=' / '.join(dict.fromkeys(x['classroom'] for x in native if x['classroom'])),remarks=notes+(' 원문 분반도 미공개입니다.' if not section else '')+(' 예약 보류: '+reason if reason else ''),scheduleStatus='scheduled' if appointments else 'unrecognized',schedules=appointments,period=dict(startDate='2026-09-01',endDate='2026-12-21'),metadata=dict(originalEducationalCells=native,sourceCodePublished=False,nativeSection=section,sourceSectionPublished=bool(section),referenceKind='publishedCourseTitle',internalIdKind='source-document-native-cell-position',sourceClassificationPublished=False,sourceCreditsPublished=False,sourceNativeTitle=title,physicalCampusScope='Official honors footer 대학로93·산학협력리더스홀5호관 matches native5-xxx rooms',researchOnly=True,actualAttendanceConfirmed=False,actualPhysicalDatesConfirmed=False,currentWholeClosureVerified=False,deliveryModeStatus='unknown-user-choice',heldReason=reason)))
data=dict(schemaVersion=2,universityId='ulsan',campus='main',campusName='대학로93·5호관',academicYear=2026,semester='2',publishedDate='2026-07-16',sourceUrl=proof['noticeUrl'],researchOnly=True,completionClaim=False,courses=cs)
(R/'ulsan-main-2026-2.reservation-planned-v1.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');print(json.dumps(dict(rows=len(cs),scheduled=sum(bool(c['schedules']) for c in cs),appointments=sum(len(c['schedules']) for c in cs),held=held),ensure_ascii=False))
