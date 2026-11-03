"""2026-10-23 한양대 수강편람(portal, robots Disallow) 직접 조회 - 사용자 결정(ALT_SOURCE_BRIEF 4번)에 따름.
curl만 사용, 요청 간격 1초 이상, 일반 브라우저 UA + DailyCalendar 표기, 로그인·NetFunnel 우회 없음(수강편람 조회 버튼은 nfStart 없음).
교육용 필드만 저장."""
import json,subprocess,time,math,sys,os,datetime
from pathlib import Path
sys.path.insert(0,'/Users/kimhwi/Documents/Codex/DailyCalendar/work/university-research/catalog-g')
from skku_inline_private_education_filter import filter_education
out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36 DailyCalendar/1.0 (+https://github.com/littlebit0/DailyCalendar)'
allowed={'suupNo','suupYear','suupTerm','bunbanNo','banSosokNm','banGrade','banNo','haksuNo','gwamokNm','gwamokEnm','isuGrade','isuTerm','isuTermNm','isuGbCd','isuGbNm','yungyukNm','ilbanCommonNm','hakjeom','ironSigan','silsSigan','hakGangSil','hakwiGb','hakwiNm','jojikGbNm','campusCd','campusNm','slgSosokNm','gnjSosokNm','daepyoGangsaNm','gyogangsaNms','suupViewtypeNm','suupTimes','suupRoomNms','suupTypeGb','suupTypeNm','juyaganNm','suupMsg','silsSuupCnt','ironSilsGb','suupOprGb','suupUnitCnt','teuksuNm','ironSilsNm','suupOprNm','isuJehanYn','etc','jipjungGanguiYn','chgGwamokNm','isuUnitNm','yrGbNm','pgmNm'}
base='https://portal.hanyang.ac.kr/sugang/'
cj=str(out/'cookies.txt');last=[0.0]
def curl(url,data=None):
  time.sleep(max(0,1.1-(time.monotonic()-last[0])));last[0]=time.monotonic()
  cmd=['curl','-s','-m','45','-A',UA,'-b',cj,'-c',cj,'-w','\n%{http_code}']
  if data is not None: cmd+=['-H','Content-Type: application/json+sua; charset=utf-8','--data-binary',data]
  r=subprocess.run(cmd+[url],capture_output=True,check=True).stdout
  body,_,code=r.rpartition(b'\n')
  if code!=b'200': raise RuntimeError(f'HTTP {code!r} {url}')
  return body
curl(base+'sulg.do')
form=dict(strLocaleGb='ko',strIsSugangSys='true',strDetailGb='0',notAppendQrys='true',strSuupOprGb='0',strSuupYear='2026',strSuupTerm='20',strIsuGrade='',strTsGangjwa='',strIlbanCommonGb='',strIsuGbCd='',strHaksuNo='',strChgGwamok='',strGwamok='',strDaehak='',strHakgwa='',strYeongyeok='',strPgmNm='',skipRows='0',maxRows='20')
res={'source':base+'SgscAct/findSuupSearchSugangSiganpyo.do','robots':'portal.hanyang.ac.kr/robots.txt User-agent: * Disallow: / — 사용자 결정에 따라 직접 조회','userAgent':UA,'startedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'campuses':{},'privacyRemovalAudit':[]}
for group,code in [('seoul','H0002256'),('seoul-medicine','H0002601'),('erica','Y0000316')]:
  form['strJojik']=code;rows=[];total=None;page=0
  while True:
    page+=1;form['skipRows']=str((page-1)*20)
    obj=json.loads(curl(base+'SgscAct/findSuupSearchSugangSiganpyo.do',json.dumps(form)))
    ds=next((v[0] for k,v in obj.items() if k!='success' and isinstance(v,list) and v and isinstance(v[0],dict) and 'list' in v[0]),None)
    if ds is None or 'exception' in obj: raise RuntimeError('unsupported response '+json.dumps(obj,ensure_ascii=False)[:300])
    batch=ds['list']
    if total is None: total=batch[0]['totalCnt'] if batch else 0;print(group,'total',total,flush=True)
    if any(r['totalCnt']!=total or str(r.get('suupYear'))!='2026' or str(r.get('suupTerm'))!='20' for r in batch): raise RuntimeError('census changed')
    for r in batch:
      safe={}
      for k,v in r.items():
        if k not in allowed: continue
        if isinstance(v,str):
          v,m,l=filter_education(v)
          if m or l: res['privacyRemovalAudit'].append({'course':r['suupNo'],'field':k,'masked':m,'lostLines':l})
        safe[k]=v
      rows.append(safe)
    if page>=math.ceil(total/20) or not batch: break
  if len(rows)!=total: raise RuntimeError(f'{group} {len(rows)}!={total}')
  res['campuses'][group]={'organization':code,'totalCnt':total,'pages':page,'records':rows}
  print(group,'done',len(rows),len({r['suupNo'] for r in rows}),flush=True)
res['finishedAt']=datetime.datetime.now(datetime.timezone.utc).isoformat()
(out/'hanyang-2026-2-20261023.json').write_text(json.dumps(res,ensure_ascii=False))
os.remove(cj)
print('DONE')
