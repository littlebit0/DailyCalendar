import 'dart:async';

import 'package:daily/core/analytics/product_analytics.dart';
import 'package:daily/core/lms/lms_web_session.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/features/settings/presentation/lms_login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAnalytics extends NoopProductAnalytics {
  final records = <AnalyticsRecord>[];
  @override
  Future<void> record(AnalyticsRecord record) async => records.add(record);
}

class _PreparingSession extends LmsWebSession {
  _PreparingSession() : super(ownerId: 'student@example.com', schoolId: 'smu');
  final preparation = Completer<void>();
  int finishes = 0;

  @override
  Future<void> beginLogin() => preparation.future;

  @override
  Future<void> finishLogin({required bool authenticated}) async => finishes++;
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<_RecordingAnalytics> openAndLeave(
    WidgetTester tester,
    _PreparingSession session,
  ) async {
    final analytics = _RecordingAnalytics();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: LmsLoginPage(session: session, analytics: analytics),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    return analytics;
  }

  List<String> outcomes(_RecordingAnalytics analytics) => [
    for (final record in analytics.records)
      '${record.attributes['stage']}/${record.attributes['result']}',
  ];

  testWidgets('leaving while the login is still preparing is one cancellation', (
    tester,
  ) async {
    final session = _PreparingSession();
    final analytics = await openAndLeave(tester, session);
    expect(outcomes(analytics), ['prepare/canceled']);
    expect(session.finishes, 1);
    session.preparation.complete();
    await tester.pump();
    expect(outcomes(analytics), ['prepare/canceled']);
  });

  testWidgets('a preparation failure after leaving is not reported as failed', (
    tester,
  ) async {
    final session = _PreparingSession();
    final analytics = await openAndLeave(tester, session);
    session.preparation.completeError(StateError('late failure'));
    await tester.pump();
    expect(outcomes(analytics), ['prepare/canceled']);
  });
}
