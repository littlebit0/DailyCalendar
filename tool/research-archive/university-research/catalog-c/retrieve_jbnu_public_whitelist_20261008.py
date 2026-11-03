import urllib.request,json,pathlib,concurrent.futures
D=pathlib.Path('work/university-research/catalog-c/jbnu-current-20261008')
x=json.loads((D/'public-current-date-guard.json').read_text());assert x.get('data',x)['dmResSchedule']['strSchedule']=='Y'
keys=['ELSM_DIVCDNM','MNG_SCSBJT_CDNM','YRSA','STDTR_NO','DVCLS_NO','SBJCT_NM','ESTBL_PNT','HR_CNT','STAFFNM','CMCRS_DIVCDNM','DOW_HR_CN','DONG_RMNM_CN','LESSN_HR_DIVCDNM','LESSN_OPER_DRC_CN','SCSBJT_SCYR_NTC_CN','ATNLC_TRGT_DIVCDNM','FTF_UNTACT_DIVCDNM','LCTR_LANG_DIVCDNM','RLM_DIVCDNM','CULT_RLM_DIVCDNM','PRVT_DIVCDNM','OPNLT_DIVCDNM','CERT_DIVCDNM','RLS_YN']
def get(t):
 body={'data':{'dmReqKey':{'strYrsa':'2026','strSemstrCd':'SUSR016.020','strCertDivCd':str(t),'strLanDivcd':'CCMN101.KOR','strLang':'ko'}}};u='https://jump.jbnu.ac.kr/SCH/SucrLessnSbjctInq/list.do'
 try:
  with urllib.request.urlopen(urllib.request.Request(u,data=json.dumps(body).encode(),headers={'Content-Type':'application/json'}),timeout=30) as q:x=json.loads(q.read());rows=x.get('data',x).get('dsEstSbjList',[])
  (D/f'current-public-type{t}-education.json').write_text(json.dumps({'sourceUrl':u,'sourceType':t,'request':body,'rows':[{k:r.get(k) for k in keys} for r in rows],'excluded':['internal SBJCT_CD','staff numbers','unrendered personnel/session columns']},ensure_ascii=False,indent=2)+'\n');return(t,len(rows))
 except Exception as e:return(t,type(e).__name__,str(e))
print(list(concurrent.futures.ThreadPoolExecutor(3).map(get,[1,2,3,4,7])))
