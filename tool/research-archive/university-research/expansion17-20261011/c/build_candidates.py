from pathlib import Path
from bs4 import BeautifulSoup as B
import json,re,xlrd
p=Path(__file__).parent
url='https://www.nambu.ac.kr/board/NAMBU_BOARD_0002/boardView.do?bdId=BD_00000000000110415&menuCd=KR006006002'
s=xlrd.open_workbook(p/'nambu-courses.xls').sheet_by_index(0);courses=[];holds=[]
clock={1:540,2:600,3:660,4:720,5:810,6:870,7:930,8:990,9:1050}
def compact(blocks):
 result=[]
 for block in sorted(blocks,key=lambda b:(b['weekday'],b['startMinute'],b['classroom'])):
  if result and result[-1]['weekday']==block['weekday'] and result[-1]['classroom']==block['classroom'] and 0<=block['startMinute']-result[-1]['endMinute']<=10:
   result[-1]['endMinute']=block['endMinute']
  elif not result or block != result[-1]:result.append(dict(block))
 return result
def v(x):return str(int(x)) if isinstance(x,float) and x.is_integer() else str(x).strip()
for i in range(2,s.nrows):
 r=[v(x) for x in s.row_values(i)]
 if not r[5]:continue
 blocks=[];issues=[]
 for t in r[15:24]:
  if not t:continue
  m=re.fullmatch(r'([월화수목금토일])(\d+)',t)
  if not m:issues.append('unrecognized period '+t);continue
  day='월화수목금토일'.index(m[1])+1;period=int(m[2])
  if period not in clock:issues.append('current night clock missing '+t);continue
  blocks.append({'weekday':day,'startMinute':clock[period],'endMinute':clock[period]+50,'classroom':' '.join(x for x in r[13:15] if x)})
 if r[13]=='온라인':issues.append('online attendance modality not confirmed')
 if issues or not blocks:holds.append({'row':i+1,'raw':r,'reasons':issues or ['no published period']});continue
 courses.append({'sourceId':f'nambu/main/2026-2/sheet0-row{i+1}','campus':'main','academicYear':2026,'semester':'2','courseCode':'','section':r[4],'courseName':r[5],'professor':r[7],'classification':r[6],'credits':float(r[8]) if r[8] else 0,'departments':[r[0]],'departmentCredits':{},'departmentClassifications':{},'sourceSchedule':' '.join(r[15:24]),'sourceClassroom':' '.join(x for x in r[13:15] if x),'remarks':'공식 공개표에 과목코드 없음. 원문 학년: '+r[3]+' / 유형: '+r[12]+'. 2026-2 수강신청 가이드의 주간 1–9교시 시각만 사용. 야간·온라인·교시 미배정 자료 별도 보류. 원문 비고: '+r[24],'period':{'startDate':'2026-09-01','endDate':'2026-12-21'},'scheduleStatus':'scheduled','schedules':compact(blocks)})
(p/'nambu-main-2026-2.candidate.json').write_text(json.dumps({'schemaVersion':2,'universityId':'nambu','campus':'main','campusName':'광주','academicYear':2026,'semester':'2','publishedDate':'2026-08-18','sourceUrl':url,'researchOnly':False,'completionClaim':False,'courses':courses},ensure_ascii=False,indent=2));(p/'nambu-holds.json').write_text(json.dumps(holds,ensure_ascii=False,indent=2));print('nambu',len(courses),len(holds))
# Preserve every positioned native text element before adjudication.
d=B((p/'pcu-preview.raw').read_bytes(),'html.parser');pages=[]
for page in d.select('div[id^="page"]'):
 n=int(re.search(r'page(\d+)',page['id'])[1]);rows=[]
 for item in page.select('p'):
  m=re.search(r'top:(\d+)px;left:(\d+)px',item.get('style',''))
  if m:rows.append({'y':int(m[1]),'x':int(m[2]),'text':' '.join(item.get_text(' ',strip=True).split())})
 pages.append({'page':n,'elements':rows})
(p/'pcu-native-positioned-pages.json').write_text(json.dumps(pages,ensure_ascii=False,indent=2))
pcu=[];pcu_holds=[];seen={};conflicts=set();duplicates=0;parsed=0
source='https://hakgwa.pcu.ac.kr/ce/article/depart_ce_notice/37507'
letter={'Z':(490,565),'A':(570,645),'B':(660,735),'C':(810,885),'D':(900,975),'E':(990,1065),'F':(1080,1155),'G':(1170,1245),'H':(1260,1335)}
for page in pages:
 n=page['page'];elements=page['elements']
 if not 153<=n<=243:continue
 for codeel in elements:
  if codeel['y']<160 or not re.search(r'\b[A-Z]{2,6}\d{4,}\b',codeel['text']):continue
  y=codeel['y'];row=sorted([e for e in elements if abs(e['y']-y)<=2],key=lambda e:e['x']);text=' '.join(e['text'] for e in row)
  m=re.match(r'^(\d+)\s+(교필선|교필|교선필|교선|전필|전선|자선|교직|공필|공선)\s+([A-Z]{2,6}\d{4,})\s+(.+?)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s+(\d{2})\s+(.+)$',text)
  if not m:pcu_holds.append({'page':n,'rowY':y,'text':text,'reason':'unresolved native row layout'});continue
  year,classification,code,title,credit,hours,section,tail=m.groups()
  # Require printed timing tokens in the same native row; never borrow from another section.
  tokens=list(re.finditer(r'([월화수목금토일])\s*\(?([ZABCDEFGH]|\d{1,2})(?:,\s*([ZABCDEFGH]|\d{1,2}))*\)?(?=$|[,\s|])',tail))
  if not tokens or '온라인' in tail or '미배정' in tail:pcu_holds.append({'page':n,'rowY':y,'text':text,'reason':'no confirmed in-person timing/teacher'});continue
  professor=tail[:tokens[0].start()].strip();room=''
  # Room may precede weekday in some columns; keep only own-row printed tokens.
  rm=re.findall(r'\b[A-Z]{1,3}\d{2,4}(?:-\d+)?\b',tail)
  blocks=[]
  for ti,t in enumerate(tokens):
   segment=tail[t.start():t.end()];periods=re.findall(r'[ZABCDEFGH]|\d{1,2}',segment[1:]);day='월화수목금토일'.index(t[1])+1
   localprefix=tail[:t.start()];localrooms=re.findall(r'\b[A-Z]{1,3}\d{2,4}(?:-\d+)?\b',localprefix)
   room=localrooms[-1] if localrooms else (' / '.join(dict.fromkeys(rm)) if rm else '')
   if not room:blocks=[];break
   for value in periods:
    if value in letter:start,end=letter[value]
    elif value.isdigit() and 0<=int(value)<=13:start=480+60*int(value);end=start+50
    else:blocks=[];break
    blocks.append({'weekday':day,'startMinute':start,'endMinute':end,'classroom':room})
  professor=re.sub(r'\b[A-Z]{1,3}\d{2,4}(?:-\d+)?\b','',professor).strip(' |')
  if not blocks or not professor or not re.fullmatch(r'[가-힣A-Za-z .·]+',professor):pcu_holds.append({'page':n,'rowY':y,'text':text,'reason':'own-row room/professor/clock unresolved'});continue
  parsed+=1
  key=(code,section)
  entry={'sourceId':f'pcu/main/2026-2/{code}-{section}','campus':'main','academicYear':2026,'semester':'2','courseCode':code,'section':section,'courseName':title,'professor':professor,'classification':classification,'credits':float(credit),'departments':[],'departmentCredits':{},'departmentClassifications':{},'sourceSchedule':tail,'sourceClassroom':' / '.join(sorted(set(x['classroom'] for x in blocks))),'remarks':f'2026-2 공식 강의시간편람 PDF {n-6}쪽 원문: '+text,'period':{'startDate':'2026-09-01','endDate':'2026-12-18'},'scheduleStatus':'scheduled','schedules':compact(blocks)}
  if key in seen:
   prior=seen[key]
   if prior['schedules']!=entry['schedules'] or prior['professor']!=professor or prior['courseName']!=title:
    conflicts.add(key);pcu_holds.append({'page':n,'rowY':y,'text':text,'reason':'conflicting same-course section'});continue
   duplicates+=1
  else:seen[key]=entry;pcu.append(entry)
pcu=[e for e in pcu if (e['courseCode'],e['section']) not in conflicts]
(p/'pcu-identity-ledger.json').write_text(json.dumps({'parsedTimedRows':parsed,'duplicateIdenticalRows':duplicates,'conflictingKeys':[list(k) for k in sorted(conflicts)],'candidateCount':len(pcu),'excludedRowCount':len(pcu_holds)},ensure_ascii=False,indent=2))
(p/'pcu-main-2026-2.candidate.json').write_text(json.dumps({'schemaVersion':2,'universityId':'pcu','campus':'main','campusName':'배재·대덕','academicYear':2026,'semester':'2','publishedDate':'2026-08-03','sourceUrl':source,'researchOnly':False,'completionClaim':False,'courses':pcu},ensure_ascii=False,indent=2));(p/'pcu-holds.json').write_text(json.dumps(pcu_holds,ensure_ascii=False,indent=2));print('pcu',len(pcu),len(pcu_holds))
