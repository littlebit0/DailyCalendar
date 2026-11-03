import fitz,json,re,sys
from pathlib import Path
out=Path(__file__).parent;source=out.parent/'c/kangnam-timetable.html';doc=fitz.open(source);rows=[];unparsed=[];active_heading=''
selected={int(x)for x in sys.argv[1:]}
if selected:
 rows=[x for x in json.loads((out/'native-rows.json').read_text())if x['page']not in selected]
for pi in range(102,len(doc)):
 if selected and pi+1 not in selected:continue
 page=doc[pi];tp=page.get_textpage();text=page.get_text(sort=True);heading=' / '.join(x.strip()for x in text.splitlines()if x.strip().startswith(('○','◎')))
 line_words={}
 for w in page.get_text('words'):
  line_words.setdefault(round(w[1],1),[]).append(w)
 markers=[]
 for yy,words in sorted(line_words.items()):
  line=' '.join(w[4]for w in sorted(words,key=lambda w:w[0]))
  if line.startswith(('○','◎')):markers.append((yy,line))
 cells=[]
 for d in page.get_drawings():
  if ((len(d['items'])==4 and all(x[0]=='l' for x in d['items'])) or (len(d['items'])==1 and d['items'][0][0]=='re')) and d['rect'].height>9 and d['rect'].width>10:
   cells.append(d['rect'])
 groups={}
 for r in cells:groups.setdefault(round(r.y0,1),[]).append(r)
 columns=None
 for y,rects in sorted(groups.items()):
  rects.sort(key=lambda r:r.x0)
  data=[re.sub(r'\s*\n\s*',' ',page.get_textbox(fitz.Rect(r.x0+.5,r.y0+1.3,r.x1-.5,r.y1-1.3),textpage=tp).strip()).replace('교과번호','학수번호')for r in rects]
  if {'学수번호','교과목명'}.issubset(set(data)):raise RuntimeError('Unexpected script')
  if {'학수번호','교과목명','분반','강의시간'}.issubset(set(data)):
   columns=[(v,r)for v,r in zip(data,rects)];continue
  if not columns:continue
  row={}
  for v,r in zip(data,rects):
   if not v:continue
   center=(r.x0+r.x1)/2
   labels=[k for k,box in columns if box.x0<=center<=box.x1]
   if len(labels)!=1:continue
   row[labels[0]]=v
  code=row.get('학수번호','')
  if re.fullmatch('[A-Z]{2}[0-9]{5}',code):
   prior=[t for yy,t in markers if yy<y]
   if prior:active_heading=prior[-1]
   rows.append({'page':pi+1,'rowY':y,'heading':active_heading,'pageHeadings':heading,'native':row})
  elif any(re.search('[A-Z]{2}[0-9]{5}',v)for v in data):unparsed.append({'page':pi+1,'cells':data})
 if pi%10==0:print('processed page',pi+1,'rows',len(rows),flush=True)
rows.sort(key=lambda x:(x['page'],x.get('rowY',0)))
(out/'native-rows.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2));(out/'table-extraction-holds.json').write_text(json.dumps(unparsed,ensure_ascii=False,indent=2))
print('Native full-book rows',len(rows),'unique',len({(x['native']['학수번호'],x['native'].get('분반',''))for x in rows}),'unparsed',len(unparsed))
