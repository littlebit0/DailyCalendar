from pathlib import Path
import urllib.request,urllib.parse,http.cookiejar,json
p=Path(__file__).parent
op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
op.addheaders=[('User-Agent','Mozilla/5.0')]
base='https://portal.hanyang.ac.kr/sugang/'
op.open(base+'sulg.do',timeout=30).read()
form=dict(strLocaleGb='ko',strIsSugangSys='true',strDetailGb='0',notAppendQrys='true',strSuupOprGb='0',strJojik='H0002256',strSuupYear='2026',strSuupTerm='20',strIsuGrade='',strTsGangjwa='',strIlbanCommonGb='',strIsuGbCd='',strHaksuNo='',strChgGwamok='',strGwamok='',strDaehak='',strHakgwa='',strYeongyeok='',strPgmNm='',skipRows='0',maxRows='20')
# Public menu source executes this normal search directly; no nfStart is present in btn_Find/goPage.
r=op.open(urllib.request.Request(base+'SgscAct/findSuupSearchSugangSiganpyo.do',data=json.dumps(form).encode(),headers={'Content-Type':'application/json+sua; charset=utf-8'}),timeout=30)
b=r.read();(p/'hanyang-seoul-page001-public.json').write_bytes(b)
print(r.status,len(b),r.headers.get('Content-Type'));print(b[:350].decode(errors='replace'))
