"""Recheck complete normal guest listing; compare official fields without overwriting prior evidence."""
import json,time,urllib.parse
from acquire_postech import ROOT,page
previous=json.loads((ROOT/'postech-2026-2-undergraduate.json').read_text())
count,pages,rows=page('U',1)
for n in range(2,pages+1):
 time.sleep(.8);nextcount,nextpages,new=page('U',n)
 if (nextcount,nextpages)!=(count,pages):raise ValueError('Scope changed during published pagination')
 rows.extend(new)
def key(r):return urllib.parse.parse_qs(urllib.parse.urlparse(r['detailUrl']).query)['id'][0]
assert len(rows)==count and len({key(r) for r in rows})==count
old={key(r):r for r in previous};new={key(r):r for r in rows}
changed=[{'publishedOfferingId':k,'changedFields':[f for f in new[k] if new[k][f]!=old[k][f] and f!='detailUrl']} for k in new.keys()&old.keys() if any(new[k][f]!=old[k][f] for f in new[k] if f!='detailUrl')]
a={'researchOnly':True,'completionClaim':False,'currentCount':count,'actualPages':pages,'oldCount':len(previous),'addedPublicOfferingIds':sorted(new.keys()-old.keys()),'removedPublicOfferingIds':sorted(old.keys()-new.keys()),'changedPublicEducationFields':changed,'publicListingHasNoExplicitCancellationStatus':True,'source':'https://plms.postech.ac.kr/local/ubion/course/lists.php?year=2026&semester=20&groupcode=U'}
(ROOT/'postech-2026-2-current-recheck-20261008.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2));(ROOT/'postech-2026-2-current-scope-recheck-20261008.json').write_text(json.dumps(a,ensure_ascii=False,indent=2));print('Current count',count,'added',len(a['addedPublicOfferingIds']),'removed',len(a['removedPublicOfferingIds']),'changed',len(changed),flush=True)
