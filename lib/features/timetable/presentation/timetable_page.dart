import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/daily_ui.dart';
import '../data/timetable_store.dart';
import '../domain/timetable.dart';
import '../domain/timetable_term.dart';
import '../domain/timetable_colors.dart';
import '../data/university_catalog.dart';
import 'weekly_timetable_grid.dart';
import 'timetable_term_picker.dart';
import 'timetable_settings_page.dart';
import 'university_course_page.dart';

String _time(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
String _weekday(BuildContext context, int day) => DateFormat.E(
  Localizations.localeOf(context).toLanguageTag(),
).format(DateTime(2026, 1, 5 + day - 1));
Future<bool> _save(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('시간표를 저장하지 못했습니다. 다시 시도해 주세요.'))),
      );
    }
    return false;
  }
}

class TimetablePage extends ConsumerStatefulWidget {
  const TimetablePage({super.key, this.loadCatalog = UniversityCatalog.load});
  final Future<List<UniversityDataset>> Function() loadCatalog;
  @override
  ConsumerState<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends ConsumerState<TimetablePage> {
  DateTime _date = DateTime.now();
  bool _showWeekChanges = false;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(timetableStoreProvider);
    final settings = ref.watch(appSettingsProvider);
    final monday = DateTime(
      _date.year,
      _date.month,
      _date.day - _date.weekday + 1,
    );
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final courses = store.activeClasses;
        final lastDay = courses
            .expand((c) => c.meetings)
            .fold<int>(5, (n, m) => m.weekday > n ? m.weekday : n);
        final days = List.generate(
          lastDay,
          (i) => DateTime(monday.year, monday.month, monday.day + i),
        );
        final occurrences = _showWeekChanges
            ? classOccurrences(
                courses,
                days,
                includeUnscheduled: true,
                periodFor: (course) =>
                    store.periodFor(course.academicYear, course.semester),
              )
            : <ClassOccurrence>[
                for (final course in courses)
                  for (final meeting in course.meetings)
                    ClassOccurrence(
                      course,
                      meeting,
                      days[meeting.weekday - 1],
                      course.defaultMode,
                    ),
              ];
        Widget grid({bool compact = false}) => WeeklyTimetableGrid(
          days: days,
          occurrences: occurrences,
          use24HourTime: settings.use24HourTime,
          showDates: _showWeekChanges,
          compact: compact,
          onOccurrenceTap: (occurrence) {
            if (_showWeekChanges) {
              showClassOccurrence(context, store, occurrence);
            } else {
              showTimetableClassDetails(context, store, occurrence.course);
            }
          },
          onEmptySlotTap: (weekday, startMinute) => showClassEditor(
            context,
            store,
            initialWeekday: weekday,
            initialStartMinute: startMinute,
          ),
        );
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final content = Column(
                  key: const ValueKey('timetable-page'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextButton.icon(
                                  key: const ValueKey('timetable-term-picker'),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 32),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => _term(context, store),
                                  icon: const Icon(Icons.expand_more, size: 16),
                                  iconAlignment: IconAlignment.end,
                                  label: Text(
                                    timetableTermLabel(
                                      context,
                                      store.activeYear,
                                      store.activeSemester,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  store.activeName ?? context.tr('내 시간표'),
                                  key: const ValueKey('timetable-name'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            key: const ValueKey('timetable-search'),
                            tooltip: context.tr('강의 검색'),
                            onPressed: store.loadError != null
                                ? null
                                : () =>
                                      Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).push<void>(
                                        MaterialPageRoute(
                                          builder: (_) => UniversityCoursePage(
                                            store: store,
                                            loadCatalog: widget.loadCatalog,
                                            university:
                                                settings
                                                    .academicProfile
                                                    ?.timetableUniversity ??
                                                'smu',
                                            initialCampus: settings
                                                .academicProfile
                                                ?.timetableCampus,
                                          ),
                                        ),
                                      ),
                            icon: const Icon(Icons.search),
                          ),
                          IconButton(
                            key: const ValueKey('timetable-add'),
                            tooltip: context.tr('직접 추가'),
                            onPressed: store.loadError != null
                                ? null
                                : () => showClassEditor(context, store),
                            icon: const Icon(Icons.add),
                          ),
                          IconButton(
                            key: const ValueKey('timetable-menu'),
                            tooltip: context.tr('시간표 설정'),
                            onPressed: () => _openSettings(context, store),
                            icon: const Icon(Icons.settings_outlined),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton.icon(
                              key: const ValueKey('timetable-period'),
                              onPressed: store.loadError != null
                                  ? null
                                  : () => _openSettings(context, store),
                              icon: const Icon(Icons.date_range, size: 18),
                              label: Text(
                                store.activePeriod != null
                                    ? context.tr(
                                        '학기 기간: {period}',
                                        args: {
                                          'period': timetablePeriodLabel(
                                            context,
                                            store.activePeriod!,
                                          ),
                                        },
                                      )
                                    : '${context.tr('학기 기간 설정')} · ${context.tr('기간을 설정하면 주·일간 스케줄에 수업이 표시됩니다.')}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            TextButton.icon(
                              key: const ValueKey('timetable-week-toggle'),
                              onPressed: () => setState(() {
                                _showWeekChanges = !_showWeekChanges;
                                if (_showWeekChanges) _alignWeek(store);
                              }),
                              icon: Icon(
                                _showWeekChanges
                                    ? Icons.calendar_view_week_outlined
                                    : Icons.event_repeat_outlined,
                                size: 18,
                              ),
                              label: Text(
                                context.tr(
                                  _showWeekChanges ? '기본 시간표' : '주간 변경',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showWeekChanges)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: context.tr('이전 주'),
                            onPressed: () => _moveWeek(-7),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Flexible(
                            child: TextButton(
                              onPressed: _pickWeek,
                              child: Text(
                                '${DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag()).format(monday)} – ${DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag()).format(days.last)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: context.tr('다음 주'),
                            onPressed: () => _moveWeek(7),
                            icon: const Icon(Icons.chevron_right),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _date = DateTime.now()),
                            child: Text(context.tr('이번 주')),
                          ),
                        ],
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: store.loadError != null
                            ? Center(
                                child: Text(
                                  context.tr(
                                    '시간표 데이터를 읽지 못했습니다. 기존 데이터는 보존됩니다.',
                                  ),
                                ),
                              )
                            : grid(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Text(
                            context.tr(
                              '수업 {count}개',
                              args: {'count': courses.length},
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.tr(
                                _showWeekChanges
                                    ? '수업을 눌러 해당 날짜의 강의 방식이나 휴강을 변경하세요.'
                                    : store.hasPendingSync
                                    ? '시간표 Google Drive 동기화 대기 중'
                                    : '시간표는 Google Drive로 동기화됩니다.',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                // A very short window must still allow reaching every control.
                final textScale =
                    MediaQuery.textScalerOf(context).scale(14) / 14;
                final minHeight =
                    320.0 + (textScale > 1 ? textScale - 1 : 0) * 240;
                final short = constraints.maxHeight < minHeight;
                return SingleChildScrollView(
                  primary: false,
                  child: SizedBox(
                    height: short
                        ? minHeight.clamp(460.0, double.infinity)
                        : constraints.maxHeight,
                    child: content,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _moveWeek(int days) => setState(() {
    _date = DateTime(_date.year, _date.month, _date.day + days);
  });

  Future<void> _pickWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(9999, 12, 31),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<TimetablePeriod?> _suggestPeriod(int year, String semester) async {
    final university =
        ref.read(appSettingsProvider).academicProfile?.timetableUniversity ??
        'smu';
    final defaults = await ref.read(timetablePeriodDefaultsProvider.future);
    return defaults.periodFor(year, semester, university: university);
  }

  void _alignWeek(TimetableStore store) {
    final period = store.activePeriod;
    if (period == null || period.contains(_date)) return;
    final today = DateTime.now();
    _date = period.contains(today) ? today : period.start;
  }

  Future<void> _openSettings(BuildContext context, TimetableStore store) async {
    final previous = (
      store.activeYear,
      store.activeSemester,
      store.activePeriod,
    );
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(builder: (_) => const TimetableSettingsPage()),
    );
    if (mounted &&
        previous !=
            (store.activeYear, store.activeSemester, store.activePeriod)) {
      setState(() => _alignWeek(store));
    }
  }

  Future<void> _term(BuildContext context, TimetableStore store) async {
    final previous = (
      store.activeYear,
      store.activeSemester,
      store.activePeriod,
    );
    await showTimetablePicker(context, store, suggestPeriod: _suggestPeriod);
    if (mounted &&
        previous !=
            (store.activeYear, store.activeSemester, store.activePeriod)) {
      setState(() {
        _alignWeek(store);
      });
    }
  }
}

String _detailTime(BuildContext context, int minute) {
  final use24HourTime = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(appSettingsProvider).use24HourTime;
  if (minute == 1440 && use24HourTime) return '24:00';
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: (minute ~/ 60) % 24, minute: minute % 60),
    alwaysUse24HourFormat: use24HourTime,
  );
}

Future<void> showTimetableClassDetails(
  BuildContext context,
  TimetableStore store,
  TimetableClass course,
) async {
  final edit = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .75,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          key: const ValueKey('class-details'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    course.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: context.tr('닫기'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (course.professor.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(course.professor),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Chip(
                avatar: const Icon(Icons.school_outlined, size: 18),
                label: Text(context.tr(lectureModeLabel(course.defaultMode))),
              ),
            ),
            for (final meeting in course.meetings)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.access_time, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_weekday(context, meeting.weekday)} ${_detailTime(context, meeting.startMinute)} – ${_detailTime(context, meeting.endMinute)}',
                          ),
                          if (meeting.classroom.isNotEmpty)
                            Text(
                              meeting.classroom,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (course.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(course.note),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('class-details-edit'),
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.edit_outlined),
                label: Text(context.tr('수업 수정')),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (edit == true && context.mounted) {
    await showClassEditor(context, store, course: course);
  }
}

Future<void> showClassOccurrence(
  BuildContext context,
  TimetableStore store,
  ClassOccurrence occurrence,
) async {
  final action = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(occurrence.course.title),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.yMMMEd(
              Localizations.localeOf(context).toLanguageTag(),
            ).format(occurrence.date),
          ),
          Text(
            '${_detailTime(context, occurrence.meeting.startMinute)} – ${_detailTime(context, occurrence.meeting.endMinute)}',
          ),
          if (occurrence.meeting.classroom.isNotEmpty)
            Text(occurrence.meeting.classroom),
          if (occurrence.course.professor.isNotEmpty)
            Text(occurrence.course.professor),
          Text(context.tr(lectureModeLabel(occurrence.mode))),
          if (occurrence.course.note.isNotEmpty) Text(occurrence.course.note),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'edit'),
          child: Text(context.tr('수업 수정')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'mode'),
          child: Text(context.tr('이번 수업 방식')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('닫기')),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (action == 'edit') {
    await showClassEditor(context, store, course: occurrence.course);
    return;
  }
  if (action != 'mode') return;
  final original =
      occurrence.course.overrides[occurrence.course.overrideKey(
        occurrence.meeting,
        occurrence.date,
      )];
  var selected = original?.name ?? 'default';
  var busy = false;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(context.tr('이번 수업 방식')),
        content: DropdownButtonFormField<String>(
          initialValue: selected,
          isExpanded: true,
          items: [
            DropdownMenuItem(
              value: 'default',
              child: Text(
                '${context.tr('기본값 사용')} (${context.tr(lectureModeLabel(occurrence.course.defaultMode))})',
              ),
            ),
            for (final mode in LectureMode.values)
              DropdownMenuItem(
                value: mode.name,
                child: Text(context.tr(lectureModeLabel(mode))),
              ),
          ],
          onChanged: busy ? null : (v) => selected = v!,
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: Text(context.tr('취소')),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    final ok = await _save(
                      context,
                      () => store.setOverride(
                        occurrence.course.id,
                        occurrence.meeting.id,
                        occurrence.date,
                        selected == 'default'
                            ? null
                            : LectureMode.values.byName(selected),
                      ),
                    );
                    if (!context.mounted) return;
                    if (ok) {
                      Navigator.pop(context);
                    } else {
                      setState(() => busy = false);
                    }
                  },
            child: Text(context.tr('저장')),
          ),
        ],
      ),
    ),
  );
}

Future<int?> _pickClassTime(
  BuildContext context,
  int minute, {
  required bool isEnd,
}) => showDialog<int>(
  context: context,
  builder: (_) => _ClassTimePicker(minute: minute, isEnd: isEnd),
);

class _ClassTimePicker extends StatefulWidget {
  const _ClassTimePicker({required this.minute, required this.isEnd});
  final int minute;
  final bool isEnd;

  @override
  State<_ClassTimePicker> createState() => _ClassTimePickerState();
}

class _ClassTimePickerState extends State<_ClassTimePicker> {
  late final _controller = ScrollController(
    initialScrollOffset: ((widget.minute ~/ 30 - 3) * 56.0).clamp(0, 2200),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    key: const ValueKey('class-meeting-time-picker'),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360, maxHeight: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr(widget.isEnd ? '종료 시간' : '시작 시간'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: context.tr('닫기'),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              controller: _controller,
              itemCount: 48,
              itemExtent: (MediaQuery.textScalerOf(context).scale(16) + 24)
                  .clamp(56, double.infinity),
              itemBuilder: (context, index) {
                final value = (index + (widget.isEnd ? 1 : 0)) * 30;
                return ListTile(
                  key: ValueKey('class-time-$value'),
                  selected: value == widget.minute,
                  title: Text(
                    value == 1440 ? '24:00' : _detailTime(context, value),
                  ),
                  trailing: value == widget.minute
                      ? const Icon(Icons.check, size: 20)
                      : null,
                  onTap: () => Navigator.pop(context, value),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> showClassEditor(
  BuildContext context,
  TimetableStore store, {
  TimetableClass? course,
  bool isNew = false,
  int initialWeekday = 1,
  int initialStartMinute = 540,
}) => showDialog<void>(
  context: context,
  useSafeArea: false,
  barrierDismissible: false,
  builder: (_) => Dialog.fullscreen(
    key: const ValueKey('class-editor-popup'),
    child: DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.fromBorderSide(DailyUi.popupBorder(context)),
      ),
      child: _ClassEditor(
        store: store,
        course: course,
        isNew: isNew,
        initialWeekday: initialWeekday,
        initialStartMinute: initialStartMinute,
      ),
    ),
  ),
);

class _ClassEditor extends StatefulWidget {
  const _ClassEditor({
    required this.store,
    this.course,
    this.isNew = false,
    this.initialWeekday = 1,
    this.initialStartMinute = 540,
  });
  final int initialWeekday;
  final int initialStartMinute;
  final bool isNew;
  final TimetableStore store;
  final TimetableClass? course;
  @override
  State<_ClassEditor> createState() => _ClassEditorState();
}

class _ClassEditorState extends State<_ClassEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.course?.title);
  late final _professor = TextEditingController(text: widget.course?.professor);
  late final _note = TextEditingController(text: widget.course?.note);
  late final _meetings = [...?widget.course?.meetings];
  late var _mode = widget.course?.defaultMode ?? LectureMode.inPerson;
  late var _color = widget.course != null && !widget.isNew
      ? widget.course!.colorValue
      : selectNewCourseColor(widget.store.activeClasses);
  var _busy = false;
  @override
  void initState() {
    super.initState();
    if (_meetings.isEmpty) {
      _meetings.add(
        ClassMeeting(
          id: const Uuid().v4(),
          weekday: widget.initialWeekday,
          startMinute: widget.initialStartMinute,
          endMinute: (widget.initialStartMinute + 60).clamp(1, 1440),
        ),
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _professor.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: context.tr('닫기'),
        onPressed: _busy ? null : () => Navigator.pop(context),
        icon: const Icon(Icons.close),
      ),
      title: Text(
        context.tr(widget.course == null || widget.isNew ? '수업 추가' : '수업 수정'),
      ),
      actions: [
        if (widget.course != null && !widget.isNew)
          IconButton(
            tooltip: context.tr('삭제'),
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                key: const ValueKey('class-title'),
                controller: _title,
                decoration: InputDecoration(labelText: context.tr('과목명')),
                validator: (s) => s == null || s.trim().isEmpty
                    ? context.tr('필수 항목입니다.')
                    : null,
              ),
              TextFormField(
                controller: _professor,
                decoration: InputDecoration(labelText: context.tr('교수명')),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<LectureMode>(
                initialValue: _mode,
                decoration: InputDecoration(labelText: context.tr('기본 강의 방식')),
                items: [
                  for (final m in LectureMode.values.where(
                    (m) => m != LectureMode.cancelled,
                  ))
                    DropdownMenuItem(
                      value: m,
                      child: Text(context.tr(lectureModeLabel(m))),
                    ),
                ],
                onChanged: (m) => _mode = m!,
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _meetings.length; i++)
                Card(
                  child: ListTile(
                    title: Text(
                      '${_weekday(context, _meetings[i].weekday)} ${_time(_meetings[i].startMinute)} – ${_time(_meetings[i].endMinute)}',
                    ),
                    subtitle: Text(
                      _meetings[i].classroom.isEmpty
                          ? context.tr('강의실 미지정')
                          : _meetings[i].classroom,
                    ),
                    onTap: _busy ? null : () => _meeting(i),
                    trailing: _meetings.length > 1
                        ? IconButton(
                            tooltip: context.tr('삭제'),
                            onPressed: _busy
                                ? null
                                : () => setState(() => _meetings.removeAt(i)),
                            icon: const Icon(Icons.remove_circle_outline),
                          )
                        : const Icon(Icons.edit_outlined),
                  ),
                ),
              TextButton.icon(
                onPressed: _busy ? null : () => _meeting(null),
                icon: const Icon(Icons.add),
                label: Text(context.tr('수업 시간 추가')),
              ),
              TextFormField(
                controller: _note,
                maxLines: 3,
                decoration: InputDecoration(labelText: context.tr('메모')),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in {...timetableCourseColors, _color})
                    IconButton(
                      tooltip:
                          '${context.tr('색상')} #${(c & 0xffffff).toRadixString(16).padLeft(6, '0')}',
                      onPressed: _busy
                          ? null
                          : () => setState(() => _color = c),
                      icon: Icon(
                        c == _color ? Icons.check_circle : Icons.circle,
                        color: Color(c),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('class-save'),
                onPressed: _busy ? null : _submit,
                child: Text(context.tr('저장')),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Future<void> _meeting(int? index) async {
    final previous = index == null ? null : _meetings[index];
    var day = previous?.weekday ?? 1;
    var start = previous?.startMinute ?? 540;
    var end = previous?.endMinute ?? 600;
    var room = previous?.classroom ?? '';
    final key = GlobalKey<FormState>();
    final result = await showDialog<ClassMeeting>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.tr('수업 시간')),
          content: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: day,
                  items: [
                    for (var d = 1; d <= 7; d++)
                      DropdownMenuItem(
                        value: d,
                        child: Text(_weekday(context, d)),
                      ),
                  ],
                  onChanged: (d) => day = d!,
                ),
                TextButton(
                  key: const ValueKey('class-meeting-start'),
                  onPressed: () async {
                    final minute = await _pickClassTime(
                      context,
                      start,
                      isEnd: false,
                    );
                    if (minute != null && context.mounted) {
                      setState(() => start = minute);
                    }
                  },
                  child: Text('${context.tr('시작 시간')} ${_time(start)}'),
                ),
                TextButton(
                  key: const ValueKey('class-meeting-end'),
                  onPressed: () async {
                    final minute = await _pickClassTime(
                      context,
                      end,
                      isEnd: true,
                    );
                    if (minute != null && context.mounted) {
                      setState(() => end = minute);
                    }
                  },
                  child: Text('${context.tr('종료 시간')} ${_time(end)}'),
                ),
                FormField<void>(
                  validator: (_) => start < end
                      ? null
                      : context.tr('종료 시간은 시작 시간보다 늦어야 합니다.'),
                  builder: (state) => state.hasError
                      ? Text(
                          state.errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                TextFormField(
                  initialValue: room,
                  onChanged: (value) => room = value,
                  decoration: InputDecoration(labelText: context.tr('강의실')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('취소')),
            ),
            FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) {
                  Navigator.pop(
                    context,
                    ClassMeeting(
                      id: previous?.id ?? const Uuid().v4(),
                      weekday: day,
                      startMinute: start == previous?.startMinute
                          ? previous!.originalStartMinute
                          : start,
                      endMinute: end == previous?.endMinute
                          ? previous!.originalEndMinute
                          : end,
                      classroom: room.trim(),
                    ),
                  );
                }
              },
              child: Text(context.tr('저장')),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (index == null) {
          _meetings.add(result);
        } else {
          _meetings[index] = result;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final previous = widget.course;
    final ids = _meetings.map((m) => m.id).toSet();
    final course = TimetableClass(
      id: previous?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      meetings: _meetings,
      academicYear: previous?.academicYear ?? widget.store.activeYear,
      semester: previous?.semester ?? widget.store.activeSemester,
      professor: _professor.text.trim(),
      note: _note.text.trim(),
      colorValue: _color,
      defaultMode: _mode,
      sourceType: previous?.sourceType ?? 'manual',
      sourceId: previous?.sourceId,
      overrides: {
        for (final entry
            in (previous?.overrides ?? <String, LectureMode>{}).entries)
          if (ids.contains(entry.key.split('/').first)) entry.key: entry.value,
      },
    );
    final ok = await _save(context, () => widget.store.save(course));
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('수업 삭제')),
        content: Text(context.tr('이 수업과 회차 변경을 삭제할까요?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('취소')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('삭제')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final ok = await _save(
      context,
      () => widget.store.remove(widget.course!.id),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }
}
