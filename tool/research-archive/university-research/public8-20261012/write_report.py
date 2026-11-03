import json
from pathlib import Path
P=Path(__file__).parent
NAMES={'sunmoon':'선문대학교','kentech':'한국에너지공과대학교','konyang':'건양대학교','dju':'대전대학교','deu':'동의대학교','snue':'서울교육대학교','cue':'진주교육대학교','cnue':'춘천교육대학교'}
blocks={
'sunmoon':'공개 2026년 2학기 10강좌 적용: 시각 있는 7강좌와 녹화 전용 3강좌. 폐강 3강좌 제외. 전체 개설목록은 미확보. 캠퍼스·강의실·코드가 미표기된 행은 추정하지 않았다.',
'kentech':'학부 편람과 교육과정은 과목코드·학점·수업 길이만 제공하고 실제 학기 분반·요일·시작시각은 없다. RC 자료는 비교과, 전북대 공개 교류 XLSX는 대학원이라고 명시되어 학부로 대체할 수 없다.',
'konyang':'SMARTKY 일반 강좌 조회는 인증 필요. 추가 의료IT·물리치료·제약생명공학 공식 게시판의 시간표 검색은 0건. 기존 바이오 3/4TERM 이미지에는 실제 시각 등 필수 연결 근거가 없다. 공개 OCW·사이버 교류를 본교 정규 강좌로 대체하지 않았다.',
'dju':'공식 하계 XLSX 46강좌 원자료 확보. 17강좌는 같은 학교가 발행한 공식 하계 안내의 1~9교시 실제 시각에 연결 가능하지만 본교 파일은 5/26 기준 “개설 예정강좌”다. 교류 안내가 예고한 6/2 최종 개설·폐강 자료를 공개 공지에서 확보하지 못하여 적용 보류. 하계 시각을 일반학기에 적용하지 않았다. 원격·모듈·현장실습의 형식상 시각도 그대로 실제 출석 블록으로 만들지 않았다.',
'deu':'고신대 공식 교류 게시물에서 동의대 발행 하계 23강좌 원본 확보. 숫자 교시만 있고 절대시각이 없다. 강의시간편성및수업규정은 일반 50분·예외 45분만 명시하여 각 교시 시작시각을 확정할 수 없다. 부경대 교류 첨부는 일반 익명 세션+Referer 재시도에도 세션 만료 HTML이며, DOOR는 로그인 화면으로 이동한다. 기존 폐강 대조 이후 잔여 강좌도 실제 운영 확정 자료가 필요하다.',
'snue':'학부 공식 460개 교육 블록은 숫자 교시로 기록되어 현재 1~8교시 시작·종료표가 필요하다. 심화과정 13페이지 경로와 2026 신입생 공식 PDF 14쪽을 확인했으나 학과 소개다. 신입생 등록 HWP는 배포용 보호 형식으로 일반 본문 추출 실패, 미리보기만 확인한 제한을 기록했다. 기존 시간표의 2개 격자 충돌도 미해결이다.',
'cue':'공식 493개 과목 객체/489개 정체성은 숫자 교시만 있고 현재 1~8교시 절대시각이 없다. 12개 학과 게시판을 확인했으나 9곳 게시물 없음, 나머지는 행사·학과 규정 등이다. 공식 도서관 안내 PDF 2쪽과 이용시간은 시설 운영시간이므로 교시로 대체하지 않았다. 교원 변경 및 기존 4개 시각 충돌도 남아 있다.',
'cnue':'공식 203개 정규 블록 및 CPR 5개가 있으나 현재 일반 교시의 절대시각 근거가 없다. 기존 강의실 안내 속 2021 화면은 4~15교시만 있고 현재 적용 여부·1~3교시 근거가 없다. 12개 학과 사이트/24개 공지·자료실과 신입생·교류 경로를 추가 확인했으나 제공 자료는 장학·행사·시설 안내다. 과거표에서 역산하지 않았다.'}
rows=[]
def add(s,u,status,reason,evidence):
 if s in NAMES and u:rows.append({'university':s,'url':u,'httpStatus':status,'finding':reason,'evidence':evidence})
a=json.loads((P/'a/handoff.json').read_text())
for r in a['attempts']:add(r['school'],r['url'],r.get('httpStatus'),r.get('outcome'),r.get('evidence'))
b=json.loads((P/'b/source-ledger.json').read_text())
for r in b:
 s=r['name'].split('-')[0]
 if s in ['mie','kypt','pharm']: s='konyang'
 if s in NAMES:
  reason=r.get('finding') or r.get('outcome') or r.get('title') or r.get('result') or blocks[s]
  add(s,r.get('url'),r.get('httpStatus'),reason,r.get('file') or r.get('name'))
for name in ['department-route-receipt.json','department-board-receipt.json','cue-board-receipt.json','newstudent-file-receipt.json','library-extra-receipt.json','library-followup-receipt.json','library-final-receipt.json']:
 d=json.loads((P/'c'/name).read_text());d=d if isinstance(d,list) else [d]
 for r in d:
  u=r.get('url') or r.get('requestURL')
  s=r.get('school') or ('snue' if u and 'snue.ac.kr' in u else 'cue' if u and 'cue.ac.kr' in u else 'cnue' if u and 'cnue.ac.kr' in u else None)
  add(s,u,r.get('status'),r.get('finding') or r.get('result') or blocks.get(s),str(P/'c'/name))
(P/'public-route-ledger.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
text=['# 실제 분류 표시 및 남은 8개 대학 공개 원자료 조사 — 2026-10-12','', '분류 필터와 강좌 표시는 해당 대학·캠퍼스·학기에 존재하는 실제 분류만 표시한다. 분류가 없는 경우 분류 줄을 숨기며, 교양필수/교양선택을 구분한다. 원본 명칭은 보존하고 해석되지 않은 대학 고유 분류는 원문으로 표시한다.','', '선문대 일부 강좌만 새로 적용했다. 나머지 7개 시간표 연동은 보류다. 공개 경로 조사를 마쳤다는 뜻이며, 전체 대학 지원 완료나 모든 공개 경로의 영구적 부재를 뜻하지 않는다. 학사일정 기존 지원은 유지했다.','']
for s,n in NAMES.items():
 text.extend([f'## {n}','',blocks[s],''])
 seen=set()
 for r in rows:
  if r['university']!=s or r['url'] in seen:continue
  seen.add(r['url']);status=f"HTTP {r['httpStatus']}" if r['httpStatus'] is not None else '응답 상세는 영수증 참조'
  text.append(f"- [{r['evidence'] or '공식 조회 경로'}]({r['url']}): {status}. {r['finding']}")
 text.append('')
text.extend(['## 근거와 검증 범위','','- 원자료·개별 해시·재현 파서: `a/`, `b/`, `c/` 디렉터리. 경로별 상세 응답은 `public-route-ledger.json` 및 각 원본 receipt에 보존.','- 적용 영수증: `integration-receipt.json`. 기존 시간표 데이터셋은 바이트 그대로 유지했다.','- 검증 영수증: `verification-receipt.json`. 최초 통합 검사 이후 실패 수정은 직접 영향 범위만 재검사했다.','- Mac 빌드 및 동일 설치 경로 업데이트 결과: `install-receipt.json`. 앱 실행·새 로그인·브라우저 창 개방·타 플랫폼 설치는 수행하지 않았다.','','등록 내용은 원자료의 공개된 범위다. 전체 개설강좌·모든 캠퍼스 확보로 확대 해석하지 않는다.'])
(P/'REPORT.md').write_text('\n'.join(text)+'\n')
print(len(rows),'route receipts')
