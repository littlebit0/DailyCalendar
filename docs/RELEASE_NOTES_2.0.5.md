# Daily 2.0.5 릴리스 노트

## 적용 범위

이번 버전은 Android Play Store 배포 준비를 먼저 다룹니다.
표시 버전은 `2.0.5`, Android versionCode는 `9`입니다.

## 변경 사항

- Google Drive 연결, 권한 승인, 동기화 실패 메시지를 사용자가 이해하기 쉽게 고쳤습니다.
- OAuth 토큰 만료, 권한 부족, 요청 과다, 서버 장애를 각각 다르게 안내합니다.
- Google Drive HTTP 오류 응답 본문과 내부 오류 코드를 화면에 그대로 보여 주지 않습니다.
- Windows Desktop OAuth의 토큰·계정 정보 오류 안내를 Google Drive 연결
  흐름에 맞췄습니다.
- iOS/macOS Google 인증과 UX 후속 수정 사항도 들어 있습니다.

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

## Play Console 제출 전 확인할 것

- Play App Signing 인증서 SHA-1/SHA-256을 Google OAuth Android client에 등록합니다.
- 개인정보처리방침 공개 URL을 준비합니다.
- 지원 이메일과 데이터 삭제 안내 URL을 준비합니다.
- 앱 액세스, 데이터 보안, 콘텐츠 등급, 광고 여부 설문을 작성합니다.
- 실제 Android 기기에서 Google Drive 연결, 동기화, 알림, 재설치 복원을 확인합니다.
