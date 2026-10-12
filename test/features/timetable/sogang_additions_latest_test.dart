// Historical checkpoint149 regression. Latest packaged152 checks are separate.
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const directory =
    'work/university-research/catalog-c/sogang-native-12hour-resolution-v3-20261008';
Map<String, dynamic> read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
String fileHash(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();
void main() {
  final audit = read('$directory/disambiguation-audit-v3.json');
  final candidate = read(
    'work/university-research/resume-batch-20261010/before-projection/sogang-unknown-2026-2.json',
  );
  final base = read(audit['baseFile']);
  final native = read(audit['nativeOriginalSource']['file']);
  final model = UniversityDataset.fromJson(candidate);
  final courses = (candidate['courses'] as List).cast<Map<String, dynamic>>();
  final previous = (base['courses'] as List).cast<Map<String, dynamic>>();
  final nativeByOffering = {
    for (final r in native['records']) '${r['subjectCode']}-${r['section']}': r,
  };
  final added = (audit['newReservations'] as List)
      .map((r) => r['offering'] as String)
      .toSet();

  test(
    'source hashes, whole native fields and frozen885 remain independent and exact',
    () {
      expect(
        fileHash('$directory/${audit['candidateFile']}'),
        audit['candidateSHA256'],
      );
      expect(
        fileHash(audit['baseFile']),
        'ae139b46caffb705509de200319c24a61da0ae09a79c39df71992bf2c1ad9ca5',
      );
      expect(
        fileHash(audit['nativeOriginalSource']['file']),
        audit['nativeOriginalSource']['sha256'],
      );
      expect(
        fileHash(audit['calendarSource']['file']),
        audit['calendarSource']['sha256'],
      );
      expect(model.courses, hasLength(1541));
      expect(
        model.courses.where((c) => c.hasSchedulableMeetings),
        hasLength(894),
      );
      expect(model.courses.expand((c) => c.meetings), hasLength(20185));
      expect(added, hasLength(9));
      var unchangedDated = 0;
      var unchangedHeld = 0;
      for (var i = 0; i < courses.length; i++) {
        final c = courses[i];
        final before = previous[i];
        final offering = '${c['courseCode']}-${c['section']}';
        final source = nativeByOffering[offering] as Map;
        final metadata = c['sourceEducationalMetadata'] as Map;
        for (final field in [
          'subjectCode',
          'section',
          'title',
          'meetingText',
          'professor',
          'credit',
          'year',
          'semester',
        ]) {
          expect(metadata[field], source[field], reason: '$offering $field');
        }
        expect(c['sourceId'], before['sourceId']);
        expect(metadata, before['sourceEducationalMetadata']);
        for (final field in [
          'campus',
          'academicYear',
          'semester',
          'courseCode',
          'section',
          'courseName',
          'professor',
          'credits',
          'departments',
          'classification',
          'departmentCredits',
          'departmentClassifications',
          'departmentRemarks',
          'sourceSchedule',
        ]) {
          expect(c[field], before[field], reason: '$offering $field');
        }
        if (!added.contains(offering)) {
          expect(jsonEncode(c), jsonEncode(before));
          if ((before['schedules'] as List).isEmpty) {
            unchangedHeld++;
          } else {
            unchangedDated++;
          }
        } else {
          expect(before['schedules'], isEmpty);
          expect(
            c['reservationEvidence']['dateMeaning'],
            'derivedRegularWeeklyReservationNotSourcePublishedAttendance',
          );
          expect(c['reservationEvidence']['sourceWeekIndexUsed'], false);
          expect(
            c['reservationEvidence']['sourcePublishedIndividualDatesClaim'],
            false,
          );
          expect(c['remarks'], contains('실제출석날짜가 아닙니다'));
        }
      }
      expect(unchangedDated, 885);
      expect(unchangedHeld, 647);
      expect(candidate['completionClaim'], false);
      expect(candidate['wholeOperatingVerified'], false);
    },
  );

  test(
    'own calendar boundaries and independent native weekly reservation dates, no source attendance inference',
    () {
      final calendar = read(audit['calendarSource']['file']);
      final rows = calendar['data'] as List;
      expect(
        rows.any(
          (r) => r['schedule'] == '2026.09.01' && r['title'].contains('개강'),
        ),
        true,
      );
      expect(
        rows.any(
          (r) => r['schedule'] == '2026.12.22' && r['title'].contains('겨울방학'),
        ),
        true,
      );
      final excluded = <String>{
        '2026-09-18',
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
        '2026-11-20',
      };
      for (var day = 20; day <= 26; day++) {
        excluded.add('2026-10-$day');
      }
      for (var day = 15; day <= 21; day++) {
        excluded.add('2026-12-$day');
      }
      expect(
        audit['calendarSource']['knownExcludedDates'],
        (excluded.toList()..sort()),
      );
      const weekdays = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7};
      var count = 0;
      for (final c in courses.where(
        (c) => added.contains('${c['courseCode']}-${c['section']}'),
      )) {
        final metadata = c['sourceEducationalMetadata'] as Map;
        final text = metadata['meetingText'] as String;
        final pieces = text.split(' ');
        final days = pieces[0].split(',').map((day) => weekdays[day]!).toSet();
        final clock = RegExp(
          r'(\d{2}):(\d{2})~(\d{2}):(\d{2})',
        ).firstMatch(text)!;
        final start = int.parse(clock[1]!) * 60 + int.parse(clock[2]!);
        final end = int.parse(clock[3]!) * 60 + int.parse(clock[4]!);
        final room = RegExp(r'\[([^\]]+)\]').firstMatch(text)![1];
        final individualExams = RegExp(r'(\d{1,2})\.(\d{1,2})\(')
            .allMatches(metadata['exam'] as String)
            .map(
              (m) => '2026-${m[1]!.padLeft(2, '0')}-${m[2]!.padLeft(2, '0')}',
            )
            .toSet();
        final expectedDates = <String>[];
        for (
          var date = DateTime(2026, 9, 1);
          !date.isAfter(DateTime(2026, 12, 21));
          date = date.add(const Duration(days: 1))
        ) {
          final key = timetableDateKey(date);
          if (days.contains(date.weekday) &&
              !excluded.contains(key) &&
              !individualExams.contains(key)) {
            expectedDates.add(key);
          }
        }
        final schedules = c['schedules'] as List;
        expect(schedules.map((m) => m['date']).toList(), expectedDates);
        expect(c['period'], {
          'startDate': '2026-09-01',
          'endDate': '2026-12-21',
        });
        for (final m in schedules) {
          expect(m['startMinute'], start);
          expect(m['endMinute'], end);
          expect(m['classroom'], room);
          expect(m['weekday'], DateTime.parse(m['date']).weekday);
          expect(m.containsKey('deliveryMode'), false);
          count++;
        }
      }
      expect(count, 234);
      for (final offering in [
        'EEE3150-01',
        'HISG104-01',
        'HLU4013-01',
        'HSS3031-01',
        'HSS3025-01',
      ]) {
        expect(
          courses.singleWhere(
            (c) => '${c['courseCode']}-${c['section']}' == offering,
          )['schedules'],
          isEmpty,
        );
      }
    },
  );

  for (final mode in [
    LectureMode.inPerson,
    LectureMode.liveOnline,
    LectureMode.video,
  ]) {
    test(
      'actual894 classes and20185 original meetings, full Drive ${mode.name}',
      () {
        final values = <String, TimetableSyncValue>{};
        var count = 0;
        for (final course in model.courses.where(
          (c) => c.hasSchedulableMeetings,
        )) {
          final saved = course.toTimetable(id: course.sourceId, mode: mode);
          expect(saved.isValid, true);
          expect(
            TimetableClass.fromJson(saved.toJson()).toJson(),
            saved.toJson(),
          );
          final source = courses.singleWhere(
            (c) => c['sourceId'] == course.sourceId,
          );
          final published = source['schedules'] as List;
          expect(saved.meetings, hasLength(published.length));
          for (var i = 0; i < published.length; i++) {
            final m = saved.meetings[i];
            final raw = published[i];
            expect(m.date, raw['date']);
            expect(m.weekday, raw['weekday']);
            expect(m.originalStartMinute, raw['startMinute']);
            expect(m.originalEndMinute, raw['endMinute']);
            expect(m.classroom, raw['classroom']);
            expect(saved.period!.contains(m.teachingDate!), true);
            if (added.contains(course.codeAndSection)) {
              expect(saved.modeOn(m, m.teachingDate!), mode);
              expect(
                classOccurrences([saved], [m.teachingDate!]),
                hasLength(mode == LectureMode.video ? 0 : 1),
              );
            } else if (raw['deliveryMode'] != null) {
              expect(
                saved.modeOn(m, m.teachingDate!).name,
                raw['deliveryMode'],
              );
            }
            count++;
          }
          final key = timetableCourseSyncKey(saved);
          expect(values.containsKey(key), false);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'research',
          );
        }
        expect(count, 20185);
        expect(values, hasLength(894));
        final doc = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final encoded =
            jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(encoded);
        expect(restored.materializeClasses(), hasLength(894));
        for (final course in restored.materializeClasses()) {
          expect(
            course.toJson(),
            values[timetableCourseSyncKey(course)]!.value,
          );
          expect(course.isValid, true);
        }
      },
    );
  }
}
