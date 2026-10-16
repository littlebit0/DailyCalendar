# 전체 오픈 이슈 우선순위 — 2026-10-16

완료 처리: #200/#217/#218/#202/#236. 앞 세 건은 커밋·전체 CI 완료, 뒤 두 건은 로컬 구현·검증 완료이며 미커밋·미배포. 원격 closed/completed 확인.

전체 오픈142건과 아래142건이 일치한다. 이슈 본문과 작업 기록 기반의 작업 순서이며 이번에 전체를 실기기로 재현하거나 현행 코드를 전수 감사한 결과는 아니다. 착수 시 현행 코드를 재대조한다. 데이터·인증 보존, 일정 정확성, 기능 장애, 성능, 편의 순으로 배치했다. 대학 관련 중단 작업은 후순위에 실행 보류로 표시했으며 위험이 낮다는 판정이나 재개 승인이 아니다. 기존 GitHub 라벨은 변경하지 않았다.

#95/#99/#134/#191은 구현·관련검사 완료지만 이슈의 성능 실측 조건이 남아 오픈 유지. #158도 전체 수용 조건 완료를 확정하지 않았다. #260은 앞서 사용자 지시로 완료 처리됐다. 이번 작업은 이슈·문서·메모리 정리이며 제품 수정·앱 설치/실행·커밋/푸시는 하지 않았다.

1. [#113](https://github.com/littlebit0/DailyCalendar/issues/113) **[버그] OAuth 갱신 응답이 로그아웃·계정 변경 뒤 저장되어 이전 세션을 되살리거나 계정과 토큰이 섞이는 문제** — 계정 전환 후 이전 토큰 혼합 위험으로 계정 경계 보호가 우선.
2. [#131](https://github.com/littlebit0/DailyCalendar/issues/131) **[버그] DB 교체의 두 rename 사이에서 중단되면 다음 실행이 기존 DB를 복구하지 않고 신규 설치로 판단하는 문제** — DB 교체 중 중단 시 기존 자료를 신규 설치로 오인할 수 있어 복구가 우선.
3. [#132](https://github.com/littlebit0/DailyCalendar/issues/132) **[버그] DB 마이그레이션이 동시 저장을 조정하지 않아 스냅샷 전후의 새 일정 변경을 잃는 문제** — 마이그레이션 중 성공한 저장 유실 위험으로 동시 쓰기 보호가 우선.
4. [#172](https://github.com/littlebit0/DailyCalendar/issues/172) **[버그] 앱 잠금 설정 저장 실패를 성공으로 처리하고 기존 PIN을 삭제하는 문제** — 설정 저장 실패 후 PIN까지 삭제할 수 있어 인증 자료 보존이 우선.
5. [#207](https://github.com/littlebit0/DailyCalendar/issues/207) **[버그] Android 보안 저장소 읽기 오류가 원본 삭제와 정상 null 응답으로 바뀌는 문제** — Android 읽기 오류가 원본 삭제로 바뀌므로 영구 손실부터 방지.
6. [#208](https://github.com/littlebit0/DailyCalendar/issues/208) **[버그] Android 암호화 마이그레이션이 새 데이터 저장 전에 기존 복호화 키를 삭제하는 문제** — 새 암호화 저장 전에 기존 키를 삭제하므로 중단 시 복구 불능부터 방지.
7. [#201](https://github.com/littlebit0/DailyCalendar/issues/201) **[버그] Apple 보안 저장 플러그인의 갱신 실패 후 삭제·재추가로 이전 인증 자료가 유실될 수 있음** — Apple Keychain 갱신 실패 후 기존 인증 자료 유실 위험부터 방지.
8. [#205](https://github.com/littlebit0/DailyCalendar/issues/205) **[버그] Windows 보안 저장이 복호화 환경·메모리 오류에서도 암호화 원본 전체를 삭제** — Windows 복호화 환경 오류에서도 원본 전체 삭제 가능성이 있어 우선 수정.
9. [#140](https://github.com/littlebit0/DailyCalendar/issues/140) **[버그] 분석 동의 해제 저장이 실패해도 성공으로 처리하여 재실행 후 수집이 다시 켜질 수 있는 문제** — 분석 동의 해제가 저장되지 않으면 재수집될 수 있어 동의 보호가 우선.
10. [#142](https://github.com/littlebit0/DailyCalendar/issues/142) **[버그] 로그아웃·초기화에서 알림 취소가 실패하면 이전 계정의 예약과 일정 내용이 남는 문제** — 로그아웃 뒤 이전 계정 알림 내용이 남을 수 있어 개인정보 경계 우선.
11. [#116](https://github.com/littlebit0/DailyCalendar/issues/116) **[버그] 음성 입력 취소 뒤 늦은 권한 응답이 마이크를 시작하고 이전 콜백이 새 요청에 적용되는 문제** — 취소한 음성 입력이 마이크를 켤 수 있어 취소 보장 우선.
12. [#164](https://github.com/littlebit0/DailyCalendar/issues/164) **[버그] 반복 일정 이동·분리 수정을 나눠 저장해 중간 실패 시 원래 회차만 제거되는 문제** — 반복 이동의 부분 실패로 원래 회차만 사라질 수 있어 원자적 저장 우선.
13. [#125](https://github.com/littlebit0/DailyCalendar/issues/125) **[버그] Siri에서 날짜별 반복 회차를 선택해도 원본 ID로 전체 반복을 수정·삭제하는 문제** — Siri 단일 회차 삭제가 전체 반복에 적용될 수 있어 파괴적 범위 오류 우선.
14. [#166](https://github.com/littlebit0/DailyCalendar/issues/166) **[버그] 반복 일정 편집 범위에 맞게 기준일·남은 횟수를 조정하지 않아 회차가 누락·추가되는 문제** — 반복 편집이 회차를 삭제·추가할 수 있어 기준일과 횟수 보정 우선.
15. [#167](https://github.com/littlebit0/DailyCalendar/issues/167) **[버그] 반복 일정 편집 저장 시 제외 날짜가 초기화되어 삭제·완료한 회차가 다시 생성되는 문제** — 제목 편집만으로 삭제한 반복 회차가 되살아날 수 있어 제외 날짜 보존 우선.
16. [#168](https://github.com/littlebit0/DailyCalendar/issues/168) **[버그] 서로 다른 반복 회차를 동시에 완료하면 원본 제외 날짜가 덮어써져 회차가 중복되는 문제** — 동시 완료가 제외 날짜를 덮을 수 있어 반복 원본 경합 수정 우선.
17. [#102](https://github.com/littlebit0/DailyCalendar/issues/102) **[버그] Android·Apple·Windows 위젯에서 반복 회차를 완료하면 반복 일정 전체가 완료되는 문제** — 위젯 한 회차 완료가 전체 반복을 완료할 수 있어 식별자 수정 우선.
18. [#145](https://github.com/littlebit0/DailyCalendar/issues/145) **[버그] 일정 DB 저장 후 알림 처리 실패를 전체 실패로 표시해 재시도에서 중복 일정이 생성되는 문제** — 저장 성공을 실패로 안내해 중복을 만들 수 있어 결과 분리 우선.
19. [#93](https://github.com/littlebit0/DailyCalendar/issues/93) **[버그] Windows 자동 업데이트의 즉시 exit(0)로 미저장 편집이 유실되는 경로 수정** — 자동 업데이트가 미저장 편집을 잃게 할 수 있어 다음 배포 전 수정.
20. [#94](https://github.com/littlebit0/DailyCalendar/issues/94) **[버그] 알람 미지원·권한 거부 기기에서 일정 편집 시 기존 알람 설정이 자동 해제됨** — 제목 편집만으로 기존 알람이 꺼질 수 있어 설정 보존 우선.
21. [#117](https://github.com/littlebit0/DailyCalendar/issues/117) **[버그] 반복 일정의 첫 시작일만 알림으로 예약해 이후 회차 알림이 누락되는 문제** — 첫 회차 이후 반복 알림 누락으로 알림 작업 중 우선 처리.
22. [#155](https://github.com/littlebit0/DailyCalendar/issues/155) **[버그] 서로 다른 일정의 알림 ID 해시가 충돌해 예약을 덮어쓰거나 다른 일정 알림을 취소하는 문제** — 서로 다른 일정의 알림 덮어쓰기·취소 위험으로 식별 충돌 우선 해결.
23. [#118](https://github.com/littlebit0/DailyCalendar/issues/118) **[버그] 시스템 알람을 실행할 수 없는 기기에서도 정시 일반 알림을 생략하는 문제** — 시스템 알람과 일반 알림이 모두 빠질 수 있어 대체 알림 우선 보장.
24. [#104](https://github.com/littlebit0/DailyCalendar/issues/104) **[버그] 앱 시작 시 알람 전체 재예약으로 Android·Apple의 스누즈 상태가 사라지는 문제** — 앱 실행만으로 스누즈 예약이 사라질 수 있어 시작 재예약 정책 수정.
25. [#96](https://github.com/littlebit0/DailyCalendar/issues/96) **[버그] 반복 일정 상세창에서 완료 해제 시 실제 상태가 유지되고 재완료하면 회차가 중복 생성됨** — 완료 취소·재완료가 상태 불일치와 중복을 만들 수 있어 우선 수정.
26. [#97](https://github.com/littlebit0/DailyCalendar/issues/97) **[버그] 월말·윤일 반복 일정이 보정된 날짜를 계속 기준으로 삼아 원래 반복일을 잃는 문제** — 월말·윤일 반복이 원래 날짜를 잃으므로 반복 정확성 우선.
27. [#101](https://github.com/littlebit0/DailyCalendar/issues/101) **[버그] Google 캘린더 가져오기에서 취소·이동된 반복 회차의 예외 정보가 유실됨** — 취소·이동한 외부 반복 회차가 되살아날 수 있어 예외 보존 우선.
28. [#100](https://github.com/littlebit0/DailyCalendar/issues/100) **[버그] 외부 캘린더 반복 규칙의 BYDAY·BYMONTHDAY 조건을 누락해 다른 날짜로 가져오는 문제** — 반복 조건 누락으로 다른 날짜에 저장될 수 있어 가져오기 정확성 우선.
29. [#109](https://github.com/littlebit0/DailyCalendar/issues/109) **[버그] iOS 외부 캘린더 조회가 EventKit의 4년 제한 때문에 1970년대 범위로 잘리는 문제** — iOS 현재 일정을 못 가져올 수 있어 조회 범위부터 수정.
30. [#111](https://github.com/littlebit0/DailyCalendar/issues/111) **[버그] Apple 위젯 완료 요청과 앱의 처리 확인이 동시에 저장되면 대기 작업이 유실되는 문제** — Apple 위젯 동시 저장이 완료 요청을 유실할 수 있어 큐 원자성 우선.
31. [#115](https://github.com/littlebit0/DailyCalendar/issues/115) **[버그] Windows 위젯 완료 요청의 파일 저장 실패를 무시해 요청이 유실되거나 재실행 후 재적용되는 문제** — Windows 위젯 저장 실패가 요청 유실·재적용을 만들 수 있어 우선 수정.
32. [#148](https://github.com/littlebit0/DailyCalendar/issues/148) **[버그] 분류 수정 중 일정 갱신 실패 시 설정과 기존 일정 분류가 불일치하는 문제** — 분류 변경의 부분 실패가 설정과 일정 자료를 갈라놓아 일관성 우선.
33. [#165](https://github.com/littlebit0/DailyCalendar/issues/165) **[버그] 완료된 반복 일정의 월간 이동·개별 수정에서 새 회차가 미완료로 초기화되는 문제** — 완료 회차 편집이 미완료로 바뀌므로 사용자 상태 보존 필요.
34. [#87](https://github.com/littlebit0/DailyCalendar/issues/87) **[학사/LMS] Google Drive 동기화·일정 보존·완료 상태·동영상 출석 처리 버그 수정** — 일부 수정된 묶음 이슈이므로 남은 보존·완료 연동 범위부터 확정.
35. [#158](https://github.com/littlebit0/DailyCalendar/issues/158) **[버그] iOS LMS 모바일 웹 로그인 인식 실패 및 저장 계정 자동로그인 실패** — 로그인 수정은 있으나 전체 수용 확인이 남아 잔여 검증 우선.
36. [#98](https://github.com/littlebit0/DailyCalendar/issues/98) **[버그] Apple 릴리스 워크플로가 입력한 태그 대신 실행 브랜치 코드를 빌드하는 문제** — 태그와 다른 코드를 배포할 수 있어 다음 Apple 릴리스 전 필수.
37. [#226](https://github.com/littlebit0/DailyCalendar/issues/226) **[버그] iOS package_info_plus의 파일 날짜 API 필수 사유 선언 누락** — 필수 사유 선언 누락은 심사에 영향 가능하므로 다음 iOS 제출 전 확인.
38. [#203](https://github.com/littlebit0/DailyCalendar/issues/203) **[버그] Linux 보안 저장의 libsecret 오류 메시지 포인터가 자동 해제 후 catch에서 사용됨** — Linux 오류 처리의 해제 포인터 접근으로 충돌 방지 필요.
39. [#233](https://github.com/littlebit0/DailyCalendar/issues/233) **[버그] Android LMS WebView 해제 후 엔진 정리에서 null 역참조가 발생하는 문제** — Android WebView 종료 시 null 역참조 가능성이 있어 종료 안정성 우선.
40. [#240](https://github.com/littlebit0/DailyCalendar/issues/240) **[버그] Windows WebView의 정상 null 콜백 응답이 권한·JS 처리에서 역참조되는 문제** — Windows 정상 null 응답도 역참조될 수 있어 기본 응답 처리 우선.
41. [#241](https://github.com/littlebit0/DailyCalendar/issues/241) **[버그] Windows WebView 메시지의 필수 키 누락이 native JSON 예외로 이어지는 문제** — 페이지 메시지 필수 키 누락이 native 예외로 이어져 입력 검증 필요.
42. [#246](https://github.com/littlebit0/DailyCalendar/issues/246) **[버그] macOS/iOS WebView 메시지 입력을 등록 확인·검증 전에 강제 변환하여 충돌할 수 있는 문제** — Apple 메시지 강제 변환으로 충돌할 수 있어 타입·등록 검증 필요.
43. [#185](https://github.com/littlebit0/DailyCalendar/issues/185) **[버그] Windows 문자열 변환 실패가 unsigned 길이 오류로 대용량 메모리 할당을 시도하는 문제** — 문자열 변환 실패가 대용량 할당으로 이어질 수 있어 오류 길이 보호.
44. [#184](https://github.com/littlebit0/DailyCalendar/issues/184) **[버그] Windows 트레이 아이콘이 없을 때도 창을 숨기고 작업 표시줄 재생성 뒤 복구하지 않는 문제** — 트레이 없이 창을 숨기면 앱 접근이 막힐 수 있어 복구 경로 우선.
45. [#110](https://github.com/littlebit0/DailyCalendar/issues/110) **[버그] iOS Google 인증 창 시작 실패 시 결과 콜백이 유실되어 시간 초과까지 대기하는 문제** — 인증 창 시작 실패가 긴 대기로 바뀌므로 실패 콜백 복원.
46. [#249](https://github.com/littlebit0/DailyCalendar/issues/249) **[버그] Android LMS 쿠키 복원에서 만료 시각이 12시간 형식으로 변하는 문제** — 쿠키 만료 시각 오류로 재로그인을 유발할 수 있어 세션 복원 수정.
47. [#227](https://github.com/littlebit0/DailyCalendar/issues/227) **[버그] iOS·macOS 날씨 위치 조회가 시간초과된 뒤 실제 위치 업데이트를 중단하지 않는 문제** — 시간초과 뒤 위치 조회가 계속될 수 있어 배터리·위치 수명 관리 필요.
48. [#122](https://github.com/littlebit0/DailyCalendar/issues/122) **[보안] Linux 알림 제목·본문이 notify-send의 프로세스 인자에 포함되는 경로 제거** — 일정 내용이 프로세스 인자에 노출되므로 전달 경계 정리 필요.
49. [#141](https://github.com/littlebit0/DailyCalendar/issues/141) **[버그] 분석 큐의 재시도 경로가 보존 기간을 재검사하지 않아 만료 이벤트를 계속 보관·전송하는 문제** — 만료 분석 이벤트가 전송될 수 있어 보존 기간을 재시도에도 적용.
50. [#192](https://github.com/littlebit0/DailyCalendar/issues/192) **[버그] 비한국어 UI에서 LMS 저장 동의 등 28개 번역 키가 누락되어 한국어로 표시됨** — 저장 동의가 지원 언어로 나오지 않아 일반 번역보다 먼저 개선.
51. [#119](https://github.com/littlebit0/DailyCalendar/issues/119) **[버그] Drive로 변경된 알림 설정이 OS 예약에 반영되지 않아 꺼진 아침 브리핑이 남는 문제** — 동기화로 끈 알림이 OS에 남을 수 있어 예약 갱신 연결 필요.
52. [#114](https://github.com/littlebit0/DailyCalendar/issues/114) **[버그] D-day 알림을 모두 끈 빈 설정이 Drive 복원 시 기본 알림으로 바뀌는 문제** — 명시적으로 끈 알림이 복원 시 되살아나므로 빈 설정 보존 필요.
53. [#137](https://github.com/littlebit0/DailyCalendar/issues/137) **[버그] 직접 입력한 D-day 알림이 설정 목록에 표시되지 않아 확인·해제할 수 없는 문제** — 직접 만든 알림을 해제할 수 없어 사용자 제어권 복원 필요.
54. [#120](https://github.com/littlebit0/DailyCalendar/issues/120) **[버그] Linux 알림 한 건의 JSON 형식 오류·전달 예외가 전체 배치를 중단하는 문제** — 한 Linux 알림 오류가 정상 알림까지 막으므로 실패 격리 필요.
55. [#112](https://github.com/littlebit0/DailyCalendar/issues/112) **[버그] 처리 중 들어온 위젯·Siri 변경 신호를 재처리하지 않아 후속 반영이 지연되는 문제** — 처리 중 새 위젯·Siri 요청이 밀리므로 대기 요청 재확인 필요.
56. [#127](https://github.com/littlebit0/DailyCalendar/issues/127) **[버그] Siri SQLite 조회가 실행 오류를 정상 종료로 취급해 빈 일정·부분 결과를 반환하는 문제** — 조회 오류가 일정 없음으로 표시되므로 오류와 빈 결과 분리.
57. [#124](https://github.com/littlebit0/DailyCalendar/issues/124) **[버그] Siri 생성형 응답 검증이 일정명·시각의 뒤바뀜과 요일·부정 표현 오류를 통과시키는 문제** — Siri 응답의 일정·시각·부정 오류가 통과하므로 안내 정확성 보강.
58. [#128](https://github.com/littlebit0/DailyCalendar/issues/128) **[버그] Signal이 영어 일정 조회와 reschedule 요청을 schedule 부분 문자열 때문에 추가로 오인하는 문제** — 조회·이동을 추가로 오인하므로 작업 의도 판별 수정.
59. [#144](https://github.com/littlebit0/DailyCalendar/issues/144) **[버그] 자연어 입력의 '2시간 전'·'20분 전' 알림을 일정 시각으로 중복 해석하는 문제** — 알림 표현이 일정 시각을 바꾸므로 자연어 입력 정확성 수정.
60. [#146](https://github.com/littlebit0/DailyCalendar/issues/146) **[버그] 잘못된 날짜·시각 입력을 다른 날짜나 종일 일정으로 조용히 바꾸는 문제** — 잘못된 날짜를 조용히 보정하므로 명시적 입력 검증 필요.
61. [#162](https://github.com/littlebit0/DailyCalendar/issues/162) **[버그] 일정 검색 조회 실패를 정상적인 검색 결과 없음으로 표시하는 문제** — 조회 실패가 자료 없음처럼 보여 오류 안내 분리 필요.
62. [#163](https://github.com/littlebit0/DailyCalendar/issues/163) **[버그] 빠른보기의 검색 버튼을 눌러도 검색 입력창이 표시되지 않는 문제** — 빠른보기 검색 버튼이 동작하지 않아 기능 복원 필요.
63. [#171](https://github.com/littlebit0/DailyCalendar/issues/171) **[버그] 하루를 넘는 반복 일정의 스케줄 블록 키가 겹쳐 회차 표시가 충돌하는 문제** — 반복 회차 키 중복으로 화면 충돌 가능성이 있어 식별 수정.
64. [#261](https://github.com/littlebit0/DailyCalendar/issues/261) **[버그] 월간 일정 드롭 저장 완료 콜백이 제거된 화면의 상태를 변경할 수 있는 문제** — 저장 뒤 폐기된 화면 접근 가능성이 있어 비동기 수명 보호.
65. [#103](https://github.com/littlebit0/DailyCalendar/issues/103) **[버그] Android·Apple·Windows 위젯이 날짜 변경 후 이전 스냅샷의 오늘 일정·D-day를 유지하는 문제** — 위젯에 어제 정보가 남을 수 있어 오늘 일정·D-day 정확성 복원.
66. [#169](https://github.com/littlebit0/DailyCalendar/issues/169) **[버그] 하루 일정 패널의 실시간 재조회가 분류 숨김·D-day·검색 필터를 적용하지 않는 문제** — 재조회가 숨김·검색 필터를 무시하므로 표시 조건 유지 필요.
67. [#179](https://github.com/littlebit0/DailyCalendar/issues/179) **[버그] 분류 순서 저장이 대기 중일 때 설정 화면을 닫으면 마지막 변경이 저장되지 않는 문제** — 화면을 닫으면 마지막 분류 순서가 유실될 수 있어 저장 수명 분리.
68. [#178](https://github.com/littlebit0/DailyCalendar/issues/178) **[버그] 월간 연속 일정 정렬이 날짜별 수동 순서를 섞어 비교 순환을 만드는 문제** — 정렬 비교가 순환할 수 있어 순서 안정성 보강.
69. [#176](https://github.com/littlebit0/DailyCalendar/issues/176) **[버그] 매일·매주 반복이 서머타임 변경 뒤 사용자가 지정한 현지 시각에서 벗어나는 문제** — 서머타임 지역에서 반복 시각이 이동하므로 해당 시간대 지원 보완.
70. [#177](https://github.com/littlebit0/DailyCalendar/issues/177) **[버그] 서머타임 변경일의 스케줄 시간선이 일정 시각을 잘못 표시하고 늦은 일정을 누락하는 문제** — 서머타임 변경일의 늦은 일정 누락 가능성으로 날짜 경계 수정.
71. [#174](https://github.com/littlebit0/DailyCalendar/issues/174) **[버그] 서머타임 시간대의 월간 달력과 위젯 스냅샷에서 날짜 칸이 중복되는 문제** — 서머타임 지역의 달력 날짜 중복 가능성으로 날짜 산술 수정.
72. [#123](https://github.com/littlebit0/DailyCalendar/issues/123) **[버그] Siri·배경화면의 별도 반복 계산이 종료일 당일과 마지막 연속 회차를 누락하는 문제** — Siri·배경화면의 마지막 반복 회차 누락으로 공통 규칙 정합성 필요.
73. [#129](https://github.com/littlebit0/DailyCalendar/issues/129) **[버그] 휴강·강의 방식 예외가 있는 수업의 요일을 변경하면 시간표 저장이 실패하는 문제** — 예외가 있는 수업의 요일 변경이 저장 실패하므로 편집 기능 복원.
74. [#133](https://github.com/littlebit0/DailyCalendar/issues/133) **[버그] 수업 기간이 겹치지 않는 주간 강좌도 시간 충돌로 판정되어 검색에서 제외되는 문제** — 기간이 겹치지 않는 수업을 숨기므로 잘못된 검색 제외 수정.
75. [#187](https://github.com/littlebit0/DailyCalendar/issues/187) **[버그] macOS Debug 네이티브 테스트 호스트가 실제 테스트 앱 제품명과 일치하지 않는 문제** — Mac 네이티브 테스트를 막을 수 있어 다음 Mac 테스트 전에 수정.
76. [#121](https://github.com/littlebit0/DailyCalendar/issues/121) **[성능] Drive 대량 일정 조회의 긴 OR 쿼리와 반복 파일 목록 탐색을 배치·인덱싱으로 개선** — 대량 Drive 쿼리 길이와 반복 탐색 문제로 큰 데이터 동기화 개선.
77. [#170](https://github.com/littlebit0/DailyCalendar/issues/170) **[성능] 날짜 범위별 일정 provider의 무제한 상태 보존을 제한해 장시간 탐색 메모리 관리 개선** — 날짜 탐색 상태가 누적될 수 있어 장시간 사용 메모리 관리 필요.
78. [#175](https://github.com/littlebit0/DailyCalendar/issues/175) **[성능] 검색 패널 재빌드마다 CurvedAnimation 상태 리스너가 누적되는 문제 개선** — 재빌드마다 리스너가 쌓이므로 반복 사용 비용을 먼저 줄이면 좋음.
79. [#210](https://github.com/littlebit0/DailyCalendar/issues/210) **[성능] Windows 경로 조회의 OS 반환 문자열 미해제로 네이티브 메모리가 누적되는 문제** — Windows 경로 조회의 OS 문자열 누수로 반복 호출 정리 필요.
80. [#242](https://github.com/littlebit0/DailyCalendar/issues/242) **[버그] Windows headless 로그인 화면을 표시 화면으로 넘길 때 원본 native WebView가 남는 문제** — 화면 전환 뒤 원본 Windows WebView가 남을 수 있어 소유권 수정.
81. [#235](https://github.com/littlebit0/DailyCalendar/issues/235) **[버그] macOS LMS headless 종료·전환 후 빈 wrapper 뷰가 남는 문제** — macOS 빈 wrapper가 누적되므로 반복 로그인 비용 개선.
82. [#228](https://github.com/littlebit0/DailyCalendar/issues/228) **[버그] Android 날씨 위치 요청 취소 후 위치 client가 manager 목록에 남는 문제** — 취소된 Android 위치 client가 남으므로 반복 요청 누적 방지.
83. [#244](https://github.com/littlebit0/DailyCalendar/issues/244) **[버그] Windows WebView 그래픽 초기화·캡처 생성 후 COM factory 참조를 해제하지 않는 문제** — COM 참조 해제 누락은 수정하되 실제 메모리 증가량은 미측정.
84. [#126](https://github.com/littlebit0/DailyCalendar/issues/126) **[성능] Linux 알림 전달 중 전체 저장소 잠금을 유지해 예약·취소·조회가 함께 대기하는 문제** — 알림 전달이 예약·취소까지 잠그므로 느린 전송과 잠금 분리.
85. [#150](https://github.com/littlebit0/DailyCalendar/issues/150) **[개선] 프레임 분석에서 화면 주사율에 맞는 끊김 비율과 발생 맥락을 확인** — 120Hz 끊김 판단을 위해 후속 실측 전에 계측 보완 권장.
86. [#95](https://github.com/littlebit0/DailyCalendar/issues/95) **[성능] LMS 항목마다 전체 일정 테이블을 읽는 병합 경로의 O(MN+M²) 비용 제거** — 조회 최적화 구현 완료, 규모별 시간·할당량 실측을 마무리할 단계.
87. [#99](https://github.com/littlebit0/DailyCalendar/issues/99) **[성능] Android 외부 캘린더 가져오기의 전체 일정·알림 조회를 메인 스레드에서 분리** — 백그라운드 조회 구현 완료, Provider·UI·직렬화 실측이 남음.
88. [#134](https://github.com/littlebit0/DailyCalendar/issues/134) **[성능] 강의 검색의 매 입력·화면 변경마다 전체 충돌·소속·검색 문자열을 재계산하는 비용 개선** — 검색 캐시 구현 완료, 1천·5천·1만 강좌 profile 검증이 남음.
89. [#191](https://github.com/littlebit0/DailyCalendar/issues/191) **[성능] 학교 강의 검색 최초 로딩의 대형 JSON 디코딩·모델 생성 비용 개선** — isolate 분리 완료, 최초 로딩 응답성과 메모리 실측이 남음.
90. [#157](https://github.com/littlebit0/DailyCalendar/issues/157) **[개선] LMS 부분 동기화에서 일정별 마지막 확인 시각과 이전 데이터 표시를 구분** — 옛 학습 상태를 최신처럼 보이지 않도록 항목별 확인 시각 개선.
91. [#259](https://github.com/littlebit0/DailyCalendar/issues/259) **[개선] LMS 로그인·자동로그인 실패 단계와 원인을 민감정보 없이 로그에 기록** — 로그인 재발 원인 추적용 진단 개선으로 기능 장애 수정 다음.
92. [#152](https://github.com/littlebit0/DailyCalendar/issues/152) **[개선] 동기화 분석에서 같은 시도의 시작과 종료 및 결과 누락을 구분** — 동기화 시작·종료 연결로 실패 통계 오판 방지 필요.
93. [#149](https://github.com/littlebit0/DailyCalendar/issues/149) **[개선] 앱 시작 분석에서 마이그레이션 완료와 캘린더 사용 준비 시간을 구분** — 초기화와 실제 사용 준비 시간을 구분하는 성능 계측 개선.
94. [#151](https://github.com/littlebit0/DailyCalendar/issues/151) **[개선] 분석 시간 상한에 걸린 작업을 정확한 120초 작업과 구분** — 120초 이상의 지연을 구분하기 위한 진단 정확성 개선.
95. [#135](https://github.com/littlebit0/DailyCalendar/issues/135) **[버그] 버그 제보 생성 응답이 유실되면 재시도에서 중복 이슈가 생기고 첫 제보 연락 정보가 삭제되는 문제** — 제보 재시도의 중복·연락 기록 손실을 막는 멱등성 필요.
96. [#154](https://github.com/littlebit0/DailyCalendar/issues/154) **[버그] 버그 제보의 입력 글자 제한과 요청 바이트 제한이 달라 정상 작성 내용도 거절되는 문제** — 정상 길이 한국어 제보도 거절될 수 있어 전송 제한 정합성 수정.
97. [#147](https://github.com/littlebit0/DailyCalendar/issues/147) **[버그] 버그 제보의 실제 빌드 번호 대신 앱 버전을 중복 기록하는 문제** — 잘못된 빌드 번호가 회귀 추적을 방해하므로 배포 진단과 함께 수정.
98. [#139](https://github.com/littlebit0/DailyCalendar/issues/139) **[버그] 분석 집계와 중복 기록을 별도로 저장해 부분 실패 후 재시도에서 이중 집계되는 문제** — 부분 실패로 분석 이중 집계가 가능해 집계 정확성 우선.
99. [#138](https://github.com/littlebit0/DailyCalendar/issues/138) **[버그] 사용성 분석 재전송이 UTC 날짜를 넘으면 같은 이벤트를 다시 집계하는 문제** — 자정을 넘는 재전송 중복으로 날짜 경계 검사 보완.
100. [#156](https://github.com/littlebit0/DailyCalendar/issues/156) **[버그] 분석 요청의 잘못된 필드 타입을 검증 오류로 반환하지 못하고 처리 중 예외를 발생시키는 문제** — 잘못된 분석 필드가 예외를 일으켜 서버 입력 검증 보강.
101. [#136](https://github.com/littlebit0/DailyCalendar/issues/136) **[성능] 사용성 분석 요청마다 당일 집계·중복 방지 JSON 전체를 재처리하는 비용 개선** — 누적 분석량에 따라 비용이 커지지만 실제 트래픽 확인 후 최적화 가능.
102. [#159](https://github.com/littlebit0/DailyCalendar/issues/159) **[개선] LMS 저장 계정 재로그인 버튼과 입력 비밀번호 표시·숨김 추가** — 재로그인·비밀번호 표시 편의는 인증 안정성 정리 뒤 진행 가능.
103. [#160](https://github.com/littlebit0/DailyCalendar/issues/160) **[개선] LMS 로그인 입력명을 ID로 변경하고 Apple 암호 자동완성으로 저장 계정 재사용 지원** — ID 표시·자동완성 편의는 저장·인증 오류 정리 뒤 진행 가능.
104. [#161](https://github.com/littlebit0/DailyCalendar/issues/161) **[버그] 빠른보기에서 일정이 적은 분류 박스 아래에 옆 분류 높이만큼 빈 공간이 생기는 문제** — 빠른보기 빈 공간은 가독성 문제로 기능·데이터 오류보다 후순위.
105. [#180](https://github.com/littlebit0/DailyCalendar/issues/180) **[버그] 일정 편집의 시간 선택 화면이 앱의 24시간 표시 설정을 적용하지 않는 문제** — 24시간 표시 불일치는 저장 장애보다 뒤에 수정 가능.
106. [#186](https://github.com/littlebit0/DailyCalendar/issues/186) **[버그] 월요일 시작의 Apple 위젯에서 주말 요일 색상이 잘못 적용되는 문제** — 주말 색상 표시 오류는 데이터 정확성 문제 뒤에 수정 가능.
107. [#189](https://github.com/littlebit0/DailyCalendar/issues/189) **[버그] 연간 월 선택 화면이 월요일 시작 설정을 무시하는 문제** — 연간 달력 주 시작 설정은 핵심 오류 이후 개선 가능.
108. [#190](https://github.com/littlebit0/DailyCalendar/issues/190) **[성능] 장소 추천과 관리 화면의 항목별 설정 JSON 반복 디코딩 비용 개선** — 장소 JSON 반복 decode는 데이터 손실 문제 뒤에 최적화 가능.
109. [#257](https://github.com/littlebit0/DailyCalendar/issues/257) **[버그] 날씨 자동 지역 선택이 이어도의 0좌표를 실제 위치로 처리하는 문제** — 0좌표의 제한적 오분류 조건으로 실제 입력 경계 확인 후 수정.
110. [#262](https://github.com/littlebit0/DailyCalendar/issues/262) **[개선] 날씨 캐시 저장 실패 후 요청 최신성 검사와 초기화 경합 검증 보강** — 날씨 경합은 검증 보강 단계이며 지속 장애 미확인으로 후순위.
111. [#222](https://github.com/littlebit0/DailyCalendar/issues/222) **[버그] Windows 알림의 32비트 UNIX 초 전달로 2038년 이후 예약 날짜를 보존하지 못함** — 2038년 이후 예약 오류로 장기 일정 지원 검증 때 처리.
112. [#197](https://github.com/littlebit0/DailyCalendar/issues/197) **[버그] DailyStudy 수집 후 사라진 강의 필터가 남아 새 학습 항목을 숨김** — 별도 DailyStudy의 새 자료 숨김으로 해당 도구 수정 시 우선.
113. [#198](https://github.com/littlebit0/DailyCalendar/issues/198) **[버그] DailyStudy에서 24시간 이내의 내일 마감을 오늘 마감으로 표시** — 별도 DailyStudy 마감 표시 문제로 본 앱 기능 복구 다음.
114. [#199](https://github.com/littlebit0/DailyCalendar/issues/199) **[버그] DailyStudy 본문 이동 링크가 현재 목록 탭을 홈으로 변경** — 별도 DailyStudy 접근성 이동 문제로 본 앱 핵심 오류 다음.
115. [#153](https://github.com/littlebit0/DailyCalendar/issues/153) **[개선] 기능 사용 분석에서 미계측 기능과 필터 취소를 실제 사용 성공과 구분** — 기능 사용 성공 계측은 사용자 기능 장애 수정 뒤 진행 가능.
116. [#91](https://github.com/littlebit0/DailyCalendar/issues/91) **[진단/자동화] 오류 및 버그 발생 시 GitHub 이슈 자동 등록 기능** — 자동 제보는 중복·개인정보 정책 설계가 필요해 기존 제보 안정화 다음.
117. [#193](https://github.com/littlebit0/DailyCalendar/issues/193) **[개선] 현재 사용처가 없는 온보딩 스크린샷 6개의 배포 리소스 포함 정리** — 미사용 이미지 정리는 실제 압축 절감량 확인 후 진행 가능.
118. [#204](https://github.com/littlebit0/DailyCalendar/issues/204) **[버그] 인수인계 문서의 archive 이동 후 docs 상대 링크 3곳이 끊어짐** — 과거 문서 링크 복구는 제품 장애보다 후순위.
119. [#76](https://github.com/littlebit0/DailyCalendar/issues/76) **일정 공유 기능 및 공유 범위 설정** — 신규 공유 기능은 기존 데이터·인증·일정 정확성 안정화 다음.
120. [#108](https://github.com/littlebit0/DailyCalendar/issues/108) **[개선] LMS 개인정보 저장·Drive 동기화·삭제 범위를 정확히 안내하기** — 개인정보 안내는 중요하며 관련 정책 작업 재개 시 우선 정리.
121. [#105](https://github.com/littlebit0/DailyCalendar/issues/105) **[개선] 현재 지원 대학의 학사일정·시간표 및 기존 LMS 이용 근거 확정** — 자료 이용 근거는 출시 판단에 중요하지만 대학 조사 중단 유지.
122. [#106](https://github.com/littlebit0/DailyCalendar/issues/106) **[개선] 지원 시간표 대학의 배포 자산·출처 및 비활성 자료 포함 경계 정리** — 비활성 배포 자료 경계는 다음 관련 배포 전 확인하되 재개 승인 필요.
123. [#107](https://github.com/littlebit0/DailyCalendar/issues/107) **[개선] 상명대 LMS 조회를 학교가 허용한 범위와 인증 절차에 맞추기** — 학교 허용 LMS 조회 범위 확인이 필요하며 허용 여부를 추측하지 않음.
124. [#173](https://github.com/littlebit0/DailyCalendar/issues/173) **[버그] 학사일정 갱신이 동시에 저장된 사용자 편집·삭제를 덮어쓰는 문제** — 학사 갱신의 개인 편집·삭제 덮어쓰기 위험으로 대학 작업 재개 시 최우선.
125. [#188](https://github.com/littlebit0/DailyCalendar/issues/188) **[버그] 중앙대 학사일정 응답 순서 변경으로 일정 ID와 사용자 완료·메모·제외 선택이 뒤바뀌는 문제** — 학사 ID 변동이 메모·완료를 옮길 수 있어 대학 작업 재개 시 우선.
126. [#256](https://github.com/littlebit0/DailyCalendar/issues/256) **[버그] 이화여대 학사 응답 연도 불일치가 요청 연도로 재해석되어 저장 후보에 포함됨** — 다른 연도 응답을 잘못 저장할 수 있어 학사 작업 재개 시 우선.
127. [#252](https://github.com/littlebit0/DailyCalendar/issues/252) **[버그] 우송대·한세대 1월 학사일정의 이전 연말 시작일이 한 해 뒤로 이동하는 문제** — 일정이 한 해 뒤로 이동하는 오류로 학사 작업 재개 시 우선.
128. [#215](https://github.com/littlebit0/DailyCalendar/issues/215) **[버그] 단국대 연계전공 표의 주관학과를 연계전공으로 재분류하는 문제** — 단국대 일반 학과의 잘못된 연계전공 분류로 재개 시 우선.
129. [#234](https://github.com/littlebit0/DailyCalendar/issues/234) **[버그] 대구대·KAIST 동일 대상의 학사일정 반복 행을 중복 가져오는 문제** — 학사일정 중복 가져오기 문제로 재개 시 식별 수정.
130. [#181](https://github.com/littlebit0/DailyCalendar/issues/181) **[버그] 영남대 학사일정이 윤년의 2월 29일을 잘못된 기간으로 거부하는 문제** — 윤일 학사 기간 거절로 해당 대학 작업 재개 후 수정.
131. [#182](https://github.com/littlebit0/DailyCalendar/issues/182) **[버그] 상지대 학사일정이 이전 연도의 정상 비중첩 응답 때문에 현재 연도 갱신을 중단하는 문제** — 과거 응답이 현재 학사 갱신을 막을 수 있어 재개 후 범위 수정.
132. [#243](https://github.com/littlebit0/DailyCalendar/issues/243) **[버그] 한국교원대 학부 개강·대학원 입학 혼합 일정이 대학원 필터로 누락** — 학부 개강이 혼합 제목 필터로 누락될 수 있어 재개 후 수정.
133. [#239](https://github.com/littlebit0/DailyCalendar/issues/239) **[버그] 연세대 학사일정의 잘못된 명시 종료월을 다른 연도 날짜로 보정하는 문제** — 잘못된 종료월 보정의 입력 검증 문제로 재개 후 방어.
134. [#92](https://github.com/littlebit0/DailyCalendar/issues/92) **[범위 정리] 지원 대학 학사일정 유지 및 시간표 단과대 선택 구조 개선** — 기존 지원 범위·단과대 구조 잔여 작업으로 재개 승인 전 보류.
135. [#232](https://github.com/littlebit0/DailyCalendar/issues/232) **[개선] 서울대 학사일정의 월 구역 완전성·정상 빈 월 계약 검증** — 정상 빈 월 계약이 미확인이라 재개 후 근거부터 확인.
136. [#237](https://github.com/littlebit0/DailyCalendar/issues/237) **[개선] 협성대·성결대 학사일정의 월 구역 완전성·정상 빈 월 계약 검증** — 월 구역 부재가 오류인지 미확정이므로 재개 후 공식 표현 확인.
137. [#254](https://github.com/littlebit0/DailyCalendar/issues/254) **[개선] 인제대 학사일정의 월 구역 완전성·정상 빈 월 계약 검증** — 빈 월 표현 계약 검증으로 확정 장애보다 뒤에 조사 가능.
138. [#245](https://github.com/littlebit0/DailyCalendar/issues/245) **[버그] 광주교육대 2학기 학사일정 출처 링크가 1학기 페이지로 저장됨** — 출처 링크가 다른 학기를 가리켜 날짜 저장 오류 다음에 수정.
139. [#247](https://github.com/littlebit0/DailyCalendar/issues/247) **[개선] 서울시립대·진주교대·대구교대·경기대·한세대 학사 출처 URL에 응답 조회 연도 보존** — 출처 링크 연도 보존은 자료 손상 문제보다 후순위.
140. [#206](https://github.com/littlebit0/DailyCalendar/issues/206) **[버그] 광주대 로고에 별도 학교명이 포함되어 심벌 표시 기준과 불일치** — 로고 기준 불일치는 대학 UI 작업 재개 후 수정.
141. [#219](https://github.com/littlebit0/DailyCalendar/issues/219) **[버그] 홍익 강의계획서 캡처가 CDP 응답 ID를 재사용해 다른 요청의 본문을 덮어씀** — 중단된 연구 캡처 도구는 재사용 전 수정하되 현재 제품보다 후순위.
142. [#86](https://github.com/littlebit0/DailyCalendar/issues/86) **충남대·단국대·전남대 LMS 일정 가져오기 지원 확대** — 신규 대학 LMS 확대는 계획 미정·보류로 별도 승인 후 진행.
