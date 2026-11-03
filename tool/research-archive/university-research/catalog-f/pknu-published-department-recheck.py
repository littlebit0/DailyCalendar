"""Use exact currently published fn_makeDeptCmb values, not old blank menu/defaults."""
import json,pathlib,urllib.request,urllib.parse,http.cookiejar,subprocess,os,signal,xml.etree.ElementTree as ET
from xml.sax.saxutils import escape
p=pathlib.Path(__file__).parent;matches=[int(x.split(None,1)[0])for x in subprocess.check_output(['ps','-eo','pid,args'],text=True).splitlines()if x.rstrip().endswith(' work/university-research/catalog-f/pknu-all-syllabus-batch.py')]
if len(matches)>1:raise SystemExit('Duplicate collectors; stop request')
pid=matches[0] if matches else None
if pid:os.kill(pid,signal.SIGSTOP)
try:
 jar=http.cookiejar.CookieJar();op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar));entry='https://irumi.pknu.ac.kr/nxui/launch.html?screenid=Desktop_screen_quick&menuId=U020913';op.open(urllib.request.Request(entry,headers={'User-Agent':'Mozilla/5.0'}),timeout=35).read()
 args={'_sqlId':'BaseStdQryPopup.findSustAndMjEtcList','_method':'getList','START_DEPT':'T','GRP_FG':'3','PERM_YN':'','ETC_YN':'Y','PGM_CD':'U020913','CYBER_YN':'N','ORDER':'DECODE(AA.USE_FG,1,1,2), AA.DEPT_KOR_NM'};url='https://irumi.pknu.ac.kr/ezworks/noSessionController'
 def ds(name,cols,rows=[]):return '<Dataset id="'+name+'"><ColumnInfo>'+''.join('<Column id="'+k+'" type="STRING" size="256"/>'for k in cols)+'</ColumnInfo><Rows>'+''.join('<Row>'+''.join('<Col id="'+k+'">'+escape(str(v))+'</Col>'for k,v in r.items())+'</Row>'for r in rows)+'</Rows></Dataset>'
 b='<?xml version="1.0" encoding="UTF-8"?><Root xmlns="http://www.nexacroplatform.com/platform/dataset"><Parameters>'+''.join('<Parameter id="'+k+'" type="string">'+escape(v)+'</Parameter>'for k,v in args.items())+'</Parameters>'
 b+=ds('__DS_TRANS_INFO__',['strAction','strSvcID','strURL','strInDatasets','strOutDatasets'],[{'strAction':'basic','strSvcID':'fn_makeDeptCmb','strURL':url,'strInDatasets':'ds_comboOpIn=ds_comboOpIn'}]);b+=ds('_gds_userInfo',['USER_ID'])+ds('_gdsProgInfo',['PGM_PATH','MENU_ID','MENU_NM','LOCALE'],[{'PGM_PATH':'uni::cour/open/LtPdocInq.xfdl','MENU_ID':'U020913','MENU_NM':'강의계획서조회','LOCALE':'ko_KR'}]);b+=ds('_gdsOpInInfoDs',['opOriDsNm'],[{'opOriDsNm':'ds_comboOpIn'}])+ds('ds_comboOpIn',['USE_FG'],[{'USE_FG':'0'},{'USE_FG':'1'}])+ds('_gdsInDsOption',['strInDatasets','datasetOption','currentRow'])+'</Root>'
 (p/'pknu-exact-published-dept-request.xml').write_text(b);r=op.open(urllib.request.Request(url,data=b.encode(),headers={'User-Agent':'Mozilla/5.0','Content-Type':'text/xml','ezclienttype':'nexacro17','Referer':entry}),timeout=35);raw=r.read();(p/'pknu-exact-published-dept-response.xml').write_bytes(raw)
 audit={'url':url,'method':'POST','parameters':args,'source':'actual fn_makeDeptCmb LtPdocInq U020913 + UniCombo defaults N and USE_FG0/1','status':r.status,'bytes':len(raw),'cookieValuesSaved':False}
 try:
  root=ET.fromstring(raw);rows=[{v.attrib['id']:v.text for v in x}for x in root.findall('.//{*}Row')];audit['rowCount']=len(rows);audit['errorCode']=root.findtext('.//{*}Parameter[@id="ErrorCode"]');(p/'pknu-exact-published-dept-rows.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
 except Exception as e:audit['responseParsingError']=type(e).__name__;audit['htmlGuard']=b'<html' in raw.lower();audit['explicitWebFirewallBlock']=b'Web firewall security policies' in raw
 (p/'pknu-exact-published-dept-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2));print(audit)
finally:
 if pid:os.kill(pid,signal.SIGCONT)
