import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';

void main() {
  test(
    'Kumoh native reservations preserve current clock and three modes in full Drive JSON',
    () {
      final originals =
          jsonDecode(
                fixtureFile(
                  'work/university-research/catalog-m/kumoh-current-educational-recheck-20261008.json',
                ).readAsStringSync(),
              )
              as List;
      final native = {for (final r in originals) '${r['SBJCT_CD_DCLSS']}': r};
      final scheduled = <UniversityCourse>[];
      var total = 0, count = 0, night = 0, zero = 0;
      for (final campus in ['yangho', 'unknown']) {
        final raw =
            jsonDecode(
                  fixtureFile(
                    'assets/timetable/kumoh-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final dataset = UniversityDataset.fromJson(raw);
        final rows = raw['courses'] as List;
        expect(raw['researchOnly'], isFalse);
        expect(raw['completionClaim'], isFalse);
        for (var i = 0; i < dataset.courses.length; i++) {
          final c = dataset.courses[i];
          final r = rows[i] as Map;
          final meta = r['metadata'] as Map;
          final original = meta['originalEducationalFields'] as Map;
          total++;
          expect(original, native[meta['nativeIdentity']]);
          expect(c.code, original['SBJCT_CD']);
          expect(c.section, original['DCLSS_NO']);
          expect(c.sourceClassification, original['SBJCT_KND_SE_NM']);
          expect(original['DEPT_SE_NM'], '학부');
          expect(meta['actualAttendanceConfirmed'], isFalse);
          expect(meta['concentratedOperatingPlanVerified'], isFalse);
          if (!c.hasSchedulableMeetings) continue;
          scheduled.add(c);
          expect(campus, anyOf('yangho', 'unknown'));
          expect(original['LSN_OPER_MTHD_NM'], '대면수업');
          expect(meta['currentClosureListMatched'], isFalse);
          for (final m in c.meetings) {
            count++;
            final date = DateTime.parse(m.date!);
            expect(date.weekday, m.weekday);
            expect(date.isBefore(DateTime(2026, 9, 1)), isFalse);
            expect(date.isAfter(DateTime(2026, 12, 7)), isFalse);
            expect([
              '2026-09-24',
              '2026-09-25',
              '2026-10-05',
              '2026-10-09',
            ], isNot(contains(m.date)));
            expect(m.originalEndMinute - m.originalStartMinute, 50);
            if (m.originalStartMinute >= 1080) {
              night++;
              expect([
                1080,
                1135,
                1190,
                1245,
                1300,
              ], contains(m.originalStartMinute));
            }
            if (m.originalStartMinute == 480) zero++;
            expect(
              (r['schedules'] as List).every(
                (dynamic s) => !(s as Map).containsKey('deliveryMode'),
              ),
              isTrue,
            );
          }
        }
      }
      expect(total, 957);
      expect(scheduled, hasLength(929));
      expect(count, 36911);
      expect(night, greaterThan(0));
      expect(zero, greaterThan(0));
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = scheduled
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final document = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(929));
        final before = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          final prior = before[c.sourceId]!;
          expect(c.isValid, isTrue);
          expect(c.defaultMode, mode);
          expect(c.note, prior.note);
          expect(c.note, contains('공개 예약 계획, 실제 등교'));
          expect(c.note, contains('원문 운영방법: 대면수업'));
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            prior.meetings.map((m) => m.toJson()).toList(),
          );
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
