import 'package:daily/core/academic/academic_source.dart';
import 'package:daily/core/academic/academic_source_registry.dart';
import 'package:flutter_test/flutter_test.dart';

AcademicSource _unused() => throw StateError('not created');

const _main = AcademicSourceRegistration(
  id: 'school',
  institutionId: 'academyinfo:0000028',
  campusIds: {'academyinfo:0000028'},
  create: _unused,
);
const _branch = AcademicSourceRegistration(
  id: 'school-branch',
  institutionId: 'academyinfo:0000028',
  campusIds: {'academyinfo:0003297'},
  create: _unused,
  primary: false,
);
const _registrations = [_main, _branch];

String? _resolve(String universityId, [String? campusId]) =>
    academicSourceIdFor(universityId, campusId, registrations: _registrations);

void main() {
  test('institution without campus uses only the primary adapter', () {
    expect(_resolve('institution:academyinfo:0000028'), 'school');
  });

  test('selected or legacy campus picks that campus adapter', () {
    expect(
      _resolve('institution:academyinfo:0000028', 'academyinfo:0003297'),
      'school-branch',
    );
    expect(_resolve('academyinfo:0003297'), 'school-branch');
    expect(_resolve('academyinfo:0000028'), 'school');
  });

  test('unserved campus and other schools never borrow an adapter', () {
    expect(
      _resolve('institution:academyinfo:0000028', 'academyinfo:0003298'),
      isNull,
    );
    expect(_resolve('institution:academyinfo:0000117'), isNull);
    expect(
      _resolve('institution:academyinfo:0000117', 'academyinfo:0000028'),
      isNull,
    );
  });

  test('registration IDs are unique', () {
    final ids = academicSourceRegistrations.map((r) => r.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });
}
