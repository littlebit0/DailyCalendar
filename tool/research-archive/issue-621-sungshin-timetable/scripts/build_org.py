import json
from pathlib import Path
E = 'work/issue-621-sungshin-timetable/evidence/'
TT = 'https://sugang.sungshin.ac.kr/findBCRM02010.do'
W = 'https://www.sungshin.ac.kr'
C = {  # college: (url, file, menu quote prefix)
 '인문융합예술대학': (W+'/humanity/index.do', 'college-humanity.html', "인문융합예술대학 사이트 '학과소개 > 학과' 메뉴"),
 '사회과학대학': (W+'/social/index.do', 'college-social.html', "사회과학대학 사이트 '학부·학과 소개 > 학부·학과' 메뉴"),
 '법과대학': (W+'/lawdean/index.do', 'college-lawdean.html', "법과대학 사이트 '학부/학과소개 > 학부' 메뉴"),
 '자연과학대학': (W+'/natscience/index.do', 'college-natscience.html', "자연과학대학 사이트 '학부/학과소개 > 학부/학과' 메뉴"),
 '공과대학': (W+'/eng/index.do', 'college-eng.html', "공과대학 사이트 '학부/학과소개 > 학부/학과' 메뉴"),
 'IT융합대학': (W+'/itc/index.do', 'college-itc.html', "IT융합대학 사이트 '학부/학과소개 > 학부/학과' 메뉴"),
 '생활산업대학': (W+'/lifeindustry/index.do', 'college-lifeindustry.html', "생활산업대학 사이트 '학과소개 > 학과' 메뉴"),
 '사범대학': (W+'/teacher/index.do', 'college-teacher.html', "사범대학 사이트 '학과소개 > 학과' 메뉴"),
 '미술대학': (W+'/midae/index.do', 'college-midae.html', "미술대학 사이트 '학과소개' 메뉴"),
 '음악대학': (W+'/music/index.do', 'college-music.html', "음악대학 사이트 '학과소개 > 학과' 메뉴"),
 '창의융합대학': (W+'/generaledu/index.do', 'college-generaledu.html', "창의융합대학 사이트 메뉴"),
 '간호대학': (W+'/nursing/index.do', 'college-nursing.html', "간호대학 사이트 바로가기 배너"),
}
rows = []
def dept(label, college, shown=None, url=None, file=None, quote=None):
    u, f, q = C[college]
    rows.append(dict(label=label, college=college, standalone=False, url=url or u, file=E+(file or f),
                     evidence=quote or f"{q}에 '{shown or label}'이 있음(2026-10-23 확인)."))
for college, labels in {
 '인문융합예술대학': [('국어국문학과','국어국문학과(수정)'),('영어영문학과','영어영문학과(수정)'),('독일어문·문화학과','독일어문·문화학과(수정)'),('프랑스어문·문화학과','프랑스어문·문화학과(수정)'),('일본어문·문화학과','일본어문·문화학과(수정)'),('중국어문·문화학과','중국어문·문화학과(수정)'),('사학과','사학과(수정)'),('문화예술경영학과','문화예술경영학과(운정)'),('미디어영상연기학과','미디어영상연기학과(운정)'),('현대실용음악학과','현대실용음악학과(운정)'),('무용예술학과','무용예술학과(운정)')],
 '사회과학대학': [('정치외교학과','정치외교학과(수정)'),('심리학과','심리학과(수정)'),('지리학과','지리학과(수정)'),('경제학과','경제학과(수정)'),('경영학과','경영학과(수정)'),('미디어커뮤니케이션학과','미디어커뮤니케이션학과(수정)'),('사회복지학과','사회복지학과(운정)')],
 '법과대학': [('법학부','법학부')],
 '자연과학대학': [('수리통계데이터사이언스학부','수리통계데이터사이언스학부(수정)'),('수학','수학과(수정)'),('통계학','통계학과(수정)'),('화학·에너지융합학부','화학·에너지융합학부(운정)'),('바이오헬스융합학부','바이오헬스융합학부(운정)'),('식품영양학','식품영양학과(운정)')],
 '공과대학': [('청정신소재공학과','청정신소재공학과(운정)'),('바이오식품공학과','바이오식품공학과(운정)'),('바이오신약의과학부','바이오신약의과학부(운정)'),('AI융합학부','AI융합학부(수정)'),('컴퓨터공학과','컴퓨터공학과(수정)'),('융합보안공학과','융합보안공학과(수정)'),('서비스디자인공학과','서비스디자인공학과(수정)')],
 'IT융합대학': [('AI융합학부',None),('컴퓨터공학과',None),('융합보안공학과',None),('서비스디자인공학과',None)],
 '생활산업대학': [('의류산업학과','의류산업학과(운정)'),('소비자산업학과','소비자산업학과(운정)'),('뷰티산업학과','뷰티산업학과(운정)'),('스포츠과학부','스포츠과학부(수정)')],
 '사범대학': [(x,None) for x in ['교육학과','사회교육과','윤리교육과','한문교육과','유아교육과']],
 '미술대학': [(x,None) for x in ['동양화과','서양화과','조소과','공예과','디자인과']],
 '음악대학': [(x,None) for x in ['성악과','기악과','작곡과']],
 '창의융합대학': [(x,None) for x in ['창의융합학부','국제학부','융합연계학부']],
 '간호대학': [('간호학과',None)],
}.items():
    for label, shown in labels:
        dept(label, college, shown)
# 학부 안의 전공: 학부 공식 사이트 원문.
sub = [
 ('빅데이터사이언스','자연과학대학', W+'/stat-math/index.do','dept-stat-math.html',"수리통계데이터사이언스학부 사이트 메뉴에 '통계학/빅데이터사이언스 전공'이 있음(자연과학대학 사이트 학부/학과 메뉴에 '수리통계데이터사이언스학부(수정)', 2026-10-23 확인)."),
 ('핀테크','자연과학대학', W+'/stat-math/index.do','dept-stat-math.html',"수리통계데이터사이언스학부 사이트 메뉴에 '수학/핀테크 전공'이 있음(자연과학대학 사이트 학부/학과 메뉴에 '수리통계데이터사이언스학부(수정)', 2026-10-23 확인)."),
 ('바이오헬스서비스','자연과학대학', W+'/sites/biohealth/index.do','dept-biohealth.html',"바이오헬스융합학부 사이트 관련사이트에 '식품영양학 전공', '바이오헬스서비스 전공'이 있음(자연과학대학 사이트 학부/학과 메뉴에 '바이오헬스융합학부(운정)', 2026-10-23 확인)."),
 ('생명공학','공과대학', W+'/biopharm/17445/subview.do','dept-biopharm-major.html',"바이오신약의과학부 '전공소개'에 '바이오신약 전공', '생명공학 전공'이 있음(공과대학 사이트 학부/학과 메뉴에 '바이오신약의과학부(운정)', 2026-10-23 확인)."),
 ('스포츠레저','생활산업대학', W+'/sportsscience/17566/subview.do','dept-sportsscience-major.html',"스포츠과학부 '전공소개'에 '스포츠레저전공', '운동재활전공'이 있음(생활산업대학 사이트 학과 메뉴에 '스포츠과학부(수정)', 2026-10-23 확인)."),
 ('운동재활','생활산업대학', W+'/sportsscience/17566/subview.do','dept-sportsscience-major.html',"스포츠과학부 '전공소개'에 '스포츠레저전공', '운동재활전공'이 있음(생활산업대학 사이트 학과 메뉴에 '스포츠과학부(수정)', 2026-10-23 확인)."),
 ('글로벌한국학','창의융합대학', W+'/siie_kor/20424/subview.do','dept-siie.html',"국제학부 소개의 모집 표에 '창의융합대학 / 국제학부 / 글로벌한국학전공'과 '뷰티·패션디자인전공'이 있음(2026-10-23 확인)."),
 ('뷰티·패션디자인','창의융합대학', W+'/siie_kor/20424/subview.do','dept-siie.html',"국제학부 소개의 모집 표에 '창의융합대학 / 국제학부 / 글로벌한국학전공'과 '뷰티·패션디자인전공'이 있음(2026-10-23 확인)."),
]
for college in ['공과대학','IT융합대학']:
    sub += [('AI',college, W+'/aiot/18402/subview.do','dept-aiot-major.html',f"AI융합학부 '전공소개'에 'AI융합학부 AI전공 소개'가 있음({C[college][2]}에 'AI융합학부', 2026-10-23 확인)."),
            ('지능형시스템',college, W+'/aiot/18029/subview.do','dept-aiot-18029.html',f"AI융합학부 '교육과정 로드맵'에 '2026년도_교육과정안_확정에_따른_로드맵_지능형시스템전공' 그림이 있음({C[college][2]}에 'AI융합학부', 2026-10-23 확인).")]
for label, college, url, file, quote in sub:
    dept(label, college, url=url, file=file, quote=quote)
# 단과대 직접 개설과 본부 개설 단위: 공식 개설강좌조회의 개설학과전공 원문.
for label in ['공과대학','생활산업대학','사범대학','미술대학']:
    rows.append(dict(label=label, standalone=True, url=TT, file='work/issue-621-sungshin-timetable/sungshin/bydept_101.json',
        evidence=f"성신여대 개설강좌조회 2026년 2학기 조직분류 '대학'의 개설학과전공 목록에 '{label}'이 있고, 개설학과전공 '{label}' 강좌가 조회됨(2026-10-23 확인)."))
for label in ['학생군사교육단','인재개발팀','현장실습운영팀','학사운영팀','국제교류지원팀','창업지원팀']:
    rows.append(dict(label=label, standalone=True, url=TT, file='work/issue-621-sungshin-timetable/sungshin/obj_10.json',
        evidence=f"성신여대 개설강좌조회 2026년 2학기 학사과정 결과에서 개설학과전공이 '{label}'인 강좌가 조회됨(2026-10-23 확인). 학과가 아닌 본부 개설 단위라 단과대 수준의 독립 개설 단위로 둔다."))
maps = []
for r in rows:
    s = r['standalone']
    maps.append({
        'college': r['label'] if s else r['college'], 'department': None if s else r['label'],
        'sourceLabel': r['label'], 'sourceUrl': TT,
        'evidence': '현재 공식 시간표 자료의 개설·학과 라벨을 그대로 보존.', 'sourceFile': None,
        'isOfferingUnit': s, 'campus': '*', 'collegeKnown': True,
        'affiliationSourceUrl': r['url'], 'affiliationSourceFile': r['file'], 'affiliationEvidence': r['evidence'],
    })
Path('assets/timetable/organizations/sungshin.json').write_text(json.dumps(
    {'schemaVersion': 1, 'university': 'sungshin', 'mappings': maps, 'courseOwners': []}, ensure_ascii=False, indent=2) + '\n')
print(len(maps), len({m['sourceLabel'] for m in maps}))
