import json
from pathlib import Path
from bs4 import BeautifulSoup
O=Path('work/all-university-completion-20261012');entries=[];checked={}
def add(school,m,college,group,url,f,evidence):
 entries.append({'university':school,'campus':m.get('campus','*'),'sourceLabel':m['sourceLabel'],'department':m['department'],'college':college,'group':group,'officialGroups':[group]if group else[],'kind':'ordinaryCollege'if college else'universityDirect','sourceUrl':url,'sourceFile':str(f),'evidence':evidence})
f=Path('work/course-owner-filter-20261012/agent-a-sources/hongik-colleges.html');url='https://www.hongik.ac.kr/kr/education/intro-university.do?article.offset=0&mode=list';s=BeautifulSoup(f.read_text(),'html.parser')
rows=json.load(open('assets/timetable/organizations/hongik.json'))['mappings']
for box in s.select('.b-uni-box'):
 top=box.select_one('.b-title-box .title-box>a').get_text(strip=True)
 if top=='융합전공':continue
 names=[a.get_text(' ',strip=True)for a in box.select('a')if '?mode=view' in a.get('href','')]
 for m in rows:
  if m.get('department') not in names:continue
  add('hongik',m,top if top.endswith('대학')else None,None if top.endswith('대학')else top,url,f,'공식 대학과정 본문 top-level 학사조직 '+top+' 아래 depth별 학과/전공 직접배치: '+m['department']+'. 대학 밖 별도학부/학과를 임의 단과대에 넣지 않음')
checked['hongik']=[{'url':url,'sourceFile':str(f)}]
f=O/'b-sources/mokpo-2026-admission.pdf';url='https://www.mokpo.ac.kr/bbs/ipsi/227/122534/download.do'
for m in json.load(open('assets/timetable/organizations/mokpo.json'))['mappings']:
 d=m.get('department')
 col={'법·경찰학부':'사회과학대학','IT금융보험학전공':'경영대학'}.get(d)
 if col:add('mokpo',m,col,None,url,f,'공식2026편입학 모집요강 대학교/학부/전공 표 PDFprinted2에 '+col+' 아래 '+('경영학부 IT금융보험학'if d=='IT금융보험학전공'else d)+' 직접배치')
 if d in ['글로벌학부','자율전공학부']:add('mokpo',m,None,d,url,f,'공식2026편입학 모집요강 PDFprinted3 학사조직 표 총장직속 아래 '+d+' 명시; 총장직속 조직을 가상단과대에 치환하지 않음')
checked['mokpo']=[{'url':url,'sourceFile':str(f)}]

import re,fitz
f=O/'b-sources/kongju-2026-guide.pdf';url='https://sdm.kongju.ac.kr/bbs/sdm/2106/646183/download.do'
guide=fitz.open(f)
rows=json.load(open('assets/timetable/organizations/kongju.json'))['mappings']
roster={}
for i in [2,10,15,28,36]:
 t=guide[i].get_text();print('guide roster',i,t[:60].replace('\n',' '))
 head={'2':'인문사회과학대학','10':'자연과학대학','15':'천안공과대학','28':'산업과학대학','36':'본부소속'}.get(str(i))
 if head not in t:continue
 for line in t.splitlines():
  if line.startswith('•'):
   for d in re.split(r'\t+',line.removeprefix('•').strip()):
    if d:roster[d]=(head,i)
for m in rows:
 d=m.get('department')or''
 if d in roster:
  col,idx=roster[d]
  add('kongju',m,col if col!='본부소속'else None,d if col=='본부소속'else None,url,f,'공식2026자율전공 전공가이드 PDFindex'+str(idx)+' '+col+' 학과목록에 '+d+' 직접명시')
 if d=='전기전자제어공학부 반도체정보공학전공':add('kongju',m,'천안공과대학',None,url,f,'공식2026자율전공 전공가이드 printed31 천안공과대학 조직목록 전기전자제어공학부 아래 반도체정보공학전공 직접명시')
f=O/'b-sources/kongju-2026-cancel.pdf';url='https://www.kongju.ac.kr/bbs/KNU/2132/648284/download.do';t=f.with_suffix('.txt').read_text()
for m in rows:
 d=m.get('department')or''
 for col in ['천안공과대학','산업과학대학','예술대학','인문사회과학대학','자연과학대학','사범대학','간호보건대학','본부소속']:
  if col+'\n'+d+'\n'in t:
   add('kongju',m,col if col!='본부소속'else None,d if col=='본부소속'else None,url,f,'공식2026-1 폐강강좌 현황 원자료 대학/학과 열에 '+col+'/'+d+' 직접기록; 폐강강좌 자체를 시간표에 추가하는 것이 아닌 공식학사조직 소속근거만 재사용')
checked['kongju']=[{'url':'https://sdm.kongju.ac.kr/bbs/sdm/2106/646183/download.do','sourceFile':str(O/'b-sources/kongju-2026-guide.pdf')},{'url':url,'sourceFile':str(f)}]
f=O/'b-sources/pknu-sea-hierarchy.html';url='https://college.pknu.ac.kr/college/3500';soup=BeautifulSoup(f.read_text(),'html.parser');mapped={}
for table in soup.find_all('table'):
 if '학부ㆍ학과ㆍ전공' not in table.get_text():continue
 spans={}
 for row in table.find_all('tr'):
  cells=[];idx=0
  for td in row.find_all(['td','th'],recursive=False):
   while idx in spans:
    text,left=spans[idx];cells.append(text)
    if left==1:del spans[idx]
    else:spans[idx]=(text,left-1)
    idx+=1
   text=td.get_text(' ',strip=True)
   for _ in range(int(td.get('colspan',1))):
    cells.append(text)
    if int(td.get('rowspan',1))>1:spans[idx]=(text,int(td['rowspan'])-1)
    idx+=1
  while idx in spans:
   text,left=spans[idx];cells.append(text)
   if left==1:del spans[idx]
   else:spans[idx]=(text,left-1)
   idx+=1
  if len(cells)<3:continue
  college=cells[0]
  if college not in ['본부','인문사회과학대학','자연과학대학','경영대학','공과대학','수산과학대학','환경ㆍ해양대학','정보융합대학']:continue
  for d in cells[2:-1]:
   if d:mapped[re.sub(r'\s+','',d)]=college
for m in json.load(open('assets/timetable/organizations/pknu.json'))['mappings']:
 d=m.get('department')or'';c=mapped.get(re.sub(r'\s+','',d))
 if c:add('pknu',m,None if c=='본부'else c,d if c=='본부'else None,url,f,'공식 학부대학 전체 대학/계열/학부ㆍ학과ㆍ전공 표 rowspan 실제 학사소속 열 '+c+' 아래 '+d+' 직접명시. 행정메뉴나 수강허용학과 소속으로 변환하지 않음')
f=O/'b-sources/pknu-full-hierarchy.html';url='https://www.pknu.ac.kr/main/5'
for m in json.load(open('assets/timetable/organizations/pknu.json'))['mappings']:
 if m.get('department')=='미래융합학부':add('pknu',m,None,'미래융합학부',url,f,'공식 학부/학과/전공 안내 독립 top-level 미래융합학부 표와 대학(학부) 목차에서 별도 학부로 직접명시; 추가전공제도의 융합전공과 구분')
checked['pknu']=[{'url':'https://college.pknu.ac.kr/college/3500','sourceFile':str(O/'b-sources/pknu-sea-hierarchy.html')},{'url':url,'sourceFile':str(f)}]
f=O/'b-sources/kongju-survey.pdf';url='https://homepage.kongju.ac.kr/bbs/M02041/1892/479050/download.do'
for m in rows:
 if m.get('department')in ['반도체기계공학과','산업경영공학과','전기전자응용공학과','지능형모빌리티공학과']:add('kongju',m,'천안공과대학',None,url,f,'공식2023 학생핵심역량 진단보고서 PDFindex19 학과별 표 천안공과대학 rowspan 아래 '+m['department']+' 직접배치. current 계약학과 홈페이지에도 동일학과명 존속확인')
checked['kongju'].append({'url':url,'sourceFile':str(f)})
f=O/'b-sources/hongik-legacy-rules.pdf';url='https://www.hongik.ac.kr/kr/newscenter/notice.do?articleNo=128118&attachNo=75700&mode=download'
for m in json.load(open('assets/timetable/organizations/hongik.json'))['mappings']:
 d=m.get('department')
 if d=='컴퓨터공학전공':add('hongik',m,'공과대학',None,url,f,'공식학칙 신구대비표 공과대학(서울) 정보·컴퓨터공학부/컴퓨터·데이터공학부 아래 컴퓨터공학전공 직접명시; 현행컴퓨터공학과로 임의이름교체하지 않고 legacy교과소속유지')
 if d=='디자인경영융합학부':add('hongik',m,None,d,url,f,'공식2026학년도 입학정원 포함 학칙 신구대비표에서 디자인경영융합학부는 단과대학 소속 없는 독립학부 행으로 직접명시; 현행 디자인·예술경영학부와 이름추정통합하지 않음')
checked['hongik'].append({'url':url,'sourceFile':str(f)})
# Official early-employment curriculum tables retain the original degree labels.
for key,department,college,url in [
 ('mokpo-early-energy','스마트에너지시스템학과','공과대학','https://early.mokpo.ac.kr/early/6060/subview.do'),
 ('mokpo-early-software','소프트웨어학과','공과대학','https://early.mokpo.ac.kr/early/6061/subview.do'),
 ('mokpo-early-transport','첨단운송기계시스템학과','공과대학','https://early.mokpo.ac.kr/early/6080/subview.do'),
 ('mokpo-early-business-alt','스마트비즈니스학과','경영대학','https://mmed.mokpo.ac.kr/early/6062/subview.do')]:
 f=O/('b-sources/'+key+'.html')
 for m in json.load(open('assets/timetable/organizations/mokpo.json'))['mappings']:
  if m.get('department')==department:add('mokpo',m,college,None,url,f,'공식 조기취업형 계약학과 교육과정 표 대학명/학과명 열에 '+college+'/'+department+' 직접 명시. 현행 페이지 제목과 구학과명을 임의 치환하지 않음')
 checked['mokpo'].append({'url':url,'sourceFile':str(f)})
f=O/'b-sources/mokpo-global-curriculum.xlsx';url='https://www.mokpo.ac.kr/crclmMn/www/20/atchmnflDownload.do'
for m in json.load(open('assets/timetable/organizations/mokpo.json'))['mappings']:
 if m.get('department')=='글로벌한국학전공':add('mokpo',m,None,'글로벌학부',url,f,'공식 교과과정 원본 제목 글로벌학부 글로벌한국학전공 직접 명시. 공식2026편입학 모집요강 총장직속 글로벌학부 구조와 결합; 전공 이름의 유사성 추정 아님')
checked['mokpo'].append({'url':url,'sourceFile':str(f)})
for m in json.load(open('assets/timetable/organizations/kongju.json'))['mappings']:
 if m.get('department')=='스포츠과학과':
  f=O/'b-sources/kongju-sports-hierarchy.html';url='https://evr.kongju.ac.kr/KNU/16729/subview.do'
  add('kongju',m,'자연과학대학',None,url,f,'공식 자연과학대학 본문과 해당 대학 메뉴 아래 스포츠과학과 직접배치. 자연과학대학 소개 9개학과 구조 명시')
  checked['kongju'].append({'url':url,'sourceFile':str(f)})
 if m.get('department')=='생산기계공학과':
  f=O/'b-sources/kongju-legacy-mechanical.pdf';url='https://www.kongju.ac.kr/bbs/KNU/2122/548275/download.do'
  add('kongju',m,'공과대학',None,url,f,'공식2016 대학통계연보 계약학과 현황 표 공과대학 rowspan 아래 생산기계공학과 직접명시. 원자료 구학사명 공과대학을 현행명으로 추정변경하지 않음')
  checked['kongju'].append({'url':url,'sourceFile':str(f)})
for m in json.load(open('assets/timetable/organizations/pknu.json'))['mappings']:
 if m.get('department')=='미디어ICT공학전공':
  f=O/'b-sources/pknu-itc-hierarchy.html';url='https://www.pknu.ac.kr/main/378'
  add('pknu',m,'정보융합대학',None,url,f,'공식 정보융합대학 학부 및 학과 본문 미디어커뮤니케이션학부(미디어ICT공학전공) 직접명시. 학부대학 안내와 현행 정보융합대학 원문 실제차이 있어 원학부 명칭 유지')
  checked['pknu'].append({'url':url,'sourceFile':str(f)})
 if m.get('department')=='경제학전공':
  f=O/'b-sources/pknu-economics-history.html';url='https://www.pknu.ac.kr/main/217'
  add('pknu',m,'인문사회과학대학',None,url,f,'공식 연혁 학부분리 경제학부 경제학전공→경제학과 직접명시. 인문사회과학대학 경제학부 원소속 및 현행 인문사회과학대학 경제학과 표와 연결, 학과명 임의 유사성 추론 아님')
  checked['pknu'].append({'url':url,'sourceFile':str(f)})
f=O/'b-sources/mokpo-evaluation-2024.pdf';url='https://www.mokpo.ac.kr/bbs/www/127/110360/download.do'
for m in json.load(open('assets/timetable/organizations/mokpo.json'))['mappings']:
 if m.get('department')=='스마트에너지시스템공학과':add('mokpo',m,'공과대학',None,url,f,'공식2024 대학자체평가 보고서 PDFindex166 단과대학/학과 조직열 공과대학 스마트에너지시스템공학과(계약학과) 직접명시. 교수전공을 역추론하지 않고 대학학과 열 그대로 사용')
 if m.get('department')=='교양학부':add('mokpo',m,None,'교양학부',url,f,'공식2024 대학자체평가 보고서 PDFindex166 단과대학/학과 조직열 단과대구분없음 교양학부 직접명시; 가상 소속대학 생성하지 않음. 강좌분류 교양은 별도로 전공전용 필터 제외')
checked['mokpo'].append({'url':url,'sourceFile':str(f)})
f=O/'b-sources/kangwon-chuncheon-humanities.html';url='https://www.kangwon.ac.kr/ko/conts/937/web.do'
for m in json.load(open('assets/timetable/organizations/kangwon.json'))['mappings']:
 if m.get('campus')=='chuncheon' and m.get('department') in ['국어국문학과','독어독문학과','사학과','영어영문학과','일본학과','중어중문학과','철학과']:
  add('kangwon',m,'인문대학',None,url,f,'공식 춘천캠퍼스 인문대학(춘천) 소개의 동일단과대 학과 menu 직접명시 '+m['department']+'. 학교 전체 공통메뉴/강릉캠퍼스 학과목록과 구분하여 춘천campus만 적용')
checked.setdefault('kangwon',[]).append({'url':url,'sourceFile':str(f)})
(O/'extra-ordinary-b.json').write_text(json.dumps({'entries':entries,'checkedSources':checked},ensure_ascii=False,indent=2));print(len(entries))
