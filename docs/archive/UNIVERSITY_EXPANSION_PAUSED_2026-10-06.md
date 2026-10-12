# 대학 지원 작업 일시 중단 인계 — 2026-10-06 21:52 KST

사용자 요청으로 작업을 일시 중단했다. 재개 요청 전 구현·조사·빌드·설치하지 않는다.
전체 완료가 아니다. LMS 추가 지원은 범위 밖이다. 릴리스·버전 변경·커밋·푸시하지 않았다.

## 확인된 상태

- 요청 대상 85개 대학; 기존 상명대 유지(85개 집계 밖).
- 공식 학사일정 구현/실제 공식 응답 검증: 69개.
- 공식 강의 검색 데이터 및 시간표 연결/검증: 7개. 단국대, 부산대, 서울대, 아주대, 인하대, 전남대, 중앙대.
- 대학 전체가 학사일정과 강의 검색 모두 완료된 것은 위 7개뿐. 실제 설치 앱의 사용자 흐름 검증은 별도이며 모두 not_verified.
- Mac 기존 ~/Applications/Daily Test.app: checkpoint20, 학사일정68/시간표7. 동일 com.littlebit0.daily.test/path로 업데이트 완료, 데이터/계정/keychain 보존, 실행 안 함.
- checkpoint20: 학사/시간표401 tests, analyze, Debug min14 build, codesign 통과. 로그 /tmp/daily-university-checkpoint20-tests.log, /tmp/daily-university-checkpoint20-analyze.log, /tmp/daily-checkpoint20-macos-build.log.
- 이번 추가 연세대: 공식 응답86 unique valid events, 집중 tests2 통과. /tmp/daily-yonsei-live.log, /tmp/daily-yonsei-tests.log. 전체 analyze/회귀/build/설치는 아직. 이 소스 추가 후 구현69, 설치68이다.
- 불가능 확정 대학 없음. WAF/단일 요청 실패/미조사는 불가능으로 처리하지 않는다.

## 남은 대학

학사일정 16개: 건국대, 고려대, 광주교대, 목포대, 부경대, 창원대, 한국해양대, 대구과기원, 동아대, 서울과기대, 순천향대, 전주교대, 조선대, 공학대, 한양대, 호서대.

강의 검색 포함 시간표 78개: 가천대, 가톨릭대, 강원대, 건국대, 경기대, 경북대, 경상국립대, 경희대, 계명대, 고려대, 경인교대, 공주교대, 광운대, 광주과기원, 광주교대, 경국대, 공주대, 군산대, 금오공과대, 목포대, 목포해양대, 부경대, 순천대, 창원대, 교통대, 한국해양대, 한밭대, 국민대, 남서울대, 대구과기원, 대구교대, 대구대, 동국대, 동아대, 동의대, 명지대, 백석대, 부산교대, 서강대, 삼육대, 서경대, 서울과기대, 서울교대, 서울시립대, 서울여대, 성균관대, 성신여대, 세종대, 수원대, 순천향대, 숙명여대, 숭실대, 연세대, 영남대, 용인대, 울산과기원, 울산대, 인천대, 전북대, 전주교대, 조선대, 제주대, 진주교대, 청주교대, 춘천교대, 충남대, 충북대, 포항공대, 한경대, 공학대, 한국과기원, 교원대, 기술교대, 외대, 항공대, 한성대, 한양대, 호서대.

## 다음 재개 순서와 근거

1. 현재 dirty diff와 AGENT_MEMORY.md 최상단, 이 파일, UNIVERSITY_SUPPORT_STATUS_2026-10-06.json 확인. unrelated LMS/auth/native/sync/settings/site 변경 보존.
2. 연세대 변경을 전체 학사/시간표 tests + analyze 후 Mac build/codesign/in-place update로 검증. 사용자 요청 없이 앱 실행 금지. 연세 신규 파일 yonsei_academic_source.dart, 해당 tests와 2025/2026 fixtures; profile/directory/provider/checktool 등록되어 있다.
   - 공식 /sc/373 → POST /schdulMng/sc/28/yearSchdul.do, kind empty/year, 이전/현재 연도 순차조회.
   - 미래 공식 /sites/wj/fnct/schdulMng/wj_from_sc_schedulMng_20260112/js/view.js 는 20260112 주석과 sc/28 상수로 신촌 데이터를 공유한다고 명시한다. mirae host sc/28 응답도 연간91행 동일 검증.
   - 월간 중복 제거86개. 공식2025 Jan28~30 요일 Sun 오기는 숫자 날짜를 유지하고 요일 텍스트로 날짜 수정하지 않는다. 계절제 별도 시작/종료 단일행을 임의 기간으로 합치지 않는다.
3. 가천대 강의3809개 수집 완료, 단기 수업 적용 기간/이수 제한 비고 검증 후 catalog 연결.
   - 유지관리 collector tool/timetable/fetch_gachon.py, 2 boundary tests 통과. /tmp/daily-gachon-verified/ current complete2campuses×6categories; global20/medical21. 출력 public fields only, MEMBER_NO 제외.
   - official /ssu/showTimetable.do, published /ui/app/ssu/ssu1000q.clx.js, POST /Ssu1000q/mainSearch.do, JSON data.SendData envelope, response MainData/dmRowCnt.rowCnt.
   - 379개12주,106개4주,5개5주; 전체 학기 반복 금지. UniversityCourse.period 기존 모델 활용 가능.
   - 공식 clock /bbs/ind/873/151112/download.do 1..14교시09..22시 50분; UI rounding 기존 방식 유지.
   - 공식 수강제한 /bbs/ind/873/151111/download.do, /tmp/daily-gachon-restrictions.pdf/txt: 학과 제한을 정확한 강의명으로 연결 필요. TRAILER는 영상 유무로 비고가 아님.
   - AI notice cs/929/122638 startSep5/Oct10/Nov14,4~5주라 정확한 종료 확인 필요; https://aibootcamp.gachon.ac.kr/ 공식 프로그램/포스터 조사. P12+4 날짜 아직 확인 안 됨. Gachon catalog 아직 비활성.
4. 나머지16학사일정 및78시간표 모두 계속. 캠퍼스 강의는 상명대 서울/천안 방식으로 분리하되 대학은 한 기관 유지.
   - 고려대 /ko/460, annualPOSTko/5는 기간 일정 시작일만 출력. 월간 POST monthSchdul.do (공식JS에 게시된 경로)에는 상세 기간 확인 필요. 추측 getSchdulJsonMonth.do는404이며 근거로 쓰지 않는다. Sejong static /kucec/3784는 오래된 고연전9월18~19, 최신8월26 수정은10월2~3; stale내용 그대로 구현 금지. official hrd.korea.ac.kr/bbs/pubs/151/272051/artclView.do 최신수정 첨부 존재.
   - 호서 최신공식 /Home/Contents.mbz?action=MAPP_2405312496 Jan2026–Mar2027 list DOM #academic_scd01/.box-month/.list-box/.list-date/.list-content. 2월6,9~12는 불연속 두 이벤트로 보존. 여름계절 최신Jun23–Jul13가2026guidePDFJun22–Jul10보다 최신. previous페이지공식 /Home/SCDList.mbz?action=MAPP_1708250140&schClassify=학부 다운됨 /tmp/daily-hoseo-calendar-legacy.html 아직 조사 전. MAPP_2507282679는 예결산2025문서, 학사일정 아님.
   - HUFS4453crosslist/3372unique 수집, tool/timetable/fetch_hufs.py/import_hufs.py 6tests. 3개Seoul13교시 실제시각 공식 미확인; 타대학clock빌리지 말 것.
   - UOS2189XLS, day13..15 미확인; KW1261XLSX 연속시간/토요일placeholder 불명; KNUE742개15week date-specificmeeting 필요; BU23PDF3156candidate2606distinct coursecodes 분반/clock/latest 검증 필요.

## 실행 제약

- Flutter root /Users/kimhwi/Documents/Codex/2026-05-26/flutter-sdk, bash tool/flutter.sh --no-pub; SDKcache/network 필요하면 sandbox escalation. narrow tests test/core/academic 및 test/features/timetable. test/core/timetable 디렉터리는 없다.
- Mac xcodebuild Runner Debug platformmacOS, -derivedDataPath build/macos MACOSX_DEPLOYMENT_TARGET=14.0; 기존 Test앱에 tar backup 후 rsync. tool/run_macos.sh는 실행도 하므로 사용 금지.
- Windows/Android/iOS 최신 검증은 미완료. 빌드/설치/실기기 흐름을 혼동하지 않는다.
- 숨긴 IAB/CLI 이용, 사용자 다른 데스크탑에 창 띄우지 않는다. CUA 재개 전 rewriteDocumentation.
- 현재 developer: 명시적 위임 승인 없이 sub-agent 생성 금지.
- 재개 시 중간 단계 지원 수치를 전체 완료처럼 말하지 않는다. completionClaim=false 유지.
