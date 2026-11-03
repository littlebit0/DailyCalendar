import json,pathlib,urllib.request,concurrent.futures,hashlib
p=pathlib.Path('work/course-owner-filter-20261012/c-sources');urls=[('sogang','all','https://computing.sogang.ac.kr/en/community/academicNotice/detail/4'),('sku','인문사회과학대학','https://www.skuniv.ac.kr/college-of-humanities-and-social-science'),('sku','이공대학','https://www.skuniv.ac.kr/college-of-science-and-engineering'),('sku','예술대학','https://www.skuniv.ac.kr/college-of-arts'),('sku','미용예술대학','https://www.skuniv.ac.kr/college-of-beauty-art'),('unist','all','https://invite.unist.ac.kr/invite/main.do'),('wsu','all','https://cs.wsu.ac.kr/main/index.jsp'),('ut','all','https://www.ut.ac.kr/kor/sub03_01_01.do'),('yu','천마학부대학','https://www.yu.ac.kr/ccgs/liberal-art/faculty-all.do'),('skku','소프트웨어융합대학','https://semi.skku.edu/sw/under_sw_intro.do'),('skku','소프트웨어융합대학','https://professor.skku.edu/sco/admission/admission.do'),('sch','SCH미디어랩스','https://home.sch.ac.kr/sch/03/011000.jsp')]
def f(q):
 u,c,url=q;r=dict(university=u,college=c,sourceUrl=url)
 try:
  b=urllib.request.urlopen(url,timeout=25).read();file=p/(u+'-extra-'+hashlib.sha256(url.encode()).hexdigest()[:12]+'.html');file.write_text(b.decode('utf8','replace'));r['file']=str(file)
 except Exception as e:r['error']=str(e)
 return r
with concurrent.futures.ThreadPoolExecutor(max_workers=8)as e:r=list(e.map(f,urls))
p.joinpath('extra-receipts.json').write_text(json.dumps(r,ensure_ascii=False,indent=2));print(r)
