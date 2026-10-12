// Historical frozen-source packet regression. Latest packaged sources are
// checked by packaged_asset_source_integrity_test and resumed_batch_changed_courses_test.
import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const root =
    'work/university-research/catalog-c/hanyang-native-clock-room-only-v4-20261009/';
Map<String, dynamic> read(String path) {
  final actual = path;
  final data =
      jsonDecode(File(actual).readAsStringSync()) as Map<String, dynamic>;
  if (data['courses'] is List) {
    data['researchOnly'] = false;
    data['productionIntegrationEnabled'] = true;
    data['completionClaim'] = false;
    data['wholeOperatingVerified'] = false;
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
    '36 own exact HH nativecampus and roomonly gates; no remote, intensive or ambiguous source activation',
    () {
      final proofs =
          jsonDecode(
                File(
                  '${root}independent36-native-clock-room-proof.json',
                ).readAsStringSync(),
              )
              as List;
      expect(proofs, hasLength(36));
      final ids = {for (final p in proofs) p['sourceId']};
      final policy = read('${root}own-calendar-scope.json');
      expect(
        policy,
        read(
          'work/university-research/catalog-c/hanyang-ordinary-source-semantic-v2-20261009/hanyang-current-policy-education-receipt-20261008.json',
        ),
      );
      expect(policy['termStartDate'], '2026-09-01');
      expect(policy['termEndDate'], '2026-12-21');
      expect(policy['examDatesOrWeeksGenerated'], false);
      var added = 0, total = 0;
      for (final campus in ['seoul', 'erica']) {
        final old = read('${root}hanyang-$campus-baseline.json');
        final now = read(
          '${root}hanyang-$campus-2026-2.native-clock-room-only-v4.json',
        );
        final before = {for (final c in old['courses']) c['sourceId']: c};
        for (final c in now['courses']) {
          total++;
          final b = before[c['sourceId']];
          expect(
            c['metadata']['originalEducationalRecord'],
            b['metadata']['originalEducationalRecord'],
          );
          if (!ids.contains(c['sourceId'])) {
            expect(c, b);
            continue;
          }
          added++;
          final p = proofs.singleWhere((p) => p['sourceId'] == c['sourceId']);
          p['baselineRow']['metadata']['researchOnly'] = false;
          expect(p['baselineRow'], b);
          expect(b['schedules'], isEmpty);
          final restored = Map<String, dynamic>.from(c);
          for (final key in [
            'schedules',
            'scheduleStatus',
            'period',
            'remarks',
            'departmentRemarks',
          ]) {
            restored[key] = b[key];
          }
          restored['metadata'] = Map<String, dynamic>.from(c['metadata']);
          restored['metadata']['reservationProjection'] =
              b['metadata']['reservationProjection'];
          expect(restored, b);
          for (final a in p['nativeAliases']) {
            expect(a['campusNm'], campus == 'seoul' ? '서울' : 'ERICA');
            expect(a['suupOprNm'], '일반');
            expect(a['suupUnitCnt'], 16);
            expect(a['suupViewtypeNm'] == '원격', false);
            expect(a['jipjungGanguiYn'], anyOf(equals('0'), isNull));
            expect(a['suupTimes'], c['sourceSchedule']);
          }
          final parts = RegExp(
            r'([월화수목금토일])\((\d\d):(\d\d)-(\d\d):(\d\d)\)',
          ).allMatches(c['sourceSchedule']).toList();
          final rooms = (c['sourceClassroom'] as String).split(',');
          expect(parts.length, rooms.length);
          for (var i = 0; i < parts.length; i++) {
            final part = parts[i];
            final weekday = '월화수목금토일'.indexOf(part[1]!) + 1;
            final start = int.parse(part[2]!) * 60 + int.parse(part[3]!);
            final end = int.parse(part[4]!) * 60 + int.parse(part[5]!);
            final room = rooms[i].trim().startsWith('비지정(')
                ? ''
                : rooms[i].trim();
            final matching = (c['schedules'] as List)
                .where(
                  (m) =>
                      m['weekday'] == weekday &&
                      m['startMinute'] == start &&
                      m['endMinute'] == end &&
                      m['classroom'] == room,
                )
                .toList();
            expect(matching, isNotEmpty);
            final expected = <String>[];
            for (
              var day = DateTime(2026, 9, 1);
              !day.isAfter(DateTime(2026, 12, 21));
              day = day.add(const Duration(days: 1))
            ) {
              final date = timetableDateKey(day);
              if (day.weekday == weekday &&
                  !(policy['conservativelyHeldNationalHolidayDates'] as List)
                      .contains(date)) {
                expected.add(date);
              }
            }
            expect(matching.map((m) => m['date']).toList(), expected);
          }
          for (final m in c['schedules']) {
            expect(m['deliveryMode'], null);
            expect(m['date'].compareTo('2026-09-01') >= 0, true);
            expect(m['date'].compareTo('2026-12-21') <= 0, true);
          }
        }
      }
      expect(total, 4961);
      expect(added, 36);
      final seoul = read(
        '${root}hanyang-seoul-2026-2.native-clock-room-only-v4.json',
      );
      for (final id in ['11139', '15070', '15071', '15072', '15073', '11311']) {
        expect(
          seoul['courses'].singleWhere(
            (c) => c['sourceId'] == 'hanyang/seoul/2026-2/$id',
          )['schedules'],
          isEmpty,
        );
      }
    },
  );
  test(
    'all3491 wholethree-modeDrive and original campus/course identity retained',
    () {
      final all = [
        for (final campus in ['seoul', 'erica'])
          ...UniversityDataset.fromJson(
            read(
              '${root}hanyang-$campus-2026-2.native-clock-room-only-v4.json',
            ),
          ).courses,
      ];
      expect(all, hasLength(4961));
      final scheduled = all.where((c) => c.hasSchedulableMeetings).toList();
      expect(scheduled, hasLength(3491));
      expect(scheduled.expand((c) => c.meetings).length, 84687);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final records = <String, TimetableSyncValue>{};
        for (final c in scheduled) {
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
