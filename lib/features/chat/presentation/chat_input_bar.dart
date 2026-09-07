import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../events/domain/event_draft.dart';

class ChatInputBar extends ConsumerStatefulWidget {
  const ChatInputBar({
    super.key,
    this.onClose,
    this.includeBottomSafeArea = true,
  });

  final VoidCallback? onClose;
  final bool includeBottomSafeArea;

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final _controller = TextEditingController();
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleInputChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleInputChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _controller.text.trim().isNotEmpty && !_submitting;
    return SafeArea(
      top: false,
      bottom: widget.includeBottomSafeArea,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Row(
          children: [
            if (widget.onClose != null) ...[
              IconButton(
                tooltip: context.tr('AI 입력 닫기'),
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: context.tr('일정을 입력하세요'),
                  prefixIcon: const Icon(Icons.chat_bubble_outline),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: context.tr('등록'),
              onPressed: canSubmit ? _submit : null,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final input = _controller.text.trim();
    if (input.isEmpty || _submitting) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final selectedDate = ref.read(selectedDateProvider);
      final settings = ref.read(appSettingsProvider);
      final result = await ref
          .read(scheduleParserProvider)
          .parse(
            input,
            baseDate: DateTime.now(),
            selectedDate: selectedDate,
            defaultReminderMinutes: settings.defaultReminderMinutes,
            defaultReminderMinutesList: settings.defaultReminderMinutesList,
          );

      if (!mounted) {
        return;
      }
      if (result.draft == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.question ?? '일정을 해석하지 못했습니다.')),
        );
        return;
      }

      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (_) => _DraftConfirmationSheet(draft: result.draft!),
      );
      if (confirmed == true) {
        if (!mounted) return;
        await ref.read(eventCommandServiceProvider).create(result.draft!);
        if (!mounted) return;
        _controller.clear();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('요청을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _DraftConfirmationSheet extends StatelessWidget {
  const _DraftConfirmationSheet({required this.draft});

  final EventDraft draft;

  @override
  Widget build(BuildContext context) {
    final scheduleTime = _formatScheduleTime(context, draft);
    final reminder = draft.reminderMinutesBeforeList.isEmpty
        ? context.tr('없음')
        : draft.reminderMinutesBeforeList.map(_minutesLabel).join(', ');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('이 일정으로 등록할까요?'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Color(
                  draft.colorValue ?? draft.category.colorValue,
                ).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Color(
                    draft.colorValue ?? draft.category.colorValue,
                  ).withValues(alpha: 0.28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(scheduleTime),
                  Text(
                    '${context.tr('분류')}: '
                    '${context.l10n.categoryName(id: draft.category.id, label: draft.category.label)}',
                  ),
                  Text('${context.tr('알림')}: $reminder'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(context.tr('취소')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(context.tr('등록')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatScheduleTime(BuildContext context, EventDraft draft) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormatter = DateFormat.yMMMMd(locale);
    final timeFormatter = DateFormat.Hm(locale);
    if (draft.allDay) {
      final inclusiveEnd = draft.endAt.subtract(const Duration(days: 1));
      if (_sameDay(draft.startAt, inclusiveEnd)) {
        return '${dateFormatter.format(draft.startAt)}  ${context.tr('종일')}';
      }
      return '${dateFormatter.format(draft.startAt)} - ${dateFormatter.format(inclusiveEnd)}  ${context.tr('종일')}';
    }
    if (_sameDay(draft.startAt, draft.endAt)) {
      return '${dateFormatter.format(draft.startAt)}  ${timeFormatter.format(draft.startAt)} - ${timeFormatter.format(draft.endAt)}';
    }
    return '${dateFormatter.format(draft.startAt)} ${timeFormatter.format(draft.startAt)} - ${dateFormatter.format(draft.endAt)} ${timeFormatter.format(draft.endAt)}';
  }

  String _minutesLabel(int minutes) {
    if (minutes == 0) {
      return '정시';
    }
    if (minutes < 60) {
      return '$minutes분 전';
    }
    if (minutes % 1440 == 0) {
      return '${minutes ~/ 1440}일 전';
    }
    if (minutes % 60 == 0) {
      return '${minutes ~/ 60}시간 전';
    }
    return '$minutes분 전';
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
