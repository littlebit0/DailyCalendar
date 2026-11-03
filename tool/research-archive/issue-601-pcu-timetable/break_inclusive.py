import json,sys
p=sys.argv[1]; d=json.load(open(p)); 
LET={490:570,570:660,660:750,810:900,900:990,990:1080,1080:1170,1170:1260,1260:1350}
# letter slot = start .. start+90 (Z capped at A start 570); numeric slot = end+10
def slot(s):
    a,b=s['startMinute'],s['endMinute']
    if b-a==75 and a in LET: return a, (570 if a==490 else a+90)
    assert a%60==0 and b%60==50,(a,b); return a,b+10
before=after=changed=merged=0
for c in d['courses']:
    sc=c['schedules']; before+=len(sc)
    if not sc: continue
    items=[]
    for i,s in enumerate(sc):
        a,b=slot(s); n=dict(s); n['startMinute']=a; n['endMinute']=b; items.append((i,n))
    order=sorted(items,key=lambda t:(t[1]['weekday'],t[1].get('classroom') or '',t[1]['startMinute']))
    out=[]
    for i,n in order:
        if out and out[-1][1]['weekday']==n['weekday'] and out[-1][1].get('classroom')==n.get('classroom') and n['startMinute']-out[-1][1]['endMinute']<60:
            out[-1][1]['endMinute']=max(out[-1][1]['endMinute'],n['endMinute']); out[-1][2]=True
        else: out.append([i,n,False])
    out.sort(key=lambda t:t[0])
    new=[t[1] for t in out]; after+=len(new)
    if len(new)<len(sc): merged+=1
    changed+=1; c['schedules']=new
json.dump(d,open(p,'w'),ensure_ascii=False,indent=2); open(p,'a').write('\n')
print(before,after,changed,merged)
