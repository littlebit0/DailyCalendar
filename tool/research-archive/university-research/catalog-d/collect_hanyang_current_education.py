"""Current anonymous public Hanyang census; only educational whitelist persists."""
import json,time,re,math,urllib.request,http.cookiejar,datetime,os,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent.parent/'catalog-g'))
from skku_inline_private_education_filter import filter_education
from pathlib import Path
p=Path(__file__).parent
allowed={'suupNo','suupYear','suupTerm','bunbanNo','banSosokNm','banGrade','banNo','haksuNo','gwamokNm','gwamokEnm','isuGrade','isuTerm','isuTermNm','isuGbCd','isuGbNm','yungyukNm','ilbanCommonNm','hakjeom','ironSigan','silsSigan','hakGangSil','hakwiGb','hakwiNm','jojikGbNm','campusCd','campusNm','slgSosokNm','gnjSosokNm','daepyoGangsaNm','gyogangsaNms','suupViewtypeNm','suupTimes','suupRoomNms','suupTypeGb','suupTypeNm','juyaganNm','suupMsg','silsSuupCnt','ironSilsGb','suupOprGb','suupUnitCnt','teuksuNm','ironSilsNm','suupOprNm','isuJehanYn','etc','jipjungGanguiYn','chgGwamokNm','isuUnitNm','yrGbNm','pgmNm'}
base='https://portal.hanyang.ac.kr/sugang/'
op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()));op.addheaders=[('User-Agent','Mozilla/5.0')]
last=0

def get(url,data=None):
 global last
 time.sleep(max(0,.8-(time.monotonic()-last)));last=time.monotonic()
 r=op.open(urllib.request.Request(url,data=data,headers={'Content-Type':'application/json+sua; charset=utf-8'} if data else {}),timeout=45)
 if r.status!=200:raise RuntimeError('Protection or non-success status')
 return r.read()

entry=get(base+'sulg.do').decode('utf8')
active=re.sub(r'<!--.*?-->','',entry,flags=re.S)
if re.search(r'netfunnel-javascript-agent|NetFunnel_Action|nfStart\(',active,re.I):raise RuntimeError('Active queue requires normal browser; stopped')
form=dict(strLocaleGb='ko',strIsSugangSys='true',strDetailGb='0',notAppendQrys='true',strSuupOprGb='0',strSuupYear='2026',strSuupTerm='20',strIsuGrade='',strTsGangjwa='',strIlbanCommonGb='',strIsuGbCd='',strHaksuNo='',strChgGwamok='',strGwamok='',strDaehak='',strHakgwa='',strYeongyeok='',strPgmNm='',skipRows='0',maxRows='20')
checkpoint=p/'hanyang-current-education-20261008.json'
result={'researchOnly':True,'completionClaim':False,'source':base+'SgscAct/findSuupSearchSugangSiganpyo.do','checkedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'anonymous':True,'wholeAcquisitionFinished':False,'campuses':{}}
for group,code in [('seoul','H0002256'),('seoul-medicine','H0002601'),('erica','Y0000316')]:
 form['strJojik']=code;rows=[];total=None
 for page in range(1,1001):
  form['skipRows']=str((page-1)*20)
  obj=json.loads(get(base+'SgscAct/findSuupSearchSugangSiganpyo.do',json.dumps(form).encode()))
  ds=next((v[0] for k,v in obj.items() if k!='success' and isinstance(v,list) and v and isinstance(v[0],dict) and 'list' in v[0]),None)
  if ds is None or 'exception' in obj:raise RuntimeError('Public response unsupported; stopped without persistence')
  batch=ds['list']
  if total is None:total=batch[0]['totalCnt'] if batch else 0;print(group,'total',total,flush=True)
  if any(r['totalCnt']!=total or str(r.get('suupYear'))!='2026' or str(r.get('suupTerm'))!='20' for r in batch):raise RuntimeError('Census changed or wrong term')
  for r in batch:
   safe={}
   for k,v in r.items():
    if k not in allowed:continue
    if isinstance(v,str):
     v,masked,lost=filter_education(v)
     if masked or lost:result.setdefault('privacyRemovalAudit',[]).append({'course':r['suupNo'],'field':k,'masked':masked,'lostLines':lost})
    safe[k]=v
   rows.append(safe)
  result['campuses'][group]={'organization':code,'totalDisplayedRecords':total,'pagesAcquired':page,'records':rows}
  temp=checkpoint.with_suffix('.tmp');temp.write_text(json.dumps(result,ensure_ascii=False));os.replace(temp,checkpoint)
  if page%20==0:print(group,'page',page,'rows',len(rows),flush=True)
  if page>=math.ceil(total/20):break
 if len(rows)!=total:raise RuntimeError('Completeness mismatch')
result['wholeAcquisitionFinished']=True;result['finishedAt']=datetime.datetime.now(datetime.timezone.utc).isoformat()
temp=checkpoint.with_suffix('.tmp');temp.write_text(json.dumps(result,ensure_ascii=False));os.replace(temp,checkpoint)
print('DONE',sum(len({r['suupNo'] for r in c['records']}) for c in result['campuses'].values()),flush=True)
