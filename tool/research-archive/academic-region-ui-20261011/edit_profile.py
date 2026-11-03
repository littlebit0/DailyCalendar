from pathlib import Path
p=Path('lib/features/settings/presentation/academic_profile_page.dart');s=p.read_text();Path('work/academic-region-ui-20261011/academic_profile_page.before.dart').write_text(s)
s=s.replace("import '../../../core/academic/university_directory.dart';", "import '../../../core/academic/university_directory.dart';\nimport '../../../core/academic/university_regions.dart';\nimport 'university_region_map.dart';")
s=s.replace('Future<void> offerAcademicProfile',"final universityRegionsProvider = FutureProvider<UniversityRegions>(\n  (ref) => UniversityRegions.load(),\n);\n\nFuture<void> offerAcademicProfile")
s=s.replace("  String _query = '';", "  String _query = '';\n  String? _region;")
s=s.replace('maxWidth: 760','maxWidth: 1400')
start=s.index('                              Padding(',s.index('                        : Column('));end=s.index('                              Container(',start)
s=s[:start]+'''                              Expanded(
                                child: directory.when(
                                  loading: () => const Center(child: CircularProgressIndicator()),
                                  error: (_, _) => _loadError(),
                                  data: (data) => ref.watch(universityRegionsProvider).when(
                                    loading: () => const Center(child: CircularProgressIndicator()),
                                    error: (_, _) => _loadError(),
                                    data: (regions) => _picker(data, regions, selectedInstitution),
                                  ),
                                ),
                              ),
'''+s[end:]
s=s.replace("                                      Text(\n                                        selectedInstitution.name,", "                                      Text(context.tr('선택한 학사 정보'), style: Theme.of(context).textTheme.labelSmall),\n                                      const SizedBox(height: 4),\n                                      Text(\n                                        selectedInstitution.name,")
mark='  @override\n  Widget build(BuildContext context) {'
methods='''  Widget _loadError() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Text(context.tr('대학 목록을 불러오지 못했습니다.')),
    TextButton(onPressed: () {
      ref.invalidate(universityDirectoryProvider);
      ref.invalidate(universityRegionsProvider);
    }, child: Text(context.tr('다시 시도'))),
  ]));

  void _selectInstitution(UniversityInstitution school) {
    if (_saving) return;
    setState(() {
      if (!school.campusSelectionRequired) {
        _selected = school.id;
      } else if (!school.campuses.any((campus) => campus.id == _selected)) {
        _selected = (school.campuses.where((campus) => campus.matchesQuery(_query)).firstOrNull ?? school.campuses.first).id;
      }
      _editingEmail = ref.read(settingsRepositoryProvider).dailyAccount()?.googleAccount?.email;
      _error = false;
    });
  }

  Widget _supportTag(String text, IconData icon, {bool active = true}) {
    final colors = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: active ? colors.secondaryContainer : colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: active ? colors.onSecondaryContainer : colors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(context.tr(text), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: active ? colors.onSecondaryContainer : colors.onSurfaceVariant)),
      ]),
    );
  }

  Widget _picker(UniversityDirectory directory, UniversityRegions regions, UniversityInstitution? selected) {
    final colors = Theme.of(context).colorScheme;
    final schools = directory.searchInstitutions(_query).where((school) => regions.includes(school.id, _region)).toList();
    final regionName = regions.byId(_region)?.name;
    final map = UniversityRegionMap(data: regions, selected: _region, onSelected: _saving ? null : (id) => setState(() => _region = id));
    Widget listPanel({required bool wide}) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.tr('대학교를 선택하세요.'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        TextField(key: const ValueKey('university-search'), enabled: !_saving,
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: context.tr('대학교 검색 · 초성 검색 가능')),
          onChanged: (value) => setState(() => _query = value)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (!wide) OutlinedButton.icon(key: const ValueKey('university-region-picker'), onPressed: _saving ? null : () async {
            FocusScope.of(context).unfocus();
            final choice = await showModalBottomSheet<String>(context: context, isScrollControlled: true, useSafeArea: true,
              builder: (context) => SizedBox(height: MediaQuery.sizeOf(context).height * .85,
                child: UniversityRegionMap(data: regions, selected: _region, onSelected: (id) => Navigator.pop(context, id ?? 'all'))));
            if (choice != null && mounted) setState(() => _region = choice == 'all' ? null : choice);
          }, icon: const Icon(Icons.map_outlined, size: 18), label: Text(context.tr('지역 선택'))),
          if (regionName != null) InputChip(key: const ValueKey('university-region-filter'), label: Text(context.tr(regionName)), onDeleted: _saving ? null : () => setState(() => _region = null))
          else Text(context.tr('전체 지역'), style: Theme.of(context).textTheme.labelMedium),
          Text('${schools.length}${context.tr('개 대학')}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant)),
        ]),
      ])),
      Expanded(child: schools.isEmpty ? Center(child: Text(context.tr('검색 결과가 없습니다.'))) : ListView.separated(
        key: const ValueKey('university-list'), padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), itemCount: schools.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final school = schools[index];
          final chosen = school.id == selected?.id;
          final hasTimetable = AcademicProfile(universityId: school.id, universityName: school.name, schoolKind: school.kind.name).timetableUniversity != null;
          return Container(decoration: BoxDecoration(color: chosen ? colors.primaryContainer.withValues(alpha: .35) : colors.surfaceContainerLow,
            border: Border.all(color: chosen ? colors.primary : DailyUi.separator(context)), borderRadius: BorderRadius.circular(12)),
            child: ListTile(key: ValueKey('university-${school.id}'), selected: chosen,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              title: Text(school.name, style: Theme.of(context).textTheme.titleSmall),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 5),
                if (school.campusSummary.isNotEmpty) Text(school.campusSummary, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant))
                else Text('${context.tr('소재지')} · ${regions.namesFor(school.id).join(' · ')}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 5, children: [
                  _supportTag(school.supportsAcademicCalendar ? '학사일정 지원' : '학사일정 준비 중', Icons.calendar_month_outlined, active: school.supportsAcademicCalendar),
                  _supportTag(hasTimetable ? '시간표 연결' : '시간표 준비 중', Icons.grid_view_outlined, active: hasTimetable),
                ]),
              ]),
              trailing: chosen ? Icon(Icons.check_circle, color: colors.primary) : null,
              onTap: _saving ? null : () => _selectInstitution(school),
            ),
          );
        },
      )),
    ]);
    return Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: LayoutBuilder(builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final wide = constraints.maxWidth >= 900 && scale <= 1.5;
      Widget panel(Widget child) => Container(decoration: BoxDecoration(border: Border.all(color: DailyUi.separator(context)), borderRadius: BorderRadius.circular(14)), clipBehavior: Clip.antiAlias, child: child);
      if (!wide) return panel(listPanel(wide: false));
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(flex: 4, child: panel(map)), const SizedBox(width: 12),
        Expanded(flex: 5, child: panel(listPanel(wide: true))),
      ]);
    }));
  }

'''
s=s.replace(mark,methods+mark,1);p.write_text(s)
