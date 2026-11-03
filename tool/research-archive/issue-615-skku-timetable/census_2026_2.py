"""성균관대 2026-2 공개 개설강좌 조회(비로그인 outdex) 전체 재집계. 강좌 키·캠퍼스·학위구분·교시 원문만 저장."""
import json,time,sys,urllib.request,http.cookiejar,pathlib
OUT=pathlib.Path(__file__).parent
G=pathlib.Path('/Users/kimhwi/Documents/Codex/DailyCalendar/work/university-research/catalog-g')
UA='Mozilla/5.0 (compatible; DailyCalendar/1.0)'
REFERER='https://kingoinfo.skku.edu/gaia/nxui/outdex.html?menuId=NHSSU030840M'
op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
last=[0.0]
def wait():
    time.sleep(max(0,0.6-(time.monotonic()-last[0])));last[0]=time.monotonic()
def post(path,params):
    wait()
    serial='SSV:UTF-8\x1e'+''.join(k+':string='+str(v)+'\x1e' for k,v in params.items())
    req=urllib.request.Request('https://kingoinfo.skku.edu/gaia'+path+'.do',data=serial.encode(),headers={'User-Agent':UA,'Referer':REFERER,'Content-Type':'text/plain','X-NX-Content-Type':'2'})
    raw=op.open(req,timeout=45).read()
    if b'ErrorCode:int=0\x1e' not in raw:raise ValueError('official error '+path)
    ds={}
    for b in raw.decode('utf8').split('Dataset:')[1:]:
        ls=b.split('\x1e');ci=next(i for i,l in enumerate(ls) if l.startswith('_RowType_'))
        cols=[x.split(':')[0] for x in ls[ci].split('\x1f')]
        ds[ls[0]]=[dict(zip(cols,l.split('\x1f'))) for l in ls[ci+1:] if l and l[0] in 'NUIRD']
    return ds
def q(path,action,params,out):
    p={**params,'_TRANSACTION_ID':action,'_FIRST_OUT_DS_NM':out,'_ALL_OUT_DS_NM':out+'='+out,'_MENU_ID':'EXT_SCHEDULE','_PGM_ID':'NHSSU030840M'}
    d=post(path+'/'+action,p)
    if out not in d:raise ValueError('dataset absent')
    return d[out]
wait();op.open(urllib.request.Request(REFERER,headers={'User-Agent':UA}),timeout=30).read()
post('/E_NCommon/sessionLogin',{'langCd':'KO'})
major=json.loads((G/'skku-ko-major-all-2026-2.json').read_text());general=json.loads((G/'skku-ko-general-all-2026-2.json').read_text())
new={};idx=[]
KEEP=('CAMPUS_GB','CAMPUS_NM','JUKYONGHAKWI_GB','HAKWI_NAME','HAKSU_NO_BUNBAN','GWAMOK_NAME','GYOSI_NAME','GAESUL_YEAR','GAESUL_TERM')
def keep(rows):
    for r in rows:
        if r['GAESUL_YEAR']!='2026' or r['GAESUL_TERM']!='20':raise ValueError('term')
        new.setdefault(r['HAKSU_NO_BUNBAN'],{k:r.get(k) for k in KEEP})
for m in major['index']:
    p={k:m[k] for k in ('YEAR','TERM','HAKGWA_CD','ROAD_MAP','CAMPUS_GB','HAK_JIBJUNG')}
    rows=q('/E_NHSSU900020M','selectMain',p,'dsGrdMain');keep(rows);idx.append(['major',p['CAMPUS_GB'],p['HAKGWA_CD'],len(rows)])
for campus in ('1','2','3'):
    common={'YEAR':'2026','TERM':'20','CAMPUS_GB':campus,'HAK_JIBJUNG':'0'};subj=set()
    for g in general['index']:
        if g['campus']!=campus:continue
        rows=q('/E_NHSSU900010M','selectMain02',{**common,'YUNGYUK_ETC_CD':g['category']},'dsGrdMain02');subj.update(r['HAKSU_NO'] for r in rows);idx.append(['general',campus,g['category'],len(rows)])
    for code in sorted(subj):
        rows=q('/E_NHSSU900010M','selectMain03',{**common,'HAKSU_NO':code},'dsGrdMain03');keep(rows)
(OUT/'census-2026-2.json').write_text(json.dumps({'checkedAt':time.strftime('%Y-%m-%dT%H:%M:%S%z'),'queries':len(idx),'count':len(new),'records':list(new.values())},ensure_ascii=False,indent=1))
print(len(idx),len(new))
