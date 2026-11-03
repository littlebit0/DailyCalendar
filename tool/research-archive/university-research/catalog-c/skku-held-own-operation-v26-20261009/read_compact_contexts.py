import pathlib,json,sys,re
p=pathlib.Path(__file__).parent;rs=json.loads((p/'next50-safe-education-contexts.json').read_text())['records']
def merge(src):
 orig=[re.sub(r'\s+',' ',s).strip() for s in src];parts=list(dict.fromkeys(orig));parts=[x for x in parts if not any(x!=y and x in y for y in parts)]
 while len(parts)>1:
  best=None
  for i,a in enumerate(parts):
   for j,b in enumerate(parts):
    if i==j:continue
    for n in range(min(len(a),len(b)),29,-1):
     if a.endswith(b[:n]):
      if best is None or n>best[0]:best=(n,i,j)
      break
  if best is None:break
  n,i,j=best;parts[i]=parts[i]+parts[j][n:];parts.pop(j)
 text='\n[separate source fragment]\n'.join(parts);assert all(t in text for t in orig);return text
for r in rs[int(sys.argv[1]):int(sys.argv[2])]:
 print(r['offeringCode'],r['sourceRow']['GYOSI_NAME'],r['sourceRow']['SUUP_TYPE_NM']);print('detail',[(d['CLASS_INFO'],d['BIGO']) for d in r['detail']])
 for a in r['attachments']:print('ATTACHMENT',a.get('pages'),a.get('explicitAcademicTermMarkers'),merge(a['educationalOperatingContexts']))
