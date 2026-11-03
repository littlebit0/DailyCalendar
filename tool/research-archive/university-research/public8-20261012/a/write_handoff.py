from pathlib import Path
import json
P=Path(__file__).parent
attempts=[]
def a(school,url,status,evidence,outcome):attempts.append(dict(school=school,url=url,httpStatus=status,evidence=evidence,outcome=outcome))
a('sunmoon','https://dla.sunmoon.ac.kr/dla/na/ntt/selectNttList.do?bbsId=1256&mi=41117',200,'sunmoon-dla.html','공개 교양학부 공지 검색. 최신 2026-2 수정/폐강 구분.')
a('sunmoon','https://dla.sunmoon.ac.kr/dla/na/ntt/selectNttInfo.do?bbsId=1256&mi=41117&nttSn=1324974',200,'sunmoon-dla-fall.html','ERW1 053510-14 목4,5 원지우 1개 운영행, 폐강3개 별도 제외. 학점/강의실 미표기.')
a('sunmoon','https://huss.kw.ac.kr/bulletin/notice.php?BoardMode=view&UID=293',200,'sunmoon-kw-huss.html;sunmoon-huss-0.zip;sunmoon-huss-1.zip','광운대 공식 제휴공지 안의 선문대 원본: 글로벌공생3 녹화100% 시각없음, 위험사회2 정확시각/기간. 위험사회 PDF강의계획서로 코드920418-11/학점3 보완.')
a('sunmoon','https://www.kookmin.ac.kr/user/kmuNews/notice/4/12155/view.do',200,'sunmoon-kookmin.html;sunmoon-kookmin-files.json;[선문대] 2026-2학기 미래자동차융합전공 학점교류 교과목 목록.xlsx','공식 HTML에서 호출하는 공개 REST 첨부목록 및 실제 학교 XLSX/HWP 획득. 미래자동차4분반 코드/교시/교수/3학점;HWP9/1–12/14 수업기간.')
a('sunmoon','https://portal.kookmin.ac.kr/por/restapi/file/ed239a47a7c54e9ea96b5271d4497ea2',200,'sunmoon-kookmin-files.json','공식페이지 동일 GET, 계정/로그인 없이 원본 fileNo/seq13–15 확보.')
a('sunmoon','https://sws.sunmoon.ac.kr/UA/Course/LectureProcess.aspx?ys=202621&su=920418&di=11&ms=N&type=일반',200,'sunmoon-syllabus-public.html','공식 PDF 하단 실제URL 정상접근이 SessionExpire.aspx로 이동. 공개 강의계획서 조회로 확장 불가; 세션 우회하지 않음.')
a('sunmoon','https://info.sunmoon.ac.kr/PageN/content/class_01.aspx',200,'sunmoon-public-class-guide.html','공개 수강안내는 시간표 수시변경/최종 교과목조회 권고. 실제 강좌목록/Guest조회 링크 없음.')
a('sunmoon','https://food.sunmoon.ac.kr/food/na/ntt/selectNttInfo.do?mi=40874&bbsId=5000&nttSn=1324663',200,'sunmoon-food-fall.html','2026교육과정표 및 기존2학기수강안내HWP. 개설 분반/시간 원본 아님.')
a('sunmoon','https://tour.sunmoon.ac.kr/tour/na/ntt/selectNttInfo.do?mi=40743&bbsId=1175&nttSn=1324554',200,'sunmoon-tour-fall.html','2026-2시간표 제목이나 일정/유의사항 안내. 전체 개설강좌표 아님.')
a('sunmoon','https://www.kongju.ac.kr/bbs/KNU/2132/430299/artclView.do',200,'sunmoon-kongju.html','공식일반학점교류공지에 안내HWP+추천양식만. 시각목록없음.')
for name in ['dept-ledger','dept-full-ledger','dept-main-ledger','dept-search-ledger','dept-notice-search-ledger']:
 for r in json.loads((P/(name+'.json')).read_text()):
  a('sunmoon',r['url'],None if 'error' in r else (403 if 'coop1.' in r['url'] else 200),name+'.json',r.get('error','공식 학과 링크를 따라 root→index.do→main.do 및 시간표 제목 검색. 최신 운영 시간표행은 별도 식별; 과거/셔틀/일정안내 제외.'))
a('kentech','https://www.kentech.ac.kr/main.do',200,'kentech-realmain.html','공식 main 실제조회. 홈페이지/교육/학사/뉴스/전체사이트맵 링크 조사.')
a('kentech','https://www.kentech.ac.kr/submenu.do?menuurl=W7HPY3igYfc7wBkObUxCqA%3d%3d&',200,'kentech-sitemap.html','학부 교육메뉴/전공5트랙/RC/학사일정. 개설분반조회나 Guest카탈로그 링크 없음.')
a('kentech','https://www.kentech.ac.kr/submenu.do?menuurl=sF%2bx1RsShDEUtcKLR6UTvQ%3d%3d&',200,'kentech-handbook-current.html','현행 공개 학부편람의 최신은2026봄학기. 기존41쪽 실제 원본은 교육과정/코드/학점/75·50분 원칙; 주간 개설요일·시각목록 아님. 가을편람 URL 추측생성하지 않음.')
a('kentech','https://www.kentech.ac.kr/submenu.do?menuurl=y61v9s7TxjWt2%2fIVVLC24w%3d%3d&',200,'kentech-curriculum.html','학부 교육과정/교과목목록. 해당학기 실제요일·HH:mm·분반 없음.')
a('kentech','https://home.kentech.ac.kr/rc/main.do',200,'kentech-rc.html','실제 RC교육센터 공개공지 링크 추가 확인.')
a('kentech','https://home.kentech.ac.kr/detail.do?menuurl=qTPzzSyKy3sXIi6LCrKsXQ%3d%3d&board_seq=7465&categoryid=220&pageNo=1',200,'kentech-rc-spring.html;kentech-rc-spring.png','이미지 공지 실제 확인: RC Co-Curricular Program, CPS홈페이지→비교과→비교과프로그램, 8개활동 기간/총시간. 정규교과 시간표가 아니며 요일/시작시각 없음.')
a('kentech','https://home.kentech.ac.kr/detail.do?menuurl=qTPzzSyKy3sXIi6LCrKsXQ%3d%3d&board_seq=7574&categoryid=220&pageNo=1',200,'kentech-rc-summer.html','RC 하계CCP 신청공지; 학부 개설강좌표로 대체하지 않음.')
a('kentech','https://www.jbnu.ac.kr/web/Board/215121/detailView.do?menu=2377',200,'kentech-jbnu.html','2026-2_KENTECH 대학원 시간표.xlsx 및 대학원 허용과목 원본 존재. 명시 대학원 자료라 학부 데이터로 임의지원하지 않음. 기존 대학원교류조사 재확인.')
x=dict(collectedDate='2026-10-12',sharedProductFilesChanged=False,testsOrBuildsRun=False,schools=[dict(id='sunmoon',candidate='sunmoon-unknown-2026-2.json',parser='parse_sunmoon.py',scheduledCourses=7,timelessCourses=3,closedExcluded=3,scope='공개 교양변경·미래자동차융합전공·HUSS위험사회/글로벌공생 일부',completeUniversityCatalog=False,campus='unknown: 원문 물리캠퍼스 명시없음',missing='학교 전체 개설목록은 sws 로그인 요구. 확보된7실제요일시각행은 재현가능.'),dict(id='kentech',candidate=None,completeUniversityCatalog=False,status='public-undergraduate-clock-source-not-found',missing='학부편람/교과목코드 교육과정은 공개, 실제 학기 분반·요일·HH:mm 개설표 미확보. 대학원/비교과로 대체 불가.')],attempts=attempts,priorEvidence='work/university-research/expansion17-20261011/b/handoff.json')
(P/'handoff.json').write_text(json.dumps(x,ensure_ascii=False,indent=2));print('Handoff:',len(attempts),'exact normal public requests')
