"""Normal KMU anonymous public timetable SSV requests from published external form."""
import urllib.request,http.cookiejar,time,json,re
from pathlib import Path
P=Path(__file__).parent
BASE='https://edward.kmu.ac.kr'
ENTRY=BASE+'/nx/index_external.html?bWVudUlkPU01MDU3MDQ='
RS='\x1e';US='\x1f'
op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
def decode(raw):
 parts=raw.decode().split(RS);out={};params={};name=None;cols=None
 for part in parts:
  if part.startswith('Dataset:'):name=part[8:];out[name]=[];cols=None
  elif name and part.startswith('_RowType_'):cols=[x.split(':')[0] for x in part.split(US)[1:]]
  elif name and cols and part.startswith(('N'+US,'U'+US,'I'+US,'D'+US)):out[name].append(dict(zip(cols,(None if v=='\x03' else v for v in part.split(US)[1:]))))
  elif not name and '=' in part:k,v=part.split('=',1);params[k.split(':')[0]]=v
 return params,out

def query(path,args=None,fields=None,menu='M505704',pgm='P505744'):
 body='SSV:utf-8'+RS+''.join(k+'='+str(v)+RS for k,v in (args or {}).items())+'requestTimeStr='+str(int(time.time()*1000))+RS
 if fields is not None:body+='Dataset:DS_COND'+RS+'_RowType_'+US+US.join(k+':string(256)' for k in fields)+RS+'N'+US+US.join(str(v) for v in fields.values())+RS
 url=BASE+'/'+path+'?menuId='+menu+'&pgmId='+pgm
 raw=op.open(urllib.request.Request(url,data=body.encode(),headers={'Content-Type':'text/plain; charset=UTF-8','JCF_Channel_Type':'nexacroplatform/ssv;charset=UTF-8','Referer':ENTRY}),timeout=45).read()
 params,data=decode(raw)
 if params.get('ErrorCode')!='0':raise RuntimeError('Public request error '+str(params.get('ErrorCode')))
 return raw,data
if __name__=='__main__':
 op.open(ENTRY,timeout=30).read()
 query('com/MenuCtr/findExMenuOne.do',{'strMenuId':'M505704'},menu='',pgm='')
 for name,tbl in [('liberal','1'),('major','2')]:
  for scope,start,end in [('weekday','2','7'),('sunday','1','1')]:
   fields={'yy':'2026','tmGbn':'2','scCd':'','scNm':'','ltTypeGbnSh':'0','campGbn':'','dayngtGbn':'','dayGbnFr':start,'dayGbnTo':end,'lectmCdFr':'1','lectmCdTo':'16','cptnGbn':'','univCd':'','colgCd':'','hgCd':'','mjCd':'','tmtblGbn':tbl,'scheCd':'040521','lsnProgLangGbn':''}
   raw,data=query('uni/cour/UnstCtr/findOpenLtCtntInqList.do',fields=fields)
   stem='kmu-2026-2-public-'+name+('-sunday' if scope=='sunday' else '')
   (P/(stem+'.ssv')).write_bytes(raw)
   (P/(stem+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2))
   print(name,scope,{k:len(v) for k,v in data.items()})
