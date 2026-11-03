"""Recheck three ordinary plans via the published anonymous plan form."""
import hashlib
import json
import pathlib
import time
import urllib.parse
import urllib.request
P = pathlib.Path(__file__).resolve().parent
rows = json.loads((P / 'dgist2026-2-2020-current-recheck-20261008.json').read_text())
old = {(x['code'], x['section']): x for x in json.loads((P / 'dgist-current-published-plans-educational.json').read_text())}
allowed = {'SBJT_NO','CLSS_NO','SBJT_NM','CPTN_DCD','TMCNT','INFO','LT_SUMA','LT_PURO','LT_POLY','LSN_MTHD','ETC','SCHETCHUL','ALL_CNTN','PWEEK_YN'}
results = []
for code, section in [('BE206', '04'), ('BR202', '01')]:
    row = next(x for x in rows if x['SBJT_NO'] == code and x['CLSS_NO'] == section)
    assert int(row['LECPLN_CNT']) > 0
    form = {k: row[v] for k,v in {'conYear':'SHYY','conTerm':'SHTM_DCD','conOrgn':'ORGN_CLSF_DCD','conSust':'ASGN_SUST_CD','conCors':'ASGN_CORS_DCD','conClss':'CLSS_NO','conSbjtNo':'SBJT_NO'}.items()}
    form.update(conLang='ko',pageNum='1',pageSize='100',commonProgramId='UcseLsnPdocMngt')
    time.sleep(0.7)
    url = 'https://welcome.dgist.ac.kr/ucs/ucseLsnPdocMngt/lecInfo.do'
    with urllib.request.urlopen(urllib.request.Request(url,data=urllib.parse.urlencode(form).encode()),timeout=35) as response:
        data = json.loads(response.read())
    assert data['SBJT_NO'] == code and data['CLSS_NO'] == section
    fields = {k:v for k,v in data.items() if k in allowed}
    results.append({'code':code,'section':section,'sourceUrl':url,'publicForm':form,'fields':fields,'previousEducationFieldsUnchanged':fields == old[(code,section)]['fields'],'completionClaim':False})
file = P / 'dgist-two-additional-plan-recheck-20261008.json'
file.write_text(json.dumps(results,ensure_ascii=False,indent=2))
print('Two additional exact public plans rechecked; education unchanged:',all(x['previousEducationFieldsUnchanged'] for x in results))
print('SHA256',hashlib.sha256(file.read_bytes()).hexdigest())
