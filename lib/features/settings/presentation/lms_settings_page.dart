import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/lms/lms_sync_service.dart';
import '../../../core/lms/lms_web_session.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/daily_ui.dart';
import '../../../core/widgets/smooth_mouse_wheel_scroll_controller.dart';
import '../../events/domain/event_category.dart';
import 'lms_login_page.dart';

class LmsSettingsPage extends ConsumerStatefulWidget {
  const LmsSettingsPage({super.key});
  @override
  ConsumerState<LmsSettingsPage> createState() => _LmsSettingsPageState();
}

class _LmsSettingsPageState extends ConsumerState<LmsSettingsPage> {
  final _scrollController = SmoothMouseWheelScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _opening = false;
  bool _failed = false;
  LmsLoginFailure? _failureReason;
  bool _savingCategory = false;
  bool _savingLogin = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) unawaited(ref.read(lmsControllerProvider).refresh());
    });
  }

  Future<void> _login() async {
    setState(() {
      _opening = true;
      _failed = false;
      _failureReason = null;
    });
    final controller = ref.read(lmsControllerProvider);
    try {
      final session = await controller.prepareLogin();
      if (!mounted) return;
      if (session == null) throw StateError('School changed');
      final connected = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => LmsLoginPage(session: session)),
      );
      if (connected == true) await controller.loginCompleted(session);
    } catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _failureReason = LmsLoginFailure.fromError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _configureAutomaticLogin() async {
    final controller = ref.read(lmsControllerProvider);
    final owner = ref
        .read(settingsRepositoryProvider)
        .dailyAccount()
        ?.googleAccount
        ?.email;
    final school = controller.schoolId;
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _LocalLmsLoginDialog(),
    );
    if (values == null || !mounted) return;
    if (owner !=
            ref
                .read(settingsRepositoryProvider)
                .dailyAccount()
                ?.googleAccount
                ?.email ||
        school != controller.schoolId) {
      return;
    }
    setState(() {
      _savingLogin = true;
      _failed = false;
      _failureReason = null;
    });
    try {
      await controller.saveAutomaticLogin(values.$1, values.$2);
    } catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _failureReason = LmsLoginFailure.fromError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _savingLogin = false);
    }
  }

  Future<void> _removeAutomaticLogin() async {
    setState(() {
      _savingLogin = true;
      _failed = false;
      _failureReason = null;
    });
    try {
      await ref.read(lmsControllerProvider).removeAutomaticLogin();
    } catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _failureReason = LmsLoginFailure.fromError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _savingLogin = false);
    }
  }

  Future<void> _selectCategory(String? id) async {
    if (id == null || _savingCategory) return;
    final repository = ref.read(settingsRepositoryProvider);
    final profile = repository.load().academicProfile;
    final owner = repository.dailyAccount()?.googleAccount?.email;
    if (profile == null || owner == null) return;
    setState(() {
      _savingCategory = true;
      _failed = false;
      _failureReason = null;
    });
    try {
      await repository.saveAcademicProfile(
        profile.withLmsCategory(id),
        expectedGoogleEmail: owner,
      );
      if (!mounted) return;
      ref.read(appSettingsProvider.notifier).state = repository.load();
      unawaited(
        ref
            .read(googleDriveSyncServiceProvider)
            .queueSettingsBackup()
            .catchError((_) {}),
      );
      await ref.read(lmsControllerProvider).sync.applyConfiguredCategory();
    } catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _failureReason = LmsLoginFailure.fromError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _savingCategory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.watch(lmsControllerProvider);
    final hasGoogle =
        ref.read(settingsRepositoryProvider).dailyAccount()?.googleAccount !=
        null;
    final sync = controller.sync;
    final busy =
        _opening ||
        _savingLogin ||
        controller.restoring ||
        sync.state == LmsSyncState.loading;
    final categories = settings.categories.where((c) => !c.locked).toList();
    final selectedCategory =
        categories
            .where((c) => c.id == settings.academicProfile?.lmsCategoryId)
            .firstOrNull
            ?.id ??
        categories.where((c) => c.id == EventCategory.basic.id).firstOrNull?.id;
    final result = sync.lastResult;
    final last = sync.lastSuccess;
    final status = controller.restoring
        ? '학교 연결을 확인하고 있습니다.'
        : switch (sync.state) {
            LmsSyncState.loading => '학교에서 최신 과제·퀴즈·학습 일정을 가져오고 있습니다.',
            LmsSyncState.ready =>
              (result?.learningCoverageIncomplete == true ||
                      (result?.unresolvedQuizStatuses ?? 0) > 0)
                  ? '학교 데이터를 동기화했습니다. 일부 학교 정보는 확인하지 못했습니다.'
                  : '학교 데이터 동기화 완료',
            LmsSyncState.fallback => '학교에 연결하지 못해 마지막으로 확인한 데이터를 표시합니다.',
            LmsSyncState.needsLogin =>
              '학교에 다시 로그인해 주세요. 기존 일정은 마지막으로 확인한 상태로 유지됩니다.',
            LmsSyncState.unsupported => '이 학교의 LMS 연결은 아직 지원하지 않습니다.',
            LmsSyncState.idle => '학교 계정으로 로그인해 연결하세요.',
          };
    return Scaffold(
      backgroundColor: DailyUi.pageBackground(context),
      appBar: DailyNavigationBar(title: context.tr('학교 LMS 연결')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                DailyGroupedSection(
                  children: [
                    DailySettingsRow(
                      leading: const DailySettingsIcon(
                        icon: Icons.school_outlined,
                      ),
                      title:
                          settings.academicProfile?.displayName ??
                          context.tr('학사 정보'),
                      subtitle: context.tr('학교 LMS 연결'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!hasGoogle)
                  Text(context.tr('Google 계정 로그인이 필요합니다.'))
                else if (!controller.supported)
                  Text(context.tr('해당 대학의 LMS 연결은 아직 지원하지 않습니다.'))
                else ...[
                  Text(
                    context.tr(
                      '학교의 공식 로그인 화면에서 인증하면 과제·퀴즈 마감과 출석 조건이 확인된 학습 일정을 자동으로 가져옵니다.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr(
                      '앱 시작·복귀 시와 사용 중 5분 간격으로 확인합니다. 학교 인증이 만료되면 다시 로그인해야 합니다.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DailyGroupedSection(
                    label: context.tr('이 기기 자동 로그인'),
                    footer: context.tr(_localLoginNotice),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const DailySettingsIcon(
                                  icon: Icons.lock_outline,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.tr('학교 아이디'),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelLarge,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        controller.localLoginLoading
                                            ? context.tr('로그인 정보를 확인하고 있습니다.')
                                            : controller.localLoginReadFailed
                                            ? context.tr(
                                                '저장된 로그인 정보를 확인하지 못했습니다.',
                                              )
                                            : controller.localLoginUsername ??
                                                  context.tr(
                                                    '저장된 로그인 정보가 없습니다.',
                                                  ),
                                        key: const ValueKey(
                                          'lms-local-login-username',
                                        ),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (controller.lastLoginFailure != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                context.tr(
                                  controller.lastLoginFailure!.message,
                                ),
                                key: const ValueKey('lms-login-failure-reason'),
                              ),
                            ],
                            if (controller.automaticLoginPaused) ...[
                              const SizedBox(height: 12),
                              Text(
                                context.tr(
                                  '자동 로그인을 일시 중지했습니다. 비밀번호나 추가 인증을 확인한 뒤 로그인 정보를 다시 저장해 주세요.',
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              key: const ValueKey('lms-local-login-configure'),
                              onPressed: busy || controller.localLoginLoading
                                  ? null
                                  : _configureAutomaticLogin,
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(context.tr('로그인 정보 저장·변경')),
                            ),
                            if (controller.localLoginUsername != null)
                              TextButton.icon(
                                key: const ValueKey('lms-local-login-remove'),
                                onPressed: busy || controller.localLoginLoading
                                    ? null
                                    : _removeAutomaticLogin,
                                style: TextButton.styleFrom(
                                  foregroundColor: DailyUi.destructive,
                                ),
                                icon: const Icon(Icons.delete_outline),
                                label: Text(context.tr('이 기기의 저장된 로그인 정보 삭제')),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DailyGroupedSection(
                    label: context.tr('LMS 일정 분류'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<String>(
                              key: ValueKey('lms-category-$selectedCategory'),
                              initialValue: selectedCategory,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: context.tr('LMS 일정 분류'),
                                border: const OutlineInputBorder(),
                              ),
                              items: [
                                for (final category in categories)
                                  DropdownMenuItem(
                                    value: category.id,
                                    child: Text(
                                      category.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: _savingCategory
                                  ? null
                                  : _selectCategory,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.tr(
                                '선택한 분류로 LMS 일정을 자동 추가하고 동기화합니다. 기존 연결 일정에도 적용됩니다.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DailyGroupedSection(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (busy || _savingCategory)
                              const LinearProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              context.tr(status),
                              key: const ValueKey('lms-sync-status'),
                            ),
                            if (last != null)
                              Text(
                                context.tr(
                                  '최근 확인: {time}',
                                  args: {
                                    'time': DateFormat.yMd(
                                      context.l10n.locale.toLanguageTag(),
                                    ).add_Hm().format(last.toLocal()),
                                  },
                                ),
                              ),
                            if (result != null)
                              Text(
                                context.tr(
                                  '수업 {courses}개 · 일정 {activities}개',
                                  args: {
                                    'courses': result.courses,
                                    'activities':
                                        result.activities - result.unscheduled,
                                  },
                                ),
                              ),
                            if (result != null && result.unscheduled > 0)
                              Text(
                                context.tr(
                                  '마감일이 없는 항목 {count}개는 달력에 표시하지 않습니다.',
                                  args: {'count': result.unscheduled},
                                ),
                              ),
                            if ((result?.learningCoverageIncomplete == true ||
                                (result?.unresolvedQuizStatuses ?? 0) > 0)) ...[
                              const SizedBox(height: 12),
                              DecoratedBox(
                                key: const ValueKey(
                                  'lms-learning-coverage-notice',
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (result!.unresolvedLearningActivities >
                                          0)
                                        Text(
                                          context.tr(
                                            '학습 정보가 충분하지 않은 항목 {count}개는 추가하지 않았습니다.',
                                            args: {
                                              'count': result
                                                  .unresolvedLearningActivities,
                                            },
                                          ),
                                        ),
                                      if (result.unresolvedQuizStatuses > 0)
                                        Text(
                                          context.tr(
                                            '퀴즈 {count}개의 응시 상태를 확인하지 못했습니다. 기존 완료 상태는 유지됩니다.',
                                            args: {
                                              'count':
                                                  result.unresolvedQuizStatuses,
                                            },
                                          ),
                                        ),
                                      if (result.failedLearningCourses > 0)
                                        Text(
                                          context.tr(
                                            '강좌 {count}개의 학습 정보를 확인하지 못했습니다. 기존 학습 일정은 유지됩니다.',
                                            args: {
                                              'count':
                                                  result.failedLearningCourses,
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (_failed)
                              Text(
                                context.tr(
                                  (controller.lastLoginFailure ??
                                              _failureReason)
                                          ?.message ??
                                      '학교 연결을 확인하지 못했습니다. 다시 시도해 주세요.',
                                ),
                              ),
                            const SizedBox(height: 20),
                            if (!controller.connected || controller.needsLogin)
                              FilledButton.icon(
                                key: const ValueKey('lms-connect'),
                                onPressed: busy ? null : _login,
                                icon: const Icon(Icons.school_outlined),
                                label: Text(context.tr('학교 계정으로 로그인')),
                              )
                            else ...[
                              FilledButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => controller.refresh(force: true),
                                icon: const Icon(Icons.sync),
                                label: Text(context.tr('지금 동기화')),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: busy ? null : controller.disconnect,
                                child: Text(context.tr('학교 연결 해제')),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr(
                      '제목·마감·제출 상태는 학교에서 갱신됩니다. 직접 완료한 일정은 학교의 미완료 상태로 변경되지 않습니다. 메모·분류·알림은 별도로 유지됩니다.',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _localLoginNotice =
    '아이디·비밀번호는 이 기기의 보안 저장소에만 저장되며 다른 기기로 동기화되지 않습니다. 자동 로그인은 해당 기기에만 적용됩니다. LMS에서 가져온 일정만 Google 계정으로 동기화됩니다. 자동 로그인 시 다른 기기나 브라우저의 LMS 세션이 종료되어 로그아웃될 수 있습니다.';

class _LocalLmsLoginDialog extends StatefulWidget {
  const _LocalLmsLoginDialog();
  @override
  State<_LocalLmsLoginDialog> createState() => _LocalLmsLoginDialogState();
}

class _LocalLmsLoginDialogState extends State<_LocalLmsLoginDialog> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  static const _passwordInputChannel = MethodChannel('daily/password_input');

  @override
  void initState() {
    super.initState();
    _passwordFocus.addListener(_passwordFocusChanged);
  }

  void _passwordFocusChanged() {
    // EditableText attaches its platform client during this frame. Restrict
    // that active native editor afterwards, before the next keyboard input.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_setEnglishInput(_passwordFocus.hasFocus));
    });
  }

  Future<void> _setEnglishInput(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    try {
      await _passwordInputChannel.invokeMethod<bool>(
        'setEnglishInput',
        enabled,
      );
    } on MissingPluginException {
      // Other hosts and old runners do not provide the Mac input context.
    } on PlatformException {
      // Preserve exact credential input if native input context is unavailable.
    }
  }

  bool _consent = false;
  late final Listenable _loginFields = Listenable.merge([_username, _password]);
  @override
  void dispose() {
    _passwordFocus.removeListener(_passwordFocusChanged);
    unawaited(_setEnglishInput(false));
    _passwordFocus.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.tr('이 기기 자동 로그인 설정')),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr(_localLoginNotice)),
            const SizedBox(height: 16),
            TextField(
              controller: _username,
              key: const ValueKey('lms-local-username'),
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: context.tr('학교 아이디')),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _password,
              focusNode: _passwordFocus,
              key: const ValueKey('lms-local-password'),
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              smartQuotesType: SmartQuotesType.disabled,
              smartDashesType: SmartDashesType.disabled,
              enableIMEPersonalizedLearning: false,
              enableInlinePrediction: false,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: context.tr('비밀번호')),
            ),
            CheckboxListTile(
              value: _consent,
              contentPadding: EdgeInsets.zero,
              key: const ValueKey('lms-local-consent'),
              title: Text(context.tr('이 기기에 저장하고 자동 로그인하는 데 동의합니다.')),
              onChanged: (value) => setState(() => _consent = value == true),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.tr('취소')),
      ),
      ListenableBuilder(
        listenable: _loginFields,
        builder: (context, _) => FilledButton(
          key: const ValueKey('lms-local-save'),
          onPressed:
              !_consent ||
                  _username.text.trim().isEmpty ||
                  _password.text.isEmpty
              ? null
              : () => Navigator.pop(context, (
                  _username.text.trim(),
                  _password.text,
                )),
          child: Text(context.tr('저장하고 연결')),
        ),
      ),
    ],
  );
}
