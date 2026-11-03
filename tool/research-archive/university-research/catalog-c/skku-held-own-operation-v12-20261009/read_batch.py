import json,pathlib,sys
p=pathlib.Path(__file__).parent;r=json.load(open(p/'next50-full-inline-routing.json'))['records'];chosen=r
def merge(texts):
 texts=list(dict.fromkeys(texts));out=''
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
   t=max(texts,key=len);out+='\n[separate original fragment]\n'+t;texts.remove(t)
 assert all(t in out for t in texts)
 return out
for a in chosen[int(sys.argv[1]):int(sys.argv[2])]:
 print(a['offeringCode'],a['sourceRow']['GYOSI_NAME'],a['sourceRow']['SUUP_TYPE_NM']);print('D',[(d['CLASS_INFO'],d['BIGO']) for d in a['detail']]);seen=set();out=[]
 for w in a['weekly']:
  note=w['BIGO'];value=note if note not in seen else '[exact same BIGO already printed]';seen.add(note);out.append((w['PLAN_WEEK_CNT'],w['PLAN_WEEK_CONT'],value))
 print('W',out)
 for x in a['attachments']:print('A',x.get('explicitAcademicTermMarkers'),merge(x.get('educationalOperatingContexts',[])))
