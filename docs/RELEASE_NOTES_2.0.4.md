# Daily 2.0.4 릴리스 노트

## 적용 범위

이번 업데이트는 Android와 Windows 빌드만 대상으로 합니다. macOS와 iOS
아티팩트는 이번 Windows/Android 작업에서 다시 빌드하지 않았습니다.

## 변경 사항

- 월간 달력의 좌우 스와이프 전환이 중간 지점에서 오래 멈춰 보이는 문제를 개선했습니다.
  - 월간 `PageView`의 페이지 정착 스프링을 조정했습니다.
  - 인접 월 페이지를 미리 준비해 스와이프 후 화면이 자연스럽게 이어지도록 했습니다.
- 월간 보기에서 데이터 범위가 다시 로드될 때 상세 패널에 큰 로딩 스피너가 떠 보이는 문제를 줄였습니다.
  - 선택 날짜 상세 패널은 유지하고, 데이터가 준비되면 실제 일정 목록으로 갱신합니다.
  - 사용자가 제외한 “일정이 없을 때 우측 상세 패널이 넓게 비는 구조”는 이번 작업에서 변경하지 않았습니다.
- Android 설정 화면에서 알림 테스트 문장이 버튼 때문에 어색하게 줄바꿈되는 문제를 수정했습니다.
- Google Drive 로컬 모드 설명 문구를 줄여 Android/Windows 좁은 폭에서 단어가 부자연스럽게 쪼개지는 현상을 줄였습니다.
- 잠금 분류는 삭제 버튼처럼 보이지 않도록 비활성 잠금 아이콘으로 표시합니다.
- Google 로그인 안정성을 보강했습니다.
  - 로그인 직후 Drive 권한 헤더까지 확인해 계정 로그인만 완료되고 실제 Drive 권한은 불완전한 상태로 남는 경우를 줄였습니다.
  - 권한 요청 중 로컬 세션이 비어 있으면 명시적 로그인 흐름으로 복구를 시도합니다.
  - 사용자 승인 대기 시간과 짧은 네트워크/토큰 요청 제한은 계속 분리합니다.
- Windows 릴리스 ZIP 패키징을 정리했습니다.
  - 실행에 필요한 런타임 파일만 별도 staging 폴더에 복사한 뒤 압축합니다.
  - `.pdb`, `.lib`, `.exp` 같은 디버그/중간 산출물이 릴리스 ZIP에 포함되지 않도록 했습니다.
- macOS/iOS 작업자는 Android/Windows에만 고질적으로 발생한 현상을 제외하고 동일한 공유 Flutter 변경을 검토해 반영해야 합니다.
  - macOS/iOS도 실제 UX/UI 시연 테스트를 진행해 버그, 취약점, 최적화 필요, 지연, 개선 필요 항목을 파악하고 수정 작업을 이어가야 합니다.

## 검증

- `.\tool\flutter.ps1 analyze --no-pub`
- `.\tool\flutter.ps1 test --no-pub`
- Android release APK 빌드: `--build-name=2.0.4 --build-number=8`
- Android x86_64 debug APK 설치/실행 스모크 테스트
- Android 월간 스와이프 및 설정 화면 시각 확인
- Windows release 빌드: `--build-name=2.0.4`
- Windows 파일/제품 버전이 `2.0.4`인지 확인
- Windows ZIP에 `.pdb/.lib/.exp` 항목이 없는지 확인

## 배포 파일

- `daily-android-2.0.4.apk`
- `daily-windows-2.0.4.zip`
- Android 패키지: `com.littlebit0.dailycalendar`
- Android versionName: `2.0.4`
- Android versionCode: `8`
- Windows product/MSIX 버전: `2.0.4.0`

SHA-256:

- `daily-android-2.0.4.apk`:
  `18080e2fedebbc48a2e685e8d7a529930125b26e795c1af31fc8732b72385681`
- `daily-windows-2.0.4.zip`:
  `5f465ed937a2afd9079ff7c62b78a68890bc11686073261031fcf4d042faec87`
