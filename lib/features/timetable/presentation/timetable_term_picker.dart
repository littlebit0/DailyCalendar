import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../data/timetable_store.dart';
import '../domain/timetable_term.dart';

typedef TimetablePeriodSuggestion =
    Future<TimetablePeriod?> Function(int year, String semester);

String timetableSemesterLabel(BuildContext context, String semester) =>
    context.tr(switch (semester) {
      '1' => '1학기',
      '여름' => '여름계절학기',
      '2' => '2학기',
      '겨울' => '겨울계절학기',
      _ => semester,
    });

String timetableTermLabel(BuildContext context, int year, String semester) =>
    context.tr(
      '{year}년도 {semester}',
      args: {
        'year': year >= 2000 && year < 2100
            ? '${year % 100}'.padLeft(2, '0')
            : '$year',
        'semester': timetableSemesterLabel(context, semester),
      },
    );

String timetablePeriodLabel(BuildContext context, TimetablePeriod period) {
  final material = MaterialLocalizations.of(context);
  return '${material.formatShortDate(period.start)} – '
      '${material.formatShortDate(period.end)}';
}

/// Moving between saved timetables does not create or modify a timetable.
Future<void> showTimetablePicker(
  BuildContext context,
  TimetableStore store, {
  TimetablePeriodSuggestion? suggestPeriod,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .8,
    child: _TimetablePicker(store: store, suggestPeriod: suggestPeriod),
  ),
);

Future<void> showTimetablePeriodEditor(
  BuildContext context,
  TimetableStore store,
  int year,
  String semester, {
  TimetablePeriodSuggestion? suggestPeriod,
}) async {
  await _showTermForm(
    context,
    store,
    year: year,
    semester: semester,
    creating: false,
    suggestPeriod: suggestPeriod,
  );
}

class _TimetablePicker extends StatefulWidget {
  const _TimetablePicker({required this.store, this.suggestPeriod});
  final TimetableStore store;
  final TimetablePeriodSuggestion? suggestPeriod;

  @override
  State<_TimetablePicker> createState() => _TimetablePickerState();
}

class _TimetablePickerState extends State<_TimetablePicker> {
  bool _busy = false;
  late int _firstYear = (widget.store.activeYear - 1).clamp(1900, 9999);
  late int _lastYear = (widget.store.activeYear + 1).clamp(1900, 9999);
  final _activeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _activeKey.currentContext;
      if (target != null) Scrollable.ensureVisible(target, alignment: .4);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final savedTerms = widget.store.terms;
      // Keep every previously saved year and nonstandard semester reachable,
      // even when it falls outside the initial list of standard semesters.
      final years = {
        for (var year = _firstYear; year <= _lastYear; year++) year,
        ...savedTerms.map((term) => term.year),
      }.toList()..sort();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('시간표 선택'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const ValueKey('timetable-picker-close'),
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  tooltip: context.tr('닫기'),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRect(
                child: SingleChildScrollView(
                  key: const ValueKey('timetable-term-list'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_firstYear > 1900)
                        TextButton(
                          key: const ValueKey('timetable-earlier-years'),
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _firstYear = (_firstYear - 3).clamp(
                                    1900,
                                    9999,
                                  ),
                                ),
                          child: Text(context.tr('이전 학기 더 보기')),
                        ),
                      for (final year in years)
                        for (final semester in {
                          '1',
                          '여름',
                          '2',
                          '겨울',
                          ...savedTerms
                              .where((term) => term.year == year)
                              .map((term) => term.semester),
                        })
                          Builder(
                            builder: (context) {
                              final saved = savedTerms
                                  .where(
                                    (term) =>
                                        term.year == year &&
                                        term.semester == semester,
                                  )
                                  .firstOrNull;
                              final selected =
                                  year == widget.store.activeYear &&
                                  semester == widget.store.activeSemester;
                              return Padding(
                                key: selected ? _activeKey : null,
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Material(
                                  color: selected
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.secondaryContainer
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    key: ValueKey(
                                      'timetable-term-$year-$semester',
                                    ),
                                    onTap: _busy
                                        ? null
                                        : () => _choose(year, semester, saved),
                                    child: Semantics(
                                      selected: selected,
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    timetableTermLabel(
                                                      context,
                                                      year,
                                                      semester,
                                                    ),
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.titleMedium,
                                                  ),
                                                  if (saved != null) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${saved.name ?? context.tr('내 시간표')} · ${context.tr('수업 {count}개', args: {'count': saved.courseCount})}',
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      saved.period == null
                                                          ? context.tr(
                                                              '학기 기간 설정 필요',
                                                            )
                                                          : timetablePeriodLabel(
                                                              context,
                                                              saved.period!,
                                                            ),
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.bodySmall,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              selected
                                                  ? Icons.check
                                                  : saved == null
                                                  ? Icons.add
                                                  : Icons.chevron_right,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      if (_lastYear < 9999)
                        TextButton(
                          key: const ValueKey('timetable-later-years'),
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _lastYear = (_lastYear + 3).clamp(
                                    1900,
                                    9999,
                                  ),
                                ),
                          child: Text(context.tr('다음 학기 더 보기')),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _choose(
    int year,
    String semester,
    TimetableTerm? existing,
  ) async {
    setState(() => _busy = true);
    try {
      if (existing != null) {
        await widget.store.selectTerm(year, semester);
        if (mounted) Navigator.pop(context);
        return;
      }
      final saved = await _showTermForm(
        context,
        widget.store,
        year: year,
        semester: semester,
        creating: true,
        suggestPeriod: widget.suggestPeriod,
      );
      if (!mounted) return;
      if (saved == true) {
        Navigator.pop(context);
      } else {
        setState(() => _busy = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _showSaveError(context);
      }
    }
  }
}

Future<bool?> _showTermForm(
  BuildContext context,
  TimetableStore store, {
  required int year,
  required String semester,
  required bool creating,
  TimetablePeriodSuggestion? suggestPeriod,
}) => showDialog<bool>(
  context: context,
  builder: (context) => _TermForm(
    store: store,
    initialYear: year,
    initialSemester: semester,
    creating: creating,
    suggestPeriod: suggestPeriod,
  ),
);

class _TermForm extends StatefulWidget {
  const _TermForm({
    required this.store,
    required this.initialYear,
    required this.initialSemester,
    required this.creating,
    this.suggestPeriod,
  });
  final TimetableStore store;
  final int initialYear;
  final String initialSemester;
  final bool creating;
  final TimetablePeriodSuggestion? suggestPeriod;

  @override
  State<_TermForm> createState() => _TermFormState();
}

class _TermFormState extends State<_TermForm> {
  final _form = GlobalKey<FormState>();
  late final int _year = widget.initialYear;
  late final String _semester = widget.initialSemester;
  String _name = '';
  TimetablePeriod? _period;
  bool _loading = false;
  bool _saving = false;
  bool _periodError = false;
  String? _saveError;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _period = widget.creating ? null : widget.store.periodFor(_year, _semester);
    if (_period == null) _suggest();
  }

  Future<void> _suggest() async {
    final request = ++_request;
    final year = _year;
    final suggest = widget.suggestPeriod;
    _loading = suggest != null;
    if (!_loading) return;
    TimetablePeriod? suggestion;
    try {
      suggestion = await suggest!(year, _semester);
    } catch (_) {
      // An unavailable suggestion never substitutes guessed dates.
    }
    if (!mounted || request != _request) return;
    setState(() {
      _period = suggestion;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => Dialog(
    key: const ValueKey('timetable-term-form'),
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                key: const ValueKey('timetable-term-form-scroll'),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.tr(
                          widget.creating ? '새 학기 시간표 만들기' : '학기 기간 설정',
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      Text(timetableTermLabel(context, _year, _semester)),
                      if (widget.creating) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const ValueKey('timetable-term-name'),
                          maxLength: 60,
                          enabled: !_saving,
                          decoration: InputDecoration(
                            labelText: context.tr('시간표 이름 (선택)'),
                          ),
                          onChanged: (value) => _name = value.trim(),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        context.tr('학기 기간'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        key: const ValueKey('timetable-term-period'),
                        onPressed: _saving ? null : _pickPeriod,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _period == null
                              ? Text(context.tr('시작일과 종료일 선택'))
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${context.tr('시작일')}: ${MaterialLocalizations.of(context).formatShortDate(_period!.start)}',
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${context.tr('종료일')}: ${MaterialLocalizations.of(context).formatShortDate(_period!.end)}',
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      if (_loading) ...[
                        const SizedBox(height: 8),
                        Text(context.tr('학기 기간을 확인하는 중…')),
                      ],
                      if (_periodError) ...[
                        const SizedBox(height: 8),
                        Text(
                          context.tr('시작일과 종료일을 선택해 주세요.'),
                          key: const ValueKey('timetable-period-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        context.tr(
                          '시작일과 종료일을 포함한 이 기간에만 주간·일간 캘린더에 수업이 표시됩니다.',
                        ),
                      ),
                      if (_saveError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          context.tr(_saveError!),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  key: const ValueKey('timetable-term-cancel'),
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Text(context.tr('취소')),
                ),
                FilledButton(
                  key: const ValueKey('timetable-term-save'),
                  onPressed: _saving ? null : _save,
                  child: Text(context.tr(widget.creating ? '만들기' : '저장')),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _pickPeriod() async {
    FocusScope.of(context).unfocus();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(9999, 12, 31),
      initialDateRange: _period == null
          ? null
          : DateTimeRange(start: _period!.start, end: _period!.end),
      currentDate: DateTime.now(),
      helpText: context.tr('학기 기간 설정'),
    );
    if (!mounted || range == null) return;
    setState(() {
      // A delayed suggestion must not replace a manually chosen range.
      _request++;
      _loading = false;
      _periodError = false;
      _period = TimetablePeriod(start: range.start, end: range.end);
    });
  }

  Future<void> _save() async {
    final valid = _form.currentState!.validate();
    setState(() => _periodError = _period == null);
    if (!valid || _period == null) return;
    if (widget.creating &&
        widget.store.terms.any(
          (term) => term.year == _year && term.semester == _semester,
        )) {
      setState(() => _saveError = '이미 저장된 학기입니다. 시간표 목록에서 선택해 주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      if (widget.creating) {
        await widget.store.createTerm(
          _year,
          _semester,
          name: _name.isEmpty ? null : _name,
          period: _period!,
        );
      } else {
        await widget.store.setTermPeriod(_year, _semester, _period!);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = '시간표를 저장하지 못했습니다. 다시 시도해 주세요.';
        });
      }
    }
  }
}

void _showSaveError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.tr('시간표를 저장하지 못했습니다. 다시 시도해 주세요.'))),
  );
}
