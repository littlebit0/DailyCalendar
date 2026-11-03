import re
DAYS='월화수목금토'
CLOCK={p:((8+p)*60,(8+p)*60+50) for p in range(11)}

def groups(text):
    parts=[];position=0
    for m in re.finditer(r'\([^()]*\)',text):
        if m.start()>position:parts.append(('lecture',text[position:m.start()]))
        parts.append(('practice',m.group()[1:-1]));position=m.end()
    if position<len(text):parts.append(('lecture',text[position:]))
    if '(' in ''.join(x[1] for x in parts) or ')' in ''.join(x[1] for x in parts):raise ValueError('unmatched parentheses')
    return parts

def parse(time,room):
    tparts=time.split('/');rparts=room.split('/')
    if len(rparts)==1:rparts*=len(tparts)
    if len(tparts)!=len(rparts):raise ValueError('slash time-room group mismatch')
    result=[]
    for t,r in zip(tparts,rparts):
        tg=groups(re.sub(r'\s+','',t));rg=groups(r.strip())
        if not tg or not rg:raise ValueError('empty time-room groups')
        if len(rg)==1 and rg[0][0]=='lecture':rg=[(kind,rg[0][1]) for kind,_ in tg]
        if [x[0] for x in tg]!=[x[0] for x in rg]:raise ValueError('lecture-practice room group mismatch')
        for (kind,raw),(rkind,where) in zip(tg,rg):
            if not where or any(x in where for x in ['미정','미배정','동영상','콘텐츠','온라인(중복']):raise ValueError('unresolved classroom')
            matches=list(re.finditer(r'([월화수목금토])(\d+(?:,\d+)*)',raw))
            if ','.join(m.group() for m in matches)!=raw:raise ValueError('unrecognized time syntax')
            for m in matches:
                for period in map(int,m[2].split(',')):
                    if period not in CLOCK:raise ValueError('period clock unpublished')
                    start,end=CLOCK[period]
                    result.append({'weekday':DAYS.index(m[1])+1,'nativePeriod':period,'startMinute':start,'endMinute':end,'classroom':where,'nativeGroupKind':kind})
    if not result or len({(x['weekday'],x['nativePeriod'],x['classroom']) for x in result})!=len(result):raise ValueError('empty or duplicate native slots')
    return result
