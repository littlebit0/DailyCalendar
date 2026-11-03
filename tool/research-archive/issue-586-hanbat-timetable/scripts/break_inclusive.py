import json,sys
# 한밭대 학사안내 교시표: 월~금 주간 1~9교시 09:00 시작 60분 간격, 야간 10~13교시 18:40/19:35/20:30/21:30
# 토요일 1~5교시 09:00 시작 60분 간격, 6~13교시 14:00 시작 55분 간격
WK=[540,600,660,720,780,840,900,960,1020,1120,1175,1230,1290]
WK_END=[600,660,720,780,840,900,960,1020,1080,1175,1230,1290,1345]
SA=[540,600,660,720,780,840,895,950,1005,1060,1115,1170,1225]
SA_END=[600,660,720,780,840,895,950,1005,1060,1115,1170,1225,1280]
def slot_end(sat,s):
    st,en=(SA,SA_END) if sat else (WK,WK_END)
    return en[st.index(s)]
stats={'before':0,'after':0,'changed':0,'merged':0}
for cp in ['daejeon','sejong']:
    p=f'assets/timetable/hanbat-{cp}-2026-2.json'
    d=json.load(open(p,encoding='utf-8'))
    for c in d['courses']:
        old=c['schedules']; stats['before']+=len(old)
        new=[]
        for m in old:
            sat=m['weekday']==6
            m=dict(m); m['endMinute']=slot_end(sat,m['startMinute'])
            prev=next((x for x in reversed(new) if x['date']==m['date'] and x['classroom']==m['classroom'] and x['weekday']==m['weekday']),None)
            if prev and 0<=m['startMinute']-prev['endMinute']<60 and m['startMinute']>=prev['startMinute']:
                prev['endMinute']=m['endMinute']
            else: new.append(m)
        stats['after']+=len(new)
        if new!=old:
            stats['changed']+=1
            if len(new)<len(old): stats['merged']+=1
        c['schedules']=new
    open(p,'w',encoding='utf-8').write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
print(stats)
