# Android / iOS 적용 대조

확인일: 2026-09-06. 기준은 현재 작업 폴더의 구현이며, 미커밋 수정도 포함한다.
Android 버전은 3.3.1 / versionCode 331을 유지한다.

## 이번에 Android에 적용한 차이

| 항목 | 적용 내용 |
| --- | --- |
| 하단 조작부 | 빠른보기 / 주 / 월 / 일 / LLM 5개 통합. 이동하는 선택 배경, 드래그 선택, 선택 시 확대 및 다른 동작 시 가로·세로 축소 |
| 날짜 헤더 | 휴대폰에서 iOS처럼 왼쪽에 제한된 너비로 배치. 가로 모드의 연월을 표시하며 중복 월 제목과 이전/다음 버튼 제거. 작은 너비에서는 텍스트를 축소하여 메뉴 공간 확보 |
| 빠른보기 | 휴대폰도 분류 2열. Android 대형 태블릿의 반응형 3열 및 사이드바 유지 |
| 설정 | 첫 화면 외의 선택 컨트롤도 좁은 화면에서 제목 아래에 배치. 설명은 공백 단위 줄바꿈, 기존 설정 값·선택지 유지 |
| LLM 입력 | Android가 구현되지 않은 Apple Signal 채널을 호출하던 경로를 기존 ChatInputBar로 연결. 가로 달력에서는 하단 입력창이 달력을 밀어 올림. 확인 후 일정 등록, 실패 후 재입력 가능 |
| Gemini 모델 | Android 파서만 종료된 2.0 Flash 대신 3.6 Flash 사용. 사용자가 Gemini 사용을 켜고 키를 설정한 경우에만 기존 규칙에 따라 호출 |
| 캘린더 위젯 | 높이가 320dp 미만이면 이번 주, 이상이면 월간. 같은 발생 일정 ID의 연속 날짜를 한 주 안에서 긴 막대로 표시하고, 겹치면 다른 줄에 배치 |
| 위젯 완료·테마 | 완료 제목도 분류색 유지. 시스템 테마 변경 시 모든 위젯 갱신, 다크 배경 검정. 아직 앱에서 처리하지 않은 체크 요청은 오래된 스냅샷보다 우선 적용 |
| 일정 알람 | Android AlarmManager에 별도 연결. 시각 일정은 시작 시각, 종일 일정은 선택 시각. 제목·메모 표시, 소리·진동, 중지 및 10분 다시 알림, 수정·삭제·재부팅 시 예약 관리 |
| 알람 권한 | 알림, 정확한 알람, 지원 OS의 전체 화면 알람 접근을 사용자에게 순서대로 요청. 거절 시 기능을 활성화하지 않으며 일반 알림으로 위장하지 않음 |
| 잠금화면 위젯 | 오늘 일정 제공자의 keyguard 지원 범주를 선언. 실제 배치 가능 여부와 모양은 Android 버전 및 제조사 위젯 호스트에 따름 |
| 릴리스 네트워크 | 인터넷 권한을 debug manifest가 아닌 main manifest에도 명시 |

## 이미 공통 코드로 적용되어 있던 기능

- 주·월·일 및 연 화면, 목록/스케줄 보기, 월간 좌우/상하 이동, 공휴일·음력·날짜 헤더.
- 30분 단위 스케줄 이동, 지속시간 유지, 날짜별 수동 순서, 완료 일정 이동.
- 일정 드래그 피드백의 대상 크기 전환, 빈 자리 애니메이션, 저장 중 낙관적 표시.
- 하루 상세 하단 시트에서 달력으로 이동할 때 시트 최소화 및 바깥 탭 닫기.
- Todo 완료, 분류색 유지, 취소선, 분류 표시/색상/순서, RGB 선택.
- 빠른보기/주/월/일을 통합한 첫 화면 선택, 전체 UI 글자 크기.
- 한국어·영어·일본어·중국어 번체, 시스템 언어 및 사용자 언어 선택.
- PIN 자릿수 자동 검증, PIN 없는 보호 화면, 시스템 인증 및 생체 인증.
- Google 계정, Drive v2 이벤트별 동기화, 백업/복원 분리, 로컬 로그아웃/삭제.
- 기본 일정 알림, 아침 브리핑, D-day, 동의 기반 분석 및 버그 제보.

이 목록은 공통 구현의 존재를 확인한 것으로, 모든 제조사 실기기 검증을 뜻하지 않는다.

## 플랫폼에 맞게 유지하는 차이

- Siri, Apple Intelligence, Apple App Intents 및 시그널 단축어는 Android에 복제하지 않는다. Android의 LLM 일정 입력을 유지하며 Siri 기능과 동일하다고 표시하지 않는다.
- Apple 로그인, Apple Maps, Apple 캘린더는 Android에 노출하지 않는다. Android에서는 Google 로그인, 카카오/네이버 지도, Samsung/Google 캘린더 가져오기를 유지한다.
- AlarmKit 자체가 아닌 Android AlarmManager를 사용한다. 반복 알람은 iOS 정책과 같이 추가하지 않았다. 강제 종료·제조사 전원 정책·사용자 권한 취소 상황에서 울림을 보장하지 않는다.
- Apple Watch 잠금해제, iOS 잠금화면 위젯 크기/배치, Apple 시스템 알람 화면의 모양은 Android에 그대로 옮길 수 없다.
- 태블릿에서 이미 적용한 넓은 화면 레이아웃을 휴대폰 크기로 강제 축소하지 않는다.

## 검증 및 배포 전 확인

- Flutter 전체 자동 테스트: 334개 통과, 기존 건너뜀 1개.
- Android 네이티브 Robolectric: 9개 통과. 예약 교체/취소/권한 거절/오래된 호출 차단/재부팅 복원, 위젯 연속 막대/완료 큐/분류색 검증.
- `./tool/flutter.sh analyze --no-pub`: 통과.
- Android arm64 debug APK 빌드 및 서명 검증 통과. 기존 `Daily_Pixel_9_API_36` (`emulator-5554`)에 `adb install -r -t`로 업데이트 설치 완료. 설치 전후 `daily.sqlite`, Flutter 설정 및 보안 저장소 3개 파일의 SHA-256이 동일하다. 앱은 실행하지 않았다.
- 실제 앱 실행, Google 로그인 승인, 실제 알람 소리·진동·잠금화면 표시, 위젯 호스트의 다크 전환, Gemini API 호출은 사용자 실사용 확인 항목이다. 자동 테스트를 실기기 성공으로 간주하지 않는다.
- Google Play 배포 전 정확한 알람, 전체 화면 인텐트 및 foreground mediaPlayback 서비스의 사용 목적·권한 정책을 검토해야 한다. 이번 작업에서는 스토어 제출하지 않는다.
- iOS/macOS 네이티브 파일은 수정하지 않는다. 공통 Dart 경로의 Apple 테스트는 포함되지만 Apple 앱을 새로 빌드·설치하지 않는다.

## 공식 근거

- [Android 정확한 알람](https://developer.android.com/develop/background-work/services/alarms)
- [Android 포그라운드 서비스 선언](https://developer.android.com/develop/background-work/services/fgs/declare)
- [위젯 범주와 호스트 지원](https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo)
- [Gemini 모델 종료 및 공식 대체 모델](https://ai.google.dev/gemini-api/docs/deprecations)
