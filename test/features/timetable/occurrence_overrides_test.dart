import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

ClassMeeting meeting(String id, int weekday) => ClassMeeting(
  id: id,
  weekday: weekday,
  startMinute: 9 * 60,
  endMinute: 10 * 60,
);

TimetableClass course(
  List<ClassMeeting> meetings,
  Map<String, LectureMode> overrides,
) => TimetableClass(
  id: 'course-1',
  title: '수업',
  meetings: meetings,
  academicYear: 2026,
  semester: '2',
  overrides: overrides,
);

void main() {
  final overrides = {
    // Mondays of block 0 and a Wednesday of block 1.
    'meeting-0/2026-10-12': LectureMode.cancelled,
    'meeting-0/2026-10-19': LectureMode.video,
    'meeting-1/2026-10-14': LectureMode.cancelled,
  };

  test('moving a block to another weekday drops only its own stale dates', () {
    final kept = occurrenceOverridesForMeetings([
      meeting('meeting-0', DateTime.tuesday),
      meeting('meeting-1', DateTime.wednesday),
    ], overrides);
    expect(kept.keys, ['meeting-1/2026-10-14']);
  });

  test('editing time or room on the same weekday keeps every change', () {
    final kept = occurrenceOverridesForMeetings([
      meeting('meeting-0', DateTime.monday),
      meeting('meeting-1', DateTime.wednesday),
    ], overrides);
    expect(kept, overrides);
  });

  test('removed blocks and malformed keys are not kept', () {
    final kept = occurrenceOverridesForMeetings(
      [meeting('meeting-0', DateTime.monday)],
      {
        ...overrides,
        'meeting-9/2026-10-12': LectureMode.cancelled,
        'x': LectureMode.video,
        'meeting-0/2026-10-1': LectureMode.video,
      },
    );
    expect(kept.keys, ['meeting-0/2026-10-12', 'meeting-0/2026-10-19']);
  });

  test('the filtered class passes the synced-document validation', () {
    final moved = course(
      [
        meeting('meeting-0', DateTime.tuesday),
        meeting('meeting-1', DateTime.wednesday),
      ],
      occurrenceOverridesForMeetings([
        meeting('meeting-0', DateTime.tuesday),
        meeting('meeting-1', DateTime.wednesday),
      ], overrides),
    );
    final key = timetableCourseSyncKey(moved);
    TimetableSyncDocument.records(
      courses: {
        key: TimetableSyncValue(
          moved.toJson(),
          DateTime.utc(2026, 10, 12),
          'test',
        ),
      },
    );
    // Without filtering, the same class is rejected (the reported failure).
    final stale = course([
      meeting('meeting-0', DateTime.tuesday),
      meeting('meeting-1', DateTime.wednesday),
    ], overrides);
    expect(
      () => TimetableSyncDocument.records(
        courses: {
          timetableCourseSyncKey(stale): TimetableSyncValue(
            stale.toJson(),
            DateTime.utc(2026, 10, 12),
            'test',
          ),
        },
      ),
      throwsFormatException,
    );
  });
}
