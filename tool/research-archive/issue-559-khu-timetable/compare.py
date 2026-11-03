import json,collections,sys
from pathlib import Path
W=Path('/Users/kimhwi/Documents/Codex/DailyCalendar/work/wt/u-khu-tt')
OLD=Path('/Users/kimhwi/Documents/Codex/DailyCalendar/work/university-research/catalogs/khu-public-2026-2')
def load(d):
    rows=collections.defaultdict(list)
    for f in sorted(d.glob('*.json')):
        for r in json.loads(f.read_text())['rows']:
            rows[(r['campus_nm'],r['lecture_cd_disp'])].append(r)
    return rows
cur=load(Path('public-2026-10-23')); old=load(OLD)
camp={'seoul':'서울','global':'국제'}
ds={}
for c in ['seoul','global']:
    d=json.loads((W/f'assets/timetable/khu-{c}-2026-2.json').read_text())
    for x in d['courses']:
        ds[(camp[c],x['courseCode']+'-'+x['section'])]=x
print('dataset',collections.Counter(k[0] for k in ds),'old',collections.Counter(k[0] for k in old),'cur',collections.Counter(k[0] for k in cur))
print('raw rows cur',sum(map(len,cur.values())),'old',sum(map(len,old.values())))
print('ds-old',len(set(ds)-set(old)),'old-ds',len(set(old)-set(ds)))
add=sorted(set(cur)-set(ds)); rem=sorted(set(ds)-set(cur))
print('added',len(add),add[:20]); print('removed',len(rem),rem[:20])
tt=[]
for k in set(cur)&set(ds):
    a=sorted({r['timetable'] for r in cur[k]}); b=sorted({r['timetable'] for r in old.get(k,[])})
    if a!=b: tt.append((k,b,a))
print('timetable changed',len(tt))
for t in tt[:15]: print(t)
other=collections.Counter()
for k in set(cur)&set(old):
    for f in ['subjt_name','teach_na','unit_num','bigo','field_gb']:
        if sorted({str(r[f]) for r in cur[k]})!=sorted({str(r[f]) for r in old[k]}): other[f]+=1
print('field changes',other)
json.dump(dict(added=[list(k) for k in add],removed=[list(k) for k in rem],timetableChanged=[[list(k),b,a] for k,b,a in tt]),open('compare-2026-10-23.json','w'),ensure_ascii=False,indent=1)
