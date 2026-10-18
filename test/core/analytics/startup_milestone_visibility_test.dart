import 'dart:io';

import 'package:daily/core/analytics/product_analytics.dart';
import 'package:daily/core/analytics/startup_milestones.dart';
import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/diagnostics/startup_timing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recording extends NoopProductAnalytics {
  final records = <AnalyticsRecord>[];
  @override
  Future<void> record(AnalyticsRecord record) async => records.add(record);
}

/// Stands in for the calendar page: reports its first frame when it mounts.
class _Calendar extends ConsumerStatefulWidget {
  const _Calendar();
  @override
  ConsumerState<_Calendar> createState() => _CalendarState();
}

class _CalendarState extends ConsumerState<_Calendar> {
  @override
  void initState() {
    super.initState();
    recordFirstCalendarFrame(context, ref);
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 10, height: 10);
}

void main() {
  late _Recording analytics;
  setUp(() {
    StartupTiming.resetClaims();
    analytics = _Recording();
  });
  tearDown(StartupTiming.resetClaims);

  Widget app(Widget home) => ProviderScope(
    overrides: [productAnalyticsProvider.overrideWithValue(analytics)],
    child: MaterialApp(home: home),
  );

  List<String> milestones() => [
    for (final record in analytics.records)
      if (record.name == AnalyticsEventName.startupMilestone)
        record.attributes['milestone']! as String,
  ];

  testWidgets('the milestone is measured when the calendar itself mounts', (
    tester,
  ) async {
    var showCalendar = false;
    late StateSetter update;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            // A loading / announcement screen stands in front of the calendar.
            return showCalendar ? const _Calendar() : const Text('loading');
          },
        ),
      ),
    );
    await tester.pump();
    expect(milestones(), isEmpty, reason: 'the loading screen is not the calendar');
    update(() => showCalendar = true);
    await tester.pump();
    await tester.pump();
    expect(milestones(), ['firstCalendarFrame']);
  });

  testWidgets('a calendar hidden behind the app lock is not measured, even once shown', (
    tester,
  ) async {
    var locked = true;
    late StateSetter update;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Offstage(offstage: locked, child: const _Calendar());
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(milestones(), isEmpty);
    // Unlocking later must not record a time that includes entering the PIN.
    update(() => locked = false);
    await tester.pump();
    await tester.pump();
    expect(milestones(), isEmpty);
  });

  testWidgets('a visible calendar is reported once', (tester) async {
    await tester.pumpWidget(app(const _Calendar()));
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(app(const _Calendar()));
    await tester.pump();
    expect(milestones(), ['firstCalendarFrame']);
  });

  test('main starts the startup clock before anything else', () {
    final main = File('lib/main.dart').readAsStringSync();
    final body = main.substring(main.indexOf('Future<void> main()'));
    expect(body.indexOf('StartupTiming.begin();'), isNonNegative);
    expect(
      body.indexOf('StartupTiming.begin();'),
      lessThan(body.indexOf('WidgetsFlutterBinding.ensureInitialized();')),
    );
  });
}
