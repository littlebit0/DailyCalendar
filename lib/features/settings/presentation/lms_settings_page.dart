import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/lms/lms_sync_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/daily_ui.dart';
import '../../events/domain/event_category.dart';
import 'lms_login_page.dart';

class LmsSettingsPage extends ConsumerStatefulWidget {
  const LmsSettingsPage({super.key});
  @override
  ConsumerState<LmsSettingsPage> createState() => _LmsSettingsPageState();
}

class _LmsSettingsPageState extends ConsumerState<LmsSettingsPage> {
  bool _opening = false;
  bool _failed = false;
  bool _savingCategory = false;

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
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _opening = false);
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
    } catch (_) {
      if (mounted) setState(() => _failed = true);
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
        _opening || controller.restoring || sync.state == LmsSyncState.loading;
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
            LmsSyncState.loading => '학교에서 최신 과제와 퀴즈를 가져오고 있습니다.',
            LmsSyncState.ready => '학교 데이터 동기화 완료',
            LmsSyncState.fallback => '학교에 연결하지 못해 마지막으로 확인한 데이터를 표시합니다.',
            LmsSyncState.needsLogin => '학교 로그인이 필요합니다.',
            LmsSyncState.unsupported => '이 학교의 LMS 연결은 아직 지원하지 않습니다.',
            LmsSyncState.idle => '학교 계정으로 로그인해 연결하세요.',
          };
    return Scaffold(
      appBar: DailyNavigationBar(title: context.tr('학교 LMS 연결')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  settings.academicProfile?.displayName ?? context.tr('학사 정보'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (!hasGoogle)
                  Text(context.tr('Google 계정 로그인이 필요합니다.'))
                else if (!controller.supported)
                  Text(context.tr('현재 상명대학교 과제·퀴즈를 지원합니다. 다른 학교는 확인 후 지원합니다.'))
                else ...[
                  Text(
                    context.tr(
                      '학교의 공식 로그인 화면에서 인증하면 과제 마감과 퀴즈 일정을 자동으로 가져옵니다.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr(
                      '앱 시작·복귀 시와 사용 중 5분 간격으로 확인합니다. 학교 인증이 만료되면 다시 로그인해야 합니다.',
                    ),
                  ),
                  const SizedBox(height: 20),
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
                    onChanged: _savingCategory ? null : _selectCategory,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      '선택한 분류로 LMS 일정을 자동 추가하고 동기화합니다. 기존 연결 일정에도 적용됩니다.',
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (busy || _savingCategory) const LinearProgressIndicator(),
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
                          'activities': result.activities - result.unscheduled,
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
                  if (_failed)
                    Text(context.tr('학교 연결을 확인하지 못했습니다. 다시 시도해 주세요.')),
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
                  const SizedBox(height: 16),
                  Text(
                    context.tr(
                      '제목·마감·제출 상태는 학교에서 갱신됩니다. Daily의 메모·분류·알림·완료 표시는 별도로 유지됩니다.',
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
