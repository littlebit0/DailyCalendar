"""Normal anonymous public catalog collection, official NetFunnel before each query.
Source evidence: yonsei-netfunnel.js, yonsei-handb.js, user-modules and Cleopatra.
No queue/cookie values are logged or saved. Capped queries remain explicitly incomplete.
"""
import urllib.request, urllib.parse, http.cookiejar, json, re, time, base64
from pathlib import Path

P = Path(__file__).parent
RAW = P / 'yonsei-2026-2-public-raw'
RAW.mkdir(exist_ok=True)
BASE = 'https://underwood1.yonsei.ac.kr'
op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
op.addheaders = [('User-Agent', 'Mozilla/5.0')]
op.open(BASE + '/com/lgin/SsoCtr/initExtPageWork.do?link=handbList&locale=ko', timeout=30).read()

def queue(opcode, values):
    params = dict(opcode=str(opcode), nfid='0', prefix=f'NetFunnel.gRtype={opcode};', js='yes')
    params.update(values)
    url = 'https://nfl.yonsei.ac.kr:443/ts.wseq?' + urllib.parse.urlencode(params) + '&' + str(int(time.time()*1000))
    text = op.open(url, timeout=30).read().decode()
    m = re.search(r"result\s*=\s*['\"]([0-9]{4}:[0-9]{3}:[^'\"]*)['\"]", text)
    if not m: raise RuntimeError('Unrecognized queue response; stopped')
    typ, code, value = m.group(1).split(':', 2)
    return int(code), dict(urllib.parse.parse_qsl(value, keep_blank_values=True))

def form(path, cond):
    code, fields = queue(5101, dict(sid='service_1', aid='act_2'))
    while code == 201:
        ttl = int(fields.get('ttl', '0'))
        if ttl <= 0 or not fields.get('key'): raise RuntimeError('Invalid queue instructions')
        time.sleep(min(ttl,30))
        code, fields = queue(5002,dict(key=fields['key'],ttl=str(min(ttl,30)),sid='service_1',aid='act_2'))
    if code != 200 or not fields.get('key'): raise RuntimeError('Queue did not admit request')
    try:
        data = {'@d1#'+k:str(v) for k,v in cond.items()}
        data.update({'@d#':'@d1#','@d1#':'dmCond','@d1#tp':'dm'})
        menu=(float(105675)*3+46)*7;menu=menu*menu*menu+78
        pgm=(float(4512)*5+48)*9;pgm=pgm*pgm+782
        data.update(_menuId=base64.b64encode(format(menu,'.0f').encode()).decode(),
                    _pgmId=base64.b64encode(format(pgm,'.0f').encode()).decode(),_menuNm='')
        req=urllib.request.Request(BASE+path,data=urllib.parse.urlencode(data).encode(),headers={
            'Content-Type':'application/x-www-form-urlencoded; charset=UTF-8','X-Requested-With':'XMLHttpRequest'})
        obj=json.loads(op.open(req,timeout=30).read())
        if obj.get('_METADATA_',{}).get('success') is False: raise RuntimeError('Public query returned unsuccessful metadata')
        return {k:v for k,v in obj.items() if k.startswith('ds')}
    finally:
        result,_ = queue(5004,dict(key=fields['key']))
        if result != 200: raise RuntimeError('Queue completion unsuccessful')
        time.sleep(.35)

def org(ds, campus='%', college='%'):
    c=dict(dsNm=ds,level='B',lv1=campus,lv2=college,lv3='%',sysinstDivCd='%',
           univGbn='A',syy='2026',smtDivCd='20',findAuthGbn='8')
    return form('/sch/sles/SlescsCtr/findSchSlesHandbList.do',c).get(ds,[])

scope=[]; records=[]; capped=[]
for campus in ['s1','s2','s7','s8']:
    colleges=org('dsUnivCd',campus)
    (RAW/f'{campus}-colleges.json').write_text(json.dumps(colleges,ensure_ascii=False,indent=2))
    for college in colleges:
        cc=college['deptCd']; departments=org('dsFaclyCd',campus,cc) if cc!=campus else []
        (RAW/f'{campus}-{cc}-departments.json').write_text(json.dumps(departments,ensure_ascii=False,indent=2))
        for dept in departments or [dict(deptCd='',deptNm='전체')]:
            dc=dept['deptCd'];name=f'{campus}-{cc}-{dc or "all"}.json'
            target=RAW/name
            if target.exists(): rows=json.loads(target.read_text())['dsSles251']
            else:
                c={k:'' for k in ['hy','cdt','kwdDivCd','kwd','allKwd','engChg','campsDivCd','stuno']}
                c.update(syy='2026',smtDivCd='20',campsBusnsCd=campus,univCd=cc,faclyCd=dc,
                         searchGbn='1',prnGbn='false',lang='ko')
                obj=form('/sch/sles/SlessyCtr/findAtnlcHandbList.do',c)
                if 'dsSles251' not in obj: raise RuntimeError('Missing catalog dataset')
                rows=obj['dsSles251'];target.write_text(json.dumps(obj,ensure_ascii=False,indent=2))
            info=dict(campus=campus,college=college['deptNm'],collegeCode=cc,
                      department=dept['deptNm'],departmentCode=dc,count=len(rows),capped=len(rows)>=200)
            scope.append(info)
            if len(rows)>=200:capped.append(info)
            records.extend(rows)
            print(campus,cc,dc,len(rows),'CAPPED' if len(rows)>=200 else '',flush=True)
            (P/'yonsei-2026-2-public-progress.json').write_text(json.dumps(dict(scopes=scope,capped=capped,
                displayRecords=len(records),completionClaim=False),ensure_ascii=False,indent=2))
(P/'yonsei-2026-2-public-all.json').write_text(json.dumps(dict(scopes=scope,capped=capped,
    records=records,completionClaim=False),ensure_ascii=False,indent=2))
print('DONE scope',len(scope),'display records',len(records),'capped',len(capped),flush=True)
