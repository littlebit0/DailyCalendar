# Daily 2.0.5 릴리스 노트

## 적용 범위

이번 버전은 Android Play Store 배포 준비를 우선 대상으로 한다.
표시 버전은 `2.0.5`, Android versionCode는 `9`를 사용한다.

## 변경 사항

- Google Drive 연결, 권한 승인, 동기화 실패 메시지를 사용자 관점으로 정리했다.
- OAuth 토큰 만료, 권한 부족, 요청 과다, 서버 장애를 구분해 안내한다.
- Google Drive HTTP 오류 응답 본문과 내부 오류 코드가 화면에 그대로 노출되지 않도록 했다.
- Windows Desktop OAuth의 토큰 및 계정 정보 오류 안내를 Google Drive 연결
  흐름에 맞게 정리했다.
- iOS/macOS Google 인증과 UX 후속 수정 사항을 포함한다.

## 검증 항목

- `./tool/flutter.ps1 analyze --no-pub`
- `./tool/flutter.ps1 test --no-pub`
- Android release App Bundle 빌드
- AAB package/versionCode/versionName 확인
- upload keystore 서명 확인
- SHA-256 체크섬 생성

## Android 배포 정보

- applicationId: `com.littlebit0.dailycalendar`
- versionName: `2.0.5`
- versionCode: `9`
- 제출 파일: `daily-android-2.0.5.aab`

## Play Console 제출 전 확인

- Play App Signing 인증서 SHA-1/SHA-256을 Google OAuth Android client에 등록
- 개인정보처리방침 공개 URL 준비
- 지원 이메일과 데이터 삭제 안내 URL 준비
- 앱 액세스, 데이터 보안, 콘텐츠 등급, 광고 여부 설문 작성
- 실제 Android 기기에서 Google Drive 연결, 동기화, 알림, 재설치 복원 확인
