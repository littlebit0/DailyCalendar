import json,re,html,collections
from pathlib import Path
p=Path(__file__).parent;idx=json.loads((p/'swu-acquisition-index.json').read_text());idx=list({(q['div'],q['department']):q for q in idx}.values());d={};query_rows=0
for q in idx:
 root=json.loads((p/q['file']).read_text())['root']
 if root.get('EXRIAERRMSG'):raise ValueError((q,root['EXRIAERRMSG']))
 rows=root.get('openSubList',{}).get('row',[]);assert len(rows)==q['rows'];query_rows+=len(rows)
 for r in rows:d.setdefault(r['REF_KEY'],[]).append({'query':{'division':q['div'],'department':q['department']},'record':r})
r=[v[0]['record']for v in d.values()];assert len(r)==len(set((x['SB_CD'],x['DIVCLS_CD'])for x in r))
s=(p/'swu-notice-138392.html').read_text();cancel=[]
for t in re.findall(r'<table\b.*?</table>',s,re.S):
 for row in re.findall(r'<tr\b.*?</tr>',t,re.S):
  c=[html.unescape(re.sub('<[^>]+>','',x)).replace('\xa0',' ').strip()for x in re.findall(r'<t[dh]\b[^>]*>(.*?)</t[dh]>',row,re.S)]
  codes=[(i,x)for i,x in enumerate(c)if re.fullmatch('[A-Z]{2,4}[0-9]{4,5}',x)]
  if codes:
   i,code=codes[0];cancel.append({'subjectCode':code,'section':c[i+2],'cells':c})
present=[x for x in cancel if any(v['SB_CD']==x['subjectCode']and int(v['DIVCLS_CD'])==int(x['section'])for v in r)]
out={'queries':idx,'queryRows':query_rows,'uniqueClasses':len(r),'untimedClasses':sum(not re.search('[월화수목금토일][1-9]',x['CLASS'])for x in r),'categories':dict(collections.Counter(x['CMP_DIV_RCD_NM']for x in r)),'finalCancellationCount':len(cancel),'cancelledPresentInCurrentCatalog':present,'records':r,'recordsByReferenceKey':d}
(p/'swu-final-cancellations.json').write_text(json.dumps(cancel,ensure_ascii=False,indent=2)+'\n');(p/'swu-all-2026-2.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in out.items()if k not in ['queries','records','recordsByReferenceKey']})
