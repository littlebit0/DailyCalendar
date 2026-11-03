"""Build Daegu organization mappings from the official 2026-2 timetable PDF and college pages.
Run from the worktree root. Evidence only from: timetable PDF (rst fileSeq=192983) and www.daegu.ac.kr/intro/N."""
import json,re,sys
from pathlib import Path
W=Path('/Users/kimhwi/Documents/Codex/DailyCalendar/work/issue-593-daegu-timetable/daegu')
PDF='https://rst.daegu.ac.kr/cmmn/fileDown.do?fileSeq=192983'
PDFFILE=str(W/'dl/timetable-2026-2.pdf')
labels=json.loads((W/'raw-labels.json').read_text())
ev=json.loads((W/'label-evidence.json').read_text())
intro={  # college -> (intro index, exact department lines as printed on the page)
 '공공인재대학':(0,['공공안전학부 소방·행정학전공','공공안전학부 공직법무전공','경찰학부 경찰행정학전공','경찰학부 자치경찰학전공','국방군사학과','부동산·지적학과']),
 '글로벌경영대학':(1,['경영학부 경영학전공','경영학부 회계학전공','경제금융통상학과','호텔관광경영학부 관광항공경영전공','호텔관광경영학부 호텔관광외식서비스전공','일본어일본학과','국제학부 한국어교육, 통번역학전공','국제학부 국제어문학전공']),
 '사회과학대학':(2,['사회복지학과','청소년상담복지학과','아동가정복지학과','평생교육실버복지학과','미디어커뮤니케이션학부 영상콘텐츠전공','미디어커뮤니케이션학부 광고PR전공','문헌정보학과','심리학과']),
 '보건바이오대학':(3,['보건의료학과','응급구조학과','동물자원학과','반려동물산업학과','스마트원예학과','식품가공학과','난임의료산업학과']),
 'IT·공과대학':(4,['건축공학과','소방안전방재학과','기계자동차공학부 기계공학전공','기계자동차공학부 미래자동차공학전공','식품영양학과','조경산림정원학과','친환경에너지학과','전자전기공학부 반도체전자공학전공','전자전기공학부 전기공학전공','컴퓨터정보공학부 컴퓨터공학전공','컴퓨터정보공학부 컴퓨터소프트웨어전공','컴퓨터정보공학부 사이버보안전공','신소재에너지시스템공학부 신소재에너지공학전공','건설시스템공학과','환경기술공학과','생명공학과','화학공학과','전자전기공학부 정보통신공학전공','AI학과','IT융합학과','메카트로닉스공학과']),
 '디자인예술대학':(5,['웹툰영상애니메이션학부 영상애니메이션전공','웹툰영상애니메이션학부 웹툰전공','시각디자인융합학부 시각디자인전공','시각디자인융합학부 서비스마케팅디자인전공','산업디자인학과','패션디자인학과','뷰티학부 헤어디자인전공','뷰티학부 메이크업·피부전공','실내건축디자인학과','게임학과','융합예술학부 아트앤디자인전공','주얼리디자인학과']),
 '사범대학':(6,['국어교육과','영어교육과','역사교육과','일반사회교육과','지리교육과','유아교육과','특수교육과','초등특수교육과','유아특수교육과','수학교육과','물리교육과','화학교육과','생물교육과','지구과학교육과']),
 '재활과학대학':(7,['물리치료학과','작업치료학과','언어치료학과','재활상담심리치료학과','의료재활학과','재활건강증진학과','특수창의융합학과']),
 '간호대학':(8,['간호학과']),
 '글로컬라이프대학':(10,['휴먼케어창의학부 실버복지·복지상담학전공','휴먼케어창의학부 자산관리·6차산업학전공','글로컬융합학부 평생교육·청소년학전공']),
 '국제대학':(11,['글로벌한국학부(한국어교육전공)','글로벌한국학부(한국어통번역전공)','글로벌인재학부(국제경제무역전공)','글로벌인재학부(글로벌경영전공)','글로벌인재학부(문화산업관리전공)','글로벌인재학부(법학전공)','글로벌인재학부(중국언어문학전공)','글로벌인재학부(회계학전공)','글로벌인재학부(AI컴퓨터공학전공)','글로벌인재학부(건축공학전공)','글로벌인재학부(기계공학전공)','글로벌인재학부(디자인예술전공)']),
 '체육레저학부':(12,['체육학과','스포츠레저학과','스포츠헬스케어학과']),
}
# Units printed only in the timetable PDF p.5 contact list (2026.07 기준), not on 2026 intro pages.
p5={'법학부':'공공인재대학','유럽문화학과':'글로벌경영대학','국제관계학과':'사회과학대학','사회학과':'사회과학대학','통계학과':'보건바이오대학','화장품바이오학부':'보건바이오대학','산림자원학과':'보건바이오대학'}
def verify_intro(college,line):
  i=intro[college][0]
  t=re.sub(r'\s+',' ',re.sub(r'<[^>]+>',' ',(W/f'dl/intro-{i}.html').read_text(encoding='utf-8',errors='ignore')))
  assert line in t,(college,line)
for c,(i,ls) in intro.items():
  for l in ls: verify_intro(c,l)
def parent(title): return title.split('(')[0]
def affiliation(title):
  p=parent(title)
  z=lambda s:re.sub(r'[\s()]','',s)
  hits=[(c,i,l) for c,(i,ls) in intro.items() for l in ls if z(l)==z(title)]
  hits=hits or [(c,i,l) for c,(i,ls) in intro.items() for l in ls if l.split(' ')[0].split('(')[0]==p]
  for c,i,l in hits[:1]:
        return c,f'https://www.daegu.ac.kr/intro/{i}',str(W/f'dl/intro-{i}.html'),f'대학·대학원 > 대학 (2026학년도) > {"국제 대학" if c=="국제대학" else c} 학과(전공) 목록: "{l}"'
  if p in p5:
    return p5[p],PDF,PDFFILE,f'2026학년도 제2학기 수업시간표(종합) PDF 5쪽 "단과대학 행정실 및 학과 연락처"(2026. 07. 기준): {p5[p]} … "{p}"'
  return None
CC='창의융복합전공'
LINES={p['page']:p['lines'] for p in json.loads((W/'pdf-lines2.json').read_text())}
def pagehead(n):
  s=sorted([l for l in LINES[n] if l[0].strip()],key=lambda l:(l[2],l[1]))
  return s[0][0].strip() if s else ''
STAND={'포용사회융합학부','사이버인재학부','미래모빌리티학부','차세대반도체융합학부','반도체AI융합전공','디지털포용 마이크로디그리','글로벌컨텐츠(GC) 나노디그리','대학전체'}
maps=[];owners=[];held=[]
def labelEvidence(l,x):
  pages=', '.join(map(str,x['pages'][:3]))
  sec=x['section'] or '창의융복합전공(139쪽 구분면)'
  return f'2026학년도 제2학기 수업시간표(종합) PDF {pages}쪽 "{sec}" {x["title"]} 표의 수강학과 원문 "{l}"'
def mk(l,college,dept,group,standalone,labelEv,aff):
  m={'college':college,'department':dept,'sourceLabel':l,'sourceUrl':PDF,'evidence':labelEv,'sourceFile':PDFFILE.replace('/Users/kimhwi/Documents/Codex/DailyCalendar/',''),
     'isOfferingUnit':standalone,'campus':'*','collegeKnown':college is not None,'affiliationSourceUrl':aff[0],'affiliationSourceFile':aff[1].replace('/Users/kimhwi/Documents/Codex/DailyCalendar/',''),'affiliationEvidence':aff[2]}
  if group: m['group']=group; m['affiliationStatus']='officialProgramSystem'
  return m
for l in labels:
  xs=[x for x in ev[l] if x['section']=='전공 강의시간표']
  if l in ('통사교','통과교'):
    x=[x for x in ev[l] if x['section']=='연계전공 강의시간표'][0]
    name={'통사교':'통합사회교육전공','통과교':'통합과학교육전공'}[l]
    head={'통사교':'가. 통합사회교육전공','통과교':'나. 통합과학교육전공'}[l]
    maps.append(mk(l,'사범대학',name,None,False,labelEvidence(l,x)+' (부제 "사범대학")',(PDF,PDFFILE,f'수업시간표(종합) PDF 138쪽 "연계전공 강의시간표 사범대학"; PDF 50~51쪽 "(붙임 3) 2026 교직 융복합전공 중복인정 교과목 현황 {head}" 교과목 목록이 이 라벨의 개설 강좌명과 모두 일치')))
    continue
  if l=='평생교육':
    x=ev[l][0] if ev[l][0]['section'] else [x for x in ev[l] if x['section']][0]
    x=[x for x in ev[l] if x['section']=='연계전공 강의시간표'][0]
    maps.append(mk(l,None,'평생교육 융복합전공','연계융복합전공',False,labelEvidence(l,x),(PDF,PDFFILE,'수업시간표(종합) PDF 136쪽 구분면 "연계융복합전공", 137쪽 "연계전공 강의시간표 대학전체" 수강학과 "평생교육"; 55쪽 "평생교육사 교과목 개설 현황은 <평생교육 융복합전공>시간표 참고"')))
    continue
  if l=='직업상담':
    x=xs[0]
    maps.append(mk(l,None,'직업상담','마이크로전공',False,labelEvidence(l,x),(PDF,PDFFILE,'수업시간표(종합) PDF 16쪽 "⑥ 마이크로전공 현황 … 직업상담 청소년상담복지학과"')))
    continue
  if l=='사회대':
    maps.append(mk(l,'사회과학대학',None,None,True,labelEvidence(l,xs[0]),('https://www.daegu.ac.kr/intro/2',str(W/'dl/intro-2.html'),'대학·대학원 > 대학 (2026학년도) > 사회과학대학; 시간표 217쪽 "전공 강의시간표 사회과학대학" 표의 수강학과 "사회대"')))
    continue
  if l=='문화콘텐츠':
    maps.append(mk(l,'문화콘텐츠학부',None,None,True,labelEvidence(l,xs[0]),('https://www.daegu.ac.kr/intro/13',str(W/'dl/intro-13.html'),'대학·대학원 > 대학 (2026학년도) > 문화콘텐츠학부 (단과대학 수준 학부, 하위 학과 없음); PDF 7쪽 "문화콘텐츠학부 행정실"')))
    continue
  ccx=[x for x in ev[l] if x['section']=='' and x['title']=='' and any(139<p<157 for p in x['pages'])]
  ccp=[p for x in ccx for p in x['pages'] if 139<p<157 and xs and pagehead(p)==xs[0]['title']]
  if len(xs)==1 and ccp:
    x=xs[0]; p=ccp[0]
    maps.append(mk(l,None,x['title'],CC,False,labelEvidence(l,x),(PDF,PDFFILE,f'수업시간표(종합) PDF 139쪽 구분면 "창의융복합전공", {p}쪽 머리글 "{x["title"]}"; 융합교육혁신센터 창의융복합전공 > 운영 현황에 AI응용전공 교육과정 편성표 게시')))
    continue
  if len(xs)!=1:
    if l in ('법학','한국어통번 역'):
      for x in xs:
        a=affiliation(x['title'])
        for sid in x['courses']:
          owners.append((sid,{'college':a[0],'department':x['title'],'sourceLabel':l,'sourceUrl':PDF,'evidence':labelEvidence(l,x),'sourceFile':PDFFILE.replace('/Users/kimhwi/Documents/Codex/DailyCalendar/',''),'isOfferingUnit':True,'collegeKnown':True,'affiliationSourceUrl':a[1],'affiliationSourceFile':a[2].replace('/Users/kimhwi/Documents/Codex/DailyCalendar/',''),'affiliationEvidence':a[3]}))
      continue
    held.append((l,'전공 강의시간표 제목 없음/복수')); continue
  x=xs[0]; t=x['title']
  if parent(t) in STAND or t in STAND:
    std=t if t in STAND else parent(t)
    aff=(PDF,PDFFILE,f'2026학년도 공식 대학·대학원 단과대학 목록(www.daegu.ac.kr/intro)과 수업시간표 PDF 5~7쪽 단과대학 연락처에 소속 단과대학이 없어, 시간표 표 제목 "{t}"의 단위를 독립 개설 단위로 둠')
    if t==std: maps.append(mk(l,std,None,None,True,labelEvidence(l,x),aff))
    else: maps.append(mk(l,std,t,None,False,labelEvidence(l,x),aff))
    continue
  a=affiliation(t)
  if a is None: held.append((l,t)); continue
  maps.append(mk(l,a[0],t,None,False,labelEvidence(l,x),(a[1],a[2],a[3])))
spec={'mappings':maps,'owners':[{'sourceId':s,'unit':u} for s,u in owners],'held':held}
(W/'mapping-spec.json').write_text(json.dumps(spec,ensure_ascii=False,indent=1))
print(len(maps),len(owners),held)
