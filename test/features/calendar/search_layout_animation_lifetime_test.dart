import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The search layout must own one CurvedAnimation for the State's lifetime:
/// creating it in `build` registers a new status listener on the controller on
/// every rebuild (#175). This runs with `flutter test`, so CI covers it.
void main() {
  final source = File(
    'lib/features/calendar/presentation/month_calendar_page.dart',
  ).readAsStringSync();
  final start = source.indexOf('class _PaintOnlySearchLayoutState');
  final end = source.indexOf('\nclass ', start + 10);
  final state = source.substring(start, end < 0 ? source.length : end);

  test('the CurvedAnimation is created once, in initState', () {
    expect('CurvedAnimation('.allMatches(state), hasLength(1));
    final initState = state.substring(
      state.indexOf('void initState'),
      state.indexOf('void didUpdateWidget'),
    );
    expect(initState, contains('CurvedAnimation('));
  });

  test('it is disposed before its parent controller', () {
    final dispose = state.substring(
      state.indexOf('void dispose'),
      state.indexOf('void _handleAnimationStatus'),
    );
    expect(
      dispose.indexOf('_animation.dispose()'),
      lessThan(dispose.indexOf('_controller.dispose()')),
    );
  });

  test('build never creates animations', () {
    final build = state.substring(state.indexOf('Widget build'));
    expect(build, isNot(contains('CurvedAnimation(')));
    expect(build, isNot(contains('AnimationController(')));
  });
}
