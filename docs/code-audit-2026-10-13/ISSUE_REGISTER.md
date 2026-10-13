# 2026-10-13 DailyCalendar 감사 이슈 전체 색인

대상: [littlebit0/DailyCalendar](https://github.com/littlebit0/DailyCalendar). **#93–#170, 78개 번호를 모두 포함**한다. 이 중 **#105–#108, #149–#153의 9건은 연계 이슈**로 분리한다. 나머지 69건은 이 대화에서 감사·등록 대상으로 추적한 항목이다. 모든 번호를 이 담당자가 단독 생성했다고 주장하지 않는다.

아래는 문제와 수정 진입점의 약칭이며 정식 이슈 본문을 대체하지 않는다. 우선순위는 해당 이슈의 현재 라벨, 실제 해결 여부는 현재 코드·PR·테스트로 확인한다. 이번 인계에서 상태·라벨을 일괄 변경하거나 이슈를 닫지 않았다.

## A. 초기 코드 감사

| 이슈 | 영역 | 문제 | 수정·검증 진입점 |
|---|---|---|---|
| [#93](https://github.com/littlebit0/DailyCalendar/issues/93) | 업데이트 | Windows 자동 업데이트의 즉시 종료로 미저장 편집 유실 | 편집 저장·종료 준비 완료 후 업데이트 전환; 실패 시 복구 |
| [#94](https://github.com/littlebit0/DailyCalendar/issues/94) | 알림·알람 | 알람 미지원·권한 거부 기기에서 편집 시 기존 알람 OFF 저장 | 저장된 선호와 현재 기기 실행 가능 여부를 분리 |
| [#95](https://github.com/littlebit0/DailyCalendar/issues/95) | LMS·성능 | LMS 항목마다 전체 일정 테이블 조회 | 한 배치의 인덱싱·최신 상태 병합으로 반복 전량 조회 제거 |
| [#96](https://github.com/littlebit0/DailyCalendar/issues/96) | 반복 일정 | 완료 후 같은 상세창이 옛 회차 ID를 계속 사용 | 분리된 실제 저장 ID를 반환·재사용하고 순차 토글 검증 |
| [#97](https://github.com/littlebit0/DailyCalendar/issues/97) | 반복 일정 | 월말·윤일 보정 후 원래 반복 기준일을 잃음 | 최초 기준일+회차 인덱스 계산; Dart/Swift 양쪽 동등성 |
| [#98](https://github.com/littlebit0/DailyCalendar/issues/98) | 릴리스 | Apple 릴리스가 입력 태그 대신 실행 브랜치 소스를 빌드 | 태그→고정 SHA 체크아웃, 패키지 버전·릴리스 노트 검증 |
| [#99](https://github.com/littlebit0/DailyCalendar/issues/99) | 가져오기·성능 | Android 외부 캘린더 전량 조회·변환이 메인 스레드에서 실행 | 권한 UI와 작업 스레드 조회 분리; 취소·반환 비용 계측 |
| [#100](https://github.com/littlebit0/DailyCalendar/issues/100) | 가져오기 | BYDAY·BYMONTHDAY 등 반복 조건 유실 | Google/Android/iOS 원본→중간 모델→회차 계산 전체 보존 |
| [#101](https://github.com/littlebit0/DailyCalendar/issues/101) | 가져오기 | Google 반복 일정의 취소·이동 예외 유실 | 부모 ID·originalStartTime·EXDATE/RDATE 관계 유지 |
| [#102](https://github.com/littlebit0/DailyCalendar/issues/102) | 위젯 | 위젯 회차 완료가 반복 원본 전체 완료로 연결 | Android·Apple·Windows payload에 실제 회차 식별자 유지 |
| [#103](https://github.com/littlebit0/DailyCalendar/issues/103) | 위젯 | 날짜 변경 후 이전 스냅샷의 오늘 일정·D-day 재사용 | 표시 기준일·캐시 범위 재계산; 플랫폼별 경로 구분 |
| [#104](https://github.com/littlebit0/DailyCalendar/issues/104) | 알림·알람 | 앱 시작 전체 재예약이 스누즈·울림 상태를 취소 | Android·macOS·iOS의 실제 예약 상태와 변경 필요분 비교 |

## B. 별도 권한·배포·개인정보 연계

| 이슈 | 영역 | 문제 | 수정·검증 진입점 |
|---|---|---|---|
| [#105](https://github.com/littlebit0/DailyCalendar/issues/105) | 연계·권한 | 대학 학사·시간표·LMS 이용 권한의 공식 근거 확인 | 다른 작업의 연계 이슈; 기술적 접근과 권한 판정을 혼동하지 않음 |
| [#106](https://github.com/littlebit0/DailyCalendar/issues/106) | 연계·배포 | 대학 자료의 배포 포함 범위와 이용 권한 대응 | 다른 작업의 연계 이슈; 지원 중단과 패키지 제외 구분 |
| [#107](https://github.com/littlebit0/DailyCalendar/issues/107) | 연계·LMS | 학교가 허용한 조회·인증 절차의 적용 범위 | 다른 작업의 연계 이슈; 실제 학교 실행·지원 확대 재개 금지 |
| [#108](https://github.com/littlebit0/DailyCalendar/issues/108) | 연계·문서 | LMS 저장·Drive 동기화·삭제 범위 안내 | 다른 작업의 연계 이슈; 자격정보와 학습정보의 처리 설명 구분 |

## C. 인증·위젯·알림·Siri·Drive

| 이슈 | 영역 | 문제 | 수정·검증 진입점 |
|---|---|---|---|
| [#109](https://github.com/littlebit0/DailyCalendar/issues/109) | 가져오기 | EventKit의 4년 조회 제한으로 현재 일정 누락 가능 | API 범위에 맞는 분할 조회 및 경계 중복 방지 |
| [#110](https://github.com/littlebit0/DailyCalendar/issues/110) | 인증 | iOS OAuth 창 시작 실패 전에 결과 콜백을 삭제 | 콜백 확보→정리→정확히 한 번 실패 전달; 늦은 작업 격리 |
| [#111](https://github.com/littlebit0/DailyCalendar/issues/111) | 위젯·저장 | Apple 공유 큐의 append/ack 전체 덮어쓰기로 요청 유실 | 프로세스 간 읽기-변경-쓰기 보호와 토큰별 확인 |
| [#112](https://github.com/littlebit0/DailyCalendar/issues/112) | 비동기 | 위젯·Siri 처리 중 새 신호에 재실행을 예약하지 않음 | 직렬 drain+재실행 표시; 실패 무한 재시도와 구분 |
| [#113](https://github.com/littlebit0/DailyCalendar/issues/113) | 인증 | 이전 OAuth 갱신 응답이 로그아웃·새 계정 뒤 저장 | 요청 당시 세대·계정에 결과를 결속하고 저장/삭제 commit 보호 |
| [#114](https://github.com/littlebit0/DailyCalendar/issues/114) | 설정·동기화 | D-day 알림 빈 배열이 복원 시 기본 알림으로 변경 | 유효한 []와 필드 누락·형식 오류를 구분 |
| [#115](https://github.com/littlebit0/DailyCalendar/issues/115) | 위젯·저장 | Windows 대기 큐 저장 실패 반환값 무시 | 추가·ack의 영속 저장 결과 전달, 미처리 토큰 복구 |
| [#116](https://github.com/littlebit0/DailyCalendar/issues/116) | 음성 | 취소 뒤 늦은 권한 콜백이 마이크를 시작할 수 있음 | 권한 대기부터 요청 ID/세대 관리; 이전 콜백의 새 요청 접근 차단 |
| [#117](https://github.com/littlebit0/DailyCalendar/issues/117) | 알림 | 반복 원본 첫 시작일만 일반 알림 예약 | 회차별 제한 범위 예약·보충·식별·취소 정책 |
| [#118](https://github.com/littlebit0/DailyCalendar/issues/118) | 알림 | 대체 알람이 불가능해도 정시 일반 알림을 생략 | 실제 대체 예약 성공을 확인한 경우만 중복 억제 |
| [#119](https://github.com/littlebit0/DailyCalendar/issues/119) | 알림·동기화 | 원격 알림 설정이 OS 예약에 미반영 | 최종 설정으로 후속 예약 조정; 제거된 사용자 지정 D-day 키도 취소 |
| [#120](https://github.com/littlebit0/DailyCalendar/issues/120) | Linux | 알림 한 파일의 JSON·전달 예외가 전체 배치를 중단 | 형식 검사와 항목별 실패 격리·재시도 분리 |
| [#121](https://github.com/littlebit0/DailyCalendar/issues/121) | Drive·성능 | 큰 OR 쿼리와 일정별 원격 목록 재탐색 | 요청 크기별 배치 및 ID→복수 파일 인덱싱 |
| [#122](https://github.com/littlebit0/DailyCalendar/issues/122) | Linux·보안 | notify-send 인자에 일정 제목·본문 포함 | 내용을 argv/환경변수로 노출하지 않는 전달 경로 |
| [#123](https://github.com/littlebit0/DailyCalendar/issues/123) | 반복 일정 | Siri·배경화면이 until 당일·마지막 연속 회차를 누락 | Swift 날짜 포함 규칙과 SQL 선별 범위를 함께 수정 |
| [#124](https://github.com/littlebit0/DailyCalendar/issues/124) | Siri·검증 | 생성형 응답 검증이 일정명·시간 뒤바뀜 등을 허용 | 사실 필드를 구조화해 결정적으로 렌더링; 검증 실패 시 원문 |
| [#125](https://github.com/littlebit0/DailyCalendar/issues/125) | Siri·반복 | 날짜별 엔티티 선택이 원본 전체 수정·삭제로 연결 | 회차 키와 작업 범위 보존; 날짜·범위 명시적 확인 |
| [#126](https://github.com/littlebit0/DailyCalendar/issues/126) | Linux·성능 | 외부 알림 전달 중 전체 저장소 파일 잠금 유지 | 외부 I/O와 짧은 commit 분리; 취소·재예약 버전 보호 |
| [#127](https://github.com/littlebit0/DailyCalendar/issues/127) | Siri·SQLite | sqlite3_step 오류를 정상 빈/부분 조회로 처리 | ROW·DONE·오류·의도적 limit 중단을 구분 |
| [#128](https://github.com/littlebit0/DailyCalendar/issues/128) | Signal | schedule·reschedule 부분 문자열을 추가 명령으로 오인 | 명사/동사·변경 의도 구분; 규칙/모델 충돌 시 안전한 확인 |

## D. 시간표·DB·제보·수신기

| 이슈 | 영역 | 문제 | 수정·검증 진입점 |
|---|---|---|---|
| [#129](https://github.com/littlebit0/DailyCalendar/issues/129) | 시간표 | 휴강·강의 방식 예외가 있는 수업의 요일 변경 실패 | 요일 변경 시 예외 유효성·재배치 정책 연결 |
| [#130](https://github.com/littlebit0/DailyCalendar/issues/130) | DB | 구형 DB에 필수 열 없이 스키마 9로 표시 | 모든 과거 버전의 마이그레이션 경로와 최종 필수 열 검증 |
| [#131](https://github.com/littlebit0/DailyCalendar/issues/131) | DB | 두 rename 사이 중단 후 기존 DB 복구 누락 | 미완료 교체 저널·다음 실행 복구; 신규 설치 오판 방지 |
| [#132](https://github.com/littlebit0/DailyCalendar/issues/132) | DB | 마이그레이션 스냅샷 전후 독립 writer 변경 유실 | 실제 교체 대상 최신 상태·Siri 등 writer 동시성 조정 |
| [#133](https://github.com/littlebit0/DailyCalendar/issues/133) | 시간표 | 실제 기간이 안 겹쳐도 요일·시간만으로 충돌 판정 | 학기·강좌 기간과 실제 수업 날짜 집합 반영 |
| [#134](https://github.com/littlebit0/DailyCalendar/issues/134) | 시간표·성능 | 강의 검색 입력·카드 상태마다 전체 재계산 | 소속·충돌·검색 정규화 캐시 및 입력별 필요한 계산 분리 |
| [#135](https://github.com/littlebit0/DailyCalendar/issues/135) | 버그 제보 | 생성 응답 유실 후 중복 제보·연락 정보 정리 오류 | 안정적인 요청 ID, 생성 결과 확인·재시도 멱등성 |
| [#136](https://github.com/littlebit0/DailyCalendar/issues/136) | 분석·성능 | 요청마다 당일 집계·중복 방지 JSON 전체 재처리 | 증분 저장·인덱스와 실제 처리량 측정 |

## E. 분석·설정·잠금·자연어·저장

| 이슈 | 영역 | 문제 | 수정·검증 진입점 |
|---|---|---|---|
| [#137](https://github.com/littlebit0/DailyCalendar/issues/137) | 알림 UI | 사용자 지정 D-day 값이 설정에 표시되지 않음 | presets+저장값 표시·해제; 화면과 실제 활성 값 일치 |
| [#138](https://github.com/littlebit0/DailyCalendar/issues/138) | 분석 | UTC 날짜를 넘긴 재전송을 다시 집계 | 보존 기간 전체의 중복 검사; 수신일과 발생일 구분 |
| [#139](https://github.com/littlebit0/DailyCalendar/issues/139) | 분석·저장 | 집계와 중복 기록을 별도 저장해 부분 실패 시 재집계 | 집계 증가+중복 표시의 원자적 commit 또는 복구 저널 |
| [#140](https://github.com/littlebit0/DailyCalendar/issues/140) | 분석·동의 | 동의 OFF 저장 실패를 무시해 재실행 후 ON 가능 | 즉시 수집 차단·영속 저장 실패 처리·철회 복구 |
| [#141](https://github.com/littlebit0/DailyCalendar/issues/141) | 분석·보존 | flush 재시도 전에 7일 만료를 재검사하지 않음 | 각 전송 선택 직전 만료 정리·영속 큐 및 타이머 갱신 |
| [#142](https://github.com/littlebit0/DailyCalendar/issues/142) | 계정·알림 | 로그아웃 취소 실패 후 이전 계정 예약이 남음 | 항목별 정리·삭제 전 최소 예약 ID 보존·새 계정과 격리 |
| [#143](https://github.com/littlebit0/DailyCalendar/issues/143) | 잠금 | PIN 보안 저장소 오류 후 checking 상태 고정 | 잠금은 유지하며 finally/오류 상태로 재시도 복구 |
| [#144](https://github.com/littlebit0/DailyCalendar/issues/144) | 자연어 | 2시간 전·20분 전 알림을 실제 일정 시각으로 중복 소비 | 날짜·시간·알림 토큰 구간 구분 및 초안 전체 검증 |
| [#145](https://github.com/littlebit0/DailyCalendar/issues/145) | 일정 저장 | DB commit 후 알림 실패를 미저장으로 안내해 재시도 중복 | 저장 ID/commit과 후속 작업 결과 분리·멱등적 재시도 |
| [#146](https://github.com/littlebit0/DailyCalendar/issues/146) | 자연어 | 잘못된 날짜·시각을 다른 날짜·종일로 조용히 보정 | 부재·유효·오류 토큰 구분; 원문 보존과 수정 확인 |
| [#147](https://github.com/littlebit0/DailyCalendar/issues/147) | 진단 | 실제 buildNumber 대신 version을 중복 전송 | 클라이언트 매핑과 서버 buildNumber 형식 검증을 함께 수정 |
| [#148](https://github.com/littlebit0/DailyCalendar/issues/148) | 분류·저장 | 분류 설정 저장 후 일정 갱신 실패로 불일치 | 두 저장소 작업의 commit·보상·재시도 상태 관리 |

## F. 병행 운영 계측 연계

| 이슈 | 영역 | 문제 | 수정·검증 진입점 |
|---|---|---|---|
| [#149](https://github.com/littlebit0/DailyCalendar/issues/149) | 연계·계측 | 마이그레이션 완료와 캘린더 사용 준비 계측 구분 | 병행 분석 이슈; 이 감사의 새 성능 측정으로 인용하지 않음 |
| [#150](https://github.com/littlebit0/DailyCalendar/issues/150) | 연계·계측 | 주사율별 끊김 비율·전체 프레임 분모 구분 | 병행 분석 이슈; 실제 하드웨어 측정은 별도 |
| [#151](https://github.com/littlebit0/DailyCalendar/issues/151) | 연계·계측 | 120000ms 상한에 걸린 시간과 정확한 경계값 구분 | 병행 분석 이슈; 과거 잘린 시간을 복원·추정하지 않음 |
| [#152](https://github.com/littlebit0/DailyCalendar/issues/152) | 연계·계측 | 동기화 시도 시작·종료·결과 불명 연결 | 병행 분석 이슈; 이벤트 차이를 실패 건수로 단정하지 않음 |
| [#153](https://github.com/littlebit0/DailyCalendar/issues/153) | 연계·계측 | 미계측 기능과 필터 취소를 사용 성공과 구분 | 병행 분석 이슈; 미계측을 이용 0회로 취급하지 않음 |

## G. 계약·알림 ID·LMS 최신성

| 이슈 | 영역 | 문제 | 수정·검증 진입점 |
|---|---|---|---|
| [#154](https://github.com/littlebit0/DailyCalendar/issues/154) | 버그 제보 | 글자 한도 내 한국어 JSON도 16 KiB 한도 초과 | 입력·UTF-8 바이트·서버 제한 정합성과 실패 초안 보존 |
| [#155](https://github.com/littlebit0/DailyCalendar/issues/155) | 알림 | 다른 합성 UUID가 같은 알림 정수 ID로 충돌 | 예약 ID 충돌 검출·소유권·지속적인 역매핑 |
| [#156](https://github.com/littlebit0/DailyCalendar/issues/156) | 분석 검증 | 배열·객체 필드가 400 대신 TypeError로 전파 | 타입 우선 검증과 일관된 거절 응답 |
| [#157](https://github.com/littlebit0/DailyCalendar/issues/157) | LMS 표시 | 부분 조회 실패 항목에 전체 갱신의 새 시각 표시 | 항목의 마지막 확인과 전체 작업 완료 시각 구분 |

## H. 사용자 요청 4건과 검색

| 이슈 | 영역 | 문제 | 수정·검증 진입점 |
|---|---|---|---|
| [#158](https://github.com/littlebit0/DailyCalendar/issues/158) | 사용자 요청·LMS | macOS 정상, iOS에서만 저장 계정 자동 로그인 실패 | headless host 준비·정확한 cookie-store 결속·실제 auto-login 경로 검증 |
| [#159](https://github.com/littlebit0/DailyCalendar/issues/159) | 사용자 요청·LMS | 저장 계정 재로그인·비밀번호 표시/숨김 버튼 | 추가 저장·재입력 없이 재시도; 암호 확인 입력란을 새로 요구하지 않음 |
| [#160](https://github.com/littlebit0/DailyCalendar/issues/160) | 사용자 요청·LMS | ID 표기와 Apple 암호 자동완성 | username/password 의미 힌트·AutofillGroup·사용자 선택·도메인 연결 조건 |
| [#161](https://github.com/littlebit0/DailyCalendar/issues/161) | 사용자 요청·빠른보기 | 옆 카드 높이를 따르는 분류 박스 아래 공백 | Wrap 줄 배치를 열별 콘텐츠 높이 배치로; 기존 모바일 열 수 보존 |
| [#162](https://github.com/littlebit0/DailyCalendar/issues/162) | 검색 | 조회 실패를 결과 없음으로 표시 | hasError·빈 결과·기존 결과·재시도 상태 구분 |
| [#163](https://github.com/littlebit0/DailyCalendar/issues/163) | 검색 | 빠른보기 검색 버튼에 대응하는 입력 패널 없음 | 보기 분기와 search state/focus/실제 입력 UI 연결 |

## I. 최종 반복 일정·표시·수명주기

| 이슈 | 영역 | 문제 | 수정·검증 진입점 |
|---|---|---|---|
| [#164](https://github.com/littlebit0/DailyCalendar/issues/164) | 반복 일정 | 이동·분리 수정의 중간 실패로 원래 회차만 제거 | 최신 원본+새 회차+완료값 원자적 저장, 후속 효과 분리 |
| [#165](https://github.com/littlebit0/DailyCalendar/issues/165) | 반복 일정 | 완료된 반복 회차의 월간 이동·분리 수정에서 false 초기화 | 최초 분리 저장에 완료값 포함; 월·주·일·상세 경로 통일 |
| [#166](https://github.com/littlebit0/DailyCalendar/issues/166) | 반복 일정 | 편집 범위의 기준일·전체 count 재사용으로 누락·추가 | 실제 변경 필드 추적; 최초 기준일·남은 횟수 정규화 |
| [#167](https://github.com/littlebit0/DailyCalendar/issues/167) | 반복 일정 | 편집 draft의 excludedDates 누락으로 삭제 회차 부활 | 최신 제외 집합·범위별 분할·분리 회차 관계 보존 |
| [#168](https://github.com/littlebit0/DailyCalendar/issues/168) | 반복 일정 | 동시 완료가 서로의 제외 날짜를 덮어씀 | 읽기·병합·회차 분리·저장을 같은 트랜잭션/버전 검사 안으로 |
| [#169](https://github.com/littlebit0/DailyCalendar/issues/169) | 표시 필터 | 하루 패널 실시간 결과에서 숨김·D-day·검색 필터 누락 | 부모와 패널 공통 표시 정책; 원본 데이터 소비자는 별도 유지 |
| [#170](https://github.com/littlebit0/DailyCalendar/issues/170) | 성능·수명주기 | 날짜 family provider의 제한 없는 상태 보존 | autoDispose/상한 캐시; pause와 dispose 구분해 실제 계측 |

## 주의

- #87에 추가했던 completed 누락 원인 설명은 철회됐다. 원래 신고 자체를 삭제하지 않는다.
- #97·#100·#102·#103·#104의 후속 플랫폼 확장 근거와 #119·#147·#161·#164의 추가 댓글도 함께 읽는다.
- #105–#108은 이번 인계에서 본문을 확인한 연결 과제다. 이 문서는 새 법률 판단이나 수집 권한 부여가 아니다.
- #149–#153의 운영 집계는 다른 작업의 관찰이다. 이 감사가 실제 운영 서버를 읽거나 장치를 측정한 결과로 인용하지 않는다.
- #143은 인계 확인 시 priority: critical 라벨이었다. 과거 추정 중요도로 덮어쓰지 않는다. 나머지 우선순위도 구현 전 최신 라벨 확인.
