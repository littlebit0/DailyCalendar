import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/calendar_event.dart';

/// Shares completion behavior while each surface keeps its own tap/drag UI.
class EventCompletionAction extends StatefulWidget {
  const EventCompletionAction({
    super.key,
    required this.event,
    required this.builder,
    this.onCompletedChanged,
  });

  final CalendarEvent event;
  final Widget Function(VoidCallback? onDoubleTap) builder;
  final ValueChanged<bool>? onCompletedChanged;

  @override
  State<EventCompletionAction> createState() => _EventCompletionActionState();
}

class _EventCompletionActionState extends State<EventCompletionAction> {
  bool _updating = false;

  bool _canComplete(CalendarEvent event) =>
      !event.readOnly && !event.holiday && !event.systemEvent;

  Future<void> _toggle() async {
    if (_updating || !_canComplete(widget.event)) return;
    _updating = true;
    final event = widget.event;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      // Search results may be a snapshot. Read the current record before toggling.
      final source = await container
          .read(eventRepositoryProvider)
          .findById(event.id);
      if (source == null || !_canComplete(source) || source.deletedAt != null) {
        return;
      }
      final target = event.occurrenceId != null && source.recurrence.isRepeating
          ? event
          : source;
      final completed = !target.completed;
      await container
          .read(eventCommandServiceProvider)
          .setCompleted(target, completed);
      if (mounted) widget.onCompletedChanged?.call(completed);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(context.tr('요청을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.')),
          ),
        );
      }
    } finally {
      _updating = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    _canComplete(widget.event) ? () => unawaited(_toggle()) : null,
  );
}
