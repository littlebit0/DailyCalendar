import json,re,sys
from pathlib import Path
sys.path.insert(0,'work/college-major-filters-20261012')
from html_tree_c import Tree
P=Path('work/all-university-completion-20261012')
packet=json.loads((P/'program-groups-root.json').read_text())
entries={(r['university'],r['campus'],r['sourceLabel'],r['department']):r for r in packet['entries']}
norm=lambda s:re.sub(r'\s+','',s or '').replace('ㆍ','·').replace('·','·')
def put(u,r,col,group,url,file,evidence):
 e={'university':u,'campus':r['campus'],'sourceLabel':r['sourceLabel'],'department':r['department'],'college':col,'kind':'programGroup' if group=='융합전공' else 'college' if col else 'universityDirect','sourceUrl':url,'sourceFile':str(file),'evidence':evidence}
 if group:e['group']=group
 entries[(u,e['campus'],e['sourceLabel'],e['department'])]=e
asset=json.loads(Path('assets/timetable/organizations/hanyang.json').read_text())
for campus in ['seoul','erica']:
 f=Path('work/college-major-filters-20261012/sources-a',f'hanyang-{campus}-nav.html')
 tree=Tree(f.read_text()).root
 for h in tree.nodes('h2')[1:]:
  parent=h.txt();anchors=h.p.p.p.nodes('a')
  for a in anchors:
   label=a.txt()
   if label=='홈페이지 바로가기 >':continue
   # Exact explicit constituents inside a faculty's own roster link.
   names={label}
   parts=re.split(r'[(),]',label)
   names.update(s.strip() for s in parts if s.strip())
   for part in list(names):
    # Published composite faculty+major links name this actual degree.
    if ' ' in part and part.endswith('전공'):names.add(part.rsplit(' ',1)[1])
   for r in asset['mappings']:
    if r['campus'] not in ['*',campus] or norm(r['department']) not in {norm(s) for s in names}:continue
    is_system=label.startswith('융합전공 ')
    put('hanyang',r,None if is_system else parent,'융합전공' if is_system else None,'https://www.hanyang.ac.kr/'+('s' if campus=='seoul' else 'e')+'_college_department-info',f,f'공식 {campus} 대학/학과 소개의 {parent} 영역에 실제 학부/전공 링크 「{label}」. '+('융합전공으로 명시된 별도 제도; 행정 대학을 전공 소속으로 치환하지 않음.' if is_system else '정규 학위 편제의 정확한 명칭.'))
# Actual current additional-program table overrides hosting-college headings.
f=Path('work/college-major-filters-20261012/sources-a/hanyang-major-fusion.html')
t=Tree(f.read_text()).root.nodes('table')[0]
for tr in t.nodes('tr'):
 cells=[x for x in tr.cs if x.tag in ['td','th']]
 if not cells:continue
 name=cells[0].txt()
 for r in asset['mappings']:
  if r['campus'] in ['erica','*'] and norm(r['department'])==norm(name):
   put('hanyang',r,None,'융합전공','https://site.hanyang.ac.kr/en/web/ehaksa/major_fusion',f,f'ERICA 공식 융합전공 페이지 참여 학과 및 최소전공이수학점 표의 「{name}」. 참여/관리학과는 전공의 단과대 소속으로 사용하지 않음.')
# College brochure names the same native advanced degree programs explicitly.
f=Path('work/college-major-filters-20261012/sources-a/hanyang-atc-pdf.txt')
for r in asset['mappings']:
 if r['campus'] in ['erica','*'] and r['department'] in ['신소재·반도체공학전공','반도체·디스플레이공학전공','지능정보양자공학전공','바이오나노공학전공','분자의약전공']:
  put('hanyang',r,'첨단융합대학',None,'https://atc.hanyang.ac.kr/',f,'공식 첨단융합대학 2026 모집인원 포함 소개책자 7쪽 실제 학부 구성 및 개별 전공 목록. 이름의 융합만으로 추가 전공제도라고 분류하지 않음.')
# Reuse exact official primary roster evidence already captured in prior research.
asset=json.loads(Path('assets/timetable/organizations/gachon.json').read_text())
for f in Path('work/college-major-filters-20261012/sources-a').glob('gachon-*-verified-roster.txt'):
 lines=f.read_text().splitlines();college=lines[0].split(':',1)[1].strip();names={norm(s) for s in ' '.join(lines[1:]).split()}
 page=f.name.split('-')[1]
 for r in asset['mappings']:
  if norm(r['department']) in names:
   put('gachon',r,college,None,f'https://www.gachon.ac.kr/kor/{page}/subview.do',f,f'공식 단과대 소개 본문 메뉴/학과장 표: {college} / {r["department"]} 정확한 명칭. 별도 전공제도 명칭이나 구학과 alias로 임의 확대하지 않음.')
packet['entries']=list(entries.values());packet['final']=False;packet['completionClaim']=False
(P/'program-groups-root.json').write_text(json.dumps(packet,ensure_ascii=False,indent=2)+'\n')
print('rows',len(entries))
for u in ['hanyang','gachon']:
 applied={(r['campus'],r['sourceLabel'],r['department'])for r in packet['entries']if r['university']==u}
 print(u, len(applied), 'not covered', sorted({r['department']for r in json.loads(Path(f'assets/timetable/organizations/{u}.json').read_text())['mappings']if not r.get('college') and not r.get('group') and (r['campus'],r['sourceLabel'],r['department'])not in applied}))
