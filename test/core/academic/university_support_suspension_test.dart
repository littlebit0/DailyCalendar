import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/university_support_policy.dart';
import 'package:daily/features/timetable/data/timetable_store.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/presentation/university_course_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'suspension preserves school identity, academic calendar and profile',
    () {
      const profile = AcademicProfile(
        universityId: 'academyinfo:0000164',
        universityName: '인제대학교',
        schoolKind: 'fourYear',
      );
      expect(profile.timetableUniversity, 'inje');
      expect(profile.timetableSupported, isFalse);
      expect(profile.academicSourceId, 'inje');
      expect(
        AcademicProfile.fromJson(profile.toJson()).toJson(),
        profile.toJson(),
      );
      expect(UniversitySupportPolicy.timetableAvailable('smu'), isTrue);
    },
  );

  testWidgets('suspended search never reads or adds a partial catalog', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = TimetableStore(preferences);
    addTearDown(store.dispose);
    await store.save(
      TimetableClass(
        id: 'existing-inje-course',
        title: '기존 저장 수업',
        academicYear: 2026,
        semester: '2',
        colorValue: 0xff123456,
        sourceType: 'university',
        sourceId: 'inje-original-course',
        meetings: [
          ClassMeeting(
            id: 'meeting',
            weekday: 1,
            startMinute: 540,
            endMinute: 600,
          ),
        ],
      ),
    );
    final before = preferences.getString(TimetableStore.storageKey);
    var loaded = false;
    var added = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UniversityCoursePanel(
            university: 'inje',
            store: store,
            loadCatalog: () async {
              loaded = true;
              return [];
            },
            onAdd: (_, _) async {
              added = true;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('해당 대학의 학교 시간표는 현재 미지원입니다.'), findsOneWidget);
    expect(loaded, isFalse);
    expect(added, isFalse);
    expect(store.classes.single.id, 'existing-inje-course');
    expect(preferences.getString(TimetableStore.storageKey), before);
  });
}
