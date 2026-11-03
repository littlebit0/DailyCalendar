import pathlib,re,collections,json
import pdfplumber
from parse_tables import course,emit,sch,SANG,clean,compact
P=pathlib.Path(__file__).parent
closuretext=(P/'sangji-fall-closure.plumber.txt').read_text()
closed={(m[1].zfill(5),m[2].zfill(2)) for m in re.finditer(r'\s(\d{4,5})\s+(\d{1,2})\s+[\d.]+\s+[\d.]+\s+(?:이론|실습)',closuretext)}
cs=[];rows=[]
for f in sorted((P/'sangji-fall-timetable').glob('*.pdf')):
 general=f.name.startswith(('1','3'));bounds=[0,60,83,247,295,320,343,362,414,577,758,1000] if general else [0,56,77,237,281,304,325,340,382,578,727,1000]
 codeLow,codeHigh=(250,291) if general else (240,279)
 with pdfplumber.open(f) as d:
  for pi,page in enumerate(d.pages):
   words=page.extract_words();anchors=[w for w in words if 30<w['x0']<55 and w['top']>(110 if general else 90) and w['text'] in ['교필','교선','전필','전선','계기','일선','교직']]
   anchors.sort(key=lambda w:w['top']);dept=clean(' '.join(w['text'] for w in words if w['top']<70 and w['x0']>550)) or ('교양' if general else '')
   for i,a in enumerate(anchors):
    lo=a['top']-3
    hi=min(anchors[i+1]['top']-3,a['top']+23) if i+1<len(anchors) else a['top']+23
    wrow=[w for w in words if lo<=w['top']<hi];cells=[]
    for left,right in zip(bounds,bounds[1:]):cells.append(clean(' '.join(w['text'] for w in sorted(wrow,key=lambda w:(round(w['top']/4)*4,w['x0'])) if left<=w['x0']<right)))
    # Extract code characters from the printed code column even when a long
    # Korean title touches the code and PDF word tokenization joins them.
    codechars=[ch for ch in page.chars if (251 if general else 241)<=ch['x0']<(294 if general else 280) and lo<=ch['top']<min(hi,lo+15) and re.fullmatch('[A-Z0-9]',ch['text'])]
    cells[3]=''.join(ch['text'] for ch in sorted(codechars,key=lambda ch:ch['x0']))
    # Long Korean titles physically overlap the code column in this PDF.
    # Keep their native characters and remove only the independently printed
    # code characters, rather than accepting merged PDF word tokens.
    codeids={id(ch) for ch in codechars}
    namechars=[ch for ch in page.chars if (88 if general else 79)<=ch['x0']<(294 if general else 281) and lo<=ch['top']<hi and id(ch) not in codeids]
    cells[2]=clean(''.join(ch['text'] for ch in sorted(namechars,key=lambda ch:(round(ch['top']/3)*3,ch['x0']))))
    kind,year,name,code,section,credits,hours,prof,raw,room,rest=cells
    if not re.fullmatch('[A-Z0-9]{5}',code) or not re.fullmatch('\d{2}',section):rows.append({'file':f.name,'page':pi+1,'row':cells,'holdReason':'PDF column identity ambiguous'});continue
    preceding=[w for w in words if w['x0']>550 and w['top']<a['top'] and re.search(r'(학과|학부|전공)$',w['text'])]
    rowdept=max(preceding,key=lambda w:w['top'])['text'] if preceding else dept
    try:c=course('sangji',2,cells,code,name,section,prof,credits,kind,rowdept,raw,pi+1)
    except ValueError:rows.append({'file':f.name,'page':pi+1,'row':cells,'holdReason':'Credit column ambiguous'});continue
    c['sourcePdf']=f.name
    try:
     if (code,section) in closed:raise ValueError('Officially closed 2026-09-08')
     raw=re.sub(r'^(전임|강사|초빙|겸임|산학|명예|객원|비전임)+','',raw)
     matches=list(re.finditer(r'([월화수목금토일])([\d,\s]+)',raw))
     if not matches or re.sub(r'\s','',re.sub(r'([월화수목금토일])([\d,\s]+)','',raw)):raise ValueError('Unrecognized official period notation')
     if any(m[1]=='토' for m in matches):raise ValueError('Saturday e-learning assessment time is not a weekly lecture time')
     if '이러닝' in room or 'OCU' in room:raise ValueError('Online assessment clock is not a published weekly lecture clock')
     if not room:raise ValueError('No published classroom/synchronous delivery evidence')
     rooms=[clean(x) for x in room.split(',')]
     if len(rooms)>1 and len(rooms)!=len(matches):raise ValueError('Multiple classroom mapping not established')
     for j,m in enumerate(matches):
      ps=[int(x) for x in re.split(r'[,\s]+',m[2].strip()) if x]
      if len(ps)!=len(set(ps)) or ps!=sorted(ps):raise ValueError('Invalid period sequence')
      c['schedules']+=sch(m[1],ps,rooms[j] if len(rooms)>1 else room,SANG)
     c['scheduleStatus']='scheduled'
    except ValueError as e:c['holdReason']=str(e);c['schedules']=[]
    cs.append(c)
emit('sangji',2,cs,'https://sangji.ac.kr/cmm/fms/FileDown.do?atchFileId=FILE_000000110049Qx8&fileSn=2','2026-07-16',{'start':'2026-08-31','endInclusive':'2026-12-12','sourceUrl':'https://sangji.ac.kr/prog/schafsSchdul/kor/sub06_01_01/A/getScheduleList.do'},'https://sangji.ac.kr/cmm/fms/FileDown.do?atchFileId=FILE_000000110049Qx8&fileSn=0',{'closureSourceUrl':'https://sangji.ac.kr/cmm/fms/FileDown.do?atchFileId=FILE_000000112051Xb8&fileSn=0','closedCourseSections':[list(x) for x in sorted(closed)],'extractionHeldRows':rows})
print('closures',len(closed),'unparsed',len(rows))
