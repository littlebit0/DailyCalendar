# Daily 3.0.1 Release Checklist

## 공통

- [ ] `pubspec.yaml` 버전이 `3.0.1`인지 확인
- [ ] 정적 분석 통과
- [ ] 전체 Flutter 테스트 통과
- [ ] DB migration 및 기존 일정 보존 확인
- [ ] 로컬 모드, Google 로그인, 로그아웃과 계정 삭제 확인
- [ ] 일정 생성·수정·삭제 후 v2 항목별 백업 확인
- [ ] 백업이 로컬 데이터를 변경하지 않고 복원만 원격 데이터를 병합하는지 확인
- [ ] 분류 색상과 숨김 상태가 동기화 후 일치하는지 확인

## iOS/iPadOS

- [ ] 앱/위젯 버전과 빌드 `3.0.1 (3.0.1)`
- [ ] 번들 ID `com.littlebit0.daily`, `com.littlebit0.daily.widgets`
- [ ] App Store 배포 서명 및 provisioning 확인
- [ ] Apple 로그인 후 Google 로그인 강제 표시 없음
- [ ] Apple Calendar 및 Google Calendar 가져오기 확인
- [ ] 홈 화면·잠금 화면 위젯 확인
- [ ] 지원 기기에서 AlarmKit 일정 알람 확인
- [ ] 좌우·상하 월 탐색과 검색 전환 확인
- [ ] App Store Connect 빌드 선택, 수출 규정 응답, 심사 추가

## macOS

- [ ] 앱/위젯 버전과 빌드 `3.0.1 (3.0.1)`
- [ ] 번들 ID `com.littlebit0.daily`, `com.littlebit0.daily.widgets`
- [ ] PKG의 Distribution 서명과 resource bundle 상태 확인
- [ ] Google 세션 조용한 복원과 명시적 재연결 확인
- [ ] Touch ID·Apple Watch·시스템 암호 및 PIN fallback 확인
- [ ] 데스크톱·알림 센터 위젯 확인
- [ ] 마우스 휠 및 트랙패드 월·연간 탐색 확인
- [ ] App Store Connect 빌드 선택, Sandbox 정보, 수출 규정 응답, 심사 추가

## Android/Windows

- [ ] CI build 성공
- [ ] 실제 OS에서 3.0.1 공유 DB migration 확인
- [ ] Google OAuth와 Drive v2 동기화 확인
- [ ] Apple 전용 위젯·AlarmKit UI가 노출되지 않는지 확인
- [ ] Android 캘린더 가져오기와 알림 확인
- [ ] Windows 트레이와 창 수명주기 확인

## GitHub Release

- [ ] 3.0.1 변경 사항 커밋 및 main push
- [ ] `v3.0.1` 태그 생성 및 push
- [ ] 태그 커밋의 Platform Builds 성공 확인. 성공이 아니면 Release Installers·Release Apple Installers가 첫 단계에서 멈춥니다. 실행 기록이 없는 태그는 Actions > Platform Builds > Run workflow에서 태그를 골라 먼저 실행합니다.
- [ ] Release Installers workflow 4개 플랫폼 성공
- [ ] 릴리스 본문이 `docs/RELEASE_NOTES_3.0.1.md`인지 확인
- [ ] IPA, DMG, APK, ZIP 파일명과 체크섬 확인
