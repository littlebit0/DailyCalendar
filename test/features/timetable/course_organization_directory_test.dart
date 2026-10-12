import 'package:daily/features/timetable/data/course_organization_directory.dart';
import 'package:daily/features/timetable/domain/course_organization.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _unit(
  String? college,
  String? department,
  String label, {
  String campus = 'main',
  bool opening = false,
}) => {
  'college': college,
  'department': department,
  'sourceLabel': label,
  'campus': campus,
  'isOfferingUnit': opening,
  'sourceUrl': 'https://school.example.edu/public-courses',
  'evidence': 'Synthetic official-row fixture, not acquired school data.',
};

Map<String, dynamic> _course() => {
  'sourceId': 'test/main/course',
  'campus': 'main',
  'academicYear': 2026,
  'semester': '2',
  'courseCode': 'COURSE',
  'courseName': '교차 조회 강좌',
  'section': '1',
  'professor': '',
  'departments': ['심리학과 조회'],
  'departmentCredits': <String, num>{},
  'departmentClassifications': {'심리학과 조회': '교양선택'},
  'scheduleStatus': 'unscheduled',
  'schedules': <dynamic>[],
};

CourseOrganizationDirectory _directory(
  List<Map<String, dynamic>> mappings, {
  List<Map<String, dynamic>> owners = const [],
}) => CourseOrganizationDirectory.fromJson({
  'schemaVersion': 1,
  'university': 'test',
  'mappings': mappings,
  'courseOwners': owners,
});

void main() {
  test('explicit college owner may omit its original department label', () {
    final unit = _unit('사범대학', null, '', opening: true)..['sourceLabel'] = null;
    final applied = _directory(
      [],
      owners: [
        {
          'sourceId': 'test/main/course',
          'units': [unit],
        },
      ],
    ).apply(_course());
    final organizations = applied['offeringOrganizations'] as List;
    expect(organizations.single['college'], '사범대학');
    expect(organizations.single['department'], isNull);
    expect(organizations.single['sourceLabel'], '');
    expect(applied['departments'], ['심리학과 조회']);
  });

  test('published major group never overrides a general-education query', () {
    final raw = _course()
      ..['classification'] = '①수소에너지소재'
      ..['classificationGroup'] = '전공'
      ..['departments'] = ['전공 조회', '교양 조회']
      ..['departmentClassifications'] = {'전공 조회': '①수소에너지소재', '교양 조회': '교양선택'};
    final course = UniversityCourse.fromJson(
      _directory([
        _unit(null, '수소시스템', '전공 조회')..['group'] = '융합전공',
        _unit('공과대학', '컴퓨터공학과', '교양 조회'),
      ]).apply(raw),
    );
    expect(course.isMajorForSourceDepartment('전공 조회'), isTrue);
    expect(course.isMajorForSourceDepartment('교양 조회'), isFalse);
    raw['classificationGroup'] = '';
    expect(
      UniversityCourse.fromJson(raw).isMajorForSourceDepartment('전공 조회'),
      isFalse,
    );
  });

  test('faculty-common native major codes stay school-specific', () {
    for (final school in ['kyonggi', 'koreatech', 'test']) {
      for (final classification in ['학필', '학선']) {
        final raw = _course()
          ..['sourceId'] = '$school/main/course'
          ..['departments'] = ['공식 조회']
          ..['departmentClassifications'] = {'공식 조회': classification};
        final course = UniversityCourse.fromJson(
          _directory([_unit('공과대학', '컴퓨터공학과', '공식 조회')]).apply(raw),
        );
        expect(
          course.isMajorForOrganization(course.offeringOrganizations.single),
          school != 'test',
          reason: '$school $classification',
        );
      }
    }
  });

  test(
    'officially cross-listed program remains selectable from both official system groups',
    () {
      final unit = _unit(null, 'XR스포츠', '공식 조회')
        ..['group'] = '융합전공'
        ..['officialGroups'] = ['융합전공', 'On-Demand 연계·융합전공'];
      final directory = _directory([unit]);
      final raw = _course()
        ..['departments'] = ['공식 조회']
        ..['departmentClassifications'] = {'공식 조회': '전공선택'};
      final course = UniversityCourse.fromJson(directory.apply(raw));
      expect(course.offeringOrganizations.map((u) => u.displayGroup).toSet(), {
        '융합전공',
        'On-Demand 연계·융합전공',
      });
      expect(course.sourceId, raw['sourceId']);
      for (final organization in course.offeringOrganizations) {
        expect(course.matchesOrganization(organization), isTrue);
        expect(course.majorClassificationLabelsForOrganization(organization), [
          '전선',
        ]);
      }
      expect(
        () => _directory([
          unit..['officialGroups'] = ['융합전공', '융합전공'],
        ]),
        throwsFormatException,
      );
      expect(
        () => _directory([unit..['officialGroups'] = '융합전공']),
        throwsFormatException,
      );
    },
  );

  test(
    'official degree and program system share a course without losing either route',
    () {
      final unit = _unit('글로벌융합학부', '데이터사이언스전공', '공식 조회')
        ..['officialGroups'] = ['융합전공'];
      final raw = _course()
        ..['departments'] = ['공식 조회']
        ..['departmentClassifications'] = {'공식 조회': '전공선택'};
      final course = UniversityCourse.fromJson(_directory([unit]).apply(raw));
      expect(course.offeringOrganizations.map((u) => u.displayGroup).toSet(), {
        '글로벌융합학부',
        '융합전공',
      });
      expect(course.offeringOrganizations.first.college, '글로벌융합학부');
      expect(course.offeringOrganizations.last.college, isNull);
      expect(
        course.offeringOrganizations.every(course.matchesOrganization),
        isTrue,
      );
      expect(
        course.offeringOrganizations.every(course.isMajorForOrganization),
        isTrue,
      );
      expect(course.sourceId, raw['sourceId']);
    },
  );

  test(
    'merged affiliation retains every original query classification key',
    () {
      final owner = _unit('공과대학', '컴퓨터공학과', '첫 조회')
        ..['sourceLabels'] = ['첫 조회', '둘째 조회'];
      final directory = _directory(
        [],
        owners: [
          {
            'sourceId': 'test/main/course',
            'units': [owner],
          },
        ],
      );
      final raw = _course()
        ..['departments'] = <String>[]
        ..['departmentClassifications'] = {'첫 조회': '교양선택', '둘째 조회': '전공선택'};
      final course = UniversityCourse.fromJson(directory.apply(raw));
      expect(course.offeringOrganizations.map((u) => u.sourceLabel).toSet(), {
        '첫 조회',
        '둘째 조회',
      });
      expect(
        course.isMajorForOrganization(course.offeringOrganizations.first),
        isTrue,
      );
      expect(
        course.classificationLabelsForOrganization(
          course.offeringOrganizations.first,
        ),
        containsAll(['교선', '전선']),
      );
      expect(
        course.majorClassificationLabelsForOrganization(
          course.offeringOrganizations.first,
        ),
        ['전선'],
      );
    },
  );

  test(
    'department major filters use selected-source classification, never another query row',
    () {
      final directory = _directory([
        _unit('공과대학', '컴퓨터공학과', '컴퓨터 조회'),
        _unit('인문대학', '심리학과', '심리학과 조회'),
      ]);
      final raw = _course()
        ..['departments'] = ['컴퓨터 조회', '심리학과 조회']
        ..['departmentClassifications'] = {'컴퓨터 조회': '전공기초', '심리학과 조회': '교양선택'};
      final course = UniversityCourse.fromJson(directory.apply(raw));
      final computer = course.offeringOrganizations.singleWhere(
        (u) => u.department == '컴퓨터공학과',
      );
      final psychology = course.offeringOrganizations.singleWhere(
        (u) => u.department == '심리학과',
      );
      expect(course.isMajorForOrganization(computer), isTrue);
      expect(course.isMajorForOrganization(psychology), isFalse);
      expect(course.isMajorForSourceDepartment('심리학과 조회'), isFalse);
      expect(course.isMajorForSourceDepartment('컴퓨터 조회'), isTrue);
      expect(UniversityCourse.isMajorClassificationLabel('전선-컴퓨터'), isTrue);
      expect(UniversityCourse.isMajorClassificationLabel('교직전선'), isFalse);
      for (final category in ['교필', '교선', '일반선택', '교직', '미확인']) {
        final other = UniversityCourse.fromJson({
          ...raw,
          'departmentClassifications': {'컴퓨터 조회': category},
          'offeringOrganizations': [_unit('공과대학', '컴퓨터공학과', '컴퓨터 조회')],
        });
        expect(
          other.isMajorForOrganization(other.offeringOrganizations.single),
          isFalse,
          reason: category,
        );
      }
    },
  );

  test(
    'program families and university-direct parents remain separate from colleges',
    () {
      final unit = CourseOrganization.fromJson(
        _unit(null, '시스템반도체설계마이크로전공', '원자료')..['group'] = '마이크로전공',
      );
      expect(unit.displayGroup, '마이크로전공');
      expect(unit.isCollegeHosted, isFalse);
      expect(
        CourseOrganization.fromJson(
          _unit(null, '신에너지마이크로전공', '원자료'),
        ).displayGroup,
        isNull,
      ); // A shared suffix cannot establish affiliation.
      final direct = CourseOrganization.fromJson(
        _unit(null, '초등교육과', '초등교육과')..['group'] = '대학 직속',
      );
      expect(direct.displayGroup, '대학 직속');
      expect(direct.college, isNull);
      final known = CourseOrganization.fromJson(_unit('공과대학', '융합전공', '융합전공'));
      expect(known.displayGroup, '공과대학');
    },
  );

  test(
    'native owner and official query department both match, college does not include child courses',
    () {
      final directory = _directory(
        [
          _unit('인문대학', '심리학과', '심리학과 조회'),
          _unit('인문대학', null, '심리학과 조회'), // College query is not a host.
        ],
        owners: [
          {
            'sourceId': 'test/main/course',
            'units': [_unit('사회과학대학', '행정학과', '행정학과')],
          },
        ],
      );
      final course = UniversityCourse.fromJson(directory.apply(_course()));
      expect(course.offeringOrganizations.length, 2);
      for (final department in ['심리학과', '행정학과']) {
        expect(
          course.offeringOrganizations.any((u) => u.department == department),
          isTrue,
        );
      }
      expect(
        course.offeringOrganizations.any((u) => u.isCollegeHosted),
        isFalse,
      );
      const college = CourseOrganization(
        college: '인문대학',
        department: null,
        sourceLabel: '인문대학',
      );
      expect(course.matchesOrganization(college), isFalse);
      final psychology = course.offeringOrganizations.firstWhere(
        (u) => u.department == '심리학과',
      );
      expect(course.classificationLabelsForOrganization(psychology), ['교선']);
    },
  );

  test(
    'only source-confirmed direct college offerings match a college selection',
    () {
      final raw = _course()..['departments'] = ['공과대학'];
      final directory = _directory([
        _unit('공과대학', null, '공과대학', opening: true),
      ]);
      final course = UniversityCourse.fromJson(directory.apply(raw));
      expect(course.offeringOrganizations.single.isCollegeHosted, isTrue);
      expect(course.offeringOrganizations.single.department, isNull);
    },
  );

  test(
    'an exact course curriculum association is not a direct college host',
    () {
      final directory = _directory(
        [],
        owners: [
          {
            'sourceId': 'test/main/course',
            'units': [
              _unit('공과대학', null, '공과대학 조회'),
              _unit('공과대학', '컴퓨터공학과', '학과별 교육과정'),
            ],
          },
        ],
      );
      final course = UniversityCourse.fromJson(directory.apply(_course()));
      expect(course.offeringOrganizations.single.department, '컴퓨터공학과');
      expect(course.offeringOrganizations.single.isCollegeHosted, isFalse);
    },
  );

  test(
    'a printed college ancestor cannot become college-only through a composite label',
    () {
      final raw = _course()..['departments'] = ['학과 / 단과대 합성 표제'];
      final directory = _directory([
        _unit('인문대학', null, '학과 / 단과대 합성 표제', opening: true)
          ..['collegeOnlyEligible'] = false,
        _unit('인문대학', '국어국문학과', '학과 / 단과대 합성 표제', opening: true),
      ]);
      final course = UniversityCourse.fromJson(directory.apply(raw));
      expect(course.offeringOrganizations.single.department, '국어국문학과');
      expect(course.offeringOrganizations.single.isCollegeHosted, isFalse);
    },
  );

  test(
    'campus affiliation does not leak and missing evidence never invents a college',
    () {
      final directory = _directory([
        _unit('다른 캠퍼스 단과대', '심리학과', '심리학과 조회', campus: 'other'),
      ]);
      final raw = _course();
      final converted = directory.apply(raw);
      expect(converted['offeringOrganizations'], isEmpty);
      expect(converted['departments'], raw['departments']);
      expect(converted['sourceId'], raw['sourceId']);
    },
  );

  test('source-less and duplicate opening identities are rejected', () {
    expect(
      () => _directory([_unit('공과대학', '학과', '학과')..['sourceUrl'] = '']),
      throwsFormatException,
    );
    final owner = {
      'sourceId': 'test/main/course',
      'units': [_unit('공과대학', '학과', '학과')],
    };
    expect(() => _directory([], owners: [owner, owner]), throwsFormatException);
  });
}
