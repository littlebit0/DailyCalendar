import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../di/app_providers.dart';
import '../localization/app_localizations.dart';

final _releasePage = Uri.parse(
  'https://github.com/littlebit0/DailyCalendar/releases/latest',
);

Future<void> _openReleasePage() async {
  try {
    await launchUrl(_releasePage, mode: LaunchMode.externalApplication);
  } on Object {
    // The explanation stays on screen; the user can update from the store.
  }
}

/// Replaces [child] while this build is older than the latest release.
/// Only viewing events stays available; school features and editing do not.
class UpdateRequiredGate extends ConsumerWidget {
  const UpdateRequiredGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<String?>(
      valueListenable: ref.watch(requiredUpdateVersionProvider),
      builder: (context, version, _) =>
          version == null ? child : UpdateRequiredView(version: version),
    );
  }
}

class UpdateRequiredView extends StatelessWidget {
  const UpdateRequiredView({super.key, required this.version});
  final String version;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.system_update_alt_rounded, size: 36),
            const SizedBox(height: 16),
            Text(
              context.tr('업데이트가 필요합니다'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                '새 버전({version})이 나왔습니다. 업데이트하기 전까지는 일정 확인만 사용할 수 있고, 학사일정·LMS·시간표와 일정 추가·수정은 사용할 수 없습니다.',
                args: {'version': version},
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('update-required-open'),
              onPressed: _openReleasePage,
              child: Text(context.tr('업데이트 받기')),
            ),
          ],
        ),
      ),
    );
  }
}

/// True (after telling the user) when editing must wait for the update.
bool blockedByRequiredUpdate(BuildContext context, WidgetRef ref) {
  final version = ref.read(requiredUpdateVersionProvider).value;
  if (version == null) return false;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.tr('업데이트가 필요합니다')),
      content: Text(
        dialogContext.tr(
          '새 버전({version})이 나왔습니다. 업데이트하기 전까지는 일정 확인만 사용할 수 있고, 학사일정·LMS·시간표와 일정 추가·수정은 사용할 수 없습니다.',
          args: {'version': version},
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.tr('닫기')),
        ),
        FilledButton(
          onPressed: () {
            _openReleasePage();
            Navigator.of(dialogContext).pop();
          },
          child: Text(dialogContext.tr('업데이트 받기')),
        ),
      ],
    ),
  );
  return true;
}
