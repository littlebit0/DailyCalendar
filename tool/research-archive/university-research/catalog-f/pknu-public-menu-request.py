from pathlib import Path
import urllib.request,json
from xml.sax.saxutils import escape
R=Path(__file__).parent
url='https://irumi.pknu.ac.kr/ezworks/noSessionController'
def dataset(name,cols,row=None):
 return '<Dataset id="'+name+'"><ColumnInfo>'+''.join('<Column id="'+k+'" type="STRING" size="256"/>' for k in cols)+'</ColumnInfo>'+('<Rows><Row>'+''.join('<Col id="'+k+'">'+escape(str(v))+'</Col>' for k,v in row.items())+'</Row></Rows>' if row else '')+'</Dataset>'
b='''<?xml version="1.0" encoding="UTF-8"?><Root xmlns="http://www.nexacroplatform.com/platform/dataset"><Parameters><Parameter id="_sqlId" type="string">menu.s03</Parameter><Parameter id="_method" type="string">getList</Parameter><Parameter id="MENU_ID" type="string">U020913</Parameter></Parameters>'''
b+=dataset('__DS_TRANS_INFO__',['strAction','strSvcID','strURL','strInDatasets','strOutDatasets'],{'strAction':'basic','strSvcID':'menu','strURL':url})
b+=dataset('_gds_userInfo',['USER_ID'])
b+=dataset('_gdsProgInfo',['PGM_PATH','MENU_ID','MENU_NM','EVNT_OCCUR_OBJ','LOCALE'],{'PGM_PATH':'unknown','MENU_ID':'unknown','MENU_NM':'unknown','LOCALE':'ko_KR'})
b+=dataset('_gdsOpInInfoDs',['opOriDsNm'])+dataset('_gdsInDsOption',['strInDatasets','datasetOption','currentRow'])+'</Root>'
(R/'pknu-menu-request.xml').write_text(b)
try:
 with urllib.request.urlopen(urllib.request.Request(url,data=b.encode(),headers={'Content-Type':'text/xml','ezclienttype':'nexacro17','User-Agent':'Mozilla/5.0'}),timeout=45) as q:
  raw=q.read();(R/'pknu-menu-response.xml').write_bytes(raw);print(q.status,len(raw),raw[:900])
except Exception as e:print(type(e).__name__,str(e))
a=json.loads((R/'requests.json').read_text());a.append({'url':url,'method':'POST','requestFile':'pknu-menu-request.xml','responseFile':'pknu-menu-response.xml','publishedSource':'work_script.xjs menu.s03 + ComApi/Common.js EzTrans noSessionController','parameters':{'_sqlId':'menu.s03','_method':'getList','MENU_ID':'U020913'}});(R/'requests.json').write_text(json.dumps(a,ensure_ascii=False,indent=2))
