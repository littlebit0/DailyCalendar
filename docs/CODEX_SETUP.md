# DailyCalendar Codex 설정

## 저장소에 적용된 설정

`.agents/skills/` 아래의 다섯 스킬은 프로젝트 전용 지침이며 외부 서비스나
플러그인을 설치하지 않는다. 현재 규칙은 [AGENTS.md](../AGENTS.md),
작업 상태와 상세 인계 진입점은 [AGENT_MEMORY.md](../AGENT_MEMORY.md)를 따른다.
같은 목적의 중단·재개 기록은 최신 인계로 통합하고 과거 원문은 보관한다.

| 스킬 | 용도 |
| --- | --- |
| `dailycalendar-project` | Flutter/Riverpod/Drift 구조, 현재 인계 확인, 래퍼 명령 |
| `daily-lms-sync` | Coursemos 파싱, 완전한 스냅샷, 안정적인 ID, 계정별 캐시 |
| `daily-auth-regression` | Google/Apple/LMS 인증, 취소, 계정 전환, 복구 경계 |
| `daily-calendar-integrity` | 날짜·반복·마이그레이션·Drive 병합·삭제 무결성 |
| `daily-cross-platform-check` | 플랫폼별 검사와 빌드/설치/실제 동작 증거 구분 |

DailyCalendar 저장소에서 Codex를 시작하면 저장소 루트와 하위 경로의
`.agents/skills`가 검색 대상이다. `$daily-lms-sync`처럼 명시적으로 사용할
수도 있다. 정상 자동 선택을 유지하며 별도 전역 설정이나 MCP 의존성을 추가하지
않았다. 실제 스킬 목록 반영이 보이지 않으면 Codex를 재시작하고 해당 저장소에서
확인한다. 이 채팅은 다른 작업 폴더에서 시작했으므로 이 채팅의 스킬 목록 갱신을
프로젝트에서의 발견 성공으로 보고하지 않는다.

근거: [공식 스킬 문서](https://learn.chatgpt.com/docs/build-skills).

## 조사 기준과 현재 구조

2026-10-05에 로컬 Git remote가 `littlebit0/DailyCalendar`인 체크아웃,
`main`의 `8056934`, 기존 미커밋 변경까지 읽어 작성했다. GitHub 원격 최신 상태나
CI 실행 결과를 확인한 것은 아니다. 기존 작업은 그대로 보존했다.

앱은 Flutter이며 `lib/main.dart` → `lib/app/daily_bootstrap.dart` →
`lib/app/daily_app.dart`, `lib/core/di/app_providers.dart`로 구성된다.
현재 Drift schema는 9, 넓은 캘린더 기준은 사용 가능 너비 720px이다.
Drive AppData v2에는 일정별 JSON·설정 JSON·시간표 JSON이 있다.
LMS는 현재 SMU WebView 세션/로컬 보안 저장을 사용한다. 독립 모바일 토큰이나
다른 기기로의 인증 이식이 완료된 것으로 기술하지 않았다. 이 수치와 구현은
향후 해당 소스에서 다시 확인한다.

## 외부 플러그인 설치와 연결

2026-10-05 Plugin Management 조회 결과다. 검색 결과는 완전한 목록이 아니며,
이전 대화의 추천을 현재 계정에서 설치 가능하다는 증거로 사용하지 않았다.

| 항목 | 확인 결과 | 추가 작업 / Daily에서의 역할 |
| --- | --- | --- |
| 프로젝트 전용 다섯 스킬 | 저장소 파일 생성 완료 | 저장소에서 발견 가능; 앱이나 서비스 설치 불필요 |
| GitHub | 설치됨, 관련 도구 노출됨 | 실제 원격 작업에는 계정의 저장소 권한 필요; 파일 작성만으로 원격 반영되지 않음 |
| Figma | 현재 세션에 플러그인 도구/스킬 노출됨 | 디자인 작업 시 별도 파일/계정 접근 확인; Flutter 앱의 필수 빌드 도구 아님 |
| Superpowers | 설치 가능(`AVAILABLE`), 미설치 | 별도 디렉터리 설치 대상; 이번에는 설치하지 않음 |
| Codex Security | 설치 가능(`AVAILABLE`), 미설치 | 별도 설치 및 대상 저장소/워크플로 접근 확인 필요 |
| build-ios-apps | 이름 검색에서 정확한 항목 미확인 | 계정/카탈로그 가용성 재확인 후 설치; Xcode·Simulator 준비는 별도 |
| test-android-apps | 이름 검색에서 정확한 항목 미확인 | 가용성 재확인 후 설치; Android SDK·Java·Emulator 준비는 별도 |
| Sentry / CodeRabbit | 검색에서 항목 미확인 | 가용성과 서비스 계정/프로젝트 연결 필요 여부 재확인 |

추가 플러그인은 [플러그인 디렉터리](https://chatgpt.com/plugins)에서 확인한다.
로컬 스킬 파일은 플러그인 설치·서비스 인증·SDK 설치를 대신하지 않는다.
지원되는 로컬 marketplace는 별도 manifest와 source를 구성할 수 있으나,
실제 패키지/가용성 확인 없이 임의의 enabled 설정을 추가하지 않았다.
연결 서비스는 인증이 필요하다.
근거: [공식 플러그인 설정 문서](https://developers.openai.com/plugins/build/plugins).

SwiftUI 스킬은 Flutter 공통 UI 구현의 중심 절차로 사용하지 않는다. Apple native
bridge/위젯/Siri 분석이나 Xcode 검증에는 관련 도구가 보조 역할을 할 수 있다.
Android도 단순 빌드와 실제 Emulator 로그인·일정 동작 검증을 구분한다.

## 검증 범위

지침만 변경할 때는 형식·참조 경로·diff와 기존 파일 보존을 확인한다.
앱 구현 작업은 AGENTS.md의 전체 작업 완료 후 검증 원칙을 따른다.
아래는 2026-10-05 당시 명령 유효성을 확인한 과거 실행 결과이며 현재 재실행 결과가 아니다:

- 공식 `skill-creator` quick validator: 5개 모두 통과.
- 스킬에 명시된 저장소 경로 존재 확인 및 새 파일 포함 diff 공백 검사: 통과.
- `analyze --no-pub`: No issues found.
- Google 인증 테스트 + `test/core/lms` + Drive 병합 규칙 + DB 마이그레이션:
  198개 통과.
- Apple LMS 쿠키 정책 Python/Swift 검사: 2개 통과. macOS/iOS의 실제 정책을
  각각 추출해 실행하며 각 정책은 16개 Swift assertion을 확인한다.
- 변경 전 605개 기존 파일 해시 대조: `AGENTS.md`만 의도대로 변경;
  기존 1~8절 본문 보존, 나머지 기존 파일 및 기존 미커밋 작업 그대로 유지.

실행 환경에서는 `FLUTTER_SUPPRESS_ANALYTICS=true` 및 `--no-version-check`로
SDK의 부수 기록/업데이트 조회를 억제했다. SQLite native asset 다운로드가
필요해 네트워크 허용 범위에서 동일 테스트를 재실행했다. Swift 검사에서는
`SWIFT_MODULECACHE_PATH`, `CLANG_MODULE_CACHE_PATH`를 쓰기 가능한 임시 작업
폴더로 지정했다. 검증기용 PyYAML은 Git에서 제외된 `work/` 아래에만 받았고
앱 의존성은 변경하지 않았다. 전체 Flutter suite, 플랫폼 앱 빌드, 실제 기기 및
다기기 인증/동기화는 이번 지침 변경의 검증 범위에 포함하지 않았다.

이번 변경은 지침 파일만 대상으로 하며 앱 설치·실행·계정 로그인·스토어 업로드를
수행하는 작업이 아니다. Git commit/push 전까지 변경은 로컬 작업 트리에 있다.
