import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('Release installers publish the notes of the tagged version', () {
    final workflow = source('.github/workflows/release-installers.yml');

    expect(workflow, isNot(contains('body_path: docs/RELEASE_NOTES_4.0.0.md')));
    expect(
      workflow,
      contains(
        r'body_path: docs/RELEASE_NOTES_${{ steps.assets.outputs.version }}.md',
      ),
    );
    expect(workflow, contains(r'docs/RELEASE_NOTES_${version}.md is missing'));
  });

  test('4.1.0 notes ask to update every device for unscheduled courses', () {
    final notes = source('docs/RELEASE_NOTES_4.1.0.md');

    expect(notes, contains('모든 기기를 4.1.0 이상으로 업데이트'));
    expect(notes, contains('일정·설정 복원도 함께 멈춥니다'));
    expect(notes, contains('지우지 않고'));
  });
}
