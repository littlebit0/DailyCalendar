import pathlib,json,sys
p=pathlib.Path(__file__).parent;rs=json.loads((p/'next50-safe-education-contexts.json').read_text())['records']
def merge(original):
 texts=list(dict.fromkeys(original));out=''
 while texts:
  texts=[t for t in texts if t not in out]
  if not texts:break
  best=None
  for t in texts:
   for n in range(min(len(out),len(t)),29,-1):
    if out.endswith(t[:n]):
     if best is None or n>best[0]:best=(n,t)
     break
  if best:out+=best[1][best[0]:];texts.remove(best[1])
  else:
   t=max(texts,key=len);out+='\n[separate source fragment]\n'+t;texts.remove(t)
 assert all(t in out for t in original)
 return out
for r in rs[int(sys.argv[1]):int(sys.argv[2])]:
 print(r['offeringCode'],r['sourceRow']['GYOSI_NAME'],r['sourceRow']['SUUP_TYPE_NM']);print('detail',[(d['CLASS_INFO'],d['BIGO']) for d in r['detail']]);
 for a in r['attachments']: print('ATTACHMENT',a.get('pages'),a.get('explicitAcademicTermMarkers'),merge(a['educationalOperatingContexts']))
