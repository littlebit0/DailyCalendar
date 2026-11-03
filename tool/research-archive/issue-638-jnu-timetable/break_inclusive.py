import json,sys,importlib.util,collections
sys.dont_write_bytecode=True
wt=sys.argv[1]
spec=importlib.util.spec_from_file_location('imp',wt+'/tool/timetable/import_jnu.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
for f in ['jnu-gwangju','jnu-yeosu']:
    p=f'{wt}/assets/timetable/{f}-2026-2.json'
    raw=open(p).read();d=json.loads(raw)
    before=after=chg=merged=0
    for c in d['courses']:
        if c['scheduleStatus']!='scheduled': 
            assert not c['schedules'] or c['scheduleStatus']!='unrecognized'
            continue
        new,st=m.meetings(c['sourceSchedule'],c['sourceClassroom'])
        assert st=='scheduled'
        before+=len(c['schedules']);after+=len(new)
        if new!=c['schedules']: chg+=1
        if len(new)<len(c['schedules']) or any(1 for _ in [0] if False): pass
        if any(x['endMinute']-x['startMinute']>(90 if x['weekday'] in (2,4) else 60) for x in new): merged+=1
        c['schedules']=new
    print(f,'seg',before,after,'changed',chg,'merged',merged)
    open(p,'w').write(json.dumps(d,ensure_ascii=False,indent=2 if raw.startswith('{\n') else None)+('\n' if raw.endswith('\n') else ''))
