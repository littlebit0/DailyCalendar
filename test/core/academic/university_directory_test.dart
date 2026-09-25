import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/university_directory.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _DirectoryBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    expect(key, 'assets/academic/universities.json');
    final bytes = await File(key).readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late UniversityDirectory directory;

  setUpAll(() async {
    directory = await UniversityDirectory.load(bundle: _DirectoryBundle());
  });

  test('sourced national corpus is complete and uniquely identified', () {
    expect(directory.dataYear, 2026);
    expect(directory.checkedAt, '2026-09-26');
    expect(directory.universities, hasLength(429));
    expect(
      directory.universities.map((school) => school.id).toSet(),
      hasLength(429),
    );
    expect(directory.search('', kind: UniversityKind.fourYear), hasLength(241));
    expect(
      directory.search('', kind: UniversityKind.juniorCollege),
      hasLength(166),
    );
    expect(
      directory.search('', kind: UniversityKind.cyberUniversity),
      hasLength(22),
    );
    final source =
        jsonDecode(File('assets/academic/universities.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(source['sourceCounts'], {
      'academyinfo': 412,
      'careernet': 11,
      'special-universities': 6,
    });
    expect(directory.search('서울대학교'), isNotEmpty);
    expect(directory.search('부산대학교'), isNotEmpty);
    expect(directory.search('제주대학교'), isNotEmpty);
    expect(directory.search('전북대학교'), isNotEmpty);
    expect(directory.search('한국과학기술원'), isNotEmpty);
    expect(directory.search('경찰대학'), isNotEmpty);
    expect(directory.search('육군3사관학교'), isNotEmpty);
    expect(directory.search('백석예술대학교'), isNotEmpty);
    expect(directory.search('세계사이버대학'), isNotEmpty);
    expect(directory.search('포스코기술대학'), hasLength(2));
  });

  test('campus IDs independently enable only supported integrations', () {
    final seoul = directory.byId('academyinfo:0000117')!;
    final cheonan = directory.byId('academyinfo:0002959')!;
    expect(seoul.displayName, '상명대학교 서울캠퍼스');
    expect(cheonan.displayName, '상명대학교 천안캠퍼스');
    expect(seoul.integrationId, 'smu/seoul');
    expect(cheonan.integrationId, 'smu/cheonan');
    expect(
      directory.universities.where((school) => school.supportsSangmyung),
      hasLength(2),
    );
    expect(directory.byId('unknown'), isNull);
    expect(
      const University(
        id: 'other',
        name: '상명대학교',
        kind: UniversityKind.fourYear,
      ).supportsSangmyung,
      isFalse,
    );
  });

  test('all campus identities belong to exactly one explicit institution', () {
    expect(directory.institutions, hasLength(369));
    expect(
      directory.searchInstitutions('', kind: UniversityKind.fourYear),
      hasLength(183),
    );
    expect(
      directory.searchInstitutions('', kind: UniversityKind.juniorCollege),
      isEmpty,
    );
    expect(
      directory.searchInstitutions('', kind: UniversityKind.cyberUniversity),
      isEmpty,
    );
    expect(
      directory.institutions.where((school) => school.campuses.length > 1),
      hasLength(37),
    );
    final campuses = directory.institutions
        .expand((institution) => institution.campuses)
        .toList();
    expect(campuses, hasLength(429));
    expect(campuses.map((campus) => campus.id).toSet(), hasLength(429));
    for (final campus in campuses) {
      final institution = directory.institutionForCampus(campus.id)!;
      expect(institution.id, campus.institutionId);
      expect(institution.name, campus.institutionName);
      expect(institution.kind, campus.kind);
      expect(directory.byId(campus.id), same(campus));
      expect(directory.institutionById(institution.id), same(institution));
    }
    final raw =
        jsonDecode(File('assets/academic/universities.json').readAsStringSync())
            as Map<String, dynamic>;
    final reviewedGroups = raw['institutionGroups'] as List;
    expect(reviewedGroups, hasLength(37));
    for (final group in reviewedGroups.cast<Map>()) {
      final institution = directory.institutionById(group['id'] as String)!;
      expect(institution.name, group['name']);
      expect(
        institution.campuses.map((campus) => campus.id),
        group['campusIds'],
      );
      expect(group['sourceUrls'], isNotEmpty);
    }
    expect(directory.institutionForCampus('unknown'), isNull);
    expect(directory.institutionById('unknown'), isNull);
  });

  test(
    'selection offers only four-year universities and preserves all excluded lookup IDs',
    () {
      final rows = directory.universities;
      expect(rows.where((row) => !row.selectable), hasLength(24));
      expect(directory.searchInstitutions(''), hasLength(183));
      expect(
        directory
            .searchInstitutions('')
            .every((school) => school.kind == UniversityKind.fourYear),
        isTrue,
      );
      for (final row in rows.where((row) => !row.selectable)) {
        expect(directory.byId(row.id), same(row));
        expect(directory.institutionForCampus(row.id), isNotNull);
        expect(
          directory
              .searchInstitutions(row.name)
              .where((school) => school.id == row.institutionId),
          isEmpty,
        );
        expect(
          directory
              .searchInstitutions(row.name, includeUnselectable: true)
              .map((school) => school.id),
          contains(row.institutionId),
        );
      }
      for (final name in [
        '고려사이버대학교',
        '디지털서울문화예술대학교',
        '세계사이버대학',
        '동양미래대학교',
        '서울예술대학교',
        'LH토지주택대학교',
      ]) {
        final school = directory
            .searchInstitutions(name, includeUnselectable: true)
            .singleWhere((school) => school.name == name);
        expect(school.selectable, isFalse);
        expect(directory.institutionById(school.id), same(school));
        expect(
          directory
              .searchInstitutions(name)
              .where((candidate) => candidate.id == school.id),
          isEmpty,
        );
        for (final kind in UniversityKind.values) {
          expect(
            directory
                .searchInstitutions(name, kind: kind)
                .where((candidate) => candidate.id == school.id),
            isEmpty,
          );
        }
      }
      expect(directory.searchInstitutions('경찰대학'), isNotEmpty);
      expect(directory.searchInstitutions('서강대학교'), isNotEmpty);
      expect(
        directory
            .searchInstitutions('가톨릭대학교')
            .where((school) => school.name == '가톨릭대학교'),
        hasLength(1),
      );
    },
  );

  test(
    'only reviewed branches require campus choice and official summaries avoid regional substitutes',
    () {
      expect(
        directory.institutions
            .where((school) => school.campusSelectionRequired)
            .map((school) => school.name)
            .toSet(),
        {'건국대학교', '고려대학교', '동국대학교', '연세대학교', '한양대학교'},
      );
      final expected = {
        '상명대학교': '서울 / 천안',
        '전남대학교': '광주 / 여수',
        '단국대학교': '죽전 / 천안',
        '명지대학교': '자연 / 인문',
        '중앙대학교': '서울 / 다빈치',
        '건양대학교': '글로컬 / 메디컬',
        '연세대학교': '신촌 / 국제 / 미래',
      };
      for (final entry in expected.entries) {
        final school = directory.searchInstitutions(entry.key).single;
        expect(school.campusSummary, entry.value);
        expect(
          school.campusNames.any(
            (name) => RegExp(r'^(본교|제\d캠퍼스)$').hasMatch(name),
          ),
          isFalse,
        );
      }
      expect(directory.byId('academyinfo:0000082')!.campus, '죽전캠퍼스');
      expect(directory.byId('academyinfo:0002726')!.campus, '천안캠퍼스');
      expect(directory.byId('academyinfo:0000149')!.campus, '신촌캠퍼스');
    },
  );

  test('requested universities appear once with accurately named campuses', () {
    final sangmyung = directory.searchInstitutions('상명대학교').single;
    expect(directory.searchInstitutions('ㅅㅁㄷ'), contains(sangmyung));
    expect(sangmyung.id, 'institution:academyinfo:0000117');
    expect(sangmyung.name, '상명대학교');
    expect(sangmyung.campuses.map((campus) => campus.campus), [
      '서울캠퍼스',
      '천안캠퍼스',
    ]);
    expect(directory.search('상명대학교'), hasLength(2));
    expect(directory.searchInstitutions('상명 천안').single, same(sangmyung));
    final chonnam = directory.searchInstitutions('전남대학교').single;
    expect(chonnam.id, 'institution:academyinfo:0000023');
    expect(chonnam.campuses.map((campus) => campus.campus), ['광주캠퍼스', '여수캠퍼스']);
    expect(chonnam.campuses.map((campus) => campus.region), ['광주', '여수']);
    expect(directory.searchInstitutions('ㅈㄴㄷ ㅇㅅ').single, same(chonnam));
    final korea = directory.searchInstitutions('고려대학교').single;
    expect(korea.id, 'institution:academyinfo:0000069');
    expect(korea.campuses.map((campus) => campus.campus), ['서울캠퍼스', '세종캠퍼스']);
    expect(directory.searchInstitutions('고려 안암').single, same(korea));
    expect(directory.searchInstitutions('ㄱㄹㄷ ㅅㅈ').single, same(korea));
    expect(directory.byId('academyinfo:0000070')!.name, '고려대학교(세종)');
    expect(directory.byId('academyinfo:0000070')!.displayName, '고려대학교 세종캠퍼스');
  });

  test(
    'single disclosure rows retain multiple official campus names for display and search',
    () {
      final reviewed = {
        '가천대학교': ['글로벌캠퍼스', '메디컬캠퍼스'],
        '경희대학교': ['서울캠퍼스', '국제캠퍼스', '광릉캠퍼스'],
        '성균관대학교': ['인문사회과학캠퍼스', '자연과학캠퍼스'],
        '한국외국어대학교': ['서울캠퍼스', '글로벌캠퍼스'],
      };
      for (final entry in reviewed.entries) {
        final school = directory
            .searchInstitutions(entry.key)
            .singleWhere((school) => school.name == entry.key);
        expect(school.campuses, hasLength(1));
        expect(school.campusSelectionRequired, isFalse);
        expect(school.campusNames, entry.value);
        expect(
          school.campusSummary,
          entry.value.map((name) => name.replaceFirst('캠퍼스', '')).join(' / '),
        );
        for (final campus in entry.value) {
          expect(directory.searchInstitutions('${entry.key} $campus'), [
            school,
          ]);
          expect(
            directory.searchInstitutions(
              '${hangulInitials(entry.key)} ${hangulInitials(campus)}',
            ),
            [school],
          );
        }
      }
    },
  );

  test(
    'reviewed branch names group without merging similarly named schools',
    () {
      for (final name in [
        '가야대학교',
        '건국대학교',
        '국립목포대학교',
        '국립창원대학교',
        '동국대학교',
        '연세대학교',
        '영산대학교',
        '한양대학교',
      ]) {
        final school = directory.searchInstitutions(name).single;
        expect(school.name, name);
        expect(school.campuses.length, greaterThan(1));
      }
      expect(directory.searchInstitutions('한국폴리텍'), isEmpty);
      expect(
        directory.searchInstitutions('한국폴리텍', includeUnselectable: true),
        hasLength(8),
      );
      expect(directory.searchInstitutions('ICT폴리텍'), isEmpty);
      expect(
        directory
            .searchInstitutions('ICT폴리텍', includeUnselectable: true)
            .single
            .campuses,
        hasLength(1),
      );
      expect(
        directory
            .searchInstitutions('가톨릭대학교')
            .map((school) => school.id)
            .toSet()
            .length,
        greaterThan(1),
      );
      final isolated = UniversityDirectory.fromJson({
        'schemaVersion': 1,
        'dataYear': 2026,
        'checkedAt': '2026-09-25',
        'rowCount': 2,
        'universities': [
          {'id': 'one', 'name': '동명대학교', 'kind': 'fourYear'},
          {'id': 'two', 'name': '동명대학교(다른기관)', 'kind': 'fourYear'},
        ],
      });
      expect(isolated.searchInstitutions('동명대학교'), hasLength(2));
    },
  );

  test(
    'search supports Hangul initials, mixed syllables and campus tokens',
    () {
      for (final query in ['ㅅㅁㄷ', 'ㅅ명대', 'ᄉᄆᄃ', '상명대학교']) {
        expect(
          directory.search(query).map((school) => school.id),
          containsAll(['academyinfo:0000117', 'academyinfo:0002959']),
          reason: query,
        );
      }
      expect(directory.search('ㅅㅁㄷ ㅊㅇ').single.id, 'academyinfo:0002959');
      expect(directory.search('상명 서울').single.id, 'academyinfo:0000117');
      expect(directory.search('  상명   천안  ').single.id, 'academyinfo:0002959');
      expect(directory.search('ict').single.name, 'ICT폴리텍대학');
      expect(directory.search('검색결과없는대학교'), isEmpty);
      expect(matchesUniversityQuery('상명대학교', '서명'), isFalse);
      expect(matchesUniversityQuery('상명대학교', '상 ㄷ'), isFalse);
      expect(hangulInitials('상명대학교 ABC'), 'ㅅㅁㄷㅎㄱ ABC');
    },
  );

  test('school kind uses source grouping instead of name suffix', () {
    expect(directory.search('서울예술대학교', kind: UniversityKind.fourYear), isEmpty);
    expect(
      directory.search('서울예술대학교', kind: UniversityKind.juniorCollege),
      isNotEmpty,
    );
    expect(directory.search('상명', kind: UniversityKind.juniorCollege), isEmpty);
    expect(
      directory.search('한국폴리텍', kind: UniversityKind.juniorCollege),
      hasLength(32),
    );
    expect(directory.search('육군3사관학교').single.kind, UniversityKind.fourYear);
  });

  test('rejects truncated, duplicate and unsupported directory data', () {
    final valid = <String, dynamic>{
      'schemaVersion': 1,
      'dataYear': 2026,
      'checkedAt': '2026-09-25',
      'rowCount': 1,
      'universities': [
        {'id': 'test', 'name': '테스트대학교', 'kind': 'fourYear'},
      ],
    };
    expect(
      () => UniversityDirectory.fromJson({...valid, 'rowCount': 2}),
      throwsFormatException,
    );
    expect(
      () => UniversityDirectory.fromJson({...valid, 'schemaVersion': 3}),
      throwsFormatException,
    );
    expect(
      () => UniversityDirectory.fromJson({
        ...valid,
        'rowCount': 2,
        'universities': [
          ...valid['universities'] as List,
          ...valid['universities'] as List,
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => UniversityDirectory.fromJson({
        ...valid,
        'universities': [
          {'id': 'test', 'name': '테스트대학교', 'kind': 'unknown'},
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => UniversityDirectory.fromJson({
        ...valid,
        'universities': [
          {
            'id': 'test',
            'name': '상명대학교',
            'kind': 'fourYear',
            'integrationId': 'smu/seoul',
          },
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => UniversityDirectory.fromJson({
        ...valid,
        'schemaVersion': 2,
        'institutionCount': 1,
      }),
      throwsFormatException,
    );
    expect(
      () => UniversityDirectory.fromJson({
        ...valid,
        'rowCount': 2,
        'universities': [
          for (final id in ['one', 'two'])
            {
              'id': id,
              'name': id,
              'kind': 'fourYear',
              'institutionId': 'institution:same',
              'institutionName': id,
            },
        ],
      }),
      throwsFormatException,
    );
  });
}
