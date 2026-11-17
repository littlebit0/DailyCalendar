import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/daily_ui.dart';

const _channel = MethodChannel('daily/siri_logs');

/// Deletes the Siri activity log (event titles, memos, places) kept in the
/// App Group on iOS and macOS.
Future<void> clearSiriActivityLogs() =>
    _channel.invokeMethod<void>('clearLogs');

class SiriActivityLogPage extends StatefulWidget {
  const SiriActivityLogPage({super.key});

  @override
  State<SiriActivityLogPage> createState() => _SiriActivityLogPageState();
}

class _SiriActivityLogPageState extends State<SiriActivityLogPage> {
  var _logs = const <_SiriActivityLog>[];
  var _loading = true;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _channel.invokeListMethod<Object?>('listLogs');
      final logs =
          (raw ?? const <Object?>[])
              .whereType<Map<Object?, Object?>>()
              .map(_SiriActivityLog.fromMap)
              .toList()
            ..sort(
              (left, right) => right.occurredAt.compareTo(left.occurredAt),
            );
      if (mounted) setState(() => _logs = logs);
    } on MissingPluginException {
      if (mounted) setState(() => _logs = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final visible = _selectedDate == null
        ? _logs
        : _logs
              .where((log) => _sameDate(log.occurredAt, _selectedDate!))
              .toList();
    final grouped = <DateTime, List<_SiriActivityLog>>{};
    for (final log in visible) {
      final date = DateTime(
        log.occurredAt.year,
        log.occurredAt.month,
        log.occurredAt.day,
      );
      grouped.putIfAbsent(date, () => []).add(log);
    }

    return Scaffold(
      backgroundColor: DailyUi.pageBackground(context),
      appBar: DailyNavigationBar(
        title: context.tr('Siri 작업 기록'),
        actions: [
          IconButton(
            tooltip: context.tr('날짜 선택'),
            onPressed: _selectDate,
            icon: const Icon(Icons.calendar_today_outlined),
          ),
          if (_selectedDate != null)
            IconButton(
              tooltip: context.tr('전체 날짜 보기'),
              onPressed: () => setState(() => _selectedDate = null),
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
          if (_logs.isNotEmpty)
            IconButton(
              tooltip: context.tr('기록 전체 삭제'),
              onPressed: _clearLogs,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : visible.isEmpty
          ? DailyAdaptiveBody(
              child: DailyInfoCallout(
                icon: Icons.record_voice_over_outlined,
                title: context.tr('기록된 Siri 작업이 없습니다.'),
                text: context.tr(
                  'Siri 또는 단축어로 Daily 작업을 실행하면 날짜별 기록이 여기에 표시됩니다.',
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      DailyUi.isDesktop ? 24 : 16,
                      6,
                      DailyUi.isDesktop ? 24 : 16,
                      28,
                    ),
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final date = grouped.keys.elementAt(index);
                      final records = grouped[date]!;
                      return DailyGroupedSection(
                        label: DateFormat.yMMMMd(locale).format(date),
                        children: [
                          for (final record in records)
                            _SiriLogTile(
                              log: record,
                              onTap: () => _showDetails(context, record),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate ??
          (_logs.isEmpty ? DateTime.now() : _logs.first.occurredAt),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null && mounted) setState(() => _selectedDate = selected);
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Siri 작업 기록 삭제')),
        content: Text(context.tr('저장된 Siri 작업 기록을 모두 삭제하시겠습니까?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('취소')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('삭제')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await clearSiriActivityLogs();
    } on PlatformException {
      // The file is still there, so the list keeps showing it.
      return;
    }
    if (!mounted) return;
    setState(() {
      _logs = const [];
      _selectedDate = null;
    });
  }

  Future<void> _showDetails(BuildContext context, _SiriActivityLog log) async {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final startAt = log.detailDate('startAtMillis');
    final endAt = log.detailDate('endAtMillis');
    final dateFormat = DateFormat.yMMMMd(locale).add_Hm();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: DailyUi.pageBackground(context),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('Siri 작업 상세'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: DailyUi.groupedSurface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: DailyUi.separator(context)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      _DetailRow(
                        label: context.tr('작업'),
                        value: context.tr(_actionLabel(log.action)),
                      ),
                      _DetailRow(
                        label: context.tr('상태'),
                        value: context.tr(log.success ? '성공' : '실패'),
                      ),
                      _DetailRow(
                        label: context.tr('실행 시각'),
                        value: dateFormat.format(log.occurredAt),
                      ),
                      if (log.summary.isNotEmpty)
                        _DetailRow(label: context.tr('요약'), value: log.summary),
                      if (log.result.isNotEmpty)
                        _DetailRow(label: context.tr('결과'), value: log.result),
                      if ((log.details['title'] ?? '').isNotEmpty)
                        _DetailRow(
                          label: context.tr('제목'),
                          value: log.details['title']!,
                        ),
                      if (startAt != null)
                        _DetailRow(
                          label: context.tr('시작'),
                          value: dateFormat.format(startAt),
                        ),
                      if (endAt != null)
                        _DetailRow(
                          label: context.tr('종료'),
                          value: dateFormat.format(endAt),
                        ),
                      if (log.details.containsKey('allDay'))
                        _DetailRow(
                          label: context.tr('종일 일정'),
                          value: context.tr(
                            log.details['allDay'] == 'true' ? '예' : '아니요',
                          ),
                        ),
                      if ((log.details['location'] ?? '').isNotEmpty)
                        _DetailRow(
                          label: context.tr('장소'),
                          value: log.details['location']!,
                        ),
                      if ((log.details['memo'] ?? '').isNotEmpty)
                        _DetailRow(
                          label: context.tr('메모'),
                          value: log.details['memo']!,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SiriLogTile extends StatelessWidget {
  const _SiriLogTile({required this.log, required this.onTap});

  final _SiriActivityLog log;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      leading: DailySettingsIcon(
        icon: log.success ? _actionIcon(log.action) : Icons.error_outline,
        color: log.success ? DailyUi.primary : DailyUi.destructive,
      ),
      title: Text(
        log.summary.isEmpty
            ? context.tr(_actionLabel(log.action))
            : log.summary,
      ),
      subtitle: Text(
        '${context.tr(_actionLabel(log.action))} · '
        '${context.tr(log.success ? '성공' : '실패')} · ${log.result}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(DateFormat.Hm(locale).format(log.occurredAt)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _SiriActivityLog {
  const _SiriActivityLog({
    required this.occurredAt,
    required this.action,
    required this.summary,
    required this.result,
    required this.success,
    required this.details,
  });

  factory _SiriActivityLog.fromMap(Map<Object?, Object?> map) {
    return _SiriActivityLog(
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        map['occurredAt'] as int? ?? 0,
      ),
      action: map['action'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      result: map['result'] as String? ?? '',
      success: map['success'] as bool? ?? false,
      details: (map['details'] as Map<Object?, Object?>? ?? const {}).map(
        (key, value) => MapEntry('$key', '$value'),
      ),
    );
  }

  final DateTime occurredAt;
  final String action;
  final String summary;
  final String result;
  final bool success;
  final Map<String, String> details;

  DateTime? detailDate(String key) {
    final milliseconds = int.tryParse(details[key] ?? '');
    return milliseconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
}

String _actionLabel(String action) =>
    switch (action.replaceFirst('signal-', '')) {
      'add' => '일정 추가',
      'update' => '일정 수정',
      'delete' => '일정 삭제',
      'search' => '일정 검색',
      'yesterday' => '어제 일정 조회',
      'today' => '오늘 일정 조회',
      'tomorrow' => '내일 일정 조회',
      'date' => '날짜별 일정 조회',
      'next' => '다음 일정 조회',
      'dday' => 'D-day 조회',
      'open' => '달력 열기',
      _ => 'Siri 작업',
    };

IconData _actionIcon(String action) =>
    switch (action.replaceFirst('signal-', '')) {
      'add' => Icons.add_circle_outline,
      'update' => Icons.edit_calendar_outlined,
      'delete' => Icons.delete_outline,
      'search' => Icons.search,
      'dday' => Icons.flag_outlined,
      'open' => Icons.open_in_new,
      _ => Icons.record_voice_over_outlined,
    };

bool _sameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
