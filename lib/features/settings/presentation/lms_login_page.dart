import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/analytics/product_analytics.dart';
import '../../../core/lms/lms_login_analytics.dart';
import '../../../core/lms/lms_web_session.dart';
import '../../../core/localization/app_localizations.dart';

/// School credentials are entered only in the school's own web form.
class LmsLoginPage extends StatefulWidget {
  const LmsLoginPage({
    super.key,
    required this.session,
    this.analytics = const NoopProductAnalytics(),
  });
  final LmsWebSession session;
  final ProductAnalytics analytics;

  @override
  State<LmsLoginPage> createState() => _LmsLoginPageState();
}

class _LmsLoginPageState extends State<LmsLoginPage> {
  bool _ready = false;
  bool _checking = false;
  bool _finished = false;
  String? _message;
  String? _visibleHost;
  double _progress = 0;
  final Set<DialogRoute<void>> _popupRoutes = {};
  late final LmsLoginReporter _reporter = LmsLoginReporter(widget.analytics);
  bool _reportedOutcome = false;

  void _report(
    AnalyticsLmsStage stage,
    AnalyticsLmsResult result, {
    LmsLoginFailure? cause,
  }) {
    _reportedOutcome = true;
    _reporter.report(
      method: AnalyticsLmsMethod.manual,
      stage: stage,
      result: result,
      cause: cause,
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    try {
      await widget.session.beginLogin();
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      // Leaving the screen already reported a cancellation for this attempt.
      if (_reportedOutcome) return;
      final failure = LmsLoginFailure.fromError(error);
      _report(
        AnalyticsLmsStage.prepare,
        AnalyticsLmsResult.failed,
        cause: failure,
      );
      if (mounted) {
        setState(() => _message = failure.message);
      }
    }
  }

  Future<void> _complete({bool automatic = false}) async {
    if (_checking || !_ready || _finished) return;
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      final principal = await widget.session.verifyAuthentication();
      if (!mounted) return;
      if (principal == null) {
        if (automatic) return;
        final failure = await widget.session.explainLoginFailure();
        _report(
          AnalyticsLmsStage.authentication,
          AnalyticsLmsResult.failed,
          cause: failure,
        );
        if (mounted) setState(() => _message = failure.message);
        return;
      }
      await widget.session.finishLogin(authenticated: true);
      _finished = true;
      _report(AnalyticsLmsStage.session, AnalyticsLmsResult.succeeded);
      if (mounted) {
        final navigator = Navigator.of(context);
        final loginRoute = ModalRoute.of(context);
        // SSO can complete in the parent before its popup closes itself.
        // Remove only this login's popups before returning its result.
        for (final popup in _popupRoutes.toList()) {
          if (popup.isActive) navigator.removeRoute(popup);
        }
        _popupRoutes.clear();
        if (loginRoute?.isCurrent == true) {
          navigator.pop(true);
        } else if (loginRoute?.isActive == true) {
          navigator.removeRoute(loginRoute!, true);
        }
      }
    } catch (error) {
      final failure = await widget.session.explainLoginFailure(error);
      _report(
        AnalyticsLmsStage.authentication,
        AnalyticsLmsResult.failed,
        cause: failure,
      );
      if (mounted) setState(() => _message = failure.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<NavigationActionPolicy> _navigate(NavigationAction action) async {
    final uri = action.request.url?.uriValue;
    if (uri != null && widget.session.policy.allowsLoginNavigation(uri)) {
      widget.session.recordLoginNavigation(uri);
      return NavigationActionPolicy.ALLOW;
    }
    if (mounted) setState(() => _message = '이 인증 경로는 앱에서 아직 지원하지 않습니다.');
    return NavigationActionPolicy.CANCEL;
  }

  Future<bool> _openPopup(CreateWindowAction request) async {
    if (!mounted) return false;
    final uri = request.request.url?.uriValue;
    if (uri != null && !widget.session.policy.allowsLoginNavigation(uri)) {
      setState(() => _message = '이 인증 경로는 앱에서 아직 지원하지 않습니다.');
      return false;
    }
    // Keep windowId: loading the popup URL into the parent breaks SSO opener
    // callbacks and may turn an authentication POST into an incorrect GET.
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      useSafeArea: true,
      builder: (context) => _LmsLoginPopup(
        session: widget.session,
        windowId: request.windowId,
        onNavigate: _navigate,
        onFailure: (failure) {
          if (mounted) setState(() => _message = failure.message);
        },
      ),
    );
    _popupRoutes.add(route);
    unawaited(
      Navigator.of(
        context,
      ).push(route).whenComplete(() => _popupRoutes.remove(route)),
    );
    return true;
  }

  @override
  void dispose() {
    // Leaving the official login screen without finishing is a cancellation,
    // not a failure. A screen still preparing is canceled at the prepare stage.
    if (!_finished && !_reportedOutcome) {
      _report(
        _ready ? AnalyticsLmsStage.authentication : AnalyticsLmsStage.prepare,
        AnalyticsLmsResult.canceled,
      );
    }
    if (!_finished) {
      unawaited(
        widget.session.finishLogin(authenticated: false).catchError((_) {}),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('학교 LMS 연결'))),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_visibleHost ?? widget.session.baseUrl.host),
                  ),
                ],
              ),
            ),
            if (_progress > 0 && _progress < 1)
              LinearProgressIndicator(value: _progress),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(l10n.text(_message!), textAlign: TextAlign.center),
              ),
            Expanded(
              child: !_ready
                  ? Center(
                      child: _message == null
                          ? const CircularProgressIndicator()
                          : TextButton(
                              onPressed: _prepare,
                              child: Text(l10n.text('다시 시도')),
                            ),
                    )
                  : InAppWebView(
                      headlessWebView: widget.session.headlessView,
                      keepAlive: widget.session.keepAlive,
                      webViewEnvironment: widget.session.webViewEnvironment,
                      initialSettings: widget.session.webViewSettings,
                      initialUrlRequest: URLRequest(
                        url: WebUri(widget.session.loginUrl.toString()),
                      ),
                      onWebViewCreated: widget.session.attachLoginController,
                      onLoadStart: (_, uri) {
                        widget.session.recordLoginNavigation(uri?.uriValue);
                        if (mounted) setState(() => _visibleHost = uri?.host);
                      },
                      onLoadStop: (_, url) {
                        widget.session.pageLoadFinished();
                        final uri = url?.uriValue;
                        if (uri != null &&
                            widget.session.policy.isSchoolOrigin(uri) &&
                            !const {
                              '/login.php',
                              '/login/index.php',
                            }.contains(uri.path)) {
                          unawaited(_complete(automatic: true));
                        }
                      },
                      onProgressChanged: (_, progress) {
                        if (mounted) setState(() => _progress = progress / 100);
                      },
                      onReceivedHttpError: (_, request, response) {
                        if (request.isForMainFrame == true &&
                            mounted &&
                            (response.statusCode ?? 0) >= 400) {
                          setState(
                            () => _message =
                                LmsLoginFailure.serverRejected.message,
                          );
                        }
                      },
                      shouldOverrideUrlLoading: (_, action) =>
                          _navigate(action),
                      onCreateWindow: (_, request) => _openPopup(request),
                      onReceivedError: (_, request, error) {
                        if (request.isForMainFrame == true) {
                          widget.session.pageLoadFailed();
                        }
                        if (request.isForMainFrame == true && mounted) {
                          setState(
                            () => _message = LmsLoginFailure.fromError(
                              error,
                            ).message,
                          );
                        }
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _ready && !_checking ? _complete : null,
                  child: Text(l10n.text(_checking ? '연결 확인 중' : '로그인 완료')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LmsLoginPopup extends StatefulWidget {
  const _LmsLoginPopup({
    required this.session,
    required this.windowId,
    required this.onNavigate,
    required this.onFailure,
  });
  final LmsWebSession session;
  final int windowId;
  final Future<NavigationActionPolicy> Function(NavigationAction) onNavigate;

  final ValueChanged<LmsLoginFailure> onFailure;

  @override
  State<_LmsLoginPopup> createState() => _LmsLoginPopupState();
}

class _LmsLoginPopupState extends State<_LmsLoginPopup> {
  LmsLoginFailure? _failure;

  void _failed(LmsLoginFailure failure) {
    if (!mounted) return;
    setState(() => _failure = failure);
    widget.onFailure(failure);
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).text('학교 인증')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          if (_failure != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(AppLocalizations.of(context).text(_failure!.message)),
            ),
          Expanded(
            child: InAppWebView(
              windowId: widget.windowId,
              webViewEnvironment: widget.session.webViewEnvironment,
              initialSettings: widget.session.webViewSettings,
              shouldOverrideUrlLoading: (_, action) async {
                final policy = await widget.onNavigate(action);
                if (policy == NavigationActionPolicy.CANCEL) {
                  _failed(LmsLoginFailure.unsupportedForm);
                }
                return policy;
              },
              onLoadStart: (_, uri) {
                if (mounted) setState(() => _failure = null);
                widget.session.recordLoginNavigation(uri?.uriValue);
              },
              onReceivedError: (_, request, error) {
                if (request.isForMainFrame == true) {
                  _failed(LmsLoginFailure.fromError(error));
                }
              },
              onReceivedHttpError: (_, request, response) {
                if (request.isForMainFrame == true &&
                    (response.statusCode ?? 0) >= 400) {
                  _failed(LmsLoginFailure.serverRejected);
                }
              },
              onCloseWindow: (_) {
                if (context.mounted &&
                    ModalRoute.of(context)?.isCurrent == true) {
                  Navigator.pop(context);
                }
              },
            ),
          ),
        ],
      ),
    ),
  );
}
