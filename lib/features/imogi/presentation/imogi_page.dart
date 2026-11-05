import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/daily_ui.dart';
import '../../../core/update/update_required_view.dart';
import '../../events/domain/event_draft.dart';
import '../../events/presentation/event_editor_dialog.dart';
import '../data/imogi_store.dart';
import '../domain/imogi_item.dart';

/// The "잊모기" tab: dateless reminders kept apart from calendar events.
class ImogiPage extends ConsumerStatefulWidget {
  const ImogiPage({super.key});

  @override
  ConsumerState<ImogiPage> createState() => _ImogiPageState();
}

class _ImogiPageState extends ConsumerState<ImogiPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (blockedByRequiredUpdateIn(context)) return false;
    try {
      await action();
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('잊모기를 저장하지 못했습니다. 다시 시도해 주세요.'))),
        );
      }
      return false;
    }
  }

  Future<void> _add(ImogiStore store) async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    if (await _run(() => store.add(title))) {
      _controller.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(imogiStoreProvider);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (store.loadError != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.tr('저장된 잊모기를 읽지 못했습니다. 기존 데이터는 그대로 보존됩니다.'),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final open = store.openItems;
        final completed = store.completedItems;
        return ListView(
          key: const ValueKey('imogi-list'),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            Text(
              context.tr('잊지 말고 메모해서 기억하자'),
              style: TextStyle(color: DailyUi.secondaryText(context)),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('imogi-quick-add'),
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.done,
              maxLength: ImogiItem.maxTitleLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: InputDecoration(
                hintText: context.tr('잊으면 안 되는 일을 적어 보세요'),
                counterText: '',
                suffixIcon: IconButton(
                  key: const ValueKey('imogi-add'),
                  tooltip: context.tr('추가'),
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => _add(store),
                ),
              ),
              onSubmitted: (_) => _add(store),
            ),
            const SizedBox(height: 12),
            if (open.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  context.tr('남은 잊모기가 없습니다.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DailyUi.secondaryText(context)),
                ),
              ),
            for (final item in open) _tile(store, item),
            if (completed.isNotEmpty)
              ExpansionTile(
                key: const ValueKey('imogi-completed'),
                tilePadding: EdgeInsets.zero,
                title: Text(
                  context.tr(
                    '완료한 잊모기 {count}개',
                    args: {'count': completed.length},
                  ),
                ),
                children: [for (final item in completed) _tile(store, item)],
              ),
          ],
        );
      },
    );
  }

  Widget _tile(ImogiStore store, ImogiItem item) {
    final secondary = DailyUi.secondaryText(context);
    return ListTile(
      key: ValueKey('imogi-item-${item.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: item.completed,
        semanticLabel: context.tr(item.completed ? '미완료로 되돌리기' : '완료'),
        onChanged: (value) =>
            _run(() => store.setCompleted(item.id, value ?? false)),
      ),
      title: Text(
        item.title,
        style: item.completed
            ? TextStyle(
                color: secondary,
                decoration: TextDecoration.lineThrough,
              )
            : null,
      ),
      subtitle: item.note == null
          ? null
          : Text(item.note!, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: item.completed
          ? null
          : IconButton(
              tooltip: context.tr(item.important ? '중요 표시 해제' : '중요 표시'),
              icon: Icon(
                item.important ? Icons.star_rounded : Icons.star_border_rounded,
                color: item.important ? DailyUi.primary : secondary,
              ),
              onPressed: () =>
                  _run(() => store.setImportant(item.id, !item.important)),
            ),
      onTap: () => _edit(store, item),
    );
  }

  Future<void> _edit(ImogiStore store, ImogiItem item) async {
    final result = await showDialog<_EditResult>(
      context: context,
      builder: (_) => _ImogiEditDialog(item: item),
    );
    if (!mounted || result == null) return;
    final (action, titleText, noteText) = result;
    switch (action) {
      case _EditAction.save:
        if (titleText.isEmpty) return;
        await _run(() => store.edit(item.id, title: titleText, note: noteText));
      case _EditAction.delete:
        await _run(() => store.remove(item.id));
      case _EditAction.convert:
        if (titleText.isEmpty) return;
        // Keep edits made in this dialog; the event is prefilled from them.
        if (!await _run(
          () => store.edit(item.id, title: titleText, note: noteText),
        )) {
          return;
        }
        await _convert(store, item.id);
    }
  }

  /// Creates exactly one event from the item, then keeps the item as a
  /// completed record (restorable) instead of deleting or duplicating it.
  /// The event ID is persisted on the item first, so a retry after a failed
  /// completion finishes the same conversion instead of adding another event.
  Future<void> _convert(ImogiStore store, String id) async {
    if (blockedByRequiredUpdate(context, ref)) return;
    final item = store.items.where((i) => i.id == id).firstOrNull;
    if (item == null) return;
    final reserved = item.conversionEventId;
    String? deletedReservation;
    if (reserved != null) {
      final existing = await ref
          .read(visibleEventRepositoryProvider)
          .findById(reserved);
      if (!mounted) return;
      if (existing != null && !existing.isDeleted) {
        if (await _run(() => store.completeConversion(id))) _showConverted();
        return;
      }
      if (existing != null) deletedReservation = reserved;
    }
    final settings = ref.read(appSettingsProvider);
    final today = DateTime.now();
    final draft = await showDialog<EventDraft>(
      context: context,
      builder: (_) => EventEditorDialog(
        initialTitle: item.title,
        initialMemo: item.note,
        frequentPlaces: ref.read(settingsRepositoryProvider).frequentPlaces,
        loadPlaceEvents: ref
            .read(visibleEventRepositoryProvider)
            .allEventsForSync,
        initialDate: DateTime(today.year, today.month, today.day),
        initialAllDay: true,
        categories: settings.categories,
        defaultReminderMinutesList: settings.defaultReminderMinutesList,
        alarmService: ref.read(alarmServiceProvider),
        use24HourTime: settings.use24HourTime,
      ),
    );
    if (draft == null || !mounted) return;
    final converted = await _run(() async {
      final eventId = await store.reserveConversion(
        id,
        discard: deletedReservation,
      );
      await ref.read(eventCommandServiceProvider).create(draft, id: eventId);
      await store.completeConversion(id);
    });
    if (converted) _showConverted();
  }

  void _showConverted() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('일정으로 전환했습니다. 잊모기는 완료 목록에 남겨 두었습니다.'))),
    );
  }
}

enum _EditAction { save, delete, convert }

typedef _EditResult = (_EditAction action, String title, String note);

/// Owns its controllers, so they outlive the dialog's closing animation.
class _ImogiEditDialog extends StatefulWidget {
  const _ImogiEditDialog({required this.item});

  final ImogiItem item;

  @override
  State<_ImogiEditDialog> createState() => _ImogiEditDialogState();
}

class _ImogiEditDialogState extends State<_ImogiEditDialog> {
  late final _title = TextEditingController(text: widget.item.title);
  late final _note = TextEditingController(text: widget.item.note ?? '');

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _close(_EditAction action) =>
      Navigator.pop(context, (action, _title.text.trim(), _note.text));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('잊모기 편집')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('imogi-edit-title'),
            controller: _title,
            autofocus: true,
            maxLength: ImogiItem.maxTitleLength,
            decoration: InputDecoration(labelText: context.tr('제목')),
          ),
          TextField(
            key: const ValueKey('imogi-edit-note'),
            controller: _note,
            minLines: 2,
            maxLines: 5,
            maxLength: ImogiItem.maxNoteLength,
            decoration: InputDecoration(labelText: context.tr('메모')),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _close(_EditAction.delete),
          child: Text(context.tr('삭제')),
        ),
        TextButton(
          key: const ValueKey('imogi-convert'),
          onPressed: () => _close(_EditAction.convert),
          child: Text(context.tr('일정으로 전환')),
        ),
        FilledButton(
          onPressed: () => _close(_EditAction.save),
          child: Text(context.tr('저장')),
        ),
      ],
    );
  }
}
