import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/academic/academic_profile.dart';
import '../../../core/academic/university_directory.dart';
import '../../../core/di/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/daily_ui.dart';
import 'settings_page.dart';

final universityDirectoryProvider = FutureProvider<UniversityDirectory>(
  (ref) => UniversityDirectory.load(),
);

Future<void> offerAcademicProfile(BuildContext context, WidgetRef ref) async {
  final repository = ref.read(settingsRepositoryProvider);
  if (repository.dailyAccount()?.googleAccount == null ||
      repository.load().academicProfile != null ||
      !context.mounted) {
    return;
  }
  await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => const AcademicProfilePage(onboarding: true),
    ),
  );
}

class AcademicProfilePage extends ConsumerStatefulWidget {
  const AcademicProfilePage({super.key, this.onboarding = false});
  final bool onboarding;
  @override
  ConsumerState<AcademicProfilePage> createState() =>
      _AcademicProfilePageState();
}

class _AcademicProfilePageState extends ConsumerState<AcademicProfilePage> {
  String _query = '';
  String? _selected;
  String? _editingEmail;
  bool _saving = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    final repository = ref.read(settingsRepositoryProvider);
    final profile = repository.load().academicProfile;
    _selected = profile?.selectedCampusId;
    _editingEmail = repository.dailyAccount()?.googleAccount?.email;
  }

  Future<void> _save(
    UniversityInstitution institution,
    University? campus,
  ) async {
    if (_saving || _editingEmail == null) return;
    setState(() {
      _saving = true;
      _error = false;
    });
    try {
      final repository = ref.read(settingsRepositoryProvider);
      await repository.saveAcademicProfile(
        AcademicProfile(
          lmsCategoryId: repository.load().academicProfile?.lmsCategoryId,
          universityId: institution.id,
          universityName: institution.name,
          schoolKind: institution.kind.name,
          campusId: institution.campusSelectionRequired ? campus?.id : null,
          campus: institution.campusSelectionRequired ? campus?.campus : null,
        ),
        expectedGoogleEmail: _editingEmail!,
      );
      if (!mounted) return;
      ref.read(appSettingsProvider.notifier).state = repository.load();
      unawaited(
        ref
            .read(googleDriveSyncServiceProvider)
            .queueSettingsBackup()
            .catchError((_) {}),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseCampus(UniversityInstitution institution) async {
    if (_saving || !institution.campusSelectionRequired) return;
    FocusScope.of(context).unfocus();
    final campus = await showModalBottomSheet<University>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${institution.name} · ${context.tr('캠퍼스 선택')}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('university-campus-close'),
                    tooltip: context.tr('닫기'),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('university-campus-list'),
                children: [
                  for (final campus in institution.campuses)
                    ListTile(
                      key: ValueKey('university-campus-${campus.id}'),
                      selected: campus.id == _selected,
                      title: Text(campus.campus ?? campus.name),
                      subtitle: campus.region == null
                          ? null
                          : Text(campus.region!),
                      trailing: campus.id == _selected
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.pop(context, campus),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (campus == null || !mounted) return;
    setState(() {
      _selected = campus.id;
      _error = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appSettingsProvider);
    final email = ref
        .watch(settingsRepositoryProvider)
        .dailyAccount()
        ?.googleAccount
        ?.email;
    final directory = ref.watch(universityDirectoryProvider);
    final current = ref.watch(appSettingsProvider).academicProfile;
    final selectedCampus = directory.asData?.value.byId(_selected ?? '');
    final selectedInstitution =
        directory.asData?.value.institutionById(_selected ?? '') ??
        directory.asData?.value.institutionForCampus(_selected ?? '');
    return Scaffold(
      appBar: DailyNavigationBar(
        title: context.tr('학사 정보'),
        actions: [
          if (widget.onboarding)
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: Text(context.tr('나중에')),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                final minHeight = 520.0 + (scale > 1 ? scale - 1 : 0) * 340;
                return SingleChildScrollView(
                  primary: false,
                  child: SizedBox(
                    height: constraints.maxHeight < minHeight
                        ? minHeight
                        : constraints.maxHeight,
                    child: email == null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (current != null)
                                    Text(
                                      current.displayName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  Text(
                                    context.tr(
                                      'Google 계정을 연결하면 학사 정보를 저장하고 다른 기기에서도 사용할 수 있습니다.',
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const SettingsPage.account(),
                                      ),
                                    ),
                                    child: Text(context.tr('Google 계정 연결')),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  12,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      context.tr(
                                        '대학교를 선택하세요. 학사 정보는 Google Drive로 동기화됩니다.',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      key: const ValueKey('university-search'),
                                      enabled: !_saving,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.search),
                                        hintText: context.tr(
                                          '대학교 검색 · 초성 검색 가능',
                                        ),
                                      ),
                                      onChanged: (value) =>
                                          setState(() => _query = value),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: directory.when(
                                  loading: () => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  error: (_, _) => Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(context.tr('대학 목록을 불러오지 못했습니다.')),
                                        TextButton(
                                          onPressed: () => ref.invalidate(
                                            universityDirectoryProvider,
                                          ),
                                          child: Text(context.tr('다시 시도')),
                                        ),
                                      ],
                                    ),
                                  ),
                                  data: (data) {
                                    final schools = data.institutions
                                        .where(
                                          (school) =>
                                              school.selectable &&
                                              school.matchesQuery(_query),
                                        )
                                        .toList();
                                    if (schools.isEmpty) {
                                      return Center(
                                        child: Text(context.tr('검색 결과가 없습니다.')),
                                      );
                                    }
                                    return ListView.builder(
                                      key: const ValueKey('university-list'),
                                      itemCount: schools.length,
                                      itemBuilder: (context, index) {
                                        final school = schools[index];
                                        return ListTile(
                                          key: ValueKey(
                                            'university-${school.id}',
                                          ),
                                          selected:
                                              school.id ==
                                              selectedInstitution?.id,
                                          title: Text(school.name),
                                          subtitle: Text(
                                            [
                                                  school.campusSummary,
                                                  if (school
                                                      .supportsAcademicFeatures)
                                                    context.tr('학사일정 · 시간표 지원'),
                                                ]
                                                .whereType<String>()
                                                .where((s) => s.isNotEmpty)
                                                .join(' · '),
                                          ),
                                          trailing:
                                              school.id ==
                                                  selectedInstitution?.id
                                              ? const Icon(Icons.check_circle)
                                              : null,
                                          onTap: _saving
                                              ? null
                                              : () => setState(() {
                                                  if (!school
                                                      .campusSelectionRequired) {
                                                    _selected = school.id;
                                                  } else if (!school.campuses
                                                      .any(
                                                        (campus) =>
                                                            campus.id ==
                                                            _selected,
                                                      )) {
                                                    _selected =
                                                        (school.campuses
                                                                    .where(
                                                                      (
                                                                        campus,
                                                                      ) => campus
                                                                          .matchesQuery(
                                                                            _query,
                                                                          ),
                                                                    )
                                                                    .firstOrNull ??
                                                                school
                                                                    .campuses
                                                                    .first)
                                                            .id;
                                                  }
                                                  _editingEmail = email;
                                                  _error = false;
                                                }),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                              Container(
                                key: const ValueKey(
                                  'academic-profile-selection-footer',
                                ),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: DailyUi.separator(context),
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (selectedInstitution != null) ...[
                                      Text(
                                        selectedInstitution.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      if (selectedInstitution
                                              .campusSelectionRequired &&
                                          selectedCampus != null)
                                        ListTile(
                                          key: const ValueKey(
                                            'academic-profile-campus',
                                          ),
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(context.tr('캠퍼스')),
                                          subtitle: Text(
                                            [
                                                  selectedCampus.campus ??
                                                      selectedCampus.name,
                                                  selectedCampus.region,
                                                ]
                                                .whereType<String>()
                                                .where(
                                                  (value) => value.isNotEmpty,
                                                )
                                                .join(' · '),
                                          ),
                                          trailing: const Icon(
                                            Icons.expand_more,
                                          ),
                                          onTap: _saving
                                              ? null
                                              : () => _chooseCampus(
                                                  selectedInstitution,
                                                ),
                                        ),
                                      if (!selectedInstitution
                                              .campusSelectionRequired &&
                                          selectedInstitution
                                              .campusSummary
                                              .isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            selectedInstitution.campusSummary,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ),
                                      if (!selectedInstitution
                                          .supportsAcademicFeatures)
                                        Text(
                                          context.tr(
                                            '학사 정보는 저장할 수 있습니다. 이 대학의 학사일정·시간표 연동은 준비 중입니다.',
                                          ),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      const SizedBox(height: 8),
                                    ],
                                    if (_error)
                                      Text(
                                        context.tr(
                                          '학사 정보를 저장하지 못했습니다. 계정 연결을 확인하고 다시 시도해 주세요.',
                                        ),
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                    FilledButton(
                                      key: const ValueKey(
                                        'academic-profile-save',
                                      ),
                                      onPressed:
                                          _saving ||
                                              selectedInstitution == null ||
                                              !selectedInstitution.selectable ||
                                              (selectedInstitution
                                                      .campusSelectionRequired &&
                                                  selectedCampus == null)
                                          ? null
                                          : () => _save(
                                              selectedInstitution,
                                              selectedCampus,
                                            ),
                                      child: Text(
                                        context.tr(_saving ? '저장 중' : '저장'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Availability follows the saved school rather than a global SMU assumption.
class AcademicFeatureGate extends ConsumerWidget {
  const AcademicFeatureGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(appSettingsProvider).academicProfile;
    if (profile?.supported == true) return child;
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school_outlined, size: 36),
              const SizedBox(height: 16),
              if (profile != null)
                Text(
                  profile.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              Text(
                context.tr(
                  profile == null
                      ? '학사 정보를 설정하면 지원되는 대학의 학사일정과 시간표를 사용할 수 있습니다.'
                      : '이 대학의 학사일정·시간표 연동은 준비 중입니다.',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('academic-profile-open'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<bool>(
                    builder: (_) => const AcademicProfilePage(),
                  ),
                ),
                child: Text(
                  context.tr(profile == null ? '학사 정보 설정' : '학사 정보 변경'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
