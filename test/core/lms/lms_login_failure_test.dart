import 'dart:async';
import 'dart:io';

import 'package:daily/core/lms/lms_web_session.dart';
import 'package:daily/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'login errors expose fixed causes and never arbitrary exception details',
    () {
      expect(
        LmsLoginFailure.fromError(const SocketException('secret-cookie')),
        LmsLoginFailure.network,
      );
      expect(
        LmsLoginFailure.fromError(TimeoutException('private-id')),
        LmsLoginFailure.timedOut,
      );
      expect(
        LmsLoginFailure.fromError(
          const HandshakeException('secret-certificate'),
        ),
        LmsLoginFailure.certificate,
      );
      expect(
        LmsLoginFailure.fromError(
          const LmsWebSessionException(LmsWebSessionError.secureStorage),
        ),
        LmsLoginFailure.secureStorage,
      );
      for (final type in [
        WebResourceErrorType.SERVER_CERTIFICATE_UNTRUSTED,
        WebResourceErrorType.FAILED_SSL_HANDSHAKE,
      ]) {
        expect(
          LmsLoginFailure.fromError(
            WebResourceError(type: type, description: 'private-school-error'),
          ),
          LmsLoginFailure.certificate,
        );
      }
      expect(
        LmsLoginFailure.fromError(
          WebResourceError(
            type: WebResourceErrorType.TIMEOUT,
            description: 'private-url',
          ),
        ),
        LmsLoginFailure.timedOut,
      );
      expect(
        LmsLoginFailure.fromError(StateError('private-password')).message,
        isNot(contains('private-password')),
      );
      expect(
        LmsLoginFailure.fromError(
          const LmsWebSessionException(
            LmsWebSessionError.authenticationRequired,
          ),
        ),
        LmsLoginFailure.authenticationUnconfirmed,
      );
      expect(
        LmsLoginFailure.fromSchoolCode('private-server-text'),
        LmsLoginFailure.unsupportedForm,
      );
    },
  );

  test(
    'all safe reasons are localized in every supported non-Korean locale',
    () {
      for (final locale in [
        const Locale('en'),
        const Locale('ja'),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ]) {
        final l10n = AppLocalizations(locale);
        for (final failure in LmsLoginFailure.values) {
          expect(
            l10n.text(failure.message),
            isNot(failure.message),
            reason: '${locale.languageCode}/${failure.name}',
          );
        }
      }
    },
  );
}
