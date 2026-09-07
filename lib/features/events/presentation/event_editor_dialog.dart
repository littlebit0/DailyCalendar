import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/semantics.dart';

import '../../../core/alarms/alarm_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/daily_ui.dart';
import '../domain/calendar_event.dart';
import '../domain/event_category.dart';
import '../domain/event_draft.dart';
import '../domain/recurrence_rule.dart';

enum _RecurrenceEndMode { never, until, count }

enum _ValidationTarget { title, date, time, recurrence }

class EventEditorDialog extends StatefulWidget {
  const EventEditorDialog({
    super.key,
    required this.initialDate,
    this.initialEndDate,
    this.initialAllDay,
    this.event,
    this.categories = EventCategory.values,
    this.defaultReminderMinutes = 60,
    this.defaultReminderMinutesList,
    this.alarmService = const UnsupportedAlarmService(),
  });

  final DateTime initialDate;
  final DateTime? initialEndDate;
  final bool? initialAllDay;
  final CalendarEvent? event;
  final List<EventCategory> categories;
  final int defaultReminderMinutes;
  final List<int>? defaultReminderMinutesList;
  final AlarmService alarmService;

  @override
  State<EventEditorDialog> createState() => _EventEditorDialogState();
}

class _EventEditorDialogState extends State<EventEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _memoController;
  late final TextEditingController _locationController;
  late final TextEditingController _urlController;
  late final TextEditingController _weatherController;
  late final FocusNode _titleFocusNode;
  late final ScrollController _scrollController;
  late DateTime _startDate;
  late DateTime _endDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _allDay;
  late EventCategory _category;
  late List<int> _reminders;
  late RecurrenceFrequency _frequency;
  late int _recurrenceInterval;
  late _RecurrenceEndMode _recurrenceEndMode;
  late DateTime? _recurrenceUntil;
  late int? _recurrenceCount;
  late bool _showDday;
  late bool _alarmEnabled;
  late TimeOfDay _allDayAlarmTime;
  AlarmAuthorizationState _alarmState = AlarmAuthorizationState.unsupported;
  var _alarmStateLoading = true;
  String? _validationMessage;
  _ValidationTarget? _validationTarget;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _titleController = TextEditingController(text: event?.title ?? '');
    _memoController = TextEditingController(text: event?.memo ?? '');
    _locationController = TextEditingController(text: event?.location ?? '');
    _urlController = TextEditingController(text: event?.url ?? '');
    _weatherController = TextEditingController(text: event?.weather ?? '');
    _titleFocusNode = FocusNode();
    _scrollController = ScrollController();
    final sourceDate = event?.startAt ?? widget.initialDate;
    _startDate = DateTime(sourceDate.year, sourceDate.month, sourceDate.day);
    final initialEndDate = widget.initialEndDate ?? widget.initialDate;
    final sourceEnd = event == null
        ? DateTime(
            initialEndDate.year,
            initialEndDate.month,
            initialEndDate.day,
            10,
          )
        : event.allDay
        ? event.endAt.subtract(const Duration(days: 1))
        : event.endAt;
    _endDate = DateTime(sourceEnd.year, sourceEnd.month, sourceEnd.day);
    if (_endDate.isBefore(_startDate)) {
      _endDate = _startDate;
    }
    _startTime = TimeOfDay.fromDateTime(
      event?.startAt ??
          DateTime(
            widget.initialDate.year,
            widget.initialDate.month,
            widget.initialDate.day,
            9,
          ),
    );
    _endTime = TimeOfDay.fromDateTime(sourceEnd);
    _allDay = event?.allDay ?? widget.initialAllDay ?? false;
    final usableCategories = _usableCategories;
    _category = usableCategories.firstWhere(
      (category) => category.id == event?.category.id,
      orElse: () => usableCategories.first,
    );
    _reminders =
        event?.reminderMinutesBeforeList ??
        normalizeReminderMinutes(
          widget.defaultReminderMinutesList ?? [widget.defaultReminderMinutes],
        );
    _frequency = event?.recurrence.frequency ?? RecurrenceFrequency.none;
    _recurrenceInterval = event?.recurrence.interval ?? 1;
    _recurrenceUntil = event?.recurrence.until;
    _recurrenceCount = event?.recurrence.count;
    _recurrenceEndMode = _recurrenceUntil != null
        ? _RecurrenceEndMode.until
        : _recurrenceCount != null
        ? _RecurrenceEndMode.count
        : _RecurrenceEndMode.never;
    _showDday = event?.showDday ?? false;
    _alarmEnabled = event?.alarmEnabled ?? false;
    final allDayAlarmMinutes = event?.allDayAlarmMinutes ?? 9 * 60;
    _allDayAlarmTime = TimeOfDay(
      hour: allDayAlarmMinutes ~/ 60,
      minute: allDayAlarmMinutes % 60,
    );
    unawaited(_loadAlarmState());
  }

  @override
  void dispose() {
    _titleFocusNode.dispose();
    _scrollController.dispose();
    _titleController.dispose();
    _memoController.dispose();
    _locationController.dispose();
    _urlController.dispose();
    _weatherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final windowSize = MediaQuery.sizeOf(context);
    final windowClass = dailyWindowClassFor(windowSize);
    final androidTablet =
        Theme.of(context).platform == TargetPlatform.android &&
        windowClass != DailyWindowClass.compact;
    final editorWidth = switch (windowClass) {
      DailyWindowClass.expanded when androidTablet => 520.0,
      DailyWindowClass.medium when androidTablet => 460.0,
      _ => 430.0,
    };
    final startDateLabel = _formatDate(_startDate);
    final endDateLabel = _formatDate(_endDate);
    final startTimeLabel = _startTime.format(context);
    final endTimeLabel = _endTime.format(context);
    final contentMaxHeight = MediaQuery.sizeOf(context).height * 0.72;

    final editorTheme = Theme.of(context).copyWith(
      inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
        filled: true,
        fillColor: DailyUi.groupedSurface(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DailyUi.separator(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: DailyUi.separator(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DailyUi.primary, width: 1.5),
        ),
      ),
    );

    return AlertDialog(
      backgroundColor: DailyUi.pageBackground(context),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: DailyUi.isDesktop
            ? 40
            : androidTablet
            ? 28
            : 14,
        vertical: DailyUi.isDesktop ? 32 : 18,
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      title: Row(
        children: [
          const DailySettingsIcon(icon: Icons.event_note_outlined),
          const SizedBox(width: 10),
          Text(
            context.tr(widget.event == null ? '일정 추가' : '일정 수정'),
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
      content: Theme(
        data: editorTheme,
        child: SizedBox(
          width: editorWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: contentMaxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_validationMessage != null) ...[
                  _DialogValidationMessage(message: _validationMessage!),
                  const SizedBox(height: 12),
                ],
                Flexible(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _titleController,
                          focusNode: _titleFocusNode,
                          decoration: InputDecoration(
                            labelText: context.tr('제목'),
                            prefixIcon: const Icon(Icons.title_rounded),
                            errorText:
                                _validationTarget == _ValidationTarget.title
                                ? context.tr('제목을 입력하세요.')
                                : null,
                          ),
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            if (_validationTarget == _ValidationTarget.title &&
                                _titleController.text.trim().isNotEmpty) {
                              _clearValidation();
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _LabeledPickerButton(
                                label: context.tr('시작일'),
                                icon: Icons.calendar_today_outlined,
                                value: startDateLabel,
                                onPressed: _pickStartDate,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _LabeledPickerButton(
                                label: context.tr('종료일'),
                                icon: Icons.event_available_outlined,
                                value: endDateLabel,
                                onPressed: _pickEndDate,
                              ),
                            ),
                          ],
                        ),
                        if (!_allDay) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _LabeledPickerButton(
                                  label: context.tr('시작 시간'),
                                  icon: Icons.schedule,
                                  value: startTimeLabel,
                                  onPressed: _pickStartTime,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _LabeledPickerButton(
                                  label: context.tr('종료 시간'),
                                  icon: Icons.schedule,
                                  value: endTimeLabel,
                                  onPressed: _pickEndTime,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        SwitchListTile(
                          value: _allDay,
                          onChanged: (value) {
                            _clearValidation();
                            setState(() => _allDay = value);
                          },
                          title: Text(context.tr('종일')),
                          contentPadding: EdgeInsets.zero,
                        ),
                        DropdownButtonFormField<EventCategory>(
                          key: ValueKey(_category.id),
                          initialValue: _category,
                          decoration: InputDecoration(
                            labelText: context.tr('분류'),
                            prefixIcon: const Icon(Icons.category_outlined),
                          ),
                          items: _usableCategories
                              .map(
                                (category) => DropdownMenuItem(
                                  value: category,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: Color(category.colorValue),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        context.l10n.categoryName(
                                          id: category.id,
                                          label: category.label,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              _clearValidation();
                              setState(() => _category = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: context.tr('알림'),
                            prefixIcon: const Icon(
                              Icons.notifications_outlined,
                            ),
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              FilterChip(
                                label: Text(context.tr('없음')),
                                selected: _reminders.isEmpty,
                                onSelected: (_) {
                                  _clearValidation();
                                  setState(() => _reminders = const <int>[]);
                                },
                              ),
                              for (final minutes in _reminderOptions())
                                FilterChip(
                                  label: Text(_label(minutes)),
                                  selected: _reminders.contains(minutes),
                                  onSelected: (selected) =>
                                      _toggleReminder(minutes, selected),
                                ),
                              IconButton.outlined(
                                tooltip: context.tr('알림 직접 입력'),
                                onPressed: _pickCustomReminder,
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            ],
                          ),
                        ),
                        if (_allDay)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                context.tr('종일 일정은 설정의 종일 알림 시간을 기준으로 예약됩니다.'),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          value:
                              _frequency == RecurrenceFrequency.none &&
                                  _alarmCanBeEnabled
                              ? _alarmEnabled
                              : false,
                          onChanged:
                              _frequency != RecurrenceFrequency.none ||
                                  !_alarmCanBeEnabled
                              ? null
                              : _toggleAlarm,
                          title: Text(context.tr('일정 알람')),
                          subtitle: Text(_alarmSubtitle),
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (_alarmEnabled &&
                            _allDay &&
                            _frequency == RecurrenceFrequency.none) ...[
                          const SizedBox(height: 4),
                          _LabeledPickerButton(
                            label: context.tr('종일 일정 알람 시각'),
                            icon: Icons.alarm,
                            value: _allDayAlarmTime.format(context),
                            onPressed: _pickAllDayAlarmTime,
                          ),
                        ],
                        const SizedBox(height: 12),
                        DropdownButtonFormField<RecurrenceFrequency>(
                          initialValue: _frequency,
                          decoration: InputDecoration(
                            labelText: context.tr('반복'),
                            prefixIcon: const Icon(Icons.repeat_rounded),
                          ),
                          items: RecurrenceFrequency.values
                              .map(
                                (frequency) => DropdownMenuItem(
                                  value: frequency,
                                  child: Text(_frequencyLabel(frequency)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              _clearValidation();
                              setState(() {
                                _frequency = value;
                                if (value != RecurrenceFrequency.none) {
                                  _alarmEnabled = false;
                                }
                              });
                            }
                          },
                        ),
                        if (_frequency != RecurrenceFrequency.none) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _LabeledPickerButton(
                                  label: context.tr('반복 간격'),
                                  icon: Icons.repeat,
                                  value: _recurrenceIntervalLabel(),
                                  onPressed: _pickRecurrenceInterval,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child:
                                    DropdownButtonFormField<_RecurrenceEndMode>(
                                      initialValue: _recurrenceEndMode,
                                      decoration: InputDecoration(
                                        labelText: context.tr('반복 종료'),
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: _RecurrenceEndMode.never,
                                          child: Text(context.tr('종료 없음')),
                                        ),
                                        DropdownMenuItem(
                                          value: _RecurrenceEndMode.until,
                                          child: Text(context.tr('날짜까지')),
                                        ),
                                        DropdownMenuItem(
                                          value: _RecurrenceEndMode.count,
                                          child: Text(context.tr('횟수만큼')),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value == null) {
                                          return;
                                        }
                                        _clearValidation();
                                        setState(() {
                                          _recurrenceEndMode = value;
                                          if (value ==
                                                  _RecurrenceEndMode.until &&
                                              _recurrenceUntil == null) {
                                            _recurrenceUntil =
                                                _endDate.isBefore(_startDate)
                                                ? _startDate
                                                : _endDate;
                                          }
                                          if (value ==
                                                  _RecurrenceEndMode.count &&
                                              _recurrenceCount == null) {
                                            _recurrenceCount = 10;
                                          }
                                        });
                                      },
                                    ),
                              ),
                            ],
                          ),
                          if (_recurrenceEndMode ==
                              _RecurrenceEndMode.until) ...[
                            const SizedBox(height: 8),
                            _LabeledPickerButton(
                              label: context.tr('반복 종료일'),
                              icon: Icons.event_busy_outlined,
                              value: _formatDate(_recurrenceUntil ?? _endDate),
                              onPressed: _pickRecurrenceUntil,
                            ),
                          ],
                          if (_recurrenceEndMode ==
                              _RecurrenceEndMode.count) ...[
                            const SizedBox(height: 8),
                            _LabeledPickerButton(
                              label: context.tr('반복 횟수'),
                              icon: Icons.format_list_numbered,
                              value: context.tr(
                                '{count}회',
                                args: {'count': _recurrenceCount ?? 10},
                              ),
                              onPressed: _pickRecurrenceCount,
                            ),
                          ],
                        ],
                        const SizedBox(height: 12),
                        SwitchListTile(
                          value: _showDday,
                          onChanged: (value) {
                            _clearValidation();
                            setState(() => _showDday = value);
                          },
                          title: Text(context.tr('D-day 표시')),
                          subtitle: Text(
                            context.tr('달력과 일정 목록에 D-day를 함께 표시합니다.'),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _locationController,
                          decoration: InputDecoration(
                            labelText: context.tr('장소'),
                            prefixIcon: const Icon(Icons.location_on_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            labelText: context.tr('URL / 링크'),
                            prefixIcon: const Icon(Icons.link_rounded),
                          ),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _weatherController,
                          decoration: InputDecoration(
                            labelText: context.tr('날씨'),
                            hintText: context.tr('예: 흐림'),
                            prefixIcon: const Icon(Icons.cloud_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _memoController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: context.tr('메모'),
                            prefixIcon: const Icon(Icons.notes_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(88, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(context.tr('취소')),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check_rounded, size: 19),
          label: Text(context.tr('저장')),
          style: FilledButton.styleFrom(
            backgroundColor: DailyUi.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(104, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  List<int> _reminderOptions() {
    return normalizeReminderMinutes([0, 10, 30, 60, 1440, ..._reminders]);
  }

  void _toggleReminder(int minutes, bool selected) {
    _clearValidation();
    final values = _reminders.toSet();
    if (selected) {
      values.add(minutes);
    } else {
      values.remove(minutes);
    }
    setState(() => _reminders = normalizeReminderMinutes(values));
  }

  String _label(int? minutes) {
    if (minutes == null) {
      return context.tr('없음');
    }
    if (minutes == 0) {
      return context.tr('정시');
    }
    if (minutes < 60) {
      return context.tr('{count}분 전', args: {'count': minutes});
    }
    if (minutes % 1440 == 0) {
      return context.tr('{count}일 전', args: {'count': minutes ~/ 1440});
    }
    if (minutes % 60 == 0) {
      return context.tr('{count}시간 전', args: {'count': minutes ~/ 60});
    }
    return context.tr('{count}분 전', args: {'count': minutes});
  }

  Future<void> _pickCustomReminder() async {
    final picked = await _showNumberDialog(
      context: context,
      title: context.tr('알림 직접 입력'),
      label: context.tr('몇 분 전에 알릴까요?'),
      initialValue: _reminders.isEmpty ? 0 : _reminders.first,
      minValue: 0,
    );
    if (picked != null) {
      _clearValidation();
      setState(
        () => _reminders = normalizeReminderMinutes([..._reminders, picked]),
      );
    }
  }

  Future<void> _pickRecurrenceInterval() async {
    final picked = await _showNumberDialog(
      context: context,
      title: context.tr('반복 간격'),
      label: context.tr(
        '몇 {unit}마다 반복할까요?',
        args: {'unit': _frequencyUnitLabel()},
      ),
      initialValue: _recurrenceInterval,
      minValue: 1,
    );
    if (picked != null) {
      _clearValidation();
      setState(() => _recurrenceInterval = picked);
    }
  }

  Future<void> _pickRecurrenceUntil() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: _startDate,
      lastDate: DateTime(2100),
      initialDate: _recurrenceUntil ?? _endDate,
    );
    if (picked != null) {
      _clearValidation();
      setState(() {
        _recurrenceUntil = DateTime(picked.year, picked.month, picked.day);
        _recurrenceEndMode = _RecurrenceEndMode.until;
      });
    }
  }

  Future<void> _pickRecurrenceCount() async {
    final picked = await _showNumberDialog(
      context: context,
      title: context.tr('반복 횟수'),
      label: context.tr('몇 회 반복할까요?'),
      initialValue: _recurrenceCount ?? 10,
      minValue: 1,
    );
    if (picked != null) {
      _clearValidation();
      setState(() {
        _recurrenceCount = picked;
        _recurrenceEndMode = _RecurrenceEndMode.count;
      });
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _startDate,
    );
    if (picked != null) {
      _clearValidation();
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
        if (_recurrenceUntil != null &&
            _recurrenceUntil!.isBefore(_startDate)) {
          _recurrenceUntil = _startDate;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
    );
    if (picked != null) {
      _clearValidation();
      setState(
        () => _endDate = DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await _showTimePicker(_startTime);
    if (picked != null) {
      _clearValidation();
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await _showTimePicker(_endTime);
    if (picked != null) {
      _clearValidation();
      setState(() => _endTime = picked);
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showValidation(
        context.tr('제목을 입력해야 일정을 저장할 수 있습니다.'),
        target: _ValidationTarget.title,
      );
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      _showValidation(
        context.tr('종료일은 시작일과 같거나 이후여야 합니다.'),
        target: _ValidationTarget.date,
      );
      return;
    }
    final startAt = _allDay
        ? _startDate
        : DateTime(
            _startDate.year,
            _startDate.month,
            _startDate.day,
            _startTime.hour,
            _startTime.minute,
          );
    final endAt = _allDay
        ? _endDate.add(const Duration(days: 1))
        : DateTime(
            _endDate.year,
            _endDate.month,
            _endDate.day,
            _endTime.hour,
            _endTime.minute,
          );
    if (!endAt.isAfter(startAt)) {
      _showValidation(
        context.tr('종료 시간은 시작 시간보다 늦어야 합니다.'),
        target: _ValidationTarget.time,
      );
      return;
    }
    if (_frequency != RecurrenceFrequency.none && _recurrenceInterval < 1) {
      _showValidation(
        context.tr('반복 간격은 1 이상이어야 합니다.'),
        target: _ValidationTarget.recurrence,
      );
      return;
    }
    final draft = EventDraft(
      title: title,
      memo: _memoController.text.trim().isEmpty
          ? null
          : _memoController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      url: _urlController.text.trim().isEmpty
          ? null
          : _urlController.text.trim(),
      weather: _weatherController.text.trim().isEmpty
          ? null
          : _weatherController.text.trim(),
      startAt: startAt,
      endAt: endAt,
      allDay: _allDay,
      category: _category,
      colorValue: _category.colorValue,
      reminderMinutesBeforeList: _reminders,
      recurrence: RecurrenceRule(
        frequency: _frequency,
        interval: _frequency == RecurrenceFrequency.none
            ? 1
            : _recurrenceInterval,
        until:
            _frequency == RecurrenceFrequency.none ||
                _recurrenceEndMode != _RecurrenceEndMode.until
            ? null
            : _recurrenceUntil,
        count:
            _frequency == RecurrenceFrequency.none ||
                _recurrenceEndMode != _RecurrenceEndMode.count
            ? null
            : _recurrenceCount,
      ),
      showDday: _showDday,
      alarmEnabled: _frequency == RecurrenceFrequency.none && _alarmEnabled,
      allDayAlarmMinutes: _allDayAlarmTime.hour * 60 + _allDayAlarmTime.minute,
    );
    Navigator.of(context).pop(draft);
  }

  void _showValidation(String message, {required _ValidationTarget target}) {
    setState(() {
      _validationMessage = message;
      _validationTarget = target;
    });
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
    );
    if (target == _ValidationTarget.title) {
      _titleFocusNode.requestFocus();
    }
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  void _clearValidation() {
    if (_validationMessage == null && _validationTarget == null) {
      return;
    }
    setState(() {
      _validationMessage = null;
      _validationTarget = null;
    });
  }

  bool get _alarmCanBeEnabled =>
      !_alarmStateLoading &&
      (_alarmState == AlarmAuthorizationState.authorized ||
          _alarmState == AlarmAuthorizationState.notDetermined);

  String get _alarmSubtitle {
    if (_frequency != RecurrenceFrequency.none) {
      return context.tr('반복 알람은 추후 루틴 기능에서 사용할 수 있습니다.');
    }
    if (_alarmStateLoading) {
      return context.tr('알람 지원 상태를 확인하고 있습니다.');
    }
    final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
    return switch (_alarmState) {
      AlarmAuthorizationState.unsupported => context.tr(
        '이 운영체제에서는 일정 알람을 사용할 수 없습니다.',
      ),
      AlarmAuthorizationState.denied => context.tr(
        '시스템 설정에서 Daily의 알람 권한을 허용해야 합니다.',
      ),
      AlarmAuthorizationState.notDetermined =>
        isMacOS
            ? context.tr('켜면 macOS 알림 권한을 요청하고 시작 시각에 시스템 알림을 전달합니다.')
            : context.tr('켜면 시스템 알람 권한을 요청하고 정시 알림을 알람으로 대체합니다.'),
      AlarmAuthorizationState.authorized =>
        isMacOS
            ? (_allDay
                  ? context.tr('선택한 시각에 소리와 다시 알림이 있는 macOS 시스템 알림을 전달합니다.')
                  : context.tr('시작 시각에 소리와 다시 알림이 있는 macOS 시스템 알림을 전달합니다.'))
            : (_allDay
                  ? context.tr('선택한 시각에 시스템 알람이 울립니다.')
                  : context.tr('시작 시각의 정시 알림을 시스템 알람으로 대체합니다.')),
    };
  }

  Future<void> _loadAlarmState() async {
    final state = await widget.alarmService.authorizationState();
    if (!mounted) {
      return;
    }
    setState(() {
      _alarmState = state;
      _alarmStateLoading = false;
      if (state == AlarmAuthorizationState.unsupported ||
          state == AlarmAuthorizationState.denied) {
        _alarmEnabled = false;
      }
    });
  }

  Future<void> _toggleAlarm(bool enabled) async {
    var state = _alarmState;
    if (enabled && state == AlarmAuthorizationState.notDetermined) {
      state = await widget.alarmService.requestAuthorization();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _alarmState = state;
      _alarmEnabled = enabled && state == AlarmAuthorizationState.authorized;
    });
  }

  Future<void> _pickAllDayAlarmTime() async {
    final picked = await _showTimePicker(_allDayAlarmTime);
    if (picked != null) {
      setState(() => _allDayAlarmTime = picked);
    }
  }

  Future<TimeOfDay?> _showTimePicker(TimeOfDay initialTime) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (pickerContext, child) => MediaQuery(
        data: MediaQuery.of(
          pickerContext,
        ).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
    );
  }

  List<EventCategory> get _usableCategories {
    final categories = widget.categories.toList();
    return categories.isEmpty ? const [EventCategory.basic] : categories;
  }

  String _formatDate(DateTime date) {
    return DateFormat.yMMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(date);
  }

  String _frequencyUnitLabel() {
    return switch (_frequency) {
      RecurrenceFrequency.daily =>
        context.l10n.languageCode == 'ko' ? '일' : context.tr('일 보기'),
      RecurrenceFrequency.weekly => context.tr('주'),
      RecurrenceFrequency.monthly => context.tr('개월'),
      RecurrenceFrequency.yearly => context.tr('년'),
      RecurrenceFrequency.none => context.tr('번'),
    };
  }

  String _frequencyLabel(RecurrenceFrequency frequency) {
    return switch (frequency) {
      RecurrenceFrequency.none => context.tr('반복 없음'),
      RecurrenceFrequency.daily => context.tr('매일'),
      RecurrenceFrequency.weekly => context.tr('매주'),
      RecurrenceFrequency.monthly => context.tr('매월'),
      RecurrenceFrequency.yearly => context.tr('매년'),
    };
  }

  String _recurrenceIntervalLabel() {
    final key = switch (_frequency) {
      RecurrenceFrequency.daily => '{count}일마다',
      RecurrenceFrequency.weekly => '{count}주마다',
      RecurrenceFrequency.monthly => '{count}개월마다',
      RecurrenceFrequency.yearly => '{count}년마다',
      RecurrenceFrequency.none => '{count}번마다',
    };
    return context.tr(key, args: {'count': _recurrenceInterval});
  }
}

class _DialogValidationMessage extends StatelessWidget {
  const _DialogValidationMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              color: colorScheme.onErrorContainer,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledPickerButton extends StatelessWidget {
  const _LabeledPickerButton({
    required this.label,
    required this.icon,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18, color: DailyUi.primary),
            label: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
            style: FilledButton.styleFrom(
              backgroundColor: DailyUi.elevatedSurface(context),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              minimumSize: const Size.fromHeight(43),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<int?> _showNumberDialog({
  required BuildContext context,
  required String title,
  required String label,
  required int initialValue,
  required int minValue,
}) async {
  final controller = TextEditingController(text: '$initialValue');
  String? errorText;
  final result = await showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        void submit() {
          final value = int.tryParse(controller.text.trim());
          if (value == null || value < minValue) {
            setState(() {
              errorText = minValue == 0
                  ? context.tr('0 이상의 숫자를 입력하세요.')
                  : context.tr(
                      '{count} 이상의 숫자를 입력하세요.',
                      args: {'count': minValue},
                    );
            });
            return;
          }
          Navigator.of(context).pop(value);
        }

        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: label, errorText: errorText),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('취소')),
            ),
            FilledButton(onPressed: submit, child: Text(context.tr('적용'))),
          ],
        );
      },
    ),
  );
  controller.dispose();
  return result;
}
