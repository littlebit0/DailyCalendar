from pathlib import Path
import urllib.request,json,sys
from xml.sax.saxutils import escape
R=Path(__file__).parent
name,sql,args=sys.argv[1:];args=json.loads(args);url='https://irumi.pknu.ac.kr/ezworks/noSessionController'
def dataset(name,cols,row=None):
 return '<Dataset id="'+name+'"><ColumnInfo>'+''.join('<Column id="'+k+'" type="STRING" size="256"/>' for k in cols)+'</ColumnInfo>'+('<Rows><Row>'+''.join('<Col id="'+k+'">'+escape(str(v))+'</Col>' for k,v in row.items())+'</Row></Rows>' if row else '')+'</Dataset>'
b='<?xml version="1.0" encoding="UTF-8"?><Root xmlns="http://www.nexacroplatform.com/platform/dataset"><Parameters>'+''.join('<Parameter id="'+k+'" type="string">'+escape(str(v))+'</Parameter>' for k,v in dict(_sqlId=sql,_method='getList',**args).items())+'</Parameters>'
b+=dataset('__DS_TRANS_INFO__',['strAction','strSvcID','strURL','strInDatasets','strOutDatasets'],{'strAction':'uni','strSvcID':'menu','strURL':url})
b+=dataset('_gds_userInfo',['USER_ID'])
b+=dataset('_gdsProgInfo',['PGM_PATH','MENU_ID','MENU_NM','EVNT_OCCUR_OBJ','LOCALE'],{'PGM_PATH':'uni::cour/open/LtPdocInq.xfdl','MENU_ID':'U020913','MENU_NM':'강의계획서조회','LOCALE':'ko_KR'})
b+=dataset('_gdsOpInInfoDs',['opOriDsNm'])+dataset('_gdsInDsOption',['strInDatasets','datasetOption','currentRow'])+'</Root>'
(R/(name+'-request.xml')).write_text(b)
try:
 with urllib.request.urlopen(urllib.request.Request(url,data=b.encode(),headers={'Content-Type':'text/xml','ezclienttype':'nexacro17','User-Agent':'Mozilla/5.0'}),timeout=45) as q:
  raw=q.read();(R/(name+'.xml')).write_bytes(raw);print(q.status,len(raw),raw[:900])
except Exception as e:print(type(e).__name__,str(e))
a=json.loads((R/'requests.json').read_text());a.append({'url':url,'method':'POST','requestFile':name+'-request.xml','responseFile':name+'.xml','publishedSource':'LtPdocInq.xfdl / UniCombo.xjs + ComApi/Common.js EzTrans noSessionController','parameters':dict(_sqlId=sql,_method='getList',**args)});(R/'requests.json').write_text(json.dumps(a,ensure_ascii=False,indent=2))
