import '../../support/source_fixture.dart';
import 'dart:convert';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Files extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      fixtureFile(key).readAsStringSync();
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(fixtureFile(key).readAsBytesSync());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('CNU keeps all current offerings and source dated attendance on restore', () async {
    final data = await UniversityCatalog.load(
      bundle: _Files(),
      university: 'cnu',
    );
    final courses = data.expand((d) => d.courses).toList();
    final ordinaryAudit =
        jsonDecode(
              fixtureFile(
                'work/university-research/catalog-c/cnu-ordinary-reservation-v1-20261008/candidate-audit.json',
              ).readAsStringSync(),
            )
            as Map;
    final latestOrdinaryAudit =
        jsonDecode(
              fixtureFile(
                'work/university-research/catalog-c/cnu-ordinary-reservation-v2-20261008/candidate-audit.json',
              ).readAsStringSync(),
            )
            as Map;
    final ordinaryIds = [
      ...ordinaryAudit['proofs'] as List,
      ...latestOrdinaryAudit['proofs'] as List,
      ...(jsonDecode(
            fixtureFile(
              'work/university-research/catalog-c/cnu-ordinary-reservation-v3-20261009/candidate-audit.json',
            ).readAsStringSync(),
          )['proofs']
          as List),
      for (final revision in [
        'v4',
        'v5',
        'v6',
        'v7',
        'v8',
        'v9',
        'v10',
        'v11',
        'v12',
      ])
        ...(jsonDecode(
              fixtureFile(
                'work/university-research/catalog-c/cnu-native-topic-versus-operation-$revision-20261009/candidate-audit.json',
              ).readAsStringSync(),
            )['proofs']
            as List),
      for (final revision in ['v14', 'v15', 'v16', 'v17'])
        ...(jsonDecode(
              fixtureFile(
                'work/university-research/catalog-c/cnu-full-context-review-packet-$revision-20261009/candidate-audit.json',
              ).readAsStringSync(),
            )['proofs']
            as List),
      for (final revision in ['v18', 'v19', 'v20', 'v21', 'v22'])
        ...(jsonDecode(
              fixtureFile(
                'work/university-research/catalog-c/cnu-full-context-review-packet-$revision-20261009/${revision == 'v21' || revision == 'v22' ? 'independent-native-topic-clock-proof' : 'candidate-audit'}.json',
              ).readAsStringSync(),
            )['proofs']
            as List),
      for (final revision in ['v23', 'v24'])
        ...(jsonDecode(
              fixtureFile(
                'work/university-research/catalog-c/cnu-pending-operation-context-review-$revision-20261009/candidate-audit.json',
              ).readAsStringSync(),
            )['proofs']
            as List),
    ].map((p) => p['sourceId']).toSet();
    final publishedLiveIds = {
      for (final revision in ['v23', 'v24'])
        for (final proof
            in jsonDecode(
                  fixtureFile(
                    'work/university-research/catalog-c/cnu-pending-operation-context-review-$revision-20261009/candidate-audit.json',
                  ).readAsStringSync(),
                )['proofs']
                as List)
          if (proof['publishedDeliveryMode'] == 'liveOnline') proof['sourceId'],
    };
    expect(publishedLiveIds, hasLength(4));
    expect(
      ordinaryIds.difference(courses.map((c) => c.sourceId).toSet()),
      isEmpty,
    );
    expect(courses.map((c) => c.sourceId).toSet(), hasLength(3888));
    expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(2022));
    expect(
      courses.where((c) => c.scheduleStatus == 'unscheduled'),
      hasLength(635),
    );
    expect(
      courses.where((c) => c.scheduleStatus == 'unrecognized'),
      hasLength(1231),
    );
    expect(
      courses.where((c) => c.remarks.contains('현재 폐강된 강좌')),
      hasLength(142),
    );
    expect(courses.expand((c) => c.meetings), hasLength(49494));
    for (final id in [
      '1372-2007-00',
      '1372-3004-00',
      '1372-3006-00',
      '1101-7019-04',
      '1101-7019-51',
      '1101-7019-55',
    ]) {
      final field = courses.singleWhere((c) => c.codeAndSection == id);
      expect(field.hasSchedulableMeetings, isFalse);
      expect(field.meetings, isEmpty);
      expect(field.sourceSchedule, isNotEmpty);
    }
    final firstNormal = courses.singleWhere(
      (c) => c.codeAndSection == '1109-1003-00',
    );
    final normalSaved = firstNormal.toTimetable(
      id: firstNormal.sourceId,
      mode: LectureMode.video,
    );
    final normalRestored = TimetableClass.fromJson(normalSaved.toJson());
    expect(normalRestored.meetings, hasLength(1));
    expect(normalRestored.meetings.single.date, '2026-09-01');
    expect(normalRestored.meetings.single.originalStartMinute, 840);
    expect(normalRestored.meetings.single.originalEndMinute, 900);
    expect(normalRestored.meetings.single.classroom, '인0236');
    expect(
      normalRestored.modeOn(
        normalRestored.meetings.single,
        DateTime(2026, 9, 1),
      ),
      LectureMode.inPerson,
    );
    expect(
      classOccurrences(
        [normalRestored],
        [DateTime(2026, 9, 3), DateTime(2026, 9, 8)],
      ),
      isEmpty,
    );
    final openingLive = courses.singleWhere(
      (c) => c.codeAndSection == '1004-7005-01',
    );
    final openingSaved = openingLive.toTimetable(
      id: openingLive.sourceId,
      mode: LectureMode.inPerson,
    );
    final openingRestored = TimetableClass.fromJson(openingSaved.toJson());
    expect(openingRestored.meetings, hasLength(1));
    expect(openingRestored.meetings.single.date, '2026-09-01');
    expect(openingRestored.meetings.single.originalStartMinute, 600);
    expect(openingRestored.meetings.single.originalEndMinute, 720);
    expect(openingRestored.meetings.single.classroom, isEmpty);
    expect(
      openingRestored.modeOn(
        openingRestored.meetings.single,
        DateTime(2026, 9, 1),
      ),
      LectureMode.liveOnline,
    );
    expect(
      classOccurrences(
        [openingRestored],
        [DateTime(2026, 9, 4), DateTime(2026, 9, 8), DateTime(2026, 12, 17)],
      ),
      isEmpty,
    );
    expect(openingLive.remarks, contains('일반 수업 날짜 확인 중'));
    final firstDay = courses.singleWhere(
      (c) => c.codeAndSection == '1293-1002-00',
    );
    expect(firstDay.meetings, hasLength(1));
    expect(firstDay.meetings.single.date, '2026-09-01');
    expect(firstDay.meetings.single.originalStartMinute, 600);
    expect(firstDay.meetings.single.originalEndMinute, 660);
    expect(firstDay.meetings.single.classroom, '생120');
    expect(firstDay.remarks, contains('9월 1일'));
    expect(
      classOccurrences(
        [
          firstDay.toTimetable(
            id: firstDay.sourceId,
            mode: LectureMode.inPerson,
          ),
        ],
        [DateTime(2026, 9, 7), DateTime(2026, 9, 8)],
      ),
      isEmpty,
    );
    for (final section in ['06', '08']) {
      final c = courses.singleWhere(
        (c) => c.codeAndSection == '1004-7003-$section',
      );
      expect(c.meetings.map((m) => m.date).toSet(), {
        '2026-10-22',
        '2026-12-17',
      });
      expect(c.remarks, contains('일반 수업 날짜 확인 중'));
      expect(c.meetings, hasLength(2));
    }
    final rawCourses = <String, Map>{
      for (final campus in ['unknown', 'daedeok'])
        for (final row
            in jsonDecode(
                  fixtureFile(
                    'assets/timetable/cnu-$campus-2026-2.json',
                  ).readAsStringSync(),
                )['courses']
                as List)
          row['sourceId'] as String: row as Map,
    };
    for (final c in courses) {
      expect(c.sourceClassification, isNotEmpty);
      if (!c.hasSchedulableMeetings) {
        expect(c.meetings, isEmpty);
        continue;
      }
      final saved = c.toTimetable(id: c.sourceId, mode: LectureMode.video);
      final restored = TimetableClass.fromJson(saved.toJson());
      expect(restored.isValid, isTrue);
      expect(restored.period?.toJson(), saved.period?.toJson());
      expect(
        restored.meetings.map((m) => m.toJson()).toList(),
        saved.meetings.map((m) => m.toJson()).toList(),
      );
      for (final m in restored.meetings) {
        expect(m.date, isNotNull);
        expect(m.teachingDate!.weekday, m.weekday);
        final sourceSession = (rawCourses[c.sourceId]!['schedules'] as List)
            .singleWhere(
              (s) =>
                  s['date'] == m.date &&
                  s['weekday'] == m.weekday &&
                  s['startMinute'] == m.originalStartMinute &&
                  s['endMinute'] == m.originalEndMinute &&
                  (s['classroom'] ?? '') == m.classroom,
            );
        expect(
          restored.modeOn(m, m.teachingDate!),
          sourceSession['deliveryMode'] == null
              ? LectureMode.video
              : LectureMode.values.byName(
                  sourceSession['deliveryMode'] as String,
                ),
        );
      }
      expect(
        classOccurrences(
          [restored],
          [
            DateTime(2026, 8, 31),
            DateTime(2026, 9, 24),
            DateTime(2026, 9, 25),
            DateTime(2026, 10, 5),
            DateTime(2026, 10, 9),
            DateTime(2026, 12, 21),
            DateTime(2027, 1, 1),
          ],
        ),
        isEmpty,
      );
    }
    final nested = courses.singleWhere(
      (c) => c.codeAndSection == '1159-7007-00',
    );
    expect(nested.sourceClassroom, '체109(경기장)-01');
    final first = courses.singleWhere(
      (c) => c.codeAndSection == '1001-7041-00',
    );
    expect(first.campus, 'daedeok');
    expect(
      classOccurrences(
        [first.toTimetable(id: 'first', mode: LectureMode.inPerson)],
        [DateTime(2026, 12, 9)],
      ),
      isEmpty,
    );
    final urban = courses.singleWhere(
      (c) => c.codeAndSection == '1138-3006-00',
    );
    expect(urban.campus, 'unknown');
    expect(urban.categoriesFor(), [CourseCategory.advancedMajor]);
    final chinese = courses.singleWhere(
      (c) => c.codeAndSection == '1105-3022-00',
    );
    final makeup = chinese.meetings
        .where((m) => m.date == '2026-12-09' || m.date == '2026-12-11')
        .toList();
    expect(makeup, hasLength(2));
    expect(makeup.every((m) => m.classroom.isEmpty), isTrue);
    expect(
      makeup.every((m) => m.originalEndMinute - m.originalStartMinute == 75),
      isTrue,
    );
  });
  test(
    'CNU profile rejects foreign campuses and retains the semester outer boundary',
    () async {
      for (final id in [
        'academyinfo:0000029',
        'institution:academyinfo:0000029',
      ]) {
        final profile = AcademicProfile(
          universityId: id,
          universityName: '충남대학교',
          schoolKind: 'fourYear',
          campus: '',
        );
        expect(profile.timetableUniversity, 'cnu');
        expect(profile.timetableCampus, 'unknown');
      }
      final foreign = AcademicProfile(
        universityId: 'academyinfo:0000029',
        universityName: '충남대학교',
        schoolKind: 'fourYear',
        campus: '',
        campusId: 'academyinfo:0000133',
      );
      expect(foreign.timetableSupported, isFalse);
      final defaults = await TimetablePeriodDefaults.load(bundle: _Files());
      final period = defaults.periodFor(2026, '2', university: 'cnu');
      expect(period?.start, DateTime(2026, 9, 1));
      expect(period?.end, DateTime(2026, 12, 20));
    },
  );
}
