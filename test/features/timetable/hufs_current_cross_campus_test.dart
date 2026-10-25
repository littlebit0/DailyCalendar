import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const root =
    'work/university-research/catalog-t/hufs-fixed-time-cross-campus-v8-20261009/';
Map<String, dynamic> read(String path) {
  final actual = path;
  final data =
      jsonDecode(fixtureFile(actual).readAsStringSync())
          as Map<String, dynamic>;
  if (data['courses'] is List) {
    data['researchOnly'] = false;
    for (final c in data['courses']) {
      if (c['metadata']?.containsKey('researchOnly') == true) {
        c['metadata']['researchOnly'] = false;
      }
    }
  }
  return data;
}

void main() {
  test(
    'four literal weekly synchronous cross-campus clocks, all old2425 unchanged',
    () {
      final proofs =
          jsonDecode(
                fixtureFile(
                  '${root}independent4-cross-campus-source-proof.json',
                ).readAsStringSync(),
              )
              as List;
      expect(proofs, hasLength(4));
      final ids = {for (final p in proofs) p['sourceId']};
      var total = 0, scheduled = 0, dates = 0, added = 0;
      for (final campus in ['seoul', 'global']) {
        final old = read('${root}hufs-$campus-baseline-v7.json');
        final raw = read(
          '${root}hufs-$campus-2026-2.fixed-time-cross-campus-v8.json',
        );
        final before = {for (final c in old['courses']) c['sourceId']: c};
        final all = UniversityDataset.fromJson(raw).courses;
        for (final c in raw['courses']) {
          total++;
          final b = before[c['sourceId']];
          if (!ids.contains(c['sourceId'])) {
            expect(c, b);
            continue;
          }
          added++;
          expect(b['schedules'], isEmpty);
          final p = proofs.singleWhere((p) => p['sourceId'] == c['sourceId']);
          final plan = read(p['sourcePlanPath'] as String);
          expect(plan, p['educationPlan']);
          expect(
            sha256
                .convert(
                  fixtureFile(p['sourcePlanPath'] as String).readAsBytesSync(),
                )
                .toString(),
            p['sourcePlanSHA256'],
          );
          expect(
            plan['fields']['methods'],
            contains('대면 수업이 없는 캠퍼스는 실시간 온라인으로 참여'),
          );
          expect(
            plan['fields']['schedule'].split('\n').first,
            c['sourceSchedule'],
          );
          final reconstructed = Map<String, dynamic>.from(c);
          for (final field in [
            'schedules',
            'scheduleStatus',
            'departmentRemarks',
          ]) {
            reconstructed[field] = b[field];
          }
          expect(reconstructed, b);
          expect(c['schedules'], p['reservations']);
          expect(c['schedules'], hasLength(12));
          expect(p['userModeForced'], false);
          expect(p['perCampusDeliveryDatesKnown'], false);
          final course = all.singleWhere((v) => v.sourceId == c['sourceId']);
          for (final m in course.meetings) {
            expect(m.weekday, 1);
            expect(m.originalStartMinute, anyOf(720, 900));
            expect(m.originalEndMinute - m.originalStartMinute, 170);
            expect(m.classroom, campus == 'seoul' ? '2508' : '5208');
            expect(m.date == '2026-10-05' || m.date == '2026-10-26', false);
          }
        }
        scheduled += all.where((c) => c.hasSchedulableMeetings).length;
        dates += all.expand((c) => c.meetings).length;
      }
      expect(total, 3372);
      expect(added, 4);
      expect(scheduled, 2429);
      expect(dates, 35105);
    },
  );
  test(
    'all2429 wholethree modeDrive, distinct campus and exact native reservation preserved',
    () {
      final all = [
        for (final campus in ['seoul', 'global'])
          ...UniversityDataset.fromJson(
            read('${root}hufs-$campus-2026-2.fixed-time-cross-campus-v8.json'),
          ).courses,
      ].where((c) => c.hasSchedulableMeetings);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final records = <String, TimetableSyncValue>{};
        for (final c in all) {
          final t = c.toTimetable(id: c.sourceId, mode: mode);
          expect(t.isValid, true);
          expect(t.defaultMode, mode);
          expect(TimetableClass.fromJson(t.toJson()).toJson(), t.toJson());
          final key = timetableCourseSyncKey(t);
          expect(records.containsKey(key), false);
          records[key] = TimetableSyncValue(
            {...t.toJson(), 'id': key},
            DateTime.utc(2026, 10, 9),
            'research',
          );
        }
        expect(records, hasLength(2429));
        final doc = TimetableSyncDocument.records(courses: records);
        expect(
          TimetableSyncDocument.fromJson(
            jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
          ).toJson(),
          doc.toJson(),
        );
      }
    },
  );
}
