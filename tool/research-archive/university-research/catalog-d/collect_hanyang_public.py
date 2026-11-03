"""Official anonymous public catalog; same20-row paging as visible UI. No login/queue tokens."""
from pathlib import Path
import urllib.request,http.cookiejar,json,time,math
p=Path(__file__).parent
base='https://portal.hanyang.ac.kr/sugang/'
op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
op.addheaders=[('User-Agent','Mozilla/5.0')]
op.open(base+'sulg.do',timeout=30).read()
form=dict(strLocaleGb='ko',strIsSugangSys='true',strDetailGb='0',notAppendQrys='true',strSuupOprGb='0',strSuupYear='2026',strSuupTerm='20',strIsuGrade='',strTsGangjwa='',strIlbanCommonGb='',strIsuGbCd='',strHaksuNo='',strChgGwamok='',strGwamok='',strDaehak='',strHakgwa='',strYeongyeok='',strPgmNm='',skipRows='0',maxRows='20')
for group,code in [('seoul','H0002256'),('seoul-medicine','H0002601'),('erica','Y0000316')]:
 raw=p/('hanyang-2026-2-'+group+'-raw');raw.mkdir(exist_ok=True)
 form['strJojik']=code;rows=[];total=None
 for page in range(1,1001):
  form['skipRows']=str((page-1)*20)
  b=op.open(urllib.request.Request(base+'SgscAct/findSuupSearchSugangSiganpyo.do',data=json.dumps(form).encode(),headers={'Content-Type':'application/json+sua; charset=utf-8'}),timeout=40).read()
  obj=json.loads(b)
  ds=next((v[0] for k,v in obj.items() if k!='success' and isinstance(v,list) and v and isinstance(v[0],dict) and 'list' in v[0]),None)
  if ds is None:raise RuntimeError('No public catalog dataset: '+str(obj)[:200])
  batch=ds['list'];(raw/f'page{page:03d}.json').write_bytes(b)
  if total is None:total=batch[0]['totalCnt'] if batch else 0;print(group,'total',total,flush=True)
  if any(r['totalCnt']!=total for r in batch):raise RuntimeError('Live catalog changed during acquisition')
  rows.extend(batch)
  if page%20==0:print(group,'page',page,'rows',len(rows),flush=True)
  if page>=math.ceil(total/20):break
  time.sleep(.12)
 if len(rows)!=total:raise RuntimeError('Page completeness mismatch')
 (p/f'hanyang-2026-2-{group}-all.json').write_text(json.dumps({'source':base+'SgscAct/findSuupSearchSugangSiganpyo.do','year':2026,'term':'20','organization':code,'totalDisplayedRecords':total,'records':rows},ensure_ascii=False,indent=2))
 print('DONE',group,total,'unique suupNo',len({r['suupNo'] for r in rows}),flush=True)
