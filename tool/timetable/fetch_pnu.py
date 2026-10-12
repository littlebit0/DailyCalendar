"""Collect the anonymous public PNU undergraduate course search and restrictions.
Uses the site's published RSA request envelope and anonymous menu authorization.
Never logs in, persists browser credentials, or exports temporary request tokens.
Five published category filters run serially; restriction requests are paced.
Requires cryptography already available in the bundled document runtime.
"""
import argparse,re,json,time,urllib.request,http.cookiejar
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
args.output.mkdir(parents=True,exist_ok=True)
from cryptography.hazmat.primitives.asymmetric import rsa,padding
s=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()));base='https://onestop.pusan.ac.kr'
h=s.open(base+'/page?menuCD=000000000000335',timeout=30).read().decode()
key=rsa.RSAPublicNumbers(int(re.search(r"RSAExponent = '([^']+)'",h)[1],16),int(re.search(r"RSAModulus = '([^']+)'",h)[1],16)).public_key()
token=re.search(r'scwin.token = "([^"]+)"',h)[1]
auth=None
def query(path,data):
 data={**data,'locale':'0001'}
 inner=json.dumps({'_data':json.dumps(data,separators=(',',':'),ensure_ascii=False),'AUTH_STR':auth},separators=(',',':'),ensure_ascii=False).encode()
 # Same published RSA PKCS1 v1.5 encoding and 200-byte chunks as site's gfn_ajax_request.
 chunks=[];chunk='';size=0
 for ch in inner.decode():
  chunk+=ch;size+=len(ch.encode())
  if size>200:chunks.append(chunk.encode());chunk='';size=0
 if chunk:chunks.append(chunk.encode())
 payload={'_data':','.join(key.encrypt(c,padding.PKCS1v15()).hex() for c in chunks)}
 r=s.open(urllib.request.Request(base+path,data=json.dumps(payload).encode(),headers={'Content-Type':'application/json','AJAX':'true','X-CSRF-TOKEN':token,'Referer':base+'/page?menuCD=000000000000335'}),timeout=40)
 d=json.loads(r.read())
 if str(d.get('statusCode','200'))!='200':raise ValueError('Public query rejected: '+str(d.get('statusCode')))

 return d
info=query('/global/info',{'menuCD':'000000000000335'})
menu=next(x for x in info['_Menu'] if x['MENU_CD']=='000000000000335');auth=menu['AUTH_STR']
term=info['termInfo']
if term['SYEAR']!='2026' or term['TERM_GCD']!='0020':raise ValueError('Unexpected current PNU term')
all_rows=[]
counts={}
for category in ['2','3','5','4','1']:
 time.sleep(.5)
 d=query('/ost/cls/atlectmanual/atlectmanual/selectAtlectManual_v2025',{'SCH_SYEAR':'2026','SCH_TERM_GCD':'0020','SCH_COLL_GRAD_GCD':'0001','SCH_GRAD_GCD':'0000','SCH_COLL_CD':'','SCH_DEPT_CD':'','SEARCH_GBN':'1','SCH_SUBJ_GBN':category,'SCH_DETAIL':'','SCH_SUBJ_NM':'','SCH_COURSE_COLL_GRAD_GCD':'0001','SCH_PNU_CAPBLTY_GCD':'','SCH_NATIVE_LANG_LECT_GCD':'','sch_AllOC_CHK':'N','pageSize':10000,'pageIndex':0})
 rows=d['data']
 if len(rows)!=int(d['pageInfo']['totCnt']):raise ValueError('Incomplete PNU category result')
 if any(r['COURSE_COLL_GRAD_GCD']!='0001' or r['SYEAR']!='2026' or r['TERM_GCD']!='0020' for r in rows):raise ValueError('Wrong PNU course scope')
 counts[category]=len(rows)
 all_rows.extend(rows)
 print('Category',category,len(rows),flush=True)
keep=['SUBJ_NO','CLASS_NO','SUBJ_NM','SUBJ_GCD_NM','MNG_DEPT_NM','TIMETABLE_SUMMARY_INFO','CRDT','PROF_NM','STDT_YEAR_NM','REMARK','ALL_CYBER','NATIVE_LANG_NM','COURSE_COLL_GRAD_GCD','SYEAR','TERM_GCD']
if len({(r['SUBJ_NO'],r['CLASS_NO']) for r in all_rows})!=len(all_rows):raise ValueError('Duplicate PNU identities')
courses=[]
for i,row in enumerate(all_rows):
 time.sleep(.5)
 restriction=query('/ost/cls/atlectmanual/atlectmanual/selectAtlectManualPrecaution',row)['data']
 if len(restriction)!=1 or 'MSG' not in restriction[0]:raise ValueError('Unexpected PNU restriction')
 current={k:row.get(k) for k in keep}
 current['restriction']=restriction[0]['MSG']
 courses.append(current)
 (args.output/'courses.partial.json').write_text(json.dumps(courses,ensure_ascii=False))
 if (i+1)%50==0:print('Restrictions',i+1,'/',len(all_rows),flush=True)
(args.output/'courses.json').write_text(json.dumps(courses,ensure_ascii=False))
(args.output/'manifest.json').write_text(json.dumps({'complete':True,'year':2026,'semester':'2','sourceUrl':base+'/page?menuCD=000000000000335','categoryCounts':counts,'total':len(courses)},ensure_ascii=False,indent=2)+'\n')
print('Complete',len(courses),flush=True)
