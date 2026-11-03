import json,re,sys,collections,pathlib
R=pathlib.Path('/Users/kimhwi/Documents/Codex/DailyCalendar/work/university-research/catalog-t')
sys.path.insert(0,'/Users/kimhwi/Documents/Codex/DailyCalendar/work/wt/u-hufs-tt/tool/timetable'); import import_hufs as mod
import os; cwd=os.getcwd(); os.chdir('/Users/kimhwi/Documents/Codex/DailyCalendar')
ns={'__file__':str(R/'gate_hufs_pending_operating_review.py')};exec((R/'gate_hufs_pending_operating_review.py').read_text().split('decisions=[]')[0],ns);approved=ns['nonoperating']
os.chdir(cwd)
src=(R/'hufs-bulk-native-operation-v15-20261010/parser.py').read_text()
for name in ['remote','special','noClass']:
    exec([l for l in src.splitlines() if l.startswith(name+'=')][0])
clocks={'H1':{str(i):[480+i*60,530+i*60]for i in range(13)},'H2':{str(i):[480+i*60,530+i*60]for i in range(1,13)}}
_,rows=mod.load_complete(pathlib.Path('raw1023')); raw=collections.defaultdict(list)
for r in rows: raw[(r['queryCampus'],r['row']['lssnCd'])].append(r)
out=[]
for h,k in json.load(open('unresolved_keys.json')):
    rr=raw[(h,k)]; row=rr[0]['row']; plan=json.load(open(f'plans1023/{h}-{k}.json')); f=plan['fields']; reasons=[]
    sched=mod.clean(row['dayTimeDisplay'])
    try: fixed=mod.meetings(sched,clocks[h])
    except ValueError as e: fixed=[]; reasons.append('native_unknown_clock_or_format:'+str(e))
    if not fixed: reasons.append('native_no_fixed_group')
    if any(r['row']['cyberFlag']=='Y' or r['row']['moocFlag']=='Y' or r['row']['focusLect'] for r in rr): reasons.append('native_remote_or_concentrated_flag')
    if f.get('schedule','').splitlines() and mod.clean(f['schedule'].splitlines()[0])!=sched: reasons.append('own_plan_clock_conflict')
    rawnotes='\n'.join(row.get(x)or'' for x in ['etc','etc2']); operating='\n'.join(f.get(x,'') for x in ['methods','notes','delivery'])
    unk=[l.strip() for l in (rawnotes+'\n'+operating).splitlines() if l.strip() and l.strip() not in approved and (remote.search(l) or special.search(l) or re.search(r'\d{1,2}:\d{2}|\d{1,2}시|시간.{0,8}(추후|변경)',l))]
    if unk: reasons.append('actual_operating_constraint_pending')
    out.append({'h':h,'k':k,'sched':sched,'planSched':f.get('schedule',''),'delivery':f.get('delivery',''),'reasons':reasons,'unknown':unk,'cyber':row['cyberFlag'],'focus':row['focusLect'],'etc':rawnotes})
json.dump(out,open('regate.json','w'),ensure_ascii=False,indent=1)
print(collections.Counter(tuple(sorted(set(x['reasons']))) for x in out))
print('pass',[(x['h'],x['k']) for x in out if not x['reasons']])
