import json,sys,collections
sys.path.insert(0,'/Users/kimhwi/Documents/Codex/DailyCalendar/work/wt/u-hufs-tt/tool/timetable')
import import_hufs as I
from pathlib import Path
old_m,old=I.load_complete(Path('/Users/kimhwi/Documents/Codex/DailyCalendar/work/university-research/catalog-t/hufs-current-20261008'))
new_m,new=I.load_complete(Path('raw1023'))
print('old rows',len(old),'new rows',len(new)); print(new_m['counts'])
def idx(rows):
    d=collections.defaultdict(list)
    for r in rows: d[(r['queryCampus'],r['row']['lssnCd'])].append(r)
    return d
o,n=idx(old),idx(new)
print('unique old',len(o),'new',len(n))
added=sorted(set(n)-set(o)); removed=sorted(set(o)-set(n))
print('added',len(added),added[:50]); print('removed',len(removed),removed[:50])
F=['subjtNaKr','empNm','unitNum','dayTimeDisplay','comptFldNm','etc','etc2','cyberFlag','wongangFlag','moocFlag','focusLect','lang','encessFlag','realLssnNum']
ch=collections.Counter(); detail=[]
for k in sorted(set(o)&set(n)):
    a={(r['queryCategory'],r['queryDepartment']) for r in o[k]}; b={(r['queryCategory'],r['queryDepartment']) for r in n[k]}
    if a!=b: ch['offering']+=1; detail.append((k,'offering',sorted(a^b)))
    for f in F:
        va=o[k][0]['row'].get(f); vb=n[k][0]['row'].get(f)
        if va!=vb: ch[f]+=1; detail.append((k,f,va,vb))
print(ch)
json.dump({'added':added,'removed':removed,'detail':detail},open('diff.json','w'),ensure_ascii=False,indent=1)
