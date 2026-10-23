import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

class _Files extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Sogang profile loads its own catalog and published outer bounds',
    () async {
      final datasets = await UniversityCatalog.load(
        bundle: _Files(),
        university: 'sogang',
      );
      expect(datasets.single.courses, hasLength(1541));
      for (final id in [
        'academyinfo:0000120',
        'institution:academyinfo:0000120',
      ]) {
        final profile = AcademicProfile(
          universityId: id,
          universityName: '서강대학교',
          schoolKind: 'fourYear',
        );
        expect(profile.timetableUniversity, 'sogang');
        expect(profile.timetableCampus, 'unknown');
        expect(
          AcademicProfile(
            universityId: id,
            universityName: '서강대학교',
            schoolKind: 'fourYear',
            campusId: 'academyinfo:0000029',
          ).timetableSupported,
          isFalse,
        );
      }
      final defaults = await TimetablePeriodDefaults.load(bundle: _Files());
      final period = defaults.periodFor(2026, '2', university: 'sogang');
      expect(period?.start, DateTime(2026, 9, 1));
      expect(period?.end, DateTime(2026, 12, 21));
    },
  );
  test('current explicit CHS dates and exam stay intact through restore', () {
    final raw =
        jsonDecode(
              File(
                'assets/timetable/sogang-unknown-2026-2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final dataset = UniversityDataset.fromJson(raw);
    expect(dataset.courses, hasLength(1541));
    expect(dataset.courses.map((c) => c.sourceId).toSet(), hasLength(1541));
    expect(dataset.courses.where((c) => c.credits == null), hasLength(105));
    expect(
      dataset.courses.where((c) => c.hasSchedulableMeetings),
      hasLength(1307),
    );
    for (final id in ['MGT4303-01', 'MGT4306-01']) {
      final course = dataset.courses.singleWhere((c) => c.codeAndSection == id);
      final saved = course.toTimetable(
        id: course.sourceId,
        mode: LectureMode.video,
      );
      final restored = TimetableClass.fromJson(saved.toJson());
      expect(restored.meetings, hasLength(28));
      expect(course.remarks, contains('공시 수업 계획'));
      expect(restored.toJson().toString(), contains('공시 수업 계획'));
      expect(
        classOccurrences(
          [restored],
          [
            DateTime(2026, 10, 5),
            DateTime(2026, 12, 16),
            DateTime(2026, 12, 21),
            DateTime(2027, 1, 1),
          ],
        ),
        isEmpty,
      );
      if (id == 'MGT4306-01') {
        expect(
          restored.meetings
              .singleWhere((m) => m.date == '2026-10-21')
              .classroom,
          'MA104',
        );
        expect(
          restored.meetings
              .where((m) => m.date != '2026-10-21')
              .map((m) => m.classroom)
              .toSet(),
          {'MA206'},
        );
      }
    }
    for (final entry in {
      'PHI2006-01': 26,
      'PHIG085-01': 28,
      'POL2010-01': 27,
    }.entries) {
      final course = dataset.courses.singleWhere(
        (c) => c.codeAndSection == entry.key,
      );
      final saved = course.toTimetable(
        id: course.sourceId,
        mode: LectureMode.video,
      );
      final restored = TimetableClass.fromJson(saved.toJson());
      expect(restored.meetings, hasLength(entry.value));
      for (final meeting in restored.meetings) {
        expect(
          restored.modeOn(meeting, meeting.teachingDate!),
          LectureMode.inPerson,
        );
      }
      final omitted = switch (entry.key) {
        'PHI2006-01' => [
          DateTime(2026, 9, 10),
          DateTime(2026, 9, 24),
          DateTime(2026, 9, 30),
          DateTime(2026, 10, 22),
          DateTime(2026, 12, 15),
          DateTime(2026, 12, 17),
        ],
        'PHIG085-01' => [
          DateTime(2026, 10, 5),
          DateTime(2026, 10, 26),
          DateTime(2026, 12, 16),
          DateTime(2026, 12, 21),
        ],
        _ => [
          DateTime(2026, 9, 24),
          DateTime(2026, 10, 20),
          DateTime(2026, 10, 22),
          DateTime(2026, 12, 15),
          DateTime(2026, 12, 17),
        ],
      };
      expect(classOccurrences([restored], omitted), isEmpty);
      expect(
        restored.meetings.map((m) => m.toJson()).toList(),
        saved.meetings.map((m) => m.toJson()).toList(),
      );
      if (entry.key == 'PHI2006-01') {
        expect(classOccurrences([restored], [DateTime(2026, 9, 29)]), isEmpty);
        expect(course.remarks, contains('임의 보정하지 않고'));
      }
      if (entry.key == 'POL2010-01') expect(course.remarks, contains('최소 두 팀'));
    }
    for (final id in ['ENG2112-01', 'GKS4015-01']) {
      final course = dataset.courses.singleWhere((c) => c.codeAndSection == id);
      final saved = course.toTimetable(
        id: course.sourceId,
        mode: LectureMode.video,
      );
      final restored = TimetableClass.fromJson(saved.toJson());
      expect(restored.meetings, hasLength(27));
      expect(restored.meetings.map((m) => m.classroom).toSet(), {
        id == 'ENG2112-01' ? 'J102' : 'X428',
      });
      expect(restored.meetings.map((m) => m.originalStartMinute).toSet(), {
        id == 'ENG2112-01' ? 630 : 990,
      });
      for (final meeting in restored.meetings) {
        expect(
          restored.modeOn(meeting, meeting.teachingDate!),
          LectureMode.inPerson,
        );
      }
      expect(
        classOccurrences(
          [restored],
          [
            DateTime(2026, 10, 5),
            DateTime(2026, 12, 16),
            DateTime(2026, 12, 21),
            DateTime(2027, 1, 1),
          ],
        ),
        isEmpty,
      );
      if (id == 'ENG2112-01') {
        expect(
          classOccurrences(
            [restored],
            [DateTime(2026, 9, 7), DateTime(2026, 10, 28)],
          ),
          isEmpty,
        );
        expect(
          classOccurrences([restored], [DateTime(2026, 10, 21)]),
          hasLength(1),
        );
        expect(
          classOccurrences([restored], [DateTime(2026, 10, 26)]),
          hasLength(1),
        );
        expect(course.remarks, contains('노트북'));
      } else {
        expect(
          classOccurrences(
            [restored],
            [DateTime(2026, 10, 21), DateTime(2026, 10, 26)],
          ),
          isEmpty,
        );
        expect(course.remarks, contains('조건부 발표 연장'));
      }
      expect(
        restored.meetings.map((m) => m.toJson()).toList(),
        saved.meetings.map((m) => m.toJson()).toList(),
      );
    }
    final statistics = dataset.courses.singleWhere(
      (c) => c.codeAndSection == 'MGT2002-02',
    );
    final statisticsSaved = statistics.toTimetable(
      id: statistics.sourceId,
      mode: LectureMode.liveOnline,
    );
    final statisticsRestored = TimetableClass.fromJson(
      statisticsSaved.toJson(),
    );
    expect(statisticsRestored.meetings, hasLength(27));
    expect(
      statisticsRestored.meetings.map((m) => m.originalStartMinute).toSet(),
      {810},
    );
    expect(
      statisticsRestored.meetings.map((m) => m.originalEndMinute).toSet(),
      {885},
    );
    expect(statisticsRestored.meetings.map((m) => m.classroom).toSet(), {
      'MA102',
    });
    for (final meeting in statisticsRestored.meetings) {
      expect(
        statisticsRestored.modeOn(meeting, meeting.teachingDate!),
        LectureMode.inPerson,
      );
    }
    expect(
      classOccurrences(
        [statisticsRestored],
        [
          DateTime(2026, 9, 24),
          DateTime(2026, 10, 20),
          DateTime(2026, 10, 22),
          DateTime(2026, 12, 15),
          DateTime(2026, 12, 17),
          DateTime(2027, 1, 1),
        ],
      ),
      isEmpty,
    );
    expect(statistics.remarks, contains('사이버캠퍼스'));
    expect(statistics.remarks, contains('통계학입문수강자 불가'));
    expect(
      statisticsRestored.meetings.map((m) => m.toJson()).toList(),
      statisticsSaved.meetings.map((m) => m.toJson()).toList(),
    );
    final psychology = dataset.courses.singleWhere(
      (c) => c.codeAndSection == 'HSS3033-01',
    );
    final psychologySaved = psychology.toTimetable(
      id: psychology.sourceId,
      mode: LectureMode.inPerson,
    );
    final psychologyRestored = TimetableClass.fromJson(
      psychologySaved.toJson(),
    );
    expect(psychologyRestored.meetings, hasLength(13));
    expect(psychologyRestored.meetings.map((m) => m.classroom).toSet(), {
      'DB101',
    });
    expect(
      psychologyRestored.meetings.map((m) => m.originalStartMinute).toSet(),
      {990},
    );
    expect(
      psychologyRestored.meetings.map((m) => m.originalEndMinute).toSet(),
      {1100},
    );
    expect(
      classOccurrences(
        [psychologyRestored],
        [DateTime(2026, 9, 23), DateTime(2026, 10, 21), DateTime(2026, 12, 16)],
      ),
      isEmpty,
    );
    expect(
      psychologyRestored.meetings.map((m) => m.toJson()).toList(),
      psychologySaved.meetings.map((m) => m.toJson()).toList(),
    );
    final japan = dataset.courses.singleWhere(
      (c) => c.codeAndSection == 'JPN4011-01',
    );
    final japanSaved = japan.toTimetable(
      id: japan.sourceId,
      mode: LectureMode.inPerson,
    );
    final japanRestored = TimetableClass.fromJson(japanSaved.toJson());
    expect(japanRestored.meetings, hasLength(12));
    expect(japanRestored.meetings.map((m) => m.weekday).toSet(), {
      DateTime.wednesday,
    });
    expect(japanRestored.meetings.map((m) => m.classroom).toSet(), {'J211'});
    expect(
      classOccurrences(
        [japanRestored],
        [
          DateTime(2026, 9, 7),
          DateTime(2026, 10, 21),
          DateTime(2026, 10, 26),
          DateTime(2026, 12, 2),
          DateTime(2026, 12, 9),
        ],
      ),
      isEmpty,
    );
    expect(japan.remarks, contains('월요일 실제 수업일'));
    expect(
      japanRestored.meetings.map((m) => m.toJson()).toList(),
      japanSaved.meetings.map((m) => m.toJson()).toList(),
    );
    for (final id in ['KOR3010-01', 'KORG001-01']) {
      final course = dataset.courses.singleWhere((c) => c.codeAndSection == id);
      final saved = course.toTimetable(
        id: course.sourceId,
        mode: LectureMode.inPerson,
      );
      final restored = TimetableClass.fromJson(saved.toJson());
      expect(restored.meetings, hasLength(id == 'KOR3010-01' ? 27 : 25));
      expect(restored.meetings.map((m) => m.classroom).toSet(), {
        id == 'KOR3010-01' ? 'J327' : 'J116',
      });
      expect(
        classOccurrences(
          [restored],
          [
            DateTime(2026, 9, 10),
            DateTime(2026, 9, 24),
            DateTime(2026, 10, 22),
            DateTime(2026, 12, 15),
            DateTime(2026, 12, 17),
          ],
        ),
        isEmpty,
      );
      expect(
        restored.meetings.map((m) => m.toJson()).toList(),
        saved.meetings.map((m) => m.toJson()).toList(),
      );
      for (final m in restored.meetings) {
        expect(m.teachingDate!.weekday, m.weekday);
        expect(m.originalStartMinute, id == 'KOR3010-01' ? 720 : 630);
        expect(m.originalEndMinute, id == 'KOR3010-01' ? 795 : 705);
      }
      expect(course.remarks, contains('개강미사'));
      if (id == 'KORG001-01') {
        expect(
          classOccurrences(
            [restored],
            [DateTime(2026, 9, 29), DateTime(2026, 10, 20)],
          ),
          isEmpty,
        );
        expect(course.remarks, contains('2강좌 이상'));
      }
    }
    final writingOne = dataset.courses.singleWhere(
      (c) => c.codeAndSection == 'COR1012-01',
    );
    final savedOne = writingOne.toTimetable(
      id: writingOne.sourceId,
      mode: LectureMode.inPerson,
    );
    final restoredOne = TimetableClass.fromJson(savedOne.toJson());
    expect(restoredOne.meetings, hasLength(20));
    expect(restoredOne.meetings.map((m) => m.classroom).toSet(), {'J202'});
    expect(restoredOne.meetings.map((m) => m.originalStartMinute).toSet(), {
      630,
    });
    expect(restoredOne.meetings.map((m) => m.originalEndMinute).toSet(), {705});
    expect(
      classOccurrences(
        [restoredOne],
        [
          DateTime(2026, 10, 5),
          DateTime(2026, 10, 21),
          DateTime(2026, 11, 16),
          DateTime(2026, 11, 25),
          DateTime(2026, 12, 14),
        ],
      ),
      isEmpty,
    );
    expect(writingOne.remarks, contains('20회'));
    expect(
      restoredOne.meetings.map((m) => m.toJson()).toList(),
      savedOne.meetings.map((m) => m.toJson()).toList(),
    );
    final theater = dataset.courses.singleWhere(
      (c) => c.codeAndSection == 'MAS2006-01',
    );
    final theaterSaved = theater.toTimetable(
      id: theater.sourceId,
      mode: LectureMode.inPerson,
    );
    final theaterRestored = TimetableClass.fromJson(theaterSaved.toJson());
    expect(theaterRestored.meetings, hasLength(12));
    expect(theaterRestored.meetings.map((m) => m.classroom).toSet(), {'GA401'});
    expect(theaterRestored.meetings.map((m) => m.originalStartMinute).toSet(), {
      630,
    });
    expect(theaterRestored.meetings.map((m) => m.originalEndMinute).toSet(), {
      705,
    });
    expect(
      classOccurrences(
        [theaterRestored],
        [
          DateTime(2026, 9, 21),
          DateTime(2026, 10, 5),
          DateTime(2026, 10, 26),
          DateTime(2026, 11, 23),
          DateTime(2026, 12, 2),
        ],
      ),
      isEmpty,
    );
    expect(theater.remarks, contains('필기시험이 없으며'));
    expect(
      theaterRestored.meetings.map((m) => m.toJson()).toList(),
      theaterSaved.meetings.map((m) => m.toJson()).toList(),
    );
    final nextWriting = dataset.courses.singleWhere(
      (c) => c.codeAndSection == 'COR1012-17',
    );
    final nextSaved = nextWriting.toTimetable(
      id: nextWriting.sourceId,
      mode: LectureMode.inPerson,
    );
    final nextRestored = TimetableClass.fromJson(nextSaved.toJson());
    expect(nextRestored.meetings, hasLength(23));
    expect(nextRestored.meetings.map((m) => m.originalStartMinute).toSet(), {
      900,
    });
    expect(nextRestored.meetings.map((m) => m.originalEndMinute).toSet(), {
      975,
    });
    expect(nextRestored.meetings.map((m) => m.classroom).toSet(), {'J325'});
    expect(nextWriting.categoriesFor(), [CourseCategory.generalEducation]);
    expect(
      classOccurrences(
        [nextRestored],
        [
          DateTime(2026, 9, 24),
          DateTime(2026, 10, 20),
          DateTime(2026, 10, 22),
          DateTime(2026, 12, 1),
          DateTime(2026, 12, 10),
          DateTime(2026, 12, 17),
        ],
      ),
      isEmpty,
    );
    expect(nextWriting.remarks, contains('과제 제출'));
    expect(nextWriting.remarks, contains('개별 면담'));
    expect(
      nextRestored.meetings.map((m) => m.toJson()).toList(),
      nextSaved.meetings.map((m) => m.toJson()).toList(),
    );
    final writing = dataset.courses.singleWhere(
      (c) => c.codeAndSection == 'COR1012-12',
    );
    final writingSaved = writing.toTimetable(
      id: writing.sourceId,
      mode: LectureMode.inPerson,
    );
    final writingRestored = TimetableClass.fromJson(writingSaved.toJson());
    expect(writingRestored.meetings, hasLength(23));
    expect(writingRestored.meetings.map((m) => m.originalStartMinute).toSet(), {
      990,
    });
    expect(writingRestored.meetings.map((m) => m.originalEndMinute).toSet(), {
      1065,
    });
    expect(
      classOccurrences(
        [writingRestored],
        [
          DateTime(2026, 9, 24),
          DateTime(2026, 10, 20),
          DateTime(2026, 10, 22),
          DateTime(2026, 12, 1),
          DateTime(2026, 12, 10),
        ],
      ),
      isEmpty,
    );
    expect(writing.remarks, contains('비대면 개별면담'));
    final course = dataset.courses.singleWhere(
      (c) => c.codeAndSection == 'CHS2003-03',
    );
    expect(course.categoriesFor(), [CourseCategory.generalEducation]);
    final original = course.toTimetable(
      id: course.sourceId,
      mode: LectureMode.liveOnline,
    );
    final restored = TimetableClass.fromJson(original.toJson());
    expect(restored.isValid, isTrue);
    expect(restored.meetings, hasLength(28));
    expect(
      restored.meetings.map((m) => m.toJson()).toList(),
      original.meetings.map((m) => m.toJson()).toList(),
    );
    for (final meeting in restored.meetings) {
      expect(meeting.teachingDate!.weekday, meeting.weekday);
      expect(meeting.originalStartMinute, 720);
      expect(meeting.originalEndMinute, 795);
      expect(meeting.classroom, 'K303');
      expect(
        restored.modeOn(meeting, meeting.teachingDate!),
        LectureMode.inPerson,
      );
    }
    expect(
      classOccurrences([restored], [DateTime(2026, 10, 20)]),
      hasLength(1),
    );
    expect(
      classOccurrences(
        [restored],
        [
          DateTime(2026, 9, 24),
          DateTime(2026, 10, 22),
          DateTime(2026, 12, 15),
          DateTime(2026, 12, 17),
          DateTime(2027, 1, 5),
        ],
      ),
      isEmpty,
    );
  });
}
