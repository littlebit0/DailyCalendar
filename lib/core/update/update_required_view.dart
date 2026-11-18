import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../di/app_providers.dart';
import '../localization/app_localizations.dart';
import '../theme/daily_ui.dart';
import 'app_update_service.dart';

final _releasePage = Uri.parse(
  'https://github.com/littlebit0/DailyCalendar/releases/latest',
);

/// Opens where this platform's update comes from: the App Store page from the
/// last lookup, Play (app first, then web), or the GitHub release.
Future<void> _openUpdatePage() async {
  final pages = <Uri>[];
  switch (updateSourceFor(defaultTargetPlatform)) {
    case UpdateSource.appStore:
      final preferences = await SharedPreferences.getInstance();
      final page = preferences.getString(AppUpdateService.storeUrlKey);
      if (page != null) pages.add(Uri.parse(page));
    case UpdateSource.play:
      pages.addAll([
        Uri.parse('market://details?id=com.littlebit0.dailycalendar'),
        Uri.parse(
          'https://play.google.com/store/apps/details?id=com.littlebit0.dailycalendar',
        ),
      ]);
    case UpdateSource.github:
      pages.add(_releasePage);
  }
  for (final page in pages) {
    try {
      if (await launchUrl(page, mode: LaunchMode.externalApplication)) return;
    } on Object {
      // Try the next page; the explanation stays on screen either way.
    }
  }
}

/// Play reports only a versionCode, so Android names no version number.
String _updateMessage(BuildContext context, String version) =>
    updateSourceFor(defaultTargetPlatform) == UpdateSource.play
    ? context.tr(
        '새 버전이 나왔습니다. 업데이트하기 전까지는 일정 확인만 사용할 수 있고, 학사일정·LMS·시간표와 일정 추가·수정은 사용할 수 없습니다.',
      )
    : context.tr(
        '새 버전({version})이 나왔습니다. 업데이트하기 전까지는 일정 확인만 사용할 수 있고, 학사일정·LMS·시간표와 일정 추가·수정은 사용할 수 없습니다.',
        args: {'version': version},
      );

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

/// Full-page variant for routes that are already open when a release is found.
class UpdateRequiredPageGate extends ConsumerWidget {
  const UpdateRequiredPageGate({
    super.key,
    required this.title,
    required this.child,
  });
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<String?>(
      valueListenable: ref.watch(requiredUpdateVersionProvider),
      builder: (context, version, _) => version == null
          ? child
          : Scaffold(
              backgroundColor: DailyUi.pageBackground(context),
              appBar: DailyNavigationBar(title: title),
              body: UpdateRequiredView(version: version),
            ),
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
            Text(_updateMessage(context, version), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('update-required-open'),
              onPressed: _openUpdatePage,
              child: Text(context.tr('업데이트 받기')),
            ),
          ],
        ),
      ),
    );
  }
}

/// True while this build must be updated before school features or editing.
bool updateRequired(WidgetRef ref) =>
    ref.read(requiredUpdateVersionProvider).value != null;

/// True (after telling the user) when editing must wait for the update.
bool blockedByRequiredUpdate(BuildContext context, WidgetRef ref) {
  if (!updateRequired(ref)) return false;
  showUpdateRequiredNotice(context, ref);
  return true;
}

/// [blockedByRequiredUpdate] for dialogs and forms built outside a Consumer.
/// Call it while [context] is mounted.
bool blockedByRequiredUpdateIn(BuildContext context) {
  final version = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(requiredUpdateVersionProvider).value;
  if (version == null) return false;
  _showNotice(context, version);
  return true;
}

/// Explains the restriction; usable after an await only behind `context.mounted`.
void showUpdateRequiredNotice(BuildContext context, WidgetRef ref) {
  final version = ref.read(requiredUpdateVersionProvider).value;
  if (version != null) _showNotice(context, version);
}

void _showNotice(BuildContext context, String version) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.tr('업데이트가 필요합니다')),
      content: Text(_updateMessage(dialogContext, version)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.tr('닫기')),
        ),
        FilledButton(
          onPressed: () {
            _openUpdatePage();
            Navigator.of(dialogContext).pop();
          },
          child: Text(dialogContext.tr('업데이트 받기')),
        ),
      ],
    ),
  );
}
