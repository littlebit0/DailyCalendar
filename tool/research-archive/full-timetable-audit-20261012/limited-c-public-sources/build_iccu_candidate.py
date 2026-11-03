import json,pathlib,re,hashlib,collections,copy
p=pathlib.Path('work/full-timetable-audit-20261012/limited-c-public-sources'); rows=json.load(open(p/'iccu-native-offering-rows.json'));old=json.load(open('assets/timetable/iccu-songdo-2026-2.json'))
url='https://www.iccu.ac.kr/bbs/download.php?bo_table=notice_b&wr_id=851&no=0'
closed={('00684','01'),('01115','01'),('00242','01'),('01279','01'),('01281','01'),('01289','01'),('32032','01')}
closedNames={'실크스크린과Printing2','미디어아트프로그래밍','국제보건간호','문제탐구와실천','유럽사로읽는오늘의세계','윤리적사고와현대사회','사회봉사2'}
periods={'15주':('2026-09-01','2026-12-14'),'8주(1)':('2026-09-01','2026-10-26'),'8주(2)':('2026-10-27','2026-12-21'),'9주':('2026-10-20','2026-12-21')}
def norm(x):return re.sub(r'\s+','',x or'')
def parent(r):
 pg,t=r['printedPage'],r['table']
 if pg<=49:return 'ELPIS교양대학'
 if pg==50:return '자유전공'if t==1 else'조형예술대학'
 if pg==51:return'조형예술학과'
 if pg==52:return'융합디자인학과'
 if pg==53:return'문화콘텐츠학과'
 if pg==54:return['스테인드글라스템페라융합전공','바이오헬스디자인융합전공','지역문화메디에이션융합전공','자기설계전공'][t]
 if pg==55:return['문화예술경영마이크로디그리전공','스마트AI-XR마이크로디그리전공','스마트로컬마이크로디그리전공','융합미디어아트마이크로디그리전공','ContemporaryArt마이크로디그리전공'][t]
 return'간호학과'
def schedules(m):
 day=(m.get('요일')or'').strip();time=(m.get('교시')or'').strip();room=(m.get('강의실')or'').strip();week=norm(m.get('수업주차'))
 if time=='비동시적':return [],'unscheduled',None
 if week not in periods:return [],'unrecognized','Explicit course period absent/unsupported; merged clinical rotation needs exact original resolution.'
 days=day.splitlines();ts=time.splitlines()
 if not days or any(d not in'월화수목금토일'or len(d)!=1 for d in days):return [],'unrecognized','Native weekday absent.'
 if len(days)>1 and len(ts)==1:ts=ts*len(days)
 if len(days)!=len(ts):return [],'unrecognized','Multi-line weekday/period correspondence ambiguous.'
 out=[]
 for d,t in zip(days,ts):
  if not re.fullmatch(r'\d+(?:,\d+)*',t):return [],'unrecognized','Native period expression not safely parsed.'
  nums=[int(i)for i in t.split(',')]
  if any(n<1 or n>10 for n in nums):return [],'unrecognized','Official book p44 publishes clock for periods1–10 only; no extrapolation.'
  blocks=[]
  for n in nums:
   if blocks and n==blocks[-1][-1]+1:blocks[-1].append(n)
   else:blocks.append([n])
  for b in blocks:out.append({'weekday':'월화수목금토일'.index(d)+1,'startMinute':480+60*b[0],'endMinute':480+60*b[-1]+50,'classroom':room})
 return out,'scheduled',None
courses={};held=[];conflicts=[];excluded=[]
for r in rows:
 m=r['metadata'];key=(norm(m['교과목코드']),norm(m['분반']));dept=parent(r);loc={k:r[k]for k in('pdfPage','printedPage','table','row')}
 if key in closed:excluded.append({'key':key,'locator':loc,'title':m['교과목명']});continue
 ss,status,reason=schedules(m);week=norm(m.get('수업주차'));per=periods.get(week)
 if key not in courses:
  c={'sourceId':f'iccu/songdo/2026/2/{key[0]}/{key[1]}','universityId':'iccu','campus':'songdo','campusName':'송도국제캠퍼스','academicYear':2026,'semester':'2','courseCode':key[0],'courseName':re.sub(r'\s+',' ',m['교과목명']).strip(),'section':key[1],'professor':re.sub(r'\s+',' ',m.get('담당교수')or'').strip(),'credits':float(m['학점'])if m.get('학점')else None,'schedules':ss,'scheduleStatus':status,'departments':[],'departmentCredits':{},'departmentClassifications':{},'departmentRemarks':{},'sourceUrl':url,'sourceSchedule':f"{m.get('수업주차')or''} {m.get('요일')or''} {m.get('교시')or''}",'sourceClassroom':m.get('강의실')or'','sourcePages':[r['pdfPage']],'sourceLocators':[],'nativeSourceRows':[]}
  if per:c['period']={'startDate':per[0],'endDate':per[1]}
  courses[key]=c
  if reason:held.append({'key':key,'title':c['courseName'],'reason':reason,'locator':loc})
 c=courses[key]
 if ss!=c['schedules']or(status!=c['scheduleStatus']):conflicts.append({'key':key,'locator':loc,'reason':'Repeated code/section row differs from first source row; needs review before replacing.'})
 if dept not in c['departments']:c['departments'].append(dept)
 c['departmentCredits'][dept]=c['credits'];c['departmentClassifications'][dept]=m.get('이수구분')or'';c['departmentRemarks'][dept]=f"공식 안내서 {r['printedPage']}쪽 조회·교과과정 소속; 주관학과 미확정"
 c['sourceLocators'].append(loc);c['nativeSourceRows'].append(m)
 if r['pdfPage']not in c['sourcePages']:c['sourcePages'].append(r['pdfPage'])
base={'schemaVersion':2,'universityId':'iccu','campus':'songdo','campusName':'송도국제캠퍼스','academicYear':2026,'semester':'2','sourceUrl':url,'sourcePageUrl':'https://www.iccu.ac.kr/bbs/board.php?bo_table=notice_b&wr_id=851','publishedDate':'2026-07-30','sourceSha256':hashlib.sha256((p/'iccu-2026fall-guide.pdf').read_bytes()).hexdigest(),'sourceRowCount':len(rows),'courses':list(courses.values())}
(p/'iccu-guide-schema2-candidate.json').write_text(json.dumps(base,ensure_ascii=False,indent=2))
# Conservative merge: preserve all latest nursing source rows, only add guide records whose exact title is absent in latest source. Do not use title-only matching to invent native section or code.
oldTitles={norm(c['courseName'])for c in old['courses']};merged=[];alignments=[]
for c in old['courses']:
 if norm(c['courseName'])in closedNames:excluded.append({'existingSourceId':c['sourceId'],'title':c['courseName'],'reason':'8/18closure predates9/2grid; nativecode absent so existing newer row retained pending contradiction resolution.','action':'retain_existing'})
 merged.append(copy.deepcopy(c))
for c in courses.values():
 same=[o for o in old['courses']if norm(o['courseName'])==norm(c['courseName'])]
 if same:
  alignments.append({'guideSourceId':c['sourceId'],'guideCode':c['courseCode'],'guideSection':c['section'],'guideTitle':c['courseName'],'existingSourceIds':[o['sourceId']for o in same],'guideSchedules':c['schedules'],'existingSchedules':[o['schedules']for o in same],'action':'keep_existing_latest_timed; no title-only code backfill; source comparison retained'})
 elif '간호학과'in c['departments']:
  alignments.append({'guideSourceId':c['sourceId'],'guideTitle':c['courseName'],'action':'hold_older_nursing_row_not_found_in_latest_grid; do not reintroduce older/clinical offering withoutSeptember proof'})
 else:merged.append(c)
result=copy.deepcopy(base);result['courses']=merged;result['additionalSourceUrls']=[old['sourceUrl'],'https://www.iccu.ac.kr/bbs/download.php?bo_table=notice_b&wr_id=865&no=0'];result['publishedDate']='2026-09-01';result['mergeStatus']='research candidate only; root must review source-conflict ledger';result['sourceRowCount']=len(merged)
(p/'iccu-merged-schema2-candidate.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
ledger={'completionClaim':False,'originalRows':len(rows),'uniqueGuideCodeSections':len(courses),'guideStatusCounts':dict(collections.Counter(c['scheduleStatus']for c in courses.values())),'existingLatestCount':len(old['courses']),'mergedCandidateCount':len(merged),'excluded':excluded,'held':held,'duplicateScheduleConflicts':conflicts,'existingAlignment':alignments,'closureSource':'https://www.iccu.ac.kr/bbs/download.php?bo_table=notice_b&wr_id=865&no=0','closureAsOf':'2026-08-18','silkscreenUpdate':{'date':'2026-08-05','nativeCode':'00684','section':'01','laterClosed':True},'phaseSource':'officialbookp44','weeklyOnly':True}
(p/'iccu-merge-ledger.json').write_text(json.dumps(ledger,ensure_ascii=False,indent=2));print({k:ledger[k]for k in('originalRows','uniqueGuideCodeSections','guideStatusCounts','existingLatestCount','mergedCandidateCount')});print('conflicts',len(conflicts),'held',len(held))
