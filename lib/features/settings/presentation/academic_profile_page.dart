import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/academic/academic_profile.dart';
import '../../../core/academic/university_support_policy.dart';
import '../../../core/academic/university_directory.dart';
import '../../../core/academic/university_regions.dart';
import 'university_region_map.dart';
import '../../../core/di/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/daily_ui.dart';
import 'settings_page.dart';
import '../../../core/lms/lms_controller.dart';
import '../../../core/widgets/smooth_mouse_wheel_scroll_controller.dart';

final universityDirectoryProvider = FutureProvider<UniversityDirectory>(
  (ref) => UniversityDirectory.load(),
);

final universityRegionsProvider = FutureProvider<UniversityRegions>(
  (ref) => UniversityRegions.load(),
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
  String? _region;
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
      final previous = repository.load().academicProfile;
      final selected = AcademicProfile(
        universityId: institution.id,
        universityName: institution.name,
        schoolKind: institution.kind.name,
      );
      final sameSchool =
          previous?.timetableUniversity != null &&
          previous!.timetableUniversity == selected.timetableUniversity;
      await repository.saveAcademicProfile(
        AcademicProfile(
          lmsCategoryId: previous?.lmsCategoryId,
          lmsUserId: sameSchool ? previous.lmsUserId : null,
          lmsIntegrationEnabled: sameSchool
              ? previous.lmsIntegrationEnabled
              : null,
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

  Widget _loadError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.tr('대학 목록을 불러오지 못했습니다.')),
        TextButton(
          onPressed: () {
            ref.invalidate(universityDirectoryProvider);
            ref.invalidate(universityRegionsProvider);
          },
          child: Text(context.tr('다시 시도')),
        ),
      ],
    ),
  );

  void _selectInstitution(
    UniversityInstitution school,
    UniversityRegions regions,
  ) {
    if (_saving) return;
    setState(() {
      if (!school.campusSelectionRequired) {
        _selected = school.id;
      } else {
        final regionalCampuses = _region == null
            ? const <University>[]
            : school.campuses
                  .where(
                    (campus) => regions.includesCampus(campus.id, _region!),
                  )
                  .toList();
        final candidates = regionalCampuses.isEmpty
            ? school.campuses
            : regionalCampuses;
        // A regional choice overrides a previously selected branch elsewhere.
        // An ambiguous or unfiltered choice retains the existing campus picker.
        if (!candidates.any((campus) => campus.id == _selected)) {
          _selected =
              (candidates
                          .where((campus) => campus.matchesQuery(_query))
                          .firstOrNull ??
                      candidates.first)
                  .id;
        }
      }
      _editingEmail = ref
          .read(settingsRepositoryProvider)
          .dailyAccount()
          ?.googleAccount
          ?.email;
      _error = false;
    });
  }

  Widget _supportTag(String text, IconData icon, {bool active = true}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? colors.secondaryContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            icon,
            size: 13,
            color: active
                ? colors.onSecondaryContainer
                : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            context.tr(text),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: active
                  ? colors.onSecondaryContainer
                  : colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _picker(
    UniversityDirectory directory,
    UniversityRegions regions,
    UniversityInstitution? selected,
  ) {
    final colors = Theme.of(context).colorScheme;
    final schools = directory
        .searchInstitutions(_query)
        .where((school) => regions.includes(school.id, _region))
        .toList();
    final regionName = regions.byId(_region)?.name;
    final map = UniversityRegionMap(
      data: regions,
      selected: _region,
      onSelected: _saving ? null : (id) => setState(() => _region = id),
    );
    Widget listPanel({required bool wide}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('대학교를 선택하세요.'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('university-search'),
                enabled: !_saving,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: context.tr('대학교 검색 · 초성 검색 가능'),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (!wide)
                    OutlinedButton.icon(
                      key: const ValueKey('university-region-picker'),
                      onPressed: _saving
                          ? null
                          : () async {
                              FocusScope.of(context).unfocus();
                              final choice = await showModalBottomSheet<String>(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                builder: (context) => SizedBox(
                                  height:
                                      MediaQuery.sizeOf(context).height * .85,
                                  child: UniversityRegionMap(
                                    data: regions,
                                    selected: _region,
                                    onSelected: (id) =>
                                        Navigator.pop(context, id ?? 'all'),
                                  ),
                                ),
                              );
                              if (choice != null && mounted) {
                                setState(
                                  () =>
                                      _region = choice == 'all' ? null : choice,
                                );
                              }
                            },
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: Text(context.tr('지역 선택')),
                    ),
                  if (regionName != null)
                    InputChip(
                      key: const ValueKey('university-region-filter'),
                      label: Text(context.tr(regionName)),
                      onDeleted: _saving
                          ? null
                          : () => setState(() => _region = null),
                    )
                  else
                    Text(
                      context.tr('전체 지역'),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  Text(
                    schools.length == 1
                        ? context.tr('대학 1개')
                        : context.tr(
                            '대학 {count}개',
                            args: {'count': schools.length},
                          ),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            key: const ValueKey('university-region-transition'),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: RepaintBoundary(child: child),
            ),
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: [
                for (final child in previous)
                  ExcludeSemantics(child: IgnorePointer(child: child)),
                ?current,
              ],
            ),
            child: KeyedSubtree(
              key: ValueKey(_region ?? 'all'),
              child: schools.isEmpty
                  ? Center(child: Text(context.tr('검색 결과가 없습니다.')))
                  : _SmoothUniversityList(
                      itemCount: schools.length,
                      itemBuilder: (context, index) {
                        final school = schools[index];
                        final chosen = school.id == selected?.id;
                        final profile = AcademicProfile(
                          universityId: school.id,
                          universityName: school.name,
                          schoolKind: school.kind.name,
                        );
                        final hasTimetable = profile.timetableSupported;
                        final hasCalendar = profile.academicSourceId != null;
                        final hasLms = LmsController.supportsSchool(
                          profile.timetableUniversity,
                        );
                        final sourcedCaption =
                            regions.captionFor(school.id) ?? '';
                        final campusSummary = school.campusNames.length > 1
                            ? school.campusSummary
                            : sourcedCaption.contains(' / ')
                            ? sourcedCaption
                            : '';
                        final location = regions
                            .namesFor(school.id)
                            .join(' · ');
                        return Material(
                          color: chosen
                              ? colors.primaryContainer.withValues(alpha: .35)
                              : colors.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: chosen
                                  ? colors.primary
                                  : DailyUi.separator(context),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            key: ValueKey('university-${school.id}'),
                            selected: chosen,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            leading:
                                regions.logoUnavailableInstitutionIds.contains(
                                  school.id,
                                )
                                ? null
                                : Container(
                                    key: ValueKey(
                                      'university-logo-${school.id}',
                                    ),
                                    width: 64,
                                    height: 48,
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Image.asset(
                                      'assets/academic/logos/${school.id.replaceAll(':', '-')}.png',
                                      fit: BoxFit.contain,
                                      color:
                                          regions.logoForegroundColors[school
                                                  .id] ==
                                              null
                                          ? null
                                          : Color(
                                              regions
                                                  .logoForegroundColors[school
                                                  .id]!,
                                            ),
                                      excludeFromSemantics: true,
                                    ),
                                  ),
                            title: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    school.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                ),
                                if (location.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      location,
                                      key: ValueKey(
                                        'university-location-${school.id}',
                                      ),
                                      textAlign: TextAlign.end,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (campusSummary.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    campusSummary,
                                    key: ValueKey(
                                      'university-campuses-${school.id}',
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 5,
                                  children: [
                                    _supportTag(
                                      hasCalendar ? '학사일정 지원' : '학사일정 준비 중',
                                      Icons.calendar_month_outlined,
                                      active: hasCalendar,
                                    ),
                                    _supportTag(
                                      hasTimetable ? '시간표 연결' : '시간표 준비 중',
                                      Icons.grid_view_outlined,
                                      active: hasTimetable,
                                    ),
                                    _supportTag(
                                      hasLms ? 'LMS 지원' : 'LMS 미지원',
                                      Icons.school_outlined,
                                      active: hasLms,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: chosen
                                ? Icon(
                                    Icons.check_circle,
                                    color: colors.primary,
                                  )
                                : null,
                            onTap: _saving
                                ? null
                                : () => _selectInstitution(school, regions),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final wide = constraints.maxWidth >= 900 && scale <= 1.5;
          Widget panel(Widget child) => Container(
            decoration: BoxDecoration(
              border: Border.all(color: DailyUi.separator(context)),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          );
          if (!wide) return panel(listPanel(wide: false));
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: math.min(
                  constraints.maxWidth * .42,
                  math.max(0, constraints.maxHeight - 56) *
                          UniversityMapProjection.aspectRatio +
                      12,
                ),
                child: panel(map),
              ),
              const SizedBox(width: 12),
              Expanded(child: panel(listPanel(wide: true))),
            ],
          );
        },
      ),
    );
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
    final regionDirectory = ref.watch(universityRegionsProvider);
    final current = ref.watch(appSettingsProvider).academicProfile;
    final selectedCampus = directory.asData?.value.byId(_selected ?? '');
    final selectedInstitution =
        directory.asData?.value.institutionById(_selected ?? '') ??
        directory.asData?.value.institutionForCampus(_selected ?? '');
    final selectedCaption = selectedInstitution == null
        ? ''
        : regionDirectory.asData?.value.captionFor(selectedInstitution.id) ??
              selectedInstitution.campusSummary;
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
            constraints: const BoxConstraints(maxWidth: 1400),
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
                              Expanded(
                                child: directory.when(
                                  loading: () => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  error: (_, _) => _loadError(),
                                  data: (data) => regionDirectory.when(
                                    loading: () => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    error: (_, _) => _loadError(),
                                    data: (regions) => _picker(
                                      data,
                                      regions,
                                      selectedInstitution,
                                    ),
                                  ),
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
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final details = Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (selectedInstitution != null) ...[
                                          Text(
                                            context.tr('선택한 학사 정보'),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelSmall,
                                          ),
                                          const SizedBox(height: 4),
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
                                                      (value) =>
                                                          value.isNotEmpty,
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
                                              selectedCaption.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              child: Text(
                                                selectedCaption,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ),
                                          if (AcademicProfile(
                                                universityId:
                                                    selectedInstitution.id,
                                                universityName:
                                                    selectedInstitution.name,
                                                schoolKind: selectedInstitution
                                                    .kind
                                                    .name,
                                              ).academicSourceId ==
                                              null)
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
                                      ],
                                    );
                                    final save = Align(
                                      alignment: Alignment.centerRight,
                                      child: SizedBox(
                                        width:
                                            MediaQuery.sizeOf(context).width >=
                                                900
                                            ? 160
                                            : double.infinity,
                                        child: FilledButton(
                                          key: const ValueKey(
                                            'academic-profile-save',
                                          ),
                                          onPressed:
                                              _saving ||
                                                  selectedInstitution == null ||
                                                  !selectedInstitution
                                                      .selectable ||
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
                                      ),
                                    );
                                    if (constraints.maxWidth >= 900 &&
                                        MediaQuery.textScalerOf(
                                              context,
                                            ).scale(14) <=
                                            21) {
                                      return Row(
                                        children: [
                                          Expanded(child: details),
                                          const SizedBox(width: 16),
                                          SizedBox(width: 160, child: save),
                                        ],
                                      );
                                    }
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [details, save],
                                    );
                                  },
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
  const AcademicFeatureGate({
    super.key,
    required this.child,
    this.calendar = false,
  });
  final Widget child;
  final bool calendar;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(appSettingsProvider).academicProfile;
    if (calendar
        ? profile?.academicSourceId != null
        : profile?.timetableSupported == true ||
              (profile?.timetableCampus != null &&
                  UniversitySupportPolicy.suspendedTimetableUniversities
                      .contains(profile!.timetableUniversity))) {
      return child;
    }
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

/// Separate positions keep rapid region changes from sharing a scroll activity.
class _SmoothUniversityList extends StatefulWidget {
  const _SmoothUniversityList({
    required this.itemCount,
    required this.itemBuilder,
  });
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  @override
  State<_SmoothUniversityList> createState() => _SmoothUniversityListState();
}

class _SmoothUniversityListState extends State<_SmoothUniversityList> {
  final _controller = SmoothMouseWheelScrollController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView.separated(
    key: const ValueKey('university-list'),
    controller: _controller,
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    itemCount: widget.itemCount,
    separatorBuilder: (_, _) => const SizedBox(height: 6),
    itemBuilder: widget.itemBuilder,
  );
}
