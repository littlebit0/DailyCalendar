import sys,json,re,zipfile,io,collections
sys.path.insert(0,'/Users/kimhwi/Documents/Codex/DailyCalendar/work/university-research/catalog-f/inu')
from collect_current_public_education import educational_rows, FIELDS
body=open('src/inu-2026-2-timetable-260904.xlsx','rb').read()
rows=educational_rows(body)
print(rows[0].get('A')); hdr=rows[1]; cols={k:v for k,v in hdr.items()}
print(cols)
edu=[]
for r in rows[2:]:
    if not r.get('G','').strip(): continue
    edu.append({cols[k]:v for k,v in r.items() if k in cols})
print(len(edu))
json.dump(edu,open('xlsx-rows.json','w'),ensure_ascii=False)
WT='/Users/kimhwi/Documents/Codex/DailyCalendar/work/wt/u-inu-tt/assets/timetable/'
assets={}
for c in ['songdo','michuhol','multiple','unknown']:
    for x in json.load(open(WT+f'inu-{c}-2026-2.json'))['courses']: assets[x['courseCode']]=x
codes=[e['학수번호'] for e in edu]
print('unique',len(set(codes)),'assets',len(assets),'match',set(codes)==set(assets))
mism=collections.Counter()
for e in edu:
    a=assets[e['학수번호']]
    if a['courseName']!=e['교과목명']: mism['name']+=1
    if (a['professor'] or '')!=(e['담당교수'] or ''): mism['prof']+=1
    if a['sourceSchedule']!=e['시간표(시간)']: mism['sched']+=1
print(mism)
print(collections.Counter(e['대학(원)'] for e in edu))
