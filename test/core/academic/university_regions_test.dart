import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:daily/core/academic/university_directory.dart';
import 'package:daily/core/academic/university_regions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:daily/features/settings/presentation/university_region_map.dart';

void main() {
  late UniversityRegions regions;
  late UniversityDirectory directory;
  setUpAll(() {
    regions = UniversityRegions.fromJson(
      jsonDecode(
            File('assets/academic/university_regions.json').readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
    directory = UniversityDirectory.fromJson(
      jsonDecode(File('assets/academic/universities.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });
  test(
    'every selectable institution stays accessible with sourced region membership',
    () {
      final expected = directory
          .searchInstitutions('')
          .map((school) => school.id)
          .toSet();
      final actual = regions.regions
          .expand((region) => region.institutionIds)
          .toSet();
      expect(actual, expected);
      for (final region in regions.regions) {
        expect(
          region.institutionIds.length,
          region.institutionIds.toSet().length,
        );
      }
      expect(regions.byId('지역 미확인'), isNull);
      expect(regions.namesFor('institution:careernet:11d7e932cd189d28'), [
        '경기남부',
      ]);
    },
  );
  test(
    'multi region campuses filter independently while sharing one institution',
    () {
      expect(
        regions.namesFor('institution:academyinfo:0000117'),
        containsAll(['서울', '천안아산']),
      );
      expect(
        regions.namesFor('institution:academyinfo:0000082'),
        containsAll(['경기남부', '천안아산']),
      );
      expect(
        regions.namesFor('institution:academyinfo:0000023'),
        containsAll(['광주', '전남']),
      );
      expect(
        regions.namesFor('institution:academyinfo:0000149'),
        containsAll(['서울', '인천', '강원']),
      );
      expect(
        regions.namesFor('institution:academyinfo:0000066'),
        containsAll(['서울', '경기북부', '경기남부']),
      );
      expect(
        regions.includes('institution:academyinfo:0000208', '천안아산'),
        isFalse,
      ); // 호남대 is in 광주, not 천안.
      expect(
        regions.includes('institution:academyinfo:0000211', '천안아산'),
        isTrue,
      );
    },
  );
  test('requested city merges preserve province and north south filters', () {
    for (final city in ['원주', '청주', '경산']) {
      expect(regions.byId(city), isNull);
    }
    expect(regions.regions.length, 19);
    expect(regions.includes('institution:academyinfo:0000194', '경기북부'), isTrue);
    expect(
      regions.includes('institution:academyinfo:0000082', '경기북부'),
      isFalse,
    );
    expect(regions.byId('천안아산')!.rings.length, greaterThanOrEqualTo(3));
    expect(regions.byId('경기북부')!.rings, isNotEmpty);
  });
  test(
    'school marks are bundled except explicitly unavailable Jungseok original',
    () async {
      final sources =
          jsonDecode(
                File(
                  'assets/academic/university_logo_sources.json',
                ).readAsStringSync(),
              )
              as Map;
      final logos = sources['logos'] as Map;
      expect(
        logos.keys.toSet(),
        directory.searchInstitutions('').map((s) => s.id).toSet(),
      );
      for (final school in directory.searchInstitutions('')) {
        final entry = logos[school.id] as Map;
        if (regions.logoUnavailableInstitutionIds.contains(school.id)) {
          expect(entry['status'], 'unavailable');
          expect(entry.containsKey('asset'), isFalse);
          expect(
            File(
              'assets/academic/logos/${school.id.replaceAll(':', '-')}.png',
            ).existsSync(),
            isFalse,
          );
          continue;
        }
        expect(entry['presentation'], isNotEmpty);
        final bytes = File(entry['asset'] as String).readAsBytesSync();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(8), reason: school.name);
        expect(frame.image.height, greaterThan(8), reason: school.name);
        frame.image.dispose();
        codec.dispose();
      }
    },
  );
  test(
    'map fills available bounds without preserving offshore travel distance',
    () {
      final projection = UniversityMapProjection(const Size(600, 650));
      expect(projection.scale, greaterThan(100));
      for (final ring in [
        ...regions.outlines,
        ...regions.islands.values.expand((rings) => rings),
      ]) {
        for (final position in projection.projectRing(ring)) {
          expect(position.dx, inInclusiveRange(0, 600));
          expect(position.dy, inInclusiveRange(0, 650));
        }
      }
      final island = projection.project(regions.islands['독도']!.first.first);
      final coast = projection.project(const Offset(129.5, 37.3));
      expect((island - coast).distance, lessThan(50));
    },
  );
  test(
    'western island translation preserves each ring shape and reduces sea width',
    () {
      final projection = UniversityMapProjection(const Size(380, 650));
      final farRing = regions.outlines.firstWhere(
        (ring) => ring.every((p) => p.dx < 125),
      );
      final projected = projection.projectRing(farRing);
      expect(projected.first.dx, greaterThanOrEqualTo(6));
      for (var i = 1; i < farRing.length; i++) {
        final delta = farRing[i] - farRing[0];
        expect(
          (projected[i] - projected[0]).distance,
          closeTo(
            Offset(
                  delta.dx * UniversityMapProjection.longitudeFactor,
                  delta.dy,
                ).distance *
                projection.scale,
            .0001,
          ),
        );
      }
      expect(UniversityMapProjection.aspectRatio, lessThan(.65));
      expect(regions.logoUnavailableInstitutionIds, {
        'institution:academyinfo:0000288',
      });
    },
  );
  test(
    'branch campus matching uses sourced locations and existing region groups',
    () {
      const expected = {
        'academyinfo:0000052': ['서울'],
        'academyinfo:0000053': ['충북'],
        'academyinfo:0000069': ['서울'],
        'academyinfo:0000070': ['세종'],
        'academyinfo:0000100': ['서울'],
        'academyinfo:0000101': ['경북'],
        'academyinfo:0000149': ['서울', '인천'],
        'academyinfo:0000150': ['강원'],
        'academyinfo:0000203': ['서울'],
        'academyinfo:0000204': ['경기남부'],
      };
      for (final entry in expected.entries) {
        expect(regions.campusRegionIds[entry.key], entry.value.toSet());
      }
      expect(regions.includesCampus('academyinfo:0000070', '서울'), isFalse);
      expect(regions.includesCampus('unknown-campus', '서울'), isFalse);
      final changwon = directory.searchInstitutions('국립창원대학교').single;
      expect(
        changwon.campuses
            .where((c) => regions.includesCampus(c.id, '경남'))
            .length,
        3,
      );
    },
  );
  test(
    'captions separate precise single campus locations from campus names',
    () {
      expect(
        regions.captionFor('institution:academyinfo:0000008'),
        '공주 / 천안 / 예산',
      );
      expect(
        regions.captionFor('institution:careernet:11d7e932cd189d28'),
        '경기 용인 / 경기 수원',
      );
      final kangnam = directory.searchInstitutions('강남대학교').single;
      expect(regions.captionFor(kangnam.id), '경기 용인');
      expect(
        regions.institutionCaptions.values.any((s) => s.contains('소재지')),
        isFalse,
      );
    },
  );
  test(
    'map labels stay on geographic anchors and islands keep mainland scale',
    () {
      for (final size in [const Size(320, 300), const Size(600, 650)]) {
        final projection = UniversityMapProjection(size);
        for (final region in regions.regions) {
          final rect = regionButtonRect(region, projection);
          expect(
            (rect.center - projection.project(region.anchor)).distance,
            closeTo(0, .0001),
          );
          expect(rect.height, lessThanOrEqualTo(24));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
        }
        final a = projection.project(const Offset(127, 36));
        final b = projection.project(const Offset(127, 37));
        expect((b - a).distance, closeTo(projection.scale, .0001));
        for (final rings in regions.islands.values) {
          for (final ring in rings) {
            final delta = ring[1] - ring[0];
            final projected =
                projection.project(ring[1]) - projection.project(ring[0]);
            expect(
              projected.distance,
              closeTo(
                Offset(
                      delta.dx * UniversityMapProjection.longitudeFactor,
                      delta.dy,
                    ).distance *
                    projection.scale,
                .0001,
              ),
            );
          }
        }
      }
    },
  );
  test(
    'Ulleungdo and both Dokdo outlines are present, not substituted with dots',
    () {
      expect(regions.islands['울릉도']!.single.length, greaterThan(10));
      expect(regions.islands['독도']!.length, 2);
      for (final ring in regions.islands['독도']!) {
        expect(ring.length, greaterThan(10));
        expect(ring.every((p) => p.dx > 131.8 && p.dy > 37), isTrue);
      }
      expect(regions.byId('광주')!.rings, isNotEmpty);
      expect(regions.byId('전남')!.rings, isNotEmpty);
    },
  );
}
