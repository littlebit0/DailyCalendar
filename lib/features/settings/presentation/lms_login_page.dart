import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/lms/lms_web_session.dart';
import '../../../core/localization/app_localizations.dart';

/// School credentials are entered only in the school's own web form.
class LmsLoginPage extends StatefulWidget {
  const LmsLoginPage({super.key, required this.session});
  final LmsWebSession session;

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

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    try {
      await widget.session.beginLogin();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _message = '학교 로그인창을 열지 못했습니다. 다시 시도해 주세요.');
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
        setState(() => _message = '학교 로그인과 필요한 인증을 완료해 주세요.');
        return;
      }
      await widget.session.finishLogin(authenticated: true);
      _finished = true;
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
    } catch (_) {
      if (mounted && !automatic) {
        setState(() => _message = '학교 연결을 확인하지 못했습니다. 다시 시도해 주세요.');
      }
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
                        final uri = url?.uriValue;
                        if (uri != null &&
                            uri.path == '/' &&
                            widget.session.policy.isSchoolOrigin(uri)) {
                          unawaited(_complete(automatic: true));
                        }
                      },
                      onProgressChanged: (_, progress) {
                        if (mounted) setState(() => _progress = progress / 100);
                      },
                      shouldOverrideUrlLoading: (_, action) =>
                          _navigate(action),
                      onCreateWindow: (_, request) => _openPopup(request),
                      onReceivedError: (_, request, _) {
                        if (request.isForMainFrame == true && mounted) {
                          setState(() => _message = '학교 로그인창을 불러오지 못했습니다.');
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

class _LmsLoginPopup extends StatelessWidget {
  const _LmsLoginPopup({
    required this.session,
    required this.windowId,
    required this.onNavigate,
  });
  final LmsWebSession session;
  final int windowId;
  final Future<NavigationActionPolicy> Function(NavigationAction) onNavigate;

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
      body: InAppWebView(
        windowId: windowId,
        webViewEnvironment: session.webViewEnvironment,
        initialSettings: session.webViewSettings,
        shouldOverrideUrlLoading: (_, action) => onNavigate(action),
        onLoadStart: (_, uri) => session.recordLoginNavigation(uri?.uriValue),
        onCloseWindow: (_) {
          if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
            Navigator.pop(context);
          }
        },
      ),
    ),
  );
}
