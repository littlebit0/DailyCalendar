# #81 전체 RGB 완료 표시 보정 — 2026-09-24

이전 수정은 대표색의 취소선 굵기 위주로 검증했고, 원본 분류색을 그대로
제목에 사용했다. 흰색·노랑은 밝은 화면에서, 검정·짙은 색은 어두운 화면에서
제목 자체가 배경에 묻혔다. 이번 수정은 임의 RGB 전체에 같은 계산을 적용한다.

## 변경 동작

- 저장된 분류색, 분류 식별용 색상, 일정 데이터는 유지한다.
- 표시용 제목색과 한 줄 취소선을 실제 배경과 함께 계산한다. 완료·미완료의
  제목색은 동일하며, 완료 시에만 한 줄이 추가된다.
- 보정은 원본 RGB를 검정 또는 흰색 방향으로 섞어 색 계열을 유지한다.
  노랑 등 특정 색 이름, RGB 상한·하한 구간별 예외표는 사용하지 않는다.
- 제목/배경 대비는 **4.5:1 이상**, 선/배경과 선/제목은 각각 **3:1 이상**이다.
  제목 기준은 [W3C 텍스트 대비 안내](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)를,
  선/배경 기준은 [비텍스트 대비 안내](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html)를 참고했다.
  선/제목 3:1은 교차 부분의 식별을 위한 추가 제품 검사 기준이다.
- 고정된 배경에서는 세 대비를 동시에 만족하는 색 조합이 없는 경우가 있다.
  그때는 배경도 가능한 명도 구간으로 최소 보정한다. 8비트 반올림 후 실제
  출력 색을 다시 검사하며, 읽을 수 없는 원본 색으로 조용히 되돌리지 않는다.
- 월간 막대는 계산된 불투명 배경을 실제로 그린다. 선택·휴일 등 형제 레이어가
  뒤에 있어도 제목 아래 색이 계산값과 달라지지 않는다. 시간·D-day·분류명도
  표시용 색을 사용하되 보조 글자에 취소선을 추가하지 않는다.
- 작은 글자에서 양 모드 모두 약 1.25 논리 픽셀 이상의 선을 확보한다.
  Android 월간 선 위치는 제목의 가운데로 맞췄다.

## 공통 처리 위치

- Flutter: [event_completion_palette.dart](../lib/core/theme/event_completion_palette.dart),
  [event_completion_style.dart](../lib/core/theme/event_completion_style.dart).
- Android: [DailyCompletionContrast.kt](../android/app/src/main/kotlin/com/littlebit0/dailycalendar/DailyCompletionContrast.kt).
  위젯의 실제 밝은 배경 `#FDFDFE`와 월간 막대의 `38/255` 불투명도를 반영한다.
- Apple: [DailyEventPalette.swift](../apple_widgets/DailyEventPalette.swift)를
  iOS Runner와 iOS/macOS 위젯이 공유한다. 배경 이미지 캐시 버전은 3으로 갱신했다.
- OS가 배경과 색조를 결정하는 Apple 잠금화면 accessory 위젯은 시스템 글자색과
  기본 취소선을 사용한다. 임의 배경화면을 검정/흰색이라고 가정하지 않는다.

## 전수 검사 결과

각 채널 값은 **0, 10, 20, …, 250, 255**이다. R/G/B의 모든 조합은
**27³ = 19,683색**이며 회색, 검정, 흰색과 양 끝값도 포함한다.

| 검사 | 범위 | 결과 |
|---|---|---|
| Flutter 팔레트 | 19,683색 × 사용 중인 표면 8개 × 불투명도 9개 = **1,417,176조합** | 실패 0 |
| Android 팔레트 | 모든 색 × 실제 위젯 표면/막대 조합 4개 = **78,732조합** | 실패 0 |
| Apple 팔레트 | 모든 색 × 위젯/배경 이미지 조합 6개 = **118,098조합** | 실패 0 |
| 구현 간 일치 | 같은 입력 512개를 Dart/Kotlin/Swift에 적용 | 출력 RGB 정확히 일치 |
| 한글 전체 색 렌더링 | 8pt, 화면 배율 1, 모든 색 × 두 모드 = **39,366쌍** | 실패 0 |
| 추가 실제 글꼴 렌더링 | 한글·Roboto × 크기 5개 × 배율 3개 × 표면 4개 × 취약색 12개 = **1,440쌍** | 실패 0 |

Flutter 팔레트의 최저 대비는 제목/배경 **4.500788**, 선/배경 **3.006203**,
선/제목 **3.008788**이었다. 배경 보정은 6,718조합에서 필요했다.
표면과 불투명도의 교차 검사는 실제 사용 조합보다 넓은 보수적 검사다.

래스터 검사는 선 없는 제목과 선 있는 제목을 실제 `TextPainter`로 그린 RGBA를
비교한다. 선의 가로 연속성, 하나의 가로띠인지, 글자 높이 내부를 가로지르는지,
제목 획이 남는지를 검사한다. 전체 색에서 가로 검출률 최저 90%, 원래 글자 획
보존 최저 71.07%였고, 가장자리 안티앨리어싱 픽셀의 대비를 4.5:1로 주장하지 않는다.
숫자 대비와 실제 렌더링은 각각 검사하며, 색 조화의 주관적 평가를 수치만으로
완전히 증명했다고 간주하지 않는다.

## 재현과 증거

```sh
./tool/flutter.sh test --no-pub test/core/theme/event_completion_style_test.dart
./tool/flutter.sh test --no-pub tool/tests/event_completion_raster_test.dart
swiftc -O apple_widgets/DailyEventPalette.swift tool/tests/event_palette_test.swift -o /tmp/daily-event-palette-test
/tmp/daily-event-palette-test
cd android
./gradlew app:testDebugUnitTest
```

실제 글꼴 검사는 macOS의 AppleSDGothicNeo와 Flutter SDK의 Roboto-Medium을
사용한다. 필요한 폰트가 없으면 명시적으로 실패하며 검사를 건너뛰지 않는다.
전체 Flutter 테스트는 **587개 통과, 기존 skip 1개**, Android JVM은 **12개 통과**.
새 공유 Swift 파일 연결 검사는 통과했고 macOS/iOS/Android debug 빌드가 성공했다.

세 플랫폼 테스트 앱을 현재 빌드로 업데이트하고 서명·설치 파일 일치를 확인했다.
설치 전후 보호 파일 해시는 macOS 2개, iPhone 3개, Android 14개 모두 동일했다.
macOS의 OS 보호 컨테이너는 읽기 제한으로 해시 확인 대상이 아니며 변경하지 않았다.
App Store 앱도 변경되지 않았다. Android는 검증된 업데이트 상태를 quick-boot
스냅샷에 저장한 뒤 에뮬레이터를 종료했다. 교체한 앱을 수동 실행하거나 새 계정에 로그인하지
않았고, 단축어 실행·배경 적용도 하지 않았다. 설치 백업과 검증 결과는 별도 보관한다.

현재 작업의 검사 출력은 Git 제외 경로 `work/issue81-full-rgb/`에 보관한다.
`palette-metrics.json`, `raster-metrics.json`, `comparison.png`에서 수치와
실제 글꼴 비교를 확인할 수 있다. 네이티브 단위 검사 로그는
`work/issue-81-full-rgb/`에 있다.

실제 iPad 배경화면 적용·단축어 실행은 사용자의 거절에 따라 수행하지 않는다.
Windows/Linux 네이티브 실행, 실제 기기별 색 표현과 OS가 색을 덮어쓰는 잠금화면
위젯 표시는 이 로컬 검사의 완료 범위에 포함하지 않는다. 릴리스·스토어 제출 및
이슈 종료는 하지 않는다.
