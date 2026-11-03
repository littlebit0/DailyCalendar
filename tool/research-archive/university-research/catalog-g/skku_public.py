"""Reproduce only published anonymous outsider Course Catalog requests."""
import urllib.request,http.cookiejar,pathlib,xml.etree.ElementTree as E,json
P=pathlib.Path(__file__).parent
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
REFERER='https://kingoinfo.skku.edu/gaia/nxui/outdex.html?language=EN&menuId=NHSSU030840M'
class Public:
 def __init__(self,lang="EN",prefix="skku-"):
  self.prefix=prefix
  self.op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
  self.op.open(urllib.request.Request(REFERER,headers={'User-Agent':UA}),timeout=30).read()
  self.post('/E_NCommon/sessionLogin',{'langCd':lang},'bootstrap-'+lang)
 def post(self,path,params,name,datasets=None,save=True):
  root=E.Element('Root',xmlns='http://www.nexacroplatform.com/platform/dataset');a=E.SubElement(root,'Parameters')
  for k,v in params.items():E.SubElement(a,'Parameter',id=k).text=str(v)
  serial='SSV:UTF-8\x1e'+''.join(k+':string='+str(v)+'\x1e' for k,v in params.items())
  for name_ds, definition in (datasets or {}).items():
   serial+='Dataset:'+name_ds+'\x1e_Const_'+''.join('\x1f'+k+':string(256)='+str(v) for k,v in definition.items())+'\x1e_RowType_\x1fCOM_CD:string(256)\x1fCD_NM:string(256)\x1e'
  data=serial.encode('utf8')
  req=urllib.request.Request('https://kingoinfo.skku.edu/gaia'+path+'.do',data=data,headers={'User-Agent':UA,'Referer':REFERER,'Content-Type':'text/plain','X-NX-Content-Type':'2'})
  raw=self.op.open(req,timeout=45).read()
  if save:(P/(self.prefix+name+'.ssv')).write_bytes(raw)
  if b'ErrorCode:int=0\x1e' not in raw:
   raise ValueError('Official response error: '+name)
  ds={}
  for b in raw.decode('utf8').split('Dataset:')[1:]:
   ls=b.split('\x1e'); ci=next(i for i,l in enumerate(ls) if l.startswith('_RowType_'))
   cols=[x.split(':')[0] for x in ls[ci].split('\x1f')]
   ds[ls[0]]=[dict(zip(cols,l.split('\x1f'))) for l in ls[ci+1:] if l and l[0] in 'NUIRD']
  if save:(P/(self.prefix+name+'.json')).write_text(json.dumps(ds,ensure_ascii=False,indent=2))
  return ds
if __name__=='__main__':
 p=Public();r=p.post('/E_NHSSU030840M/selectMenutree',{},'course-menu');print(r)
