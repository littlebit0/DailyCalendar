import 'dart:async';

import '../analytics/product_analytics.dart';
import 'lms_web_session.dart';

/// Reports LMS login outcomes as fixed codes only: the method, the stage where
/// the attempt ended, the result and a [LmsLoginFailure] name. Nothing from the
/// school, the platform, an exception, a URL or the stored account is passed
/// in, and a failure to report never changes the login (#259).
class LmsLoginReporter {
  const LmsLoginReporter(this._analytics);

  final ProductAnalytics _analytics;

  void report({
    required AnalyticsLmsMethod method,
    required AnalyticsLmsStage stage,
    required AnalyticsLmsResult result,
    LmsLoginFailure? cause,
    AnalyticsLmsSkipReason? skipReason,
  }) {
    try {
      unawaited(
        _analytics
            .record(
              AnalyticsRecord.lmsLogin(
                method: method,
                stage: stage,
                result: result,
                cause: cause?.name,
                skipReason: skipReason,
              ),
            )
            .catchError((Object _) {}),
      );
    } on Object {
      // Analytics must never affect the login.
    }
  }
}
