import json,sys,collections
# 서울: 1~6교시 75분+15분(90분 슬롯), 7~10교시 50분+10분(60분 슬롯). 세종: 50분+10분(60분 슬롯).
# 근거 문서 미확인: 현재 자료의 연속 교시 시작 간격으로 슬롯을 만든다. 시계 시각 강좌(교시표에 없는 구간)와 0교시(08:00 시작)는 바꾸지 않는다.
SEOUL_START=[540,630,720,810,900,990,1080,1140,1200,1260]
SEOUL_END=[615,705,795,885,975,1065,1130,1190,1250,1310]
SEOUL_SLOT_END=[630,720,810,900,990,1080,1140,1200,1260,1320]
SEJONG_START=[540+60*i for i in range(13)]
SEJONG_END=[s+50 for s in SEJONG_START]
SEJONG_SLOT_END=[s+60 for s in SEJONG_START]
OLD='교시 사이의 공표 휴식은 합치지 않았습니다'
NEW='교시는 다음 교시 시작까지(쉬는 시간 포함)를 한 슬롯으로 보고 같은 강의실의 연속 교시는 한 구간으로 합쳤습니다'
def run(campus,path,S,E,SE):
    d=json.load(open(path,encoding='utf-8'))
    st=collections.Counter()
    for x in d['courses']:
        if OLD in x['remarks']: x['remarks']=x['remarks'].replace(OLD,NEW); st['remarks']+=1
        sch=x.get('schedules',[]); st['before']+=len(sch)
        if not sch: continue
        res=[];keep=[];changed=False
        for s in sch:
            if s['startMinute'] in S and s['endMinute'] in E and S.index(s['startMinute'])<=E.index(s['endMinute']):
                ne=SE[E.index(s['endMinute'])]
                if ne!=s['endMinute']: s['endMinute']=ne;changed=True
        by=collections.OrderedDict()
        for s in sch:
            k=(s['date'],s['weekday'],s['classroom']) if s['startMinute']!=480 else ('keep',id(s))
            by.setdefault(k,[]).append(s)
        out=[];merged=False
        for k,v in by.items():
            v.sort(key=lambda s:s['startMinute']); cur=v[0]
            for n in v[1:]:
                if n['startMinute']-cur['endMinute']<60:
                    cur['endMinute']=max(cur['endMinute'],n['endMinute']);merged=True
                else: out.append(cur);cur=n
            out.append(cur)
        if merged:
            x['schedules']=out; st['merged']+=1
        if changed or merged: st['changed']+=1
        st['after']+=len(x['schedules'])
    if '--write' in sys.argv: open(path,'w',encoding='utf-8').write(json.dumps(d,ensure_ascii=False,indent=2))
    print(campus,dict(st))
run('seoul','assets/timetable/korea-seoul-2026-2.json',SEOUL_START,SEOUL_END,SEOUL_SLOT_END)
run('sejong','assets/timetable/korea-sejong-2026-2.json',SEJONG_START,SEJONG_END,SEJONG_SLOT_END)
