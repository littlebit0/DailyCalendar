import json,collections,re,sys
rows=json.load(open('rows.json'))
H8=['학년','이수구분','교과목코드','교과목명','학점','시수','분반','담당교수']
tt=[r for r in rows if r['hdr'][:8]==H8]
def norm(s): return re.sub(r'\s+','',s or '')
def rec(r):
    h=r['hdr']; c=r['cells']; f=dict(zip(h,c))
    if '강의실및강의시간' in f:
        time=f['강의실및강의시간']; room=None
    else:
        time=f.get('강의시간'); room=f.get('강의실')
    return {'year':norm(f['학년']),'cls':norm(f['이수구분']),'code':norm(f['교과목코드']),'name':norm(f['교과목명']),
            'cr':norm(f['학점']),'hr':norm(f['시수']),'sec':norm(f['분반']),'prof':norm(f['담당교수']),
            'time':norm(time) if time is not None else None,'room':norm(room) if room is not None else None,
            'note':(f.get('비고') or '').strip(),'page':r['page'],'heading':r['heading'],'raw':c,'heads':r['heads'],'hdr':h}
recs=[rec(r) for r in tt]
by=collections.defaultdict(list)
for x in recs: by[(x['code'],x['sec'])].append(x)
json.dump({f'{k[0]}-{k[1]}':v for k,v in by.items()},open('official.json','w'),ensure_ascii=False,indent=0)
