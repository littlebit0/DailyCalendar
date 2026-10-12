import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
    'registered Kwangwoon keeps whole search and dated attendance on restore',
    () async {
      final data = (await UniversityCatalog.load(
        bundle: _Files(),
        university: 'kwangwoon',
      )).single;
      expect(data.courses, hasLength(1261));
      expect(data.courses.map((c) => c.sourceId).toSet(), hasLength(1261));
      expect(
        data.courses.where((c) => c.hasSchedulableMeetings),
        hasLength(945),
      );
      expect(
        data.courses.where((c) => c.scheduleStatus == 'unrecognized'),
        hasLength(316),
      );
      for (final c in data.courses) {
        expect(c.campus, 'unknown');
        expect(c.sourceSchedule, isNotEmpty);
        if (!c.hasSchedulableMeetings) continue;
        final saved = c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson);
        final restored = TimetableClass.fromJson(saved.toJson());
        expect(restored.isValid, isTrue, reason: c.sourceId);
        expect(
          restored.meetings.map((m) => m.toJson()).toList(),
          saved.meetings.map((m) => m.toJson()).toList(),
        );
        expect(restored.period?.toJson(), saved.period?.toJson());
        for (final m in restored.meetings) {
          expect(m.date, isNotNull);
          for (final other in restored.meetings) {
            if (identical(m, other) || m.date != other.date) continue;
            expect(
              m.startMinute < other.endMinute &&
                  other.startMinute < m.endMinute,
              isFalse,
              reason: '${c.codeAndSection} ${m.date}',
            );
          }
          expect(m.teachingDate!.weekday, m.weekday);
          if (m.classroom.isEmpty) {
            expect(c.sourceClassroom, isEmpty);
          } else {
            expect(
              c.sourceClassroom.split(RegExp(r'[;\n]')).map((s) => s.trim()),
              contains(m.classroom),
            );
          }
          expect(
            m.originalEndMinute - m.originalStartMinute,
            isIn([75, 45, 95, 145, 195, 245, 110, 230]),
          );
          expect(restored.modeOn(m, m.teachingDate!), LectureMode.inPerson);
        }
        expect(
          classOccurrences(
            [restored],
            [
              DateTime(2026, 8, 31),
              DateTime(2026, 9, 24),
              DateTime(2026, 9, 25),
              DateTime(2026, 9, 26),
              DateTime(2026, 10, 3),
              DateTime(2026, 10, 5),
              DateTime(2026, 10, 9),
              DateTime(2026, 12, 15),
              DateTime(2026, 12, 21),
              DateTime(2027, 1, 1),
            ],
          ),
          isEmpty,
        );
      }
    },
  );
  test(
    'Kwangwoon profile uses actual unknown course location and published term',
    () async {
      for (final id in [
        'institution:academyinfo:0000074',
        'academyinfo:0000074',
      ]) {
        final profile = AcademicProfile(
          universityId: id,
          universityName: '광운대학교',
          schoolKind: 'fourYear',
        );
        expect(profile.timetableUniversity, 'kwangwoon');
        expect(profile.timetableCampus, 'unknown');
        expect(profile.academicSourceId, 'kwangwoon');
      }
      const foreign = AcademicProfile(
        universityId: 'institution:academyinfo:0000074',
        universityName: '광운대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000200',
      );
      expect(foreign.timetableCampus, isNull);
      final defaults = await TimetablePeriodDefaults.load(bundle: _Files());
      final term = defaults.periodFor(2026, '2', university: 'kwangwoon');
      expect(term?.start, DateTime(2026, 9, 1));
      expect(term?.end, DateTime(2026, 12, 21));
    },
  );
}
