# Daily Google Play 제출 준비

## 2026-09-21 비공개 테스트용 3.5.0

- 업로드 차단: 사용자가 Play Console에 제출했으나 업로드 키 불일치로 거절됨.
  Console 요구 SHA-1은 `04:97:A8:86:73:A5:53:43:D3:13:47:BB:C3:B2:EC:26:65:73:BC:0E`,
  현재 AAB는 `3A:B4:4A:04:82:7C:B2:18:65:4F:34:C6:77:79:29:1B:25:6D:29:50`이다.
  사용자가 기존 키가 없음을 확인했다. 현재 키의 공개 인증서를
  `dist/google-play/closed-testing/3.5.0/Daily-upload-certificate.pem`에 추출했고
  AAB와 지문 일치를 검증했다. 개인 키는 포함하지 않는다.
  공개 인증서는 준비됐으나 재설정 요청은 제출하지 않았다.
- **후속 확인 반영(2026-09-24 기록 감사):** 9월 21일 나중에 확인한 Console
  화면에는 첫 App Bundle 업로드 후 인증서 지문이 표시된다고 나왔고, 업로드 키
  재설정 버튼은 없었다. 기존 업로드 키가 등록돼 있다고 단정했던 안내는 철회됐다.
  앞선 오류와 이 화면의 상태가 맞지 않으므로, 다음 제출 작업에서 같은 앱의
  오류·요구 지문·인증서 화면을 확인한 뒤 해결 방법을 결정한다. 키 재설정을
  확정된 선행 조건으로 안내하거나 앱 서명 키를 임의로 바꾸지 않는다.
  다운로드한 `certificates.zip`은 공개 인증서 3개이며 서명용 개인 키가 아니다.
  재업로드 성공·재설정 신청·versionCode 재사용 가능 여부는 확인되지 않았다.
- 출시 문구의 학사일정 지원 대학은 **상명대학교만**이다. 9월 21일 대화에서
  단국대학교·전남대학교까지 지원한다고 적은 문구는 구현과 달라 사용하지 않는다.
- 패키지: `com.littlebit0.dailycalendar`, 버전 `3.5.0`, versionCode `350`.
- 파일: `dist/google-play/closed-testing/3.5.0/Daily-3.5.0-code-350.aab`
  (71,721,846 bytes).
- SHA-256: `82667dace4cdf99c484cb709d43cf5c9b81bd978e836ddbd4ef2949912cb3dc4`.
- 기존 Android 배포 키로 Release AAB를 생성했다. 별도 패키지나 디버그 키를
  사용하지 않으며 비공개 배포 여부는 Play Console의 테스트 트랙에서 정한다.
- `bundletool validate`, 최종 번들 manifest(최소 SDK 24, 대상 SDK 36,
  debuggable=false), JAR 서명 검증 통과. 전체 payload 524개 항목의 인증서
  SHA-256이 기존 배포 키와 일치한다. 서명 인증서는 2054-01-23까지 유효하다.
- arm64-v8a/armeabi-v7a/x86_64 포함. 64비트 네이티브 라이브러리 10개의
  ELF 16KB 정렬과 BundleConfig의 PAGE_ALIGNMENT_16K를 확인했다.
- Flutter analyze 통과, 전체 테스트 548개 통과(기존 skip 1개). 앱 설치·실행,
  실기기 로그인, Play Console 업로드·비공개 테스트 트랙 생성은 하지 않았다.
- Play Console의 기존 versionCode 사용 여부는 미확인이다.
  기존 코드가 350 이상이면 새 코드로 재빌드한다.
- Google Play 앱 서명 인증서가 로컬 업로드 인증서와 다르면 Play 앱 서명
  SHA-1로 Android OAuth 클라이언트를 추가해야 한다. 업로드 키의 OAuth
  등록만으로 Play 설치본의 Google 로그인이 검증된 것은 아니다.
- 아래 3.0.1 내용은 과거 참고 자료이며 현재 데이터 보안 답변이나 테스트
  지시로 그대로 사용하지 않는다. 특히 기존 앱은 데이터 보호 없이 삭제하지 않는다.

## 과거 3.0.1 제출 초안

현재 공유 소스 기준은 `3.0.1`이다. Android 실기기 및 최종 AAB 검증은 아직
완료되지 않았으므로, 아래 항목은 제출 전 점검 문서로 사용한다.

## 앱 정보

- 앱 이름: `Daily`
- 패키지명: `com.littlebit0.dailycalendar`
- 카테고리: 생산성
- 버전: `3.0.1`
- versionCode: `301`
- 제출 형식: Android App Bundle

## 스토어 문구 초안

### 짧은 설명

일정, 알림, D-day와 선택적 Google Drive 동기화를 지원하는 개인 캘린더

### 자세한 설명

Daily는 개인 일정을 빠르게 기록하고 여러 기기에서 이어서 사용할 수
있는 캘린더 앱입니다.

- 주간, 월간, 일간 달력 보기
- 일정 알림과 아침 브리핑
- 반복 일정과 D-day
- 음력과 대한민국 공휴일 표시
- PIN, 생체 인증, 시스템 인증을 지원하는 앱 잠금
- 로그인 없이 사용하는 로컬 모드
- 선택적 Google Drive AppData 백업 및 기기 간 동기화

Google Drive 연결은 선택 사항입니다. 연결하면 사용자의 Google Drive
AppData 영역에 Daily 전용 데이터만 저장합니다. 일반 Google Drive 파일은
읽거나 변경하지 않습니다.

## Play Console 필수 입력

- 개인정보처리방침 URL
- 지원 이메일
- 앱 또는 지원 웹사이트 URL
- 데이터 삭제 안내 URL
- 앱 액세스: 로그인 없이 로컬 모드로 심사 가능
- 광고 포함 여부: 광고 없음
- 콘텐츠 등급 설문
- 대상 연령과 아동 대상 여부
- 데이터 보안 양식

## 데이터 보안 작성 기준

- 수집/처리 데이터: 일정, 설정, 선택한 Google Drive 연결 인증 정보
- 사용 목적: 앱 기능, 백업, 기기 간 동기화
- Google Drive 범위: `drive.appdata`
- 일반 Drive 파일 접근: 없음
- 앱 잠금 PIN: 기기 보안 저장소에만 저장, 동기화하지 않음
- Gemini API 키: 보안 저장소에만 저장, 현재 AI 기능은 비활성 상태
- 데이터 삭제: 앱 설정의 로컬 데이터 초기화 또는 Drive 백업 삭제에서
  로컬 데이터와 Drive AppData 백업 삭제

## 출시 전 실제 기기 확인

1. 앱을 완전히 삭제하고 Play 서명 빌드를 설치한다.
2. 로컬 모드가 정상적으로 시작되는지 확인한다.
3. Google Drive 연결과 Drive 권한 승인을 완료한다.
4. 기존 v2 일정과 설정이 복원되는지 확인한다.
5. 일정 생성, 수정, 삭제가 다른 기기에 반영되는지 확인한다.
6. 알림 권한과 예약 알림을 확인한다.
7. Google Drive 연결 해제와 Drive 백업 삭제 흐름을 확인한다.
8. 재설치 후 Google Drive 백업 복원을 확인한다.

## 제출 파일 검증

- AAB 파일명: `daily-android-3.0.1.aab`
- applicationId: `com.littlebit0.dailycalendar`
- versionName: `3.0.1`
- versionCode: `301`
- upload keystore 서명 확인
- SHA-256 체크섬 기록
