import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/imogi_item.dart';

const imogiIcon = Icons.lightbulb_outline_rounded;
const imogiSelectedIcon = Icons.lightbulb_rounded;

/// Puts the in-app open-item count badge on the imogi navigation icon. It is
/// not an OS notification or app-icon badge.
class ImogiTabIcon extends ConsumerWidget {
  const ImogiTabIcon({super.key, required this.child, this.enabled = true});

  final Widget child;

  /// False passes [child] through, for shared builders of other tabs.
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) return child;
    final store = ref.watch(imogiStoreProvider);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final count = store.openCount;
        final label = imogiBadgeLabel(count);
        return Semantics(
          value: label == null
              ? null
              : context.tr('미완료 {count}개', args: {'count': count}),
          child: Badge(
            key: const ValueKey('imogi-tab-badge'),
            isLabelVisible: label != null,
            label: label == null ? null : Text(label),
            child: child,
          ),
        );
      },
    );
  }
}
