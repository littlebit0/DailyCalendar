import json,re,datetime as dt,hashlib,copy
from pathlib import Path
P=Path(__file__).parent/'kmou-current-new-notices'
load=lambda p:json.loads(p.read_text())
receipts={Path(r['file']).stem:r for r in load(P/'download-receipt.json')}
raw=[];held=[]
navfiles={'9d687689711f7492bc9bf9e968e39a33':1,'33b1337677e88f429bb7d8fd77bb7874':2,'d0d2a12ebdd0a65440a114fa7ae6c892':4}
aisfiles={'3d99b5186c86b212d2b01c3a9ce3edae':1,'28d097ac23bdb4a2b8f9f318b254ed95':2,'fad81b3d72103421dd40de674f6b9ab8':4}
norm=lambda x:re.sub(r'\s+','',x or '')
def loc(f,pg,ti,row,col,text):return {'fileKey':f,'sha256':receipts[f]['sha256'],'sourceUrl':receipts[f]['url'],'noticeUrl':receipts[f]['noticeUrl'],'page':pg,'table':ti,'row':row,'column':col,'nativeText':text}
for f,grade in aisfiles.items():
 for pg in load(P/(f+'.tables.json')):
  course_tables=[(ti,t) for ti,t in enumerate(pg['tables']) if t and t[0][:3]==['No.','교과구분','교과코드']]
  for order,(ti,t) in enumerate(course_tables):
   program=['AI전공','사이버보안전공'][order]
   for ri,r in enumerate(t[1:],1):
    if len(r)<9 or not re.fullmatch(r'\d+',r[0] or ''):continue
    cl,code,title,section,credit,prof,clock,remark=r[1:9]
    e=loc(f,pg['page'],ti,ri,None,r)
    base={'courseCode':code,'section':section,'courseName':title,'professor':prof or '', 'classification':cl,'credits':float(re.match(r'[\d.]+',credit).group()) if credit else None,'departments':['해사인공지능·보안학부'],'sourceProgramName':program,'grade':grade,'sourceEducation':[e]}
    m=re.fullmatch(r'([월화수목금토일])\s*(\d+)(?:-(\d+))?\s*(?:/\s*(.*))?',clock or '')
    if not re.fullmatch(r'\d{3}',section or '') or not m or m[1] in '토일':
     held.append(dict(base,reason='개별 분반 미지정 또는 실제 평일 수업 시간 미확인',sourceSchedule=clock));continue
    wd='월화수목금토일'.index(m[1])+1;start=int(m[2]);end=int(m[3] or m[2]);room=m[4] or ''
    raw.append(dict(base,slots=[{'weekday':wd,'period':v,'classroom':room} for v in range(start,end+1)]))
for f,grade in navfiles.items():
 pages=load(P/(f+'.tables.json'))
 for pg in pages:
  page_records=[];no_codes=[]
  for ti,t in enumerate(pg['tables']):
   if not t or t[0][:6]!=['교시','월','화','水','목','금'] and t[0][:6]!=['교시','월','화','수','목','금']:continue
   for col in range(1,6):
    ri=1
    while ri<len(t):
     text=t[ri][col]
     if not text:ri+=1;continue
     end=ri
     while end+1<len(t) and t[end+1][col] is None:end+=1
     e=loc(f,pg['page'],ti,ri,col,text);e['mergedThroughRow']=end
     codes=list(re.finditer(r'\b([A-Z]?\d{4,5})-(\d{3})\b',text))
     if len(codes)!=1 or any(s in text for s in ['일요일','택1','우측','논문지도']):
      if not codes and re.search(r'\n\d{3}\n',text):no_codes.append((text,e,col,ri,end))
      else:held.append({'sourceEducation':[e],'reason':'단일 과목코드·분반 미확인 또는 선택/일요일 입력용 안내로 실제 수업 불확정'})
      ri=end+1;continue
     m=codes[0];before=text[:m.start()].strip();after=text[m.end():].strip().splitlines()
     if len(after)<2:held.append({'sourceEducation':[e],'reason':'강의실·교수 분리 불확정'});ri=end+1;continue
     title=norm(re.sub(r'\(전공선택\)','',before));room=after[0];prof=' '.join(after[1:])
     base={'courseCode':m[1],'section':m[2],'courseName':title,'professor':prof,'classification':'전공선택' if '(전공선택)' in before else '', 'credits':None,'departments':['항해융합학부'],'grade':grade,'sourceEducation':[e],'slots':[{'weekday':col,'period':v,'classroom':room} for v in range(int(t[ri][0]),int(t[end][0])+1)]}
     page_records.append(base);ri=end+1
  for text,e,col,ri,end in no_codes:
   bits=text.strip().splitlines();idx=next(i for i,x in enumerate(bits) if re.fullmatch(r'\d{3}',x));title=norm(''.join(bits[:idx]));section=bits[idx];after=bits[idx+1:]
   matches=[r for r in page_records if norm(r['courseName'])==title and r['section']==section and len(after)>=2 and r['slots'][0]['classroom']==after[0] and norm(r['professor'])==norm(''.join(after[1:]))]
   if len(matches)!=1:held.append({'sourceEducation':[e],'reason':'같은 페이지 코드 생략 칸의 제목·분반·교수·강의실 정확 일치 미확인'});continue
   r=matches[0];r['sourceEducation'].append(e);r['slots'] += [{'weekday':col,'period':v,'classroom':after[0]} for v in range(ri,end+1)]
  raw+=page_records
# Strict explicit code+section grouping, no title-only affiliation or identity joins.
groups={}
for r in raw:groups.setdefault((r['courseCode'],r['section']),[]).append(r)
old=load(Path('assets/timetable/kmou-unknown-2026-2.json'))
oldnames={norm(c['courseName']) for c in old['courses']}; candidates=[];collisions=[]
mapdates=[('2026-09-24','2026-12-10'),('2026-09-25','2026-12-11'),('2026-10-05','2026-12-14'),('2026-10-09','2026-12-08'),('2026-11-05','2026-12-09')]
dates={}
for wd in range(1,6):
 d=dt.date(2026,9,1);arr=[]
 while d<=dt.date(2026,12,7):
  if d.isoweekday()==wd and d.isoformat() not in dict(mapdates) and not(dt.date(2026,10,20)<=d<=dt.date(2026,10,26)):arr.append(d.isoformat())
  d+=dt.timedelta(days=1)
 arr += [a for b,a in mapdates if dt.date.fromisoformat(b).isoweekday()==wd];dates[wd]=sorted(arr)
for key,rs in groups.items():
 identity={(norm(r['courseName']),norm(r['professor'])) for r in rs}
 slotsets={tuple(sorted((s['weekday'],s['period'],s['classroom']) for s in r['slots'])) for r in rs}
 if len(identity)>1 or len(slotsets)>1:
  held.append({'courseCode':key[0],'section':key[1],'sourceRows':rs,'reason':'공식 자료 사이 동일 코드·분반의 제목·교수 또는 교시·강의실 불일치'});continue
 r=copy.deepcopy(rs[0]);slots=r.pop('slots');r['sourceEducation']=[e for x in rs for e in x['sourceEducation']]
 r['departments']=sorted({v for x in rs for v in x['departments']});r['credits']=next((x['credits'] for x in rs if x['credits'] is not None),None);r['classification']=next((x['classification'] for x in rs if x['classification']), '')
 r.update(sourceId='kmou-2026-2-'+key[0]+'-'+key[1],academicYear=2026,semester='2',campus='unknown',canonicalSubjectCodePublished=True,nativeSectionPublished=True,scheduleStatus='scheduled',period={'startDate':'2026-09-01','endDate':'2026-12-14'},sourceSchedule='; '.join(f"{s['weekday']}요일 {s['period']}교시 {s['classroom']}" for s in slots),schedules=[])
 for s in slots:
  for date in dates[s['weekday']]:
   item={'date':date,'weekday':dt.date.fromisoformat(date).isoweekday(),'startMinute':(8+s['period'])*60,'endMinute':(8+s['period'])*60+50,'classroom':s['classroom']}
   for before,after in mapdates:
    if after==date and dt.date.fromisoformat(before).isoweekday()==s['weekday']:item.update(sourceWeekday=s['weekday'],makeupForDate=before,scheduleKind='publishedMakeup')
   r['schedules'].append(item)
 r['sourceClockPeriods']=slots
 if norm(r['courseName']) in oldnames:collisions.append(dict(r,reason='기존 30개 중 같은 제목 존재; 기존 과목코드 미공개이므로 제목만으로 합치거나 중복 추가하지 않음'))
 else:candidates.append(r)
receipt={'researchOnly':True,'productionIntegrationEnabled':False,'completionClaim':False,'existing30Preserved':True,'sourceCourseRows':len(raw),'exactCodeSectionGroups':len(groups),'newCollisionFreeTimedCandidates':len(candidates),'sameTitleExistingIdentityHolds':len(collisions),'otherHolds':len(held),'newDatedSlots':sum(len(c['schedules']) for c in candidates),'clockSource':'general2026-clock-proof.json','calendarSource':'work/university-research/catalog-c/kmou-elecom-semester-makeup-v3-20261009/independent-semester-literal-proof.json','verificationRun':False,'server404Correction':'Normal public board HTML and search form returned with HTTP 404. Earlier status-only failure classification invalid. Server-side cause unverified.'}
for name,obj in [('normalized-new-education-rows.json',raw),('kmou-new-collision-free-candidate.json',dict(old,courses=candidates,sourceUrl='https://www.kmou.ac.kr/navigation/na/ntt/selectNttInfo.do?nttSn=10377141',sourceUrls=['https://www.kmou.ac.kr/navigation/na/ntt/selectNttInfo.do?nttSn=10377141','https://www.kmou.ac.kr/aisec/na/ntt/selectNttInfo.do?nttSn=10377210'],publishedDate='2026-07-24',researchOnly=True,productionIntegrationEnabled=False,completionClaim=False)),('existing-title-collision-holds.json',collisions),('new-source-holds.json',held),('candidate-receipt.json',receipt)]:
 (P/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(receipt,ensure_ascii=False))
