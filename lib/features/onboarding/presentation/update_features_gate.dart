import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/di/app_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/daily_ui.dart';
import '../../../core/widgets/lock_screen_wallpaper_service.dart';
import '../../settings/presentation/weather_settings_page.dart';
import '../../settings/presentation/academic_calendar_page.dart';
import '../feature_announcements.dart';

class UpdateFeaturesGate extends ConsumerStatefulWidget {
  const UpdateFeaturesGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<UpdateFeaturesGate> createState() => _UpdateFeaturesGateState();
}

class _UpdateFeaturesGateState extends ConsumerState<UpdateFeaturesGate> {
  List<FeatureAnnouncement>? _pending;
  int _step = 0;
  int _total = 0;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform().timeout(
        const Duration(seconds: 3),
      );
      if (!mounted) return;
      final items = ref
          .read(settingsRepositoryProvider)
          .announcements
          .pending(info.version, defaultTargetPlatform);
      setState(() {
        _pending = items;
        _total = items.length;
      });
    } catch (_) {
      // An optional introduction must never prevent calendar access.
      if (mounted) setState(() => _pending = []);
    }
  }

  Future<void> _advance({required bool open}) async {
    if (_busy || _pending!.isEmpty) return;
    final item = _pending!.first;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (open) {
        switch (item.feature) {
          case AnnouncementFeature.wallpaper:
            await LockScreenWallpaperService.openSettings();
          case AnnouncementFeature.weather:
            await Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const WeatherSettingsPage()),
            );
          case AnnouncementFeature.academicCalendar:
            await Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const AcademicCalendarPage()),
            );
        }
      }
      if (!mounted) return;
      await ref.read(settingsRepositoryProvider).announcements.acknowledge([
        item.id,
      ]);
      if (mounted) {
        setState(() {
          _pending!.removeAt(0);
          _step++;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = context.tr('다시 시도'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pending == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_pending!.isEmpty) return widget.child;
    final (title, description, icon) = switch (_pending!.first.feature) {
      AnnouncementFeature.wallpaper => (
        '잠금화면 월간 캘린더',
        '잠금화면에서 이번 달 일정을 확인하세요. 설정은 나중에도 할 수 있습니다.',
        Icons.calendar_month,
      ),
      AnnouncementFeature.weather => (
        '날씨 예보',
        '캘린더에서 선택한 지역의 날씨를 확인하세요. 기존 설정은 그대로 유지됩니다.',
        Icons.cloud_outlined,
      ),
      AnnouncementFeature.academicCalendar => (
        '대학교 학사일정',
        '대학교 공식 학사일정을 가져오고 변경사항을 갱신하세요. 현재 상명대학교를 지원합니다.',
        Icons.school_outlined,
      ),
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _advance(open: false);
      },
      child: Scaffold(
        body: DailyOnboardingFrame(
          step: _step,
          stepCount: _total,
          kicker: context.tr('새로운 기능'),
          title: context.tr(title),
          description: context.tr(description),
          primaryLabel: context.tr('설정 보기'),
          onPrimary: _busy ? null : () => _advance(open: true),
          secondaryLabel: context.tr('나중에'),
          onSecondary: _busy ? null : () => _advance(open: false),
          busy: _busy,
          content: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  if (_error != null) Text(_error!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
