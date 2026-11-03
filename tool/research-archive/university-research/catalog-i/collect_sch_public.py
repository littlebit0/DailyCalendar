"""Normal anonymous public SCH timetable collection; official form schema, no queue/auth bypass."""
import http.cookiejar,json,re,urllib.request,xml.etree.ElementTree as ET
from pathlib import Path
from xml.sax.saxutils import escape
P=Path(__file__).parent
LAUNCH='https://h5.sch.ac.kr/html5/SCH/LaunchProject2.jsp?surl=5d964dca78bd84efb9cc2166a8cd43a52debb69f1493f9cb'
op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
s=op.open(LAUNCH,timeout=30).read().decode()
key=re.search(r'addVariable\("gv_schkey",\s*"([^"]+)"',s)[1]
def query(path,params,datasets=''):
 params={**params,'SCHKEY':key}
 body=('<?xml version="1.0" encoding="UTF-8"?><Root xmlns="http://www.tobesoft.com/platform/dataset"><Parameters>'+''.join('<Parameter id="'+k+'">'+escape(v)+'</Parameter>' for k,v in params.items())+'</Parameters>'+datasets+'</Root>').encode()
 raw=op.open(urllib.request.Request('https://h5.sch.ac.kr/web/'+path+'/standard.xpl',data=body,headers={'Content-Type':'text/xml; charset=UTF-8','X-Requested-With':'XMLHttpRequest','Referer':LAUNCH}),timeout=45).read()
 return raw,ET.fromstring(raw)
query('cpj',{'ncTrId':'COMFRAME_pSearchProgramByPgmCd','MENU_CD':'U014033','USER_NO':''})
# Public radio 5 (학부(과)/전공), both 대학 and 학과 selected 전체.
fields={'YY':'2026','SMT':'21','OPEN_UNIV_CD':'','OPEN_ORGN':'','SBJT_KOR_NM':''}
ds='<Dataset id="DS_SEARCH"><ColumnInfo>'+''.join('<Column id="'+k+'" type="STRING" size="256"/>' for k in fields)+'</ColumnInfo><Rows><Row>'+''.join('<Col id="'+k+'">'+v+'</Col>' for k,v in fields.items())+'</Row></Rows></Dataset>'
raw,root=query('upj',{'ncTrId':'ULETKLS_pExecuteCommonService','IN_DATASET_LIST':'','OUT_DATASET_LIST':'DS_LIST=DULE_TM_TBL_SEARCH.S_UleTmTblSearch_HTML(DS_SEARCH) '},ds)
params={x.attrib.get('id'):x.text for x in root.iter() if x.tag.endswith('Parameter')}
if params.get('ErrorCode')!='0': raise RuntimeError('Public query returned '+str(params.get('ErrorCode')))
rows=[]
for x in root.iter():
 if x.tag.endswith('Row'):rows.append({c.attrib.get('id'):c.text for c in x if c.tag.endswith('Col')})
(P/'sch-2026-2-public-all.xml').write_bytes(raw.replace(key.encode(),b'[REDACTED anonymous launch key]'))
(P/'sch-2026-2-public-all.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
print(json.dumps({'rows':len(rows),'columns':sorted({k for r in rows for k in r})},ensure_ascii=False))
