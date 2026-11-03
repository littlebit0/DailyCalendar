import json,re
from pathlib import Path
P=Path(__file__).parent;scope='bnue cbnu cje dgist dnue eulji ginue gist gjue gnue hansei hknu gknu hanbat'.split();entries=[];unresolved=[];ledger=[]
load=lambda p:json.loads(p.read_text())
old=load(Path('work/college-major-filters-20261012/college-a.json'))
prior={}
for x in old['entries']:
 if x['university'] in scope:prior[(x['university'],x['department'])]=x
already={}
for f in ['program-groups-b.json','program-groups-c.json','program-groups-root.json']:
 for x in load(P/f)['entries']:already[(x['university'],x.get('campus','*'),x['department'])]=x
for u in scope:
 org=load(Path('assets/timetable/organizations')/(u+'.json'));seen=set()
 for x in org['mappings']:
  if x.get('college') or not x.get('department'):continue
  key=(x.get('campus','*'),x.get('sourceLabel'),x['department'])
  if key in seen:continue
  seen.add(key);prev=prior.get((u,x['department']))
  if prev:
   en=dict(prev,university=u,campus=x.get('campus','*'),sourceLabel=x.get('sourceLabel',x['department']))
   en['kind']='ordinaryCollege' if prev.get('college') else 'universityDirect'
   if u in ['bnue','dnue'] and not prev.get('college'):
    en.update(group='심화과정',officialGroups=['심화과정'],sourceUrl='https://www.bnue.ac.kr/content/life03_02' if u=='bnue' else 'https://www.dnue.ac.kr/kor/CMS/SiteMap/SiteMap.do?mCode=MN179',sourceFile=str(P/'root-sources'/('bnue-curriculum.html' if u=='bnue' else 'dnue-org.html')),evidence='공식 '+('교육과정: 심화과정은 13개 심화전공별로 구성' if u=='bnue' else '사이트맵 대학/심화과정: 윤리교육심화과정 등 13개 학과 개별 목록')+'; 기존 원자료 학과 대응 유지. 단과대 신설하지 않음')
   entries.append(en)
  elif u in ['ginue','gjue']:
   name='ginue-deepen' if u=='ginue' else 'gjue-deepen';url='https://www.ginue.ac.kr/kor/CMS/Contents/Contents.do?mCode=MN075' if u=='ginue' else 'https://www.gjue.ac.kr/kor/contents/44'
   entries.append(dict(university=u,campus=x.get('campus','*'),sourceLabel=x.get('sourceLabel',x['department']),department=x['department'],college=None,group='심화과정',officialGroups=['심화과정'],kind='universityDirect',sourceUrl=url,sourceFile=str(P/'a-sources'/(name+'.html')),evidence='공식 심화과정변경 페이지가 학과 변경 제도로 설명하고 학교의 학과 목록을 직접 제공. 기존 학년/반→학과 대응을 유지하며 가짜 단과대 부여 안 함'))
  else:unresolved.append(dict(university=u,campus=x.get('campus','*'),department=x['department'],sourceLabel=x.get('sourceLabel'),checkedSources=[x.get('sourceUrl')],reason='현재 원문 소속 추가 확인 필요',researchComplete=False))
def add(u,name,group,url,file,evidence,college=None,**extra):
 e=dict(university=u,campus='*',sourceLabel=name,department=name,college=college,group=group,officialGroups=extra.pop('officialGroups',[group] if group else []),kind='officialProgramSystem',sourceUrl=url,sourceFile=str(file),evidence=evidence,**extra)
 if (u,'*',name) not in already:entries.append(e)
# Hanbat explicit multi-program system table (rowspan grouping retained). Published college column is recorded separately from host department.
x=load(P/'root-sources/hanbat-systems-tables.json')[1]['rows'];group=None
for i,r in enumerate(x[1:],1):
 if len(r)==4:group,name,college,host=r
 elif len(r)==3:name,college,host=r
 else:continue
 add('hanbat',name,group,'https://fund.hanbat.ac.kr/kor/sub05_030104.do',P/'root-sources/hanbat-systems.html',f'공식 다중전공 현황 표 행{i}: 전공구분={group}, 전공명={name}, 단과대학={college}, 주관학과={host}. 일반 학과 별칭으로 추측 연결하지 않음',college=college,sourceHostDepartment=host)
# GKNU complete named list, not suffix grouping or host-college inference.
x=load(P/'root-sources/gknu-systems-tables.json')
for ti in [1,2]:
 for r in x[ti]['rows'][1:]:
  add('gknu',r[1],'융합전공','https://www.gknu.ac.kr/gknu/html.do?menu_idx=41',P/'root-sources/gknu-systems.html','공식 융합전공 현황 직접 목록: '+ ' / '.join(r),sourceHostDepartment=r[2] if ti==1 else r[3])
# GIST table lists native short labels; no assumed full-label crosswalk.
x=load(P/'root-sources/gist-minors-tables.json')[0]['rows']
for r in x[1:]:
 if r[0] in ['구분','공통사항','선택과목','총이수학점']:continue
 add('gist',r[0],'부전공','https://ipa.gist.ac.kr/kr/html/sub05/05021505.html',P/'root-sources/gist-minors.html','공식 부전공 선언 페이지 분야별 이수요건 부전공 열='+r[0]+'; '+r[1],nativeProgramShortLabel=True)
# Eulji named list (retired program explicitly excluded).
x=load(P/'a-sources/eulji-convergence-tables.json')[0]['rows']
for r in x[1:]:
 if len(r)!=3 or '폐지' in r[0]:continue
 name=r[0].split('※')[0].strip()
 add('eulji',name,'창의융복합교육과정','https://www.eulji.ac.kr/?menuno=7054',P/'a-sources/eulji-convergence.html','공식 창의융복합교육과정 표 전공명='+r[0]+'; 참여학과='+r[1]+'; 참여학과를 프로그램 단과대로 추정하지 않음',sourceParticipatingDepartments=r[1])
# HKNU current named convergence list with explicit academic parent, no 2027 college invention.
url='https://hrd.hknu.ac.kr/bbs/kor/70/99049/artclView.do'
for name in ['스마트헬스케어융합전공','AI스마트팜융합전공','AI빅데이터융합전공','공공헬스케어IT융합전공','반도체융합전공','스마트애그리푸드시스템전공','탄소중립바이오시스템융합전공']:
 add('hknu',name,'AI융합학부',url,P/'root-sources/hknu-flex-guide.pdf','2026학년도 유연학사 안내자료 융합전공·융합부전공 세부 안내: 신청가능 전공(AI융합학부) 목록에 '+name+' 직접 명시. 2027 단과대 조직으로 바꾸지 않음',officialGroups=['융합전공','융합부전공'])
# HKNU all 60 microdegree titles, exact MD publication label; operator/participant only preserved, not hostcollege.
x=load(P/'root-sources/hknu-micro-6-1-tables.json')
for pg in x:
 for ti,t in enumerate(pg['tables']):
  for ri,r in enumerate(t):
   if not r or not re.fullmatch(r'\d+',r[0] or '') or not r[1]:continue
   name=' '.join(r[1].split());operator=' '.join((r[2] or '').split());participants=' '.join((r[3] or '').split())
   add('hknu',name,'소단위 전공과정(마이크로디그리)',url,P/'root-sources/hknu-micro-6-1.pdf',f'2026 소단위전공과정 리스트 PDF {pg["page"]}쪽 표{ti} 행{ri}: 연번={r[0]}, 과정명={name}, 교육운영전공={operator}, 참여전공={participants}',sourceHostDepartment=operator,sourceParticipatingDepartments=participants)
for u in scope:ledger.append({'university':u,'scope':'공식 전공제도 목록 + 현재 원소재미확인 조직의 정확 소속','entries':len([e for e in entries if e['university']==u]),'unresolved':len([e for e in unresolved if e['university']==u]),'researchComplete':False,'note':'추가 확인 진행 중; 단과대 없는 학부/심화과정은 공식 parent로 구분'})
(P/'program-groups-a.json').write_text(json.dumps({'final':False,'assignedUniversities':scope,'entries':entries,'unresolved':unresolved,'coverage':ledger},ensure_ascii=False,indent=2)+'\n')
print('entries',len(entries),'unresolved',len(unresolved))
