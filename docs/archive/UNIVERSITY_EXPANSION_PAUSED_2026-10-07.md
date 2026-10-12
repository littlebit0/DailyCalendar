# 대학 지원 작업 일시 중단 인계 — 2026-10-07 12:24 KST

사용자가 "중단하고 나중에 바로 이어서 할 수 있도록 메모리 기록"을 요청했다.
재개 요청을 2026-10-07에 받았다. 현재 진행 상태는 AGENT_MEMORY.md 최상단 CURRENT를 따른다. 아래는 중단 시점의 인계 기록이다.
이 파일이 2026-10-06 중단 문서보다 우선한다. 전체 완료 아님; completionClaim=false.

## 중단 당시 실제 반영 상태 (현재는 AGENT_MEMORY.md 참고)
- 대상85개 대학 + 기존 상명대(집계 밖) 보존.
- 학사일정83/85 구현·공식 실제 응답 검증·Mac Test앱 반영.
- 시간표8/85: 단국대, 부산대, 서울대, 세종대, 아주대, 인하대, 전남대, 중앙대.
- 남은 학사일정: 창원대(전체 캠퍼스; 본교만 부분 연결), 순천향대.
- 남은 시간표77개는 아래 목록. 원자료 확보는 지원 완료가 아니다.
- 지원 불가능 확정 대학0. HTTP 실패/자료 미확인만으로 불가능 판정 금지.
- installedAcceptance/device 사용자 흐름은 not_verified; 다른 플랫폼 검증 미완료.
- Mac ~/Applications/Daily Test.app checkpoint27, com.littlebit0.daily.test 동일 경로/identity 업데이트 완료. 계정·데이터·keychain 보존, 실행 안 함. 생산 /Applications/Daily.app 손대지 않음.
- 릴리스/버전 승격/커밋/푸시 없음. 기존 방대한 LMS/auth/native/sync/settings/site dirty diff 보존.

## 최신 검증 checkpoint27
한국해양대 현재 학부 HTML+공식 이전 PDF의 실제64개 일정. 정확한 Mozilla/5.0 User-Agent와 정상 published Referer 필요; cookies/login 불필요.
집중3tests+학사/시간표/Drive459tests 통과, analyze clean, Mac Debug min14 build/codesign 전후 통과.
로그 /tmp/daily-kmou-live.log, /tmp/daily-kmou-tests.log, /tmp/daily-university-checkpoint27-tests.log, /tmp/daily-university-checkpoint27-analyze.log, /tmp/daily-checkpoint27-macos-build.log.
백업 work/test-app-backups/daily-test-before-university-checkpoint27-20261007.tar.gz.
전체 앱 tests는 checkpoint25의1255pass/1skip; checkpoint27에서 full suite 재실행했다고 주장 금지.

## 중단된 수집과 재개 지점
서브에이전트 course_data_acquisition, remaining_calendars_a, remaining_calendars_b interrupt 완료.
중단 당시 parent 실행 목록에는 수집 프로세스가 없었고 session88276은 unknown process였다. 재개 시 owning agent가 PID71746의 계속 실행을 확인했으므로 종료됐다는 당시 판단은 잘못됐다. 소유 agent의 종료 확인이 필요하며 중복 재시작하지 않는다.
부경대 catalog-f/pknu-syllabus-batch-progress.json: index1150/2720, success999, cached2, notPublished148, errors2. 전체 현재 시각 검증 미완료.
재개: catalog-f/pknu-all-syllabus-batch.py 캐시를 재사용하며 이어서 수집. 성공 JSON 캐시 보존; unpublished button 요청 금지. 정상 공개 경로만, 순차·간격 유지.
포항공대 공개 상세418개 수집은 중단 전 완료(errors0), 신규 지원 활성화 아님.
추가 삼육대/서경대/수원대 조사 계획만 선정, catalog-l 디렉터리 아직 없음. 세종대는 이미 지원되므로 재조사 대상으로 중복 선정하지 않는다.

## 먼저 이어갈 일
1. AGENTS.md, AGENT_MEMORY.md 최상단, 본 문서, status JSON, 현재 dirty diff 확인. 이전 조사 재수집보다 캐시/README 먼저 확인.
2. 창원 전체 캠퍼스: calendar-b/README.md와 changwon-campus-published-flows.json 확인.
   - 거창 중앙 /CW0301/101014.asp?mi=101014 현재53행(2026Mar–2027Feb), 실제 published /2026A.asp?hday=01/02에서2026JanFeb6행. 이전 겨울 공식 notice /CW0401/101001.asp?bno=2421&page=1 actual2025Dec15–2026Jan9. generic2026winter를 이전해로 복사 금지.
   - 거창 최소 fixtures geochang-current-minimal-fixture.html, geochang-current-jan-feb-home-minimal-fixture.html, geochang-winter-minimal-fixture.html. source production 미등록.
   - 남해 현재 annual /namhae_01/web/content.do?proFn=namhae1_3 확보, 이전겨울 미확인. 게시판 이관 날짜2026에 붙은2014–2016제목을2026자료로 사용 금지.
   - 기관0000028, 거창campus0003297/남해0003298. 현재 profile save는 campusSelectionRequired=true일 때만 campusId 저장; 실제 행정 분리 근거 있을 경우 전체 grouped directory flag 일치 필요. 임의 UI 확장 금지.
3. 순천향 calendar-i: sch-2026-calendar-dom.tsv 실제 현재64행; 정상 browser 성공이 자동수집 성공 아님.
   - https://home.sch.ac.kr/sch/05/010000.jsp 와 actual2026selector: 브라우저64DOM, 무쿠키/fullChromeUA+Referer/정상 anonymous CookieJar homepage bootstrap 후에도 HTTP500. login/security 우회 금지.
   - 공식2025 통합 PDF sch-2025-integrated-academic-calendar.pdf/.txt 이전겨울2025Dec24–2026Jan15. 2026겨울 실제수업기간 미게시, 등록기간으로 수업기간 생성 금지.
4. 시간표 생산 연결에 앞서 현재 미해결 날짜별 수업 저장·editor·Drive 호환을 해결할 설계 필요.
   - ClassMeeting은 weekday/clock/room만; TimetableClass.period는 단일 기간, 전체term과 intersect.
   - SeoulTech 미래융합192actual dated sessions/303VOD, Hansung summer-credit June23–July13 등 전체fall 반복 금지.
   - store version1/Drive inner1 strict, outer2. 날짜필드를 그대로inner1추가하면 구클라이언트가 무시하고 잘못 반복할 수 있어 호환 보호 필요. 거대한 취소override/전체학기 범위 확대로 임시 해결 금지.
5. 자료 검증을 이어서 importer/registry/fixture/tests/실제 source 점검 완료 후 활성화. 원자료 확보/fixture검증/live검증/설치/device검증 구분.

## 연구 자료 요약 (생산 미활성)
- catalog-d 연세: broadquery200 cap popup. 조건분할329쿼리7184display/4926unique/capped0. 전체캠퍼스·기간·종강/분류 검증 남음. 숨긴IAB alert가 사용자화면 방해할 수 있으니 broadquery 피한다.
- catalog-f 부경: 현재2720강좌/120org, 이전July119강좌삭제+4신규; 실제room/time변경 발견. 현재계획152미게시(146externalonline+6physical). 2026Jan21 공식clock policy 확보, 50/75 구분 현재강좌 전체 확인 필요. MML multi-TL v2 사용. 전북3576/충남3888/경북4122 raw, 최신/예외 감사 남음.
- catalog-g 교육대8곳 모두 최신 공개 원자료 확보. 경인 현재6차두캠퍼스/정각clock; 진주493code+section+grade unique(grade제외4충돌)/교시clock미확인/실습보강 계획; 서울9/8최신표에폐강강좌 남아 명시filter필요; 광주전후반교체/청주10교시/춘천병합강좌 예외. education-catalog-manifest.json 확인. 성균2814/Kyonggi1640/KW1261 raw, intensive/clock/캠퍼스 미완료.
- catalog-h 한성1489계획 전량완료1466currentY+23fallbackN/errors0. 693department metadata variants 보존. Thursdaynight19:40–20:50 문서실제값을 MonWed19:25–20:40으로 통일 금지. Saturday/75분M경계/Futureplus5–8주/date 미확인. V020027-Z Jun23–Jul13 actualMonFri13–16 preterm여름학점. 서울과기1990unique, futurecollege실제dates 보존 필요.
- catalog-i 계명3166/원격48/untimed114, 순천향2598/OCU109/학내가상47 및미배정126, 제주3095/조선공개UI3255. 학내가상일요일/토요일 관리slot을 실제대면수업시간으로 바로 사용 금지.
- catalog-j 목포해양124grid/1552timecells, 전체coursecodes/credits/categories 미완료.
- catalog-k 포항공대 전체696(publicIDsunique;code-section695)/학부418unique,348timed70untimed. 학부상세418 errors0, postech-public-details/. 전체code중CITE700B-01 서로다른grad2과목을merge금지. XXX199 연구참여 중 mentor별기간/intro/final dates 때문에 전체학기weekly금지. 부산교대9/4whole4gradexlsx+8/5electivesxlsx 확보, codes/credits/closure 미완료.
- KAIST 다음공개근거 조사만 시작: https://fs.kaist.ac.kr/ko/?c=192&gbn=viewok&gp=1&ix=3847&s= actual2026fallnotice, attachment2026가을학기시간표_0827.pdf. 아직다운로드/범위검증 안 함; 대학원게시판 자료라 학부전체 여부 확인 필요.

## 실행 범위/제약
사용자 재개 요청 후 대학 학사일정/시간표 범위 내 작업과 데이터 수집 서브에이전트 병렬 허용. LMS확장/토큰실험은 보류; 코스모스대학목록별도 docs/COURSEMOS_UNIVERSITY_DISCOVERY_2026-10-07.md 보존.
수정 후 narrow meaningful tests/analyze/affectedplatformbuild/verified in-place Testupdate. 개인화면에 창띄우지 않음, 사용자요청 없이 앱실행 안 함. 로그인/계정변경/인증우회 없이 published guest flows만. contact/token/cookie 저장 금지.
Flutter /Users/kimhwi/Documents/Codex/2026-05-26/flutter-sdk + tool/flutter.sh --no-version-check.
Mac xcodebuild Runner Debug platformmacOS derivedDataPath build/macos min14, codesign verify후 tar non-app backup 및기존앱rsync. run_macos.sh는launch하므로금지.

## 남은 시간표77개
가천대, 가톨릭대, 강원대, 건국대, 경기대, 경북대, 경상국립대, 경희대, 계명대, 고려대, 경인교대, 공주교대, 광운대, 광주과기원, 광주교대, 경국대, 공주대, 군산대, 금오공과대, 목포대, 목포해양대, 부경대, 순천대, 창원대, 교통대, 한국해양대, 한밭대, 국민대, 남서울대, 대구과기원, 대구교대, 대구대, 동국대, 동아대, 동의대, 명지대, 백석대, 부산교대, 서강대, 삼육대, 서경대, 서울과기대, 서울교대, 서울시립대, 서울여대, 성균관대, 성신여대, 수원대, 순천향대, 숙명여대, 숭실대, 연세대, 영남대, 용인대, 울산과기원, 울산대, 인천대, 전북대, 전주교대, 조선대, 제주대, 진주교대, 청주교대, 춘천교대, 충남대, 충북대, 포항공대, 한경대, 공학대, 한국과기원, 교원대, 기술교대, 외대, 항공대, 한성대, 한양대, 호서대
