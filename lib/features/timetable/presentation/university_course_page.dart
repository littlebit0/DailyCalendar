import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/academic/university_support_policy.dart';
import '../../../core/widgets/smooth_mouse_wheel_scroll_controller.dart';
import '../domain/course_organization.dart';
import '../data/timetable_store.dart';
import '../data/university_catalog.dart';
import '../domain/timetable.dart';
import '../domain/timetable_colors.dart';
import '../domain/university_course.dart';

/// A full-screen host for callers that do not have a timetable preview beside it.
class UniversityCoursePage extends StatelessWidget {
  const UniversityCoursePage({
    super.key,
    required this.store,
    this.loadCatalog = UniversityCatalog.load,
    this.initialCampus,
    this.university = 'smu',
  });
  final Future<List<UniversityDataset>> Function() loadCatalog;
  final TimetableStore store;
  final String? initialCampus;
  final String university;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('학교 시간표에서 선택'))),
    body: SafeArea(
      top: false,
      child: UniversityCoursePanel(
        store: store,
        loadCatalog: loadCatalog,
        initialCampus: initialCampus,
        university: university,
        onAdd: (course, mode) async {
          await store.save(
            TimetableClass.fromJson({
              ...course.toTimetable(id: const Uuid().v4(), mode: mode).toJson(),
              'colorValue': selectNewCourseColor(store.activeClasses),
            }),
          );
          return true;
        },
      ),
    ),
  );
}

/// Search results expand in place. A candidate is not saved until the user
/// chooses a lecture mode and confirms the addition.
class UniversityCoursePanel extends StatefulWidget {
  const UniversityCoursePanel({
    super.key,
    required this.store,
    this.loadCatalog = UniversityCatalog.load,
    required this.onAdd,
    this.onPreviewChanged,
    this.initialCampus,
    this.university = 'smu',
  });
  final TimetableStore store;
  final Future<List<UniversityDataset>> Function() loadCatalog;
  final Future<bool> Function(UniversityCourse, LectureMode) onAdd;
  final ValueChanged<UniversityCourse?>? onPreviewChanged;
  final String? initialCampus;
  final String university;

  @override
  State<UniversityCoursePanel> createState() => _UniversityCoursePanelState();
}

class _UniversityCoursePanelState extends State<UniversityCoursePanel> {
  Map<String, String?> _catalogCampuses = {};
  int _catalogGeneration = 0;
  List<String> get _campuses => _catalogCampuses.isNotEmpty
      ? _catalogCampuses.keys.toList()
      : switch (widget.university) {
          'dku' => const ['jukjeon', 'cheonan'],
          'cau' => const ['seoul', 'davinci'],
          'jnu' => const ['gwangju', 'yeosu'],
          'smu' => const ['seoul', 'cheonan'],
          _ => const ['main'],
        };

  Future<List<UniversityDataset>> _loadCatalog() async {
    final generation = ++_catalogGeneration;
    if (!UniversitySupportPolicy.timetableAvailable(widget.university)) {
      return const [];
    }
    final datasets = await (widget.loadCatalog == UniversityCatalog.load
        ? UniversityCatalog.load(university: widget.university)
        : widget.loadCatalog());
    final campuses = <String, String?>{};
    for (final dataset in datasets.where(
      (d) => d.university == widget.university,
    )) {
      final previous = campuses[dataset.campus];
      if (previous != null &&
          dataset.campusName != null &&
          previous != dataset.campusName) {
        throw const FormatException('Conflicting catalog campus names');
      }
      campuses[dataset.campus] = dataset.campusName ?? previous;
    }
    if (mounted && generation == _catalogGeneration) {
      setState(() {
        _catalogCampuses = campuses;
        if (!_campuses.contains(_campus)) {
          _campus = _campuses.first;
          _organization = null;
          _sourceDepartment = null;
          _category = null;
          _resetSelection();
        }
      });
    }
    return datasets;
  }

  late Future<List<UniversityDataset>> _catalog = _loadCatalog();
  final _search = TextEditingController();
  late String _campus = widget.initialCampus ?? _campuses.first;
  CourseOrganization? _organization;
  String? _sourceDepartment;
  final _scroll = SmoothMouseWheelScrollController();
  String? _category;
  String _query = '';
  bool _hideConflicts = false;
  bool _filtersVisible = false;
  UniversityCourse? _selected;
  bool _adding = false;
  late int _year = widget.store.activeYear;
  late String _semester = widget.store.activeSemester;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_storeChanged);
  }

  @override
  void didUpdateWidget(covariant UniversityCoursePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_storeChanged);
      widget.store.addListener(_storeChanged);
      // A new host owns its preview; do not notify it during this build.
      _year = widget.store.activeYear;
      _semester = widget.store.activeSemester;
      _organization = null;
      _sourceDepartment = null;
      _resetSelection();
    }
    if (oldWidget.loadCatalog != widget.loadCatalog ||
        oldWidget.university != widget.university) {
      _catalogCampuses = {};
      _catalog = _loadCatalog();
    }
    if (oldWidget.initialCampus != widget.initialCampus ||
        oldWidget.university != widget.university) {
      _campus = widget.initialCampus ?? _campuses.first;
      _organization = null;
      _sourceDepartment = null;
      _category = null;
      _resetSelection();
    }
  }

  void _storeChanged() {
    final termChanged =
        _year != widget.store.activeYear ||
        _semester != widget.store.activeSemester;
    final selectedWasSaved =
        _selected != null &&
        widget.store.activeClasses.any(
          (course) => course.sourceId == _selected!.sourceId,
        );
    final clearPreview = _selected != null && (termChanged || selectedWasSaved);
    setState(() {
      if (termChanged) {
        _year = widget.store.activeYear;
        _semester = widget.store.activeSemester;
        _organization = null;
        _sourceDepartment = null;
        _category = null;
      }
      if (termChanged) _resetSelection();
    });
    if (clearPreview) widget.onPreviewChanged?.call(null);
  }

  void _resetSelection() {
    _selected = null;
  }

  void _changeFilter(VoidCallback update) {
    if (_adding) return;
    final hadPreview = _selected != null;
    setState(() {
      update();
      _resetSelection();
    });
    if (hadPreview) widget.onPreviewChanged?.call(null);
  }

  void _select(UniversityCourse course) {
    if (_adding) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _selected = _selected?.sourceId == course.sourceId ? null : course;
      _filtersVisible = false;
    });
    final alreadyAdded = widget.store.activeClasses.any(
      (saved) => saved.sourceId == _selected?.sourceId,
    );
    widget.onPreviewChanged?.call(alreadyAdded ? null : _selected);
  }

  Future<bool> _add(UniversityCourse course, LectureMode mode) async {
    if (_adding) return false;
    setState(() => _adding = true);
    try {
      final success = await widget.onAdd(course, mode);
      if (success && mounted) widget.onPreviewChanged?.call(null);
      return success;
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_storeChanged);
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _campusName(String campus) =>
      _catalogCampuses[campus] ??
      context.tr(switch (campus) {
        'seoul' => '서울캠퍼스',
        'jukjeon' => '죽전캠퍼스',
        'davinci' => '다빈치캠퍼스',
        'gwangju' => '광주캠퍼스',
        'yeosu' => '여수캠퍼스',
        'cheonan' => '천안캠퍼스',
        'main' => '전체',
        _ => campus,
      });

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_adding,
    child: AbsorbPointer(
      absorbing: _adding,
      child: FutureBuilder<List<UniversityDataset>>(
        future: _catalog,
        builder: (context, snapshot) {
          if (!UniversitySupportPolicy.timetableAvailable(widget.university)) {
            return _CatalogMessage(
              icon: Icons.school_outlined,
              message: context.tr('해당 대학의 학교 시간표는 현재 미지원입니다.'),
            );
          }
          // A replacement future can retain the previous school snapshot.
          // Its campus and category filters are no longer valid while loading.
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _CatalogMessage(
              icon: Icons.cloud_off_outlined,
              message: context.tr('강의 목록을 불러오지 못했습니다.'),
              action: TextButton.icon(
                onPressed: () {
                  final catalog = _loadCatalog();
                  setState(() {
                    _catalog = catalog;
                  });
                },
                icon: const Icon(Icons.refresh),
                label: Text(context.tr('다시 시도')),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _catalogView(snapshot.data!);
        },
      ),
    ),
  );

  void _selectOrganization(CourseOrganization? unit) => _changeFilter(() {
    _organization = unit;
    _sourceDepartment = null;
    _category = null;
  });

  // Department lookup contains major courses for every supported school.
  bool _matchesUnit(UniversityCourse course) =>
      (_organization == null ||
          (course.matchesOrganization(_organization!) &&
              (_organization!.isCollegeHosted ||
                  course.isMajorForOrganization(_organization!)))) &&
      (_sourceDepartment == null ||
          (course.departments.contains(_sourceDepartment) &&
              course.isMajorForSourceDepartment(_sourceDepartment!)));

  List<String> _classificationLabels(UniversityCourse course) {
    if (_sourceDepartment case final String department) {
      return course.majorClassificationLabelsForSourceDepartment(department);
    }
    if (_organization case final CourseOrganization unit
        when !unit.isCollegeHosted) {
      return course.majorClassificationLabelsForOrganization(unit);
    }
    return course.classificationLabelsForOrganization(_organization);
  }

  Widget _departmentChoices(List<CourseOrganization> units) => Align(
    alignment: Alignment.centerLeft,
    child: Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final unit in units)
          ChoiceChip(
            key: ValueKey('course-department-${unit.key}'),
            label: Text(unit.department!),
            selected: _organization?.key == unit.key,
            onSelected: (selected) =>
                _selectOrganization(selected ? unit : null),
          ),
      ],
    ),
  );

  Widget _catalogView(List<UniversityDataset> catalog) {
    final theme = Theme.of(context);
    final datasets = catalog
        .where(
          (d) =>
              d.universityId == widget.university &&
              d.campus == _campus &&
              d.courses.any(
                (c) => c.academicYear == _year && c.semester == _semester,
              ),
        )
        .toList();
    final all = datasets
        .expand((d) => d.courses)
        .where((c) => c.academicYear == _year && c.semester == _semester)
        .toList();
    final organizations = <String, CourseOrganization>{
      for (final course in all)
        for (final unit in course.offeringOrganizations)
          if (unit.isCollegeHosted || course.isMajorForOrganization(unit))
            '${unit.key}\u0000${unit.displayGroup}': unit,
    }.values.toList()..sort((a, b) => a.label.compareTo(b.label));
    final colleges =
        organizations
            .where((unit) => unit.isCollegeHosted)
            .map((unit) => unit.college)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
    final departmentGroups = <String?, List<CourseOrganization>>{};
    for (final unit in organizations.where((unit) => unit.department != null)) {
      (departmentGroups[unit.displayGroup] ??= []).add(unit);
    }
    // Preserve source filters where no verified academic organization exists.
    // Cohort and administration labels remain literal, without guessed parents.
    final sourceDepartments =
        all
            .expand(
              (course) => course.departments.where(
                (label) =>
                    course.isMajorForSourceDepartment(label) &&
                    !course.offeringOrganizations.any(
                      (unit) => unit.sourceLabel == label,
                    ),
              ),
            )
            .where((label) => label.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final availableLabels = all
        .where(_matchesUnit)
        .expand(_classificationLabels)
        .toSet();
    final categoryLabels = [
      for (final category in CourseCategory.values)
        if (availableLabels.remove(category.label)) category.label,
      ...(availableLabels.toList()..sort()),
    ];
    final activeCategory = categoryLabels.contains(_category)
        ? _category
        : null;
    final saved = widget.store.activeClasses;
    final conflicts = {
      for (final course in all)
        course.sourceId: _conflictingClasses(course, saved),
    };
    final courses = all.where((course) {
      if (!_matchesUnit(course)) {
        return false;
      }
      if (activeCategory != null &&
          !_classificationLabels(course).contains(activeCategory)) {
        return false;
      }
      if (_hideConflicts && conflicts[course.sourceId]!.isNotEmpty) {
        return false;
      }
      return course.matchesQuery(_query);
    }).toList();
    if (_query.trim().isNotEmpty) {
      courses.sort((a, b) {
        final ranked = a.queryRank(_query).compareTo(b.queryRank(_query));
        if (ranked != 0) return ranked;
        final title = a.title.compareTo(b.title);
        if (title != 0) return title;
        final code = a.code.compareTo(b.code);
        if (code != 0) return code;
        return (int.tryParse(a.section) ?? 0).compareTo(
          int.tryParse(b.section) ?? 0,
        );
      });
    }
    final addedIds = saved
        .map((course) => course.sourceId)
        .whereType<String>()
        .toSet();
    final courseIndices = {
      for (final (index, course) in courses.indexed)
        'course-card-${course.sourceId}': index,
    };
    final hasFilters =
        _organization != null ||
        _sourceDepartment != null ||
        activeCategory != null ||
        _hideConflicts ||
        _campus != (widget.initialCampus ?? _campuses.first);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('course-search'),
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    hintText: context.tr('과목명 · 과목코드 · 교수 · 초성 검색'),
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: context.tr('검색어 지우기'),
                            onPressed: () => _changeFilter(() {
                              _search.clear();
                              _query = '';
                            }),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => _changeFilter(() => _query = value),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: (MediaQuery.sizeOf(context).width * .22).clamp(120, 240),
                child: FilledButton.tonal(
                  key: const ValueKey('course-filters-toggle'),
                  onPressed: () =>
                      setState(() => _filtersVisible = !_filtersVisible),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: hasFilters
                        ? theme.colorScheme.primaryContainer
                        : null,
                  ),
                  child: Text(context.tr('학과 선택')),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: CustomScrollView(
            key: const ValueKey('university-course-panel'),
            controller: _scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            context.tr(switch (widget.university) {
                              'inje' => '인제대학교',
                              'hongik' => '홍익대학교',
                              'wsu' => '우송대학교',
                              'sunmoon' => '선문대학교',
                              'dju' => '대전대학교',
                              'iccu' => '인천가톨릭대학교',
                              'ewha' => '이화여자대학교',
                              'eulji' => '을지대학교',
                              'hansei' => '한세대학교',
                              'hyupsung' => '협성대학교',
                              'sungkyul' => '성결대학교',
                              'sangji' => '상지대학교',
                              'nambu' => '남부대학교',
                              'kangnam' => '강남대학교',
                              'pcu' => '배재대학교',
                              'dku' => '단국대학교',
                              'jnu' => '전남대학교',
                              'smu' => '상명대학교',
                              'snu' => '서울대학교',
                              'ajou' => '아주대학교',
                              'cau' => '중앙대학교',
                              'sejong' => '세종대학교',
                              _ => widget.university,
                            }),
                            style: theme.textTheme.labelMedium,
                          ),
                          DropdownButton<String>(
                            key: const ValueKey('course-campus'),
                            value: _campus,
                            isDense: true,
                            underline: const SizedBox.shrink(),
                            style: theme.textTheme.labelMedium,
                            items: [
                              for (final campus in _campuses)
                                DropdownMenuItem(
                                  value: campus,
                                  child: Text(_campusName(campus)),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null || value == _campus) return;
                              FocusScope.of(context).unfocus();
                              _changeFilter(() {
                                _campus = value;
                                _organization = null;
                                _sourceDepartment = null;
                                _category = null;
                              });
                            },
                          ),
                        ],
                      ),
                      if (categoryLabels.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          key: const ValueKey('course-category-row'),
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final label in <String?>[
                                null,
                                ...categoryLabels,
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    key: ValueKey(
                                      'course-category-${label == null ? 'all' : _categoryForLabel(label)?.name ?? 'native-$label'}',
                                    ),
                                    selected: activeCategory == label,
                                    showCheckmark: false,
                                    visualDensity: VisualDensity.compact,
                                    label: label == null
                                        ? Text(context.tr('전체'))
                                        : CourseCategoryLabel(
                                            category:
                                                _categoryForLabel(label) ??
                                                CourseCategory.unknown,
                                            label: label,
                                          ),
                                    onSelected: (_) =>
                                        _changeFilter(() => _category = label),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            '$_year $_semester${context.tr('학기')}',
                            style: theme.textTheme.labelSmall,
                          ),
                          Text(
                            context.tr(
                              '수업 {count}개',
                              args: {'count': courses.length},
                            ),
                            key: const ValueKey('course-results-count'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          if (datasets.isNotEmpty)
                            Tooltip(
                              message: datasets
                                  .map((d) => d.sourceUrl)
                                  .join('\n'),
                              child: Text(
                                '${context.tr('자료 기준일')}: ${datasets.map((d) => d.publishedDate).toSet().join(', ')}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          if (_organization != null ||
                              _sourceDepartment != null ||
                              activeCategory != null ||
                              _hideConflicts)
                            Text(
                              [
                                _organization?.label ?? _sourceDepartment,
                                if (activeCategory != null)
                                  context.tr(activeCategory),
                                if (_hideConflicts) context.tr('겹치는 강의 제외'),
                              ].whereType<String>().join(' · '),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                      for (final notice
                          in datasets
                              .map((d) => d.sourceNotice)
                              .where((n) => n.isNotEmpty)
                              .toSet())
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            context.tr(notice),
                            key: const ValueKey('course-source-notice'),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      if (_filtersVisible) ...[
                        const SizedBox(height: 12),
                        if (_organization != null || _sourceDepartment != null)
                          ActionChip(
                            key: const ValueKey('course-organization-reset'),
                            label: Text(context.tr('전체 주관')),
                            avatar: const Icon(Icons.close, size: 16),
                            onPressed: () => _selectOrganization(null),
                          ),
                        if (colleges.isNotEmpty) ...[
                          Text(
                            context.tr('단과대 주관'),
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'course-college-$_campus-${_organization?.isCollegeHosted == true ? _organization?.college : null}',
                            ),
                            initialValue: _organization?.isCollegeHosted == true
                                ? _organization?.college
                                : '',
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: context.tr('단과대 직접 주관 과목'),
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: '',
                                child: Text(context.tr('선택 안 함')),
                              ),
                              for (final college in colleges)
                                DropdownMenuItem(
                                  value: college,
                                  child: Text(college),
                                ),
                            ],
                            onChanged: (value) => _selectOrganization(
                              value == null || value.isEmpty
                                  ? null
                                  : CourseOrganization(
                                      college: value,
                                      department: null,
                                      sourceLabel: value,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (departmentGroups.isNotEmpty) ...[
                          Text(
                            context.tr('학과·전공 선택'),
                            style: theme.textTheme.labelLarge,
                          ),
                          for (final entry in departmentGroups.entries)
                            if (entry.key == null)
                              _departmentChoices(entry.value)
                            else
                              ExpansionTile(
                                key: ValueKey(
                                  'course-college-departments-${entry.key}',
                                ),
                                title: Text(entry.key!),
                                subtitle:
                                    entry.value.any(
                                      (unit) => unit.affiliationUnconfirmed,
                                    )
                                    ? Text(context.tr('소속 미확인 · 이름 기준 분류'))
                                    : null,
                                expansionAnimationStyle:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? AnimationStyle.noAnimation
                                    : const AnimationStyle(
                                        duration: Duration(milliseconds: 180),
                                        curve: Curves.easeOutCubic,
                                      ),
                                initiallyExpanded:
                                    _organization?.department != null &&
                                    _organization?.displayGroup == entry.key,
                                tilePadding: EdgeInsets.zero,
                                childrenPadding: const EdgeInsets.only(
                                  bottom: 12,
                                ),
                                children: [_departmentChoices(entry.value)],
                              ),
                        ] else if (sourceDepartments.isEmpty)
                          Text(context.tr('공개된 학과 주관 정보가 없습니다.')),
                        if (sourceDepartments.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'course-source-department-$_campus-$_sourceDepartment',
                            ),
                            initialValue: _sourceDepartment ?? '',
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: context.tr('원자료 분류'),
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: '',
                                child: Text(context.tr('전체')),
                              ),
                              for (final label in sourceDepartments)
                                DropdownMenuItem(
                                  value: label,
                                  child: Text(label),
                                ),
                            ],
                            onChanged: (value) => _changeFilter(() {
                              _organization = null;
                              _sourceDepartment = value == null || value.isEmpty
                                  ? null
                                  : value;
                              _category = null;
                            }),
                          ),
                        ],
                        CheckboxListTile(
                          key: const ValueKey('course-hide-conflicts'),
                          value: _hideConflicts,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(context.tr('겹치는 강의 제외')),
                          onChanged: (value) => _changeFilter(
                            () => _hideConflicts = value ?? false,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (all.isEmpty || courses.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _CatalogMessage(
                    icon: all.isEmpty
                        ? Icons.calendar_month_outlined
                        : Icons.search_off,
                    message: context.tr(
                      all.isEmpty
                          ? '선택한 학기의 학교 데이터가 없습니다. 직접 수업을 추가할 수 있습니다.'
                          : '검색 결과가 없습니다.',
                    ),
                    action: all.isEmpty
                        ? null
                        : TextButton(
                            onPressed: () => _changeFilter(() {
                              _search.clear();
                              _query = '';
                              _organization = null;
                              _sourceDepartment = null;
                              _category = null;
                              _hideConflicts = false;
                            }),
                            child: Text(context.tr('검색 조건 지우기')),
                          ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  sliver: SliverList.builder(
                    itemCount: courses.length,
                    findChildIndexCallback: (key) => key is ValueKey<String>
                        ? courseIndices[key.value]
                        : null,
                    itemBuilder: (context, index) {
                      final course = courses[index];
                      final added = addedIds.contains(course.sourceId);
                      final selected = _selected?.sourceId == course.sourceId;
                      return _CourseCard(
                        key: ValueKey('course-card-${course.sourceId}'),
                        course: course,
                        added: added,
                        selected: selected,
                        conflicting: conflicts[course.sourceId]!.isNotEmpty,
                        categories: _classificationLabels(course),
                        onTap: () => _select(course),
                        details: selected
                            ? _CourseDetails(
                                key: ValueKey(
                                  'course-expanded-${course.sourceId}',
                                ),
                                course: course,
                                added: added,
                                conflicting: conflicts[course.sourceId]!,
                                onAdd: _add,
                              )
                            : null,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CourseDetails extends StatefulWidget {
  const _CourseDetails({
    super.key,
    required this.course,
    required this.added,
    required this.conflicting,
    required this.onAdd,
  });
  final UniversityCourse course;
  final bool added;
  final List<TimetableClass> conflicting;
  final Future<bool> Function(UniversityCourse, LectureMode) onAdd;

  @override
  State<_CourseDetails> createState() => _CourseDetailsState();
}

class _CourseDetailsState extends State<_CourseDetails>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  LectureMode? _selectedMode;
  bool _modeRequired = false;
  bool _adding = false;
  bool _addFailed = false;

  Future<void> _add(UniversityCourse course) async {
    if (_adding || widget.added || !course.hasSchedulableMeetings) return;
    final mode = _selectedMode;
    if (mode == null) {
      setState(() => _modeRequired = true);
      return;
    }
    setState(() {
      _adding = true;
      _addFailed = false;
    });
    var success = false;
    try {
      success = await widget.onAdd(course, mode);
    } catch (_) {
      // A rejected write keeps the selected mode and course available for retry.
    }
    if (!mounted) return;
    setState(() {
      _adding = false;
      _addFailed = !success;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _details(widget.course, widget.conflicting);
  }

  Widget _details(UniversityCourse course, List<TimetableClass> conflicting) {
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey('course-details-${course.sourceId}'),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 20),
          Text(
            course.departments.join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          if (course.departmentClassifications.values.any(
                (v) => v.trim().isNotEmpty,
              ) ||
              course.sourceClassification.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(context.tr('공식 이수구분'), style: theme.textTheme.labelSmall),
            if (course.departmentClassifications.isEmpty)
              Text(
                course.sourceClassification,
                style: theme.textTheme.bodySmall,
              ),
            for (final entry in course.departmentClassifications.entries.where(
              (e) => e.value.trim().isNotEmpty,
            ))
              Text(
                '${entry.key}: ${entry.value}',
                style: theme.textTheme.bodySmall,
              ),
          ],
          const SizedBox(height: 6),
          if (course.credits != null)
            Text(
              '${context.tr('학점')}: ${_creditText(course.credits!)}',
              style: theme.textTheme.bodySmall,
            )
          else ...[
            Text(
              context.tr('학과별 학점이 다릅니다. 원문을 확인해 주세요.'),
              style: theme.textTheme.bodySmall,
            ),
            for (final entry in course.departmentCredits.entries)
              Text(
                '${entry.key}: ${_creditText(entry.value)}',
                style: theme.textTheme.bodySmall,
              ),
          ],
          if (course.sourceSchedule.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(context.tr('공식 수업 시간'), style: theme.textTheme.labelSmall),
            Text(course.sourceSchedule, style: theme.textTheme.bodySmall),
          ],
          if (course.sourceClassroom.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(context.tr('강의실'), style: theme.textTheme.labelSmall),
            Text(course.sourceClassroom, style: theme.textTheme.bodySmall),
          ],
          if (!course.hasSchedulableMeetings) ...[
            const SizedBox(height: 10),
            Text(
              context.tr(
                '시간표에 배치할 수 있는 시간 정보가 없습니다. 학교에서 시간을 확인한 뒤 직접 추가해 주세요.',
              ),
              key: ValueKey('course-schedule-unavailable-${course.sourceId}'),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (course.remarks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(context.tr('비고'), style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              course.remarks,
              key: ValueKey('course-remarks-${course.sourceId}'),
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (!widget.added &&
              conflicting.isNotEmpty &&
              _selectedMode != LectureMode.video) ...[
            const SizedBox(height: 10),
            Text(
              '${context.tr('시간 겹침')}: ${conflicting.map((c) => c.title).join(', ')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (!widget.added && course.hasSchedulableMeetings) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<LectureMode>(
              key: ValueKey('course-mode-${course.sourceId}'),
              initialValue: _selectedMode,
              decoration: InputDecoration(
                labelText: context.tr('기본 강의 방식'),
                border: const OutlineInputBorder(),
                errorText: _modeRequired
                    ? context.tr('강의 방식을 직접 선택해 주세요.')
                    : null,
                errorMaxLines: 2,
                contentPadding: const EdgeInsets.all(12),
              ),
              isExpanded: true,
              items: [
                for (final mode in LectureMode.values.where(
                  (mode) => mode != LectureMode.cancelled,
                ))
                  DropdownMenuItem(
                    value: mode,
                    child: Text(context.tr(lectureModeLabel(mode))),
                  ),
              ],
              onChanged: _adding
                  ? null
                  : (value) => setState(() {
                      _selectedMode = value;
                      _modeRequired = false;
                    }),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('추가 전 실제 수강 내역과 시간을 확인해 주세요.'),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (_addFailed && !widget.added) ...[
            const SizedBox(height: 8),
            Text(
              context.tr('강의를 추가하지 못했습니다. 다시 시도해 주세요.'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: ValueKey('course-add-${course.sourceId}'),
              onPressed:
                  _adding || widget.added || !course.hasSchedulableMeetings
                  ? null
                  : () => _add(course),
              icon: _adding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(widget.added ? Icons.check : Icons.add, size: 18),
              label: Text(context.tr(widget.added ? '추가됨' : '시간표에 추가')),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    super.key,
    required this.course,
    required this.added,
    required this.selected,
    required this.conflicting,
    required this.categories,
    this.onTap,
    this.details,
  });
  final UniversityCourse course;
  final Widget? details;
  final bool added, selected, conflicting;
  final List<String> categories;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? colors.surfaceContainerLow : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              expanded: selected,
              child: ListTile(
                key: ValueKey(course.sourceId),
                contentPadding: const EdgeInsets.fromLTRB(14, 2, 12, 2),
                title: Text(
                  course.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final category in categories)
                            CourseCategoryLabel(
                              category:
                                  _categoryForLabel(category) ??
                                  CourseCategory.unknown,
                              label: category,
                            ),
                          Text(
                            course.codeAndSection,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${course.professor}${course.credits == null ? '' : ' · ${_creditText(course.credits!)}${context.tr('학점')}'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final meeting in timetableDisplayMeetings(
                        course.meetings,
                      ))
                        Text(
                          _meetingText(context, meeting),
                          style: theme.textTheme.bodySmall,
                        ),
                      if (!course.hasSchedulableMeetings)
                        Text(
                          context.tr('시간 확인 필요'),
                          style: theme.textTheme.bodySmall,
                        ),
                      if (added || conflicting)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            context.tr(added ? '추가됨' : '시간 겹침'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: added ? colors.primary : colors.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                trailing: Icon(
                  selected ? Icons.expand_less : Icons.expand_more,
                  color: colors.primary,
                ),
                onTap: onTap,
              ),
            ),
            AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              alignment: Alignment.topCenter,
              child: details ?? const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

CourseCategory? _categoryForLabel(String label) {
  for (final category in CourseCategory.values) {
    if (category.label == label) return category;
  }
  return null;
}

/// Fixed hues and readable text identify categories in both themes.
Color courseCategoryColor(CourseCategory category) => switch (category) {
  CourseCategory.major => const Color(0xff657faf),
  CourseCategory.certification => const Color(0xffaa6d74),
  CourseCategory.requiredMajor => const Color(0xff9b6188),
  CourseCategory.foundation => const Color(0xff7b8444),
  CourseCategory.advancedMajor => const Color(0xff8c66bf),
  CourseCategory.electiveMajor => const Color(0xff467ec5),
  CourseCategory.minorMajor => const Color(0xff7582a4),
  CourseCategory.teaching => const Color(0xffbf7153),
  CourseCategory.generalEducation => const Color(0xff488979),
  CourseCategory.requiredGeneralEducation => const Color(0xff39816e),
  CourseCategory.electiveGeneralEducation => const Color(0xff668b48),
  CourseCategory.general => const Color(0xff7a8190),
  CourseCategory.microDegree => const Color(0xff9c7c35),
  CourseCategory.unknown => const Color(0xff7d7d7d),
};

class CourseCategoryLabel extends StatelessWidget {
  const CourseCategoryLabel({super.key, required this.category, this.label});
  final CourseCategory category;
  final String? label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: courseCategoryColor(category),
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 5),
      Text(
        context.tr(label ?? category.label),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ],
  );
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({
    required this.icon,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 28,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    ),
  );
}

List<TimetableClass> _conflictingClasses(
  UniversityCourse course,
  List<TimetableClass> saved,
) => saved
    .where(
      (existing) =>
          existing.sourceId != course.sourceId &&
          existing.defaultMode != LectureMode.video &&
          existing.meetings.any(
            (meeting) => course.meetings.any(
              (candidate) =>
                  meeting.weekday == candidate.weekday &&
                  (meeting.date == null ||
                      candidate.date == null ||
                      meeting.date == candidate.date) &&
                  (candidate.date == null ||
                      existing.period == null ||
                      existing.period!.contains(candidate.teachingDate!)) &&
                  (meeting.date == null ||
                      course.period == null ||
                      course.period!.contains(meeting.teachingDate!)) &&
                  meeting.startMinute < candidate.endMinute &&
                  candidate.startMinute < meeting.endMinute,
            ),
          ),
    )
    .toList();

String _meetingText(BuildContext context, ClassMeeting meeting) {
  final day = DateFormat.E(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(DateTime(2026, 1, 5 + meeting.weekday - 1));
  return '$day ${_time(meeting.startMinute)}–${_time(meeting.endMinute)}${meeting.classroom.isEmpty ? '' : ' · ${meeting.classroom}'}';
}

String _time(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
String _creditText(num value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
