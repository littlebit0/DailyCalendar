# DailyCalendar Drive 읽기 규약

2026-10-16 작업 트리의 실제 직렬화 코드로 확인한 구조. 데이터에 새로운 버전이 나오면 해당 버전의 의미를 확인하고, 모르는 구조를 임의로 옛 형식으로 처리하지 않는다.

## 파일과 접근

Drive API v3의 `files.list`에 `spaces=appDataFolder`를 사용하는 앱 전용 공간이다. DailyCalendar OAuth 범위는 `https://www.googleapis.com/auth/drive.appdata`다. 이 범위는 이름과 달리 읽기 전용 OAuth 범위가 아니므로 연결 구현은 조회 작업만 노출해야 한다. 이 문서는 자격증명을 포함하지 않는다.

권한이 있는 연결에서 `trashed = false`와 DailyCalendar 파일 이름을 기준으로 모든 페이지를 열거한다. 파일 메타데이터와 ID를 확인한 뒤 원본 내용을 읽는다. 실제 연결이 제공하지 않는 API를 호출할 수 있다고 가정하지 않는다.

| 파일 | 의미 |
| --- | --- |
| `daily-sync-v2-event-{eventId}.json` | 일정 원본 또는 삭제 기록 |
| `daily-sync-v2-settings.json` | 설정/분류 등 해석에 필요한 문맥 |
| `daily-sync-v2-timetable.json` | 일반 이벤트와 별도로 동기화되는 시간표 |

`daily-sync-v1.json`을 현행 전체 데이터 대신 사용하지 않는다. 파일 목록만으로 각 일정 날짜를 알 수 없으며 과거 생성 파일에도 미래 반복이 있을 수 있다. 설정은 일정 해석에 필요한 문맥으로 쓰고, 계정/환경 설정을 일정 내용처럼 사용자에게 나열하지 않는다.

## 이벤트

일반 봉투는 `schemaVersion: 2`, `type: event`, `event: {...}`다. 기존 독립 event 객체도 읽기 코드에서 지원한다. `updatedAt` 봉투는 업로드 시각일 수 있으므로 내용 버전 비교에는 event 내부 시각을 사용한다.

전체 필드에는 `id`, `title`, `memo`, `location`, `url`, `weather`, `lms`, `startAt`, `endAt`, `allDay`, `startDate`, `endDate`, `category`, `categoryLabel`, `categoryLocked`, `colorValue`, `reminderMinutesBefore`, `reminderMinutesBeforeList`, `recurrenceFrequency`, `recurrenceInterval`, `recurrenceUntil`, `recurrenceUntilDate`, `recurrenceExcludedDatesOnly`, `recurrenceCount`, `recurrenceExcludedDates`, `createdAt`, `updatedAt`, `deletedAt`, `deviceId`, `showDday`, `completed`, `alarmEnabled`, `allDayAlarmMinutes`가 있다. 선택 필드의 부재를 값이 확인된 것으로 해석하지 않는다.

- 종일 일정은 날짜 전용 `startDate`/`endDate` 우선. UTC 변환으로 날짜를 이동하지 않는다. 종료일은 배타적이다. 예를 들어 10월 16일~17일은 16일 하루다.
- 시간 일정은 타임스탬프를 사용자 시간대로 해석한다. 구간 종료가 하한과 같으면 겹치지 않는다. LMS의 시작=종료 일정은 해당 시각의 점 일정으로 다룬다.
- 반복은 none/daily/weekly/monthly/yearly 및 interval/until/count/excludedDates를 함께 해석한다. 날짜 전용 until/excluded 필드 우선. count는 제외된 날짜도 생성 횟수로 센다. 월말/윤년은 앱의 순차 날짜 보정 규칙을 따르며 단순 30일/365일 계산으로 대체하지 않는다. 정확한 발생일을 계산할 수 없으면 원본 규칙을 제시하고 발생일을 확정하지 않는다.
- 삭제는 `event.deletedAt != null` 또는 `compacted: true, deletion: {...}`다. 후자는 일정 내용이 없는 압축 삭제 기록이다. 삭제가 최신이면 일정 후보에서 제거한다.
- 같은 event ID가 여러 파일에 있으면 내부 createdAt/updatedAt/deletedAt 중 최댓값(압축 삭제는 deletion.deletedAt)을 비교하고 같은 시각에는 삭제 우선. LMS 소유자 보존, 압축 삭제, 수동 완료 및 canonical JSON 동률 규칙까지 필요하면 아래 구현을 따른다. 최종 동률을 해결할 수 없으면 파일 목록 순서나 Drive modifiedTime으로 임의 선택하지 말고 충돌로 보고한다.
- LMS 자료는 현재 확인된 소유자와 일치해야 한다. `lms:` ID인데 소유 메타데이터가 없으면 개인 일정으로 간주하지 않는다.

## 시간표

외부 봉투는 `schemaVersion: 2, type: timetable, document: {...}`. 내부 document는 별도의 schemaVersion 1/2를 가진다. `courses`, `termNames`, `termPeriods`의 각 값은 `value`, `changedAt`, `deviceId`를 갖는 레코드다. `value: null`은 삭제다. 레거시 `activeTerm`만 보고 다른 미래 학기를 누락하지 않는다.

동일 키 충돌은 변경 시각, 삭제 우선, deviceId, canonical JSON 순으로 비교한다. 날짜가 명시된 수업은 그 날짜에만, 기간이 있는 수업은 그 기간 안에서만 해석한다. 시간표의 전체 원문과 메모·강의실·시간·날짜 제약을 유지한다. 해석되지 않은 시간표가 남으면 일반 이벤트만 읽은 상태를 전체 일정 확인이라고 하지 않는다.

## 구현 근거

DailyCalendar 저장소가 연결된 환경에서는 다음 소스로 추가 해석을 확인할 수 있다. 저장소가 없더라도 위 규약과 실제 원본으로 처리하며 코드를 읽었다고 가장하지 않는다.

- `lib/core/sync/google_drive_sync_service.dart`: 파일 열거, 봉투 직렬화, `_DownloadedEvent.compareTo`.
- `lib/core/sync/sync_version.dart`: `compareEventVersions`, `eventVersionValues`.
- `lib/features/events/domain/calendar_event.dart`: 종일 경계, 겹침, 계정 소유권.
- `lib/features/events/data/recurrence_expander.dart`: 반복 발생일 계산.
- `lib/features/timetable/data/timetable_sync_document.dart`: 시간표 버전과 레코드 병합.
- `lib/features/timetable/domain/timetable.dart`: 수업 전체 필드와 날짜 제약.

## 범위 예시

사용자 시간대에서 D=2026-10-16이면 오늘/미래 필수 범위는 10월 16일 00:00 이후 전체이며, 필요시 과거 범위는 10월 9일 00:00 이상~10월 16일 00:00 미만이다. 10월 8일에 시작해 10월 10일까지 이어진 일정은 과거 구간과 겹친다. 2025년에 시작한 무기한 반복 일정도 미래 발생이 있으면 포함한다. 2030년의 단발 일정도 상한 없이 포함한다. 이 날짜는 예시이며 실행일을 대신하지 않는다.
