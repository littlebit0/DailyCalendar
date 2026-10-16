import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/daily_ui.dart';

class DotConnectTile extends StatelessWidget {
  const DotConnectTile({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) {
      return const SizedBox.shrink();
    }
    return ListTile(
      key: const ValueKey('dot-connect-button'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.auto_awesome_outlined),
      title: Text(context.tr('Dot 연계하기')),
      subtitle: Text(context.tr('Dot 연동 점검 중 · 사용 중지')),
      trailing: const Icon(Icons.lock_outline_rounded),
      enabled: false,
    );
  }
}

class DotSetupDialog extends StatefulWidget {
  const DotSetupDialog({super.key});

  @override
  State<DotSetupDialog> createState() => _DotSetupDialogState();
}

class _DotSetupDialogState extends State<DotSetupDialog>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('daily/dot_integration');
  bool _busy = false;
  bool _purchaseRefreshPending = false;
  bool _unlocked = false;
  bool _testAccess = false;
  bool _available = false;
  bool _checked = false;
  String _price = '';
  String? _message;
  Timer? _statusTimer;
  bool _readingSetup = false;
  bool _setupRefreshPending = false;
  bool _submittingRequest = false;
  bool _filesPrepared = false;
  bool _pluginReady = false;
  bool _googleConnected = false;
  bool _queryVerified = false;
  String? _requestID;
  DateTime? _requestedAt;
  bool _openedGoogle = false;
  String? _requestAction;
  bool _waitingForPlugin = false;
  String? _queryPhase;
  int _filesRead = 0;
  int _filesTotal = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'setupChanged') {
        await _readSetup();
      } else if (call.method == 'purchaseChanged') {
        if (_busy) {
          _purchaseRefreshPending = true;
        } else {
          await _refresh();
        }
      }
    });
    _refresh();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _readSetup(),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _apply(Map<Object?, Object?>? status) {
    if (status == null || status['unlocked'] is! bool) {
      throw const FormatException('Invalid purchase status');
    }
    _testAccess = status['testAccess'] == true;
    _unlocked = status['unlocked'] == true || _testAccess;
    _available = status['available'] == true;
    _price = status['price'] is String ? status['price']! as String : '';
    _checked = true;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _message = switch (error) {
          PlatformException(code: 'unsupported_os') =>
            'Dot 결제에는 macOS 12 이상이 필요합니다.',
          PlatformException(code: 'folderCancelled') =>
            '폴더 선택을 취소했습니다. 연결 파일 만들기를 다시 눌러 주세요.',
          PlatformException(code: 'protectedFolder') =>
            '앱 보호 폴더는 공유할 수 없습니다. 다른 연결 폴더를 선택해 주세요.',
          PlatformException(code: 'folderRequired') =>
            '연결 폴더 접근이 필요합니다. 연결 파일 만들기를 눌러 폴더를 선택해 주세요.',
          PlatformException(code: 'filesRequired') => '먼저 연결 파일을 만들어 주세요.',
          _ => '상태를 확인하지 못했습니다. 다시 시도해 주세요.',
        };
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_purchaseRefreshPending) {
          _purchaseRefreshPending = false;
          unawaited(_refresh());
        }
      }
    }
  }

  Future<void> _readSetup() async {
    if (!mounted) return;
    if (_readingSetup) {
      _setupRefreshPending = true;
      return;
    }
    _readingSetup = true;
    try {
      final state = await _channel
          .invokeMapMethod<String, Object?>('setupStatus')
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _filesPrepared = state?['filesPrepared'] == true;
        _pluginReady = _filesPrepared && state?['pluginReady'] == true;
        if (_pluginReady) _waitingForPlugin = false;
        _googleConnected = _pluginReady && state?['googleConnected'] == true;
        _queryVerified = _googleConnected && state?['lastQuery'] is num;
        final requestState = state?['requestState'];
        final created = state?['requestCreatedAt'];
        if (_requestID == null &&
            state?['requestID'] is String &&
            created is num &&
            const [
              'running',
              'waiting_for_keychain',
              'waiting_for_google',
            ].contains(requestState)) {
          final requested = DateTime.fromMillisecondsSinceEpoch(
            (created * 1000).round(),
          );
          final age = DateTime.now().difference(requested);
          if (!age.isNegative && age < const Duration(minutes: 11)) {
            _requestID = state!['requestID']! as String;
            _requestAction = state['requestAction'] as String?;
            _requestedAt = requested;
            _openedGoogle = false;
          }
        }
        if (_requestID != null && state?['requestID'] == _requestID) {
          _queryPhase = state?['queryPhase'] as String?;
          _filesRead = (state?['filesRead'] as num?)?.toInt() ?? 0;
          _filesTotal = (state?['filesTotal'] as num?)?.toInt() ?? 0;
          if (state?['requestState'] == 'complete') {
            _requestID = null;
            _message = '확인을 완료했습니다.';
          } else if (state?['requestState'] == 'error') {
            _requestID = null;
            _message = switch (state?['errorCode']) {
              'busy' => '다른 연결 또는 조회가 진행 중입니다. 완료 후 다시 눌러 주세요.',
              'keychain_access' =>
                'macOS 키체인 접근을 확인하지 못했습니다. Google 연결에서 접근을 허용해 주세요.',
              'timeout' => '연결 대기 시간이 끝났습니다. 다시 시도해 주세요.',
              _ => '연결 또는 조회에 실패했습니다. 다시 시도해 주세요.',
            };
          } else if (requestState == 'waiting_for_keychain') {
            _message = 'macOS 키체인 응답을 기다리고 있습니다. 표시된 승인 창을 확인해 주세요.';
          } else if (requestState == 'waiting_for_google') {
            _message = '브라우저에서 Google 로그인과 접근 승인을 완료해 주세요.';
          }
        }
        if (_requestID != null &&
            _requestedAt != null &&
            DateTime.now().difference(_requestedAt!) >
                const Duration(minutes: 11)) {
          _requestID = null;
          _message = '연결 대기 시간이 끝났습니다. 다시 시도해 주세요.';
        }
      });
      if (_requestID != null &&
          state?['requestID'] == _requestID &&
          state?['hasAuthURL'] == true &&
          !_openedGoogle) {
        try {
          await _channel.invokeMethod<void>('openGoogle');
          _openedGoogle = true;
        } catch (_) {
          if (mounted) {
            setState(() => _message = 'Google 로그인 창을 열지 못했습니다. 다시 시도하고 있습니다.');
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = '상태를 확인하지 못했습니다. 다시 시도해 주세요.';
        });
      }
    } finally {
      _readingSetup = false;
      if (_setupRefreshPending && mounted) {
        _setupRefreshPending = false;
        unawaited(_readSetup());
      }
    }
  }

  Future<void> _request(String action) => _run(() async {
    setState(() {
      _submittingRequest = true;
      _requestAction = action;
      _queryPhase = null;
      _filesRead = 0;
      _filesTotal = 0;
      _requestedAt = DateTime.now();
      _openedGoogle = false;
      _message = '연결된 조회 도구의 응답을 기다리고 있습니다.';
    });
    try {
      final id = await _channel.invokeMethod<String>('requestSetup', action);
      if (!mounted) return;
      setState(() => _requestID = id);
      await _readSetup();
    } finally {
      if (mounted) setState(() => _submittingRequest = false);
    }
  });

  Future<void> _refresh() => _run(() async {
    await _readSetup();
    try {
      final status = await _channel.invokeMapMethod<Object?, Object?>(
        'purchaseStatus',
      );
      if (mounted) _apply(status);
    } catch (_) {
      if (mounted) {
        _testAccess = false;
        _unlocked = false;
        _available = false;
        _checked = false;
      }
      rethrow;
    }
  });

  Future<void> _purchase() => _run(() async {
    final result = await _channel.invokeMethod<String>('purchase');
    if (!mounted) return;
    if (result == 'pending') {
      _message = '구매 승인 대기 중입니다.';
    } else if (result == 'purchased') {
      final status = await _channel.invokeMapMethod<Object?, Object?>(
        'purchaseStatus',
      );
      if (mounted) _apply(status);
    }
    // Cancellation never changes the entitlement.
  });

  Future<void> _restore() => _run(() async {
    final status = await _channel.invokeMapMethod<Object?, Object?>(
      'restorePurchases',
    );
    if (mounted) {
      _apply(status);
      _message = _unlocked ? 'Dot 구매를 복원했습니다.' : '복원할 Dot 구매가 없습니다.';
    }
  });

  Future<void> _prepareFiles() => _run(() async {
    final data = await rootBundle.load(
      'assets/dot/dailycalendar-awareness.skill',
    );
    await _channel.invokeMethod<void>(
      'preparePlugin',
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    await _readSetup();
    if (mounted) {
      _message = _filesPrepared
          ? '연결 파일을 만들었습니다. 다음으로 플러그인을 연결해 주세요.'
          : '연결 파일을 확인하지 못했습니다. 다시 만들어 주세요.';
    }
  });

  Future<void> _openPlugin() => _run(() async {
    await _channel.invokeMethod<void>('openPlugin');
    if (mounted) {
      _waitingForPlugin = true;
      _message = 'ChatGPT에서 플러그인 설치와 도구 사용을 허용해 주세요.';
    }
  });

  Widget _row(
    String title,
    String state, {
    bool complete = false,
    bool loading = false,
    String? detail,
    Widget? action,
  }) {
    return Padding(
      key: ValueKey('dot-step-$title'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 430 ||
              MediaQuery.textScalerOf(context).scale(14) > 20;
          final description = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(title),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Semantics(
                liveRegion: true,
                child: Text(context.tr(loading ? '진행 중' : state)),
              ),
              if (detail != null) ...[
                const SizedBox(height: 4),
                Text(
                  context.tr(detail),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (stacked && action != null) ...[
                const SizedBox(height: 8),
                action,
              ],
            ],
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (loading)
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  complete ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: complete
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              const SizedBox(width: 12),
              Expanded(child: description),
              if (!stacked && action != null) ...[
                const SizedBox(width: 12),
                Flexible(child: action),
              ],
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedSteps = [
      _unlocked,
      _filesPrepared,
      _pluginReady,
      _googleConnected,
      _queryVerified,
      false,
    ];
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 608, maxHeight: 740),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Dot 연계하기'),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: context.tr('닫기'),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (var index = 0; index < 6; index++)
                          Expanded(
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: completedSteps[index]
                                      ? theme.colorScheme.primary
                                      : theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                  foregroundColor: completedSteps[index]
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurface,
                                  child: completedSteps[index]
                                      ? const Icon(Icons.check, size: 18)
                                      : Text('${index + 1}'),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  context.tr(
                                    [
                                      '잠금 해제',
                                      '파일 생성',
                                      '플러그인',
                                      'Google 연결',
                                      '조회 확인',
                                      'Mac 연결',
                                    ][index],
                                  ),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      context.tr('Dot 잠금 해제'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.tr(
                        _testAccess
                            ? '테스트 앱에서는 결제 없이 Dot 연결을 사용할 수 있습니다.'
                            : '1,000원 일회성 구매로 Dot 기능만 잠금 해제합니다.',
                      ),
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    _row(
                      _testAccess ? 'Dot 테스트 사용' : 'Dot 구매',
                      !_checked
                          ? '확인 중'
                          : _testAccess
                          ? '테스트용 활성화'
                          : _unlocked
                          ? '완료'
                          : '미완료',
                      complete: _unlocked,
                      action: _testAccess
                          ? null
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!_unlocked)
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: DailyUi.primary,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(0, 48),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed:
                                        _busy || !_available || _price.isEmpty
                                        ? null
                                        : _purchase,
                                    child: Text(
                                      _price.isEmpty
                                          ? context.tr('Dot 잠금 해제')
                                          : context.tr(
                                              '{price} · Dot 잠금 해제',
                                              args: {'price': _price},
                                            ),
                                    ),
                                  ),
                                TextButton(
                                  onPressed: _busy ? null : _restore,
                                  child: Text(context.tr('구매 복원')),
                                ),
                              ],
                            ),
                    ),
                    _row(
                      '연결 파일 생성',
                      _filesPrepared ? '완료' : '미완료',
                      complete: _filesPrepared,
                      detail: '폴더를 선택하면 필요한 연결 파일을 자동으로 만듭니다.',
                      action: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: DailyUi.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _busy || !_unlocked || _requestID != null
                            ? null
                            : _prepareFiles,
                        child: Text(context.tr('연결 파일 만들기')),
                      ),
                    ),
                    _row(
                      '플러그인 설치와 도구 사용',
                      _pluginReady ? '완료' : '확인 필요',
                      complete: _pluginReady,
                      loading: _waitingForPlugin,
                      detail: _filesPrepared
                          ? 'ChatGPT에서 플러그인 설치와 도구 실행을 허용해 주세요.'
                          : '먼저 연결 파일을 만들어 주세요.',
                      action: _unlocked
                          ? FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: DailyUi.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _busy || !_filesPrepared
                                  ? null
                                  : _openPlugin,
                              child: Text(context.tr('플러그인 연결')),
                            )
                          : null,
                    ),
                    _row(
                      'Google Drive 접근 승인',
                      _googleConnected ? '완료' : '확인 필요',
                      complete: _googleConnected,
                      loading:
                          (_submittingRequest || _requestID != null) &&
                          _requestAction != 'read',
                      detail: !_unlocked
                          ? '먼저 Dot 잠금을 해제해 주세요.'
                          : !_pluginReady
                          ? '먼저 플러그인을 연결하고 ChatGPT에서 도구 실행을 허용해 주세요.'
                          : '기존 Google 승인이 있으면 확인하고, 없으면 로그인 창을 엽니다.',
                      action: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DailyUi.primary,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed:
                            _busy ||
                                !_unlocked ||
                                _requestID != null ||
                                !_pluginReady
                            ? null
                            : () => _request('connect'),
                        child: Text(context.tr('Google 연결')),
                      ),
                    ),
                    _row(
                      '일정 원본 조회 검증',
                      _queryVerified ? '완료' : '미완료',
                      complete: _queryVerified,
                      loading:
                          (_submittingRequest || _requestID != null) &&
                          _requestAction == 'read',
                      detail:
                          (_submittingRequest || _requestID != null) &&
                              _requestAction == 'read'
                          ? switch (_queryPhase) {
                              'listing' => 'Drive의 일정 파일 목록을 확인하고 있습니다.',
                              'downloading' => context.tr(
                                '일정 파일 {done}/{total}개 읽는 중',
                                args: {
                                  'done': '$_filesRead',
                                  'total': '$_filesTotal',
                                },
                              ),
                              'verifying' ||
                              'verified' => '조회 중 변경된 일정이 있는지 검증하고 있습니다.',
                              _ => '조회 도구의 응답을 기다리고 있습니다.',
                            }
                          : 'Google 연결 완료 후 실제 일정 조회를 확인합니다.',
                      action: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DailyUi.primary,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed:
                            _busy ||
                                !_unlocked ||
                                _requestID != null ||
                                !_pluginReady ||
                                !_googleConnected
                            ? null
                            : () => _request('read'),
                        child: Text(context.tr('조회 확인')),
                      ),
                    ),
                    _row(
                      'Dot의 Mac 접근 허용',
                      'ChatGPT의 Dot 프로필에서 확인',
                      detail:
                          'Dot 프로필에서 이 Mac의 접근을 허용해 주세요. 앱에서는 완료 여부를 확인할 수 없습니다.',
                      action: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DailyUi.primary,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _busy || !_unlocked
                            ? null
                            : () => _run(
                                () => _channel.invokeMethod<void>('openDot'),
                              ),
                        child: Text(context.tr('Dot 열기')),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('Mac이 온라인이고 ChatGPT가 실행 중이어야 합니다.'),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('설치 화면을 여는 것만으로 연결 완료로 표시하지 않습니다.'),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (_checked && !_unlocked && !_available) ...[
                      const SizedBox(height: 16),
                      Text(context.tr('현재 스토어에서 Dot 구매 상품을 불러올 수 없습니다.')),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(context.tr(_message!)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_busy || _requestID != null || _waitingForPlugin)
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  TextButton(
                    onPressed: _busy ? null : _refresh,
                    child: Text(context.tr('다시 확인')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
