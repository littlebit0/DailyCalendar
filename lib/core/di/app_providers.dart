import '../notifications/recoverable_notification_service.dart';
import 'provider_retention.dart';
import '../academic/kangnam_academic_source.dart';
import '../academic/expansion_a_academic_sources.dart';
import '../academic/expansion_b_academic_sources.dart';
import '../academic/expansion17_c_academic_sources.dart';
import '../academic/namhae_academic_source.dart';
import '../academic/geochang_academic_source.dart';
import '../academic/sch_academic_source.dart';
import '../academic/hoseo_academic_source.dart';
import '../academic/kmou_academic_source.dart';
import '../academic/donga_academic_source.dart';
import '../academic/seoultech_academic_source.dart';
import '../academic/konkuk_academic_source.dart';
import '../academic/jnue_academic_source.dart';
import '../academic/dgist_academic_source.dart';
import '../academic/chosun_academic_source.dart';
import '../academic/gnue_academic_source.dart';
import '../academic/tuk_academic_source.dart';
import '../academic/hanyang_academic_source.dart';
import '../academic/korea_academic_source.dart';
import '../academic/yonsei_academic_source.dart';
import '../academic/gachon_academic_source.dart';
import '../academic/sku_academic_source.dart';
import '../academic/kyonggi_academic_source.dart';
import '../academic/cue_academic_source.dart';
import '../academic/kumoh_academic_source.dart';
import '../academic/khu_academic_source.dart';
import '../academic/gknu_academic_source.dart';
import '../academic/snue_academic_source.dart';
import '../academic/yu_academic_source.dart';
import '../academic/sungshin_academic_source.dart';
import '../academic/mmu_academic_source.dart';
import '../academic/cnu_academic_source.dart';
import '../academic/dnue_academic_source.dart';
import '../academic/hufs_academic_source.dart';
import '../academic/pnu_academic_source.dart';
import '../academic/pknu_academic_source.dart';
import '../academic/koreatech_academic_source.dart';
import '../academic/cbnu_academic_source.dart';
import '../academic/kau_academic_source.dart';
import '../academic/swu_academic_source.dart';
import '../academic/hansung_academic_source.dart';
import '../academic/suwon_academic_source.dart';
import '../academic/sogang_academic_source.dart';
import '../academic/mju_academic_source.dart';
import '../academic/gjue_academic_source.dart';
import '../academic/cnue_academic_source.dart';
import '../academic/ginue_academic_source.dart';
import '../academic/uos_academic_source.dart';
import '../academic/bu_academic_source.dart';
import '../academic/cje_academic_source.dart';
import '../academic/nsu_academic_source.dart';
import '../academic/kwangwoon_academic_source.dart';
import '../academic/inha_academic_source.dart';
import '../academic/inu_academic_source.dart';
import '../academic/knue_kunsan_academic_source.dart';
import '../academic/mokpo_academic_source.dart';
import '../academic/kongju_academic_source.dart';
import '../academic/hanbat_academic_source.dart';
import '../academic/hknu_academic_source.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../features/timetable/data/timetable_store.dart';
import '../../features/timetable/data/timetable_period_defaults.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../features/chat/application/gemini_schedule_parser.dart';
import '../../features/chat/application/hybrid_schedule_parser.dart';
import '../../features/chat/application/rule_based_schedule_parser.dart';
import '../../features/chat/domain/schedule_parser.dart';
import '../../features/events/application/event_command_service.dart';
import '../../features/events/data/app_database.dart';
import '../../features/events/data/drift_event_repository.dart';
import '../../features/events/data/owner_scoped_event_repository.dart';
import '../lms/lms_controller.dart';
import '../lms/lms_sync_service.dart';
import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_category.dart';
import '../../features/events/domain/event_repository.dart';
import '../analytics/product_analytics.dart';
import '../support/bug_report_service.dart';
import '../auth/apple_sign_in_service.dart';
import '../alarms/alarm_service.dart';
import '../alarms/native_alarm_service.dart';
import '../calendar/korean_holiday_service.dart';
import '../calendar_import/calendar_import_service.dart';
import '../calendar_import/google_calendar_source.dart';
import '../calendar_import/native_calendar_source.dart';
import '../migration/todo_database_migration_service.dart';
import '../notifications/local_notification_service.dart';
import '../notifications/notification_service.dart';
import '../settings/app_settings.dart';
import '../settings/settings_repository.dart';
import '../sync/google_drive_auth_service.dart';
import '../sync/google_drive_sync_service.dart';
import '../sync/sync_service.dart';
import '../widgets/calendar_widget_service.dart';
import '../weather/weather_controller.dart';
import '../weather/kma_weather_service.dart';
import '../academic/academic_calendar_service.dart';
import '../academic/academic_source.dart';
import '../academic/snu_academic_source.dart';
import '../academic/ajou_academic_source.dart';
import '../academic/gist_academic_source.dart';
import '../academic/skku_academic_source.dart';
import '../academic/knu_academic_source.dart';
import '../academic/daegu_academic_source.dart';
import '../academic/ulsan_academic_source.dart';
import '../academic/deu_academic_source.dart';
import '../academic/bnue_academic_source.dart';
import '../academic/ut_academic_source.dart';
import '../academic/kookmin_academic_source.dart';
import '../academic/unist_academic_source.dart';
import '../academic/kangwon_academic_source.dart';
import '../academic/kaist_academic_source.dart';
import '../academic/cau_academic_source.dart';
import '../academic/yongin_academic_source.dart';
import '../academic/jeju_academic_source.dart';
import '../academic/kmu_academic_source.dart';
import '../academic/ssu_academic_source.dart';
import '../academic/syu_academic_source.dart';
import '../academic/gnu_academic_source.dart';
import '../academic/sv_academic_source.dart';
import '../academic/jbnu_academic_source.dart';
import '../academic/dongguk_academic_source.dart';

class CalendarRange {
  const CalendarRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) {
    return other is CalendarRange && start == other.start && end == other.end;
  }

  @override
  int get hashCode => Object.hash(start, end);
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError('settingsRepositoryProvider must be overridden');
});

final weatherControllerProvider = Provider<WeatherController>((ref) {
  final controller = WeatherController(
    store: ref.watch(settingsRepositoryProvider).weatherStore,
    service: KmaWeatherService(),
    location: DeviceWeatherLocation(),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

final productAnalyticsProvider = Provider<ProductAnalytics>((ref) {
  return const NoopProductAnalytics();
});

final appSettingsProvider = StateProvider<AppSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).load();
});

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return DriftEventRepository(ref.watch(databaseProvider));
});

final visibleEventRepositoryProvider = Provider<EventRepository>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return OwnerScopedEventRepository(
    ref.watch(eventRepositoryProvider),
    () => settings.dailyAccount()?.googleAccount?.email,
  );
});

final lmsPresentationStateProvider = Provider<LmsPresentationState>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  return LmsPresentationState(
    cachedVisibility: (event) {
      final profile = repository.load().academicProfile;
      return LmsSyncService.isCachedEventVisible(
        event,
        owner: repository.dailyAccount()?.googleAccount?.email,
        school: profile?.timetableUniversity,
        principal: profile?.lmsUserId,
        hasProfile: profile != null,
      );
    },
  );
});

final Provider<CalendarWidgetService> calendarWidgetServiceProvider =
    Provider<CalendarWidgetService>((ref) {
      final presentation = ref.watch(lmsPresentationStateProvider);
      final service = CalendarWidgetService(
        eventRepository: ref.watch(visibleEventRepositoryProvider),
        settingsRepository: ref.watch(settingsRepositoryProvider),
        isEventVisible: presentation.isEventVisible,
        lmsVerifiedAt: () => presentation.verifiedAt,
      );
      ref.onDispose(service.dispose);
      return service;
    });

/// Temporary source-compatibility alias for extensions that still reference
/// the pre-parity provider name.
final appleWidgetServiceProvider = calendarWidgetServiceProvider;

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return RecoverableNotificationService(
    LocalNotificationService(
      settingsRepository: settings,
      eventRepository: ref.watch(visibleEventRepositoryProvider),
    ),
    settings,
  );
});

final alarmServiceProvider = Provider<AlarmService>((ref) {
  return NativeAlarmService(
    onAlarmScheduled: (event) async {
      final service = ref.read(notificationServiceProvider);
      if (service is RecoverableNotificationService) {
        await service.confirmAlarmScheduled(event);
      }
    },
  );
});

final koreanHolidayServiceProvider = Provider<KoreanHolidayService>((ref) {
  return KoreanHolidayService();
});

final googleDriveAuthServiceProvider = Provider<GoogleDriveAuthService>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return GoogleDriveAuthService(
    linkedGoogleEmail: () => settings.dailyAccount()?.googleAccount?.email,
  );
});

final appleSignInServiceProvider = Provider<AppleSignInService>((ref) {
  return AppleSignInService(
    settingsRepository: ref.watch(settingsRepositoryProvider),
  );
});

final googleDriveSyncServiceProvider = Provider<GoogleDriveSyncService>((ref) {
  final service = GoogleDriveSyncService(
    authService: ref.watch(googleDriveAuthServiceProvider),
    eventRepository: ref.watch(eventRepositoryProvider),
    notificationService: ref.watch(notificationServiceProvider),
    alarmService: ref.watch(alarmServiceProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
    analytics: ref.watch(productAnalyticsProvider),
    onEventsChanged: ref.watch(calendarWidgetServiceProvider).refresh,
  );
  ref.onDispose(service.dispose);
  return service;
});

final bugReportServiceProvider = Provider<BugReportService>((ref) {
  final service = BugReportService();
  ref.onDispose(service.dispose);
  return service;
});

final todoDatabaseMigrationServiceProvider =
    Provider<TodoDatabaseMigrationService>((ref) {
      final database = ref.watch(databaseProvider);
      final settingsRepository = ref.watch(settingsRepositoryProvider);
      final syncService = ref.watch(googleDriveSyncServiceProvider);
      final service = TodoDatabaseMigrationService(
        databaseFile: database.databaseFile,
        hasLinkedGoogleAccount: () =>
            settingsRepository.dailyAccount()?.googleAccount != null,
        loadRemoteEvents: syncService.downloadEventsForMigration,
        remoteDeletionRecords: () => syncService.migrationDeletions,
        backupMigratedEvents: syncService.syncPendingChangesNow,
      );
      ref.onDispose(service.dispose);
      return service;
    });

// A first sign-in hands restoration to the calendar's existing startup gate.
// Account scoped and memory only; never persisted or synchronized.
final onboardingRestoreOwnerProvider = StateProvider<String?>((ref) => null);

final syncServiceProvider = Provider<SyncService>((ref) {
  return ref.watch(googleDriveSyncServiceProvider);
});

final eventFollowUpFailureProvider = StateProvider<int>((ref) => 0);

final eventCommandServiceProvider = Provider<EventCommandService>((ref) {
  return EventCommandService(
    repository: ref.watch(eventRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
    notificationService: ref.watch(notificationServiceProvider),
    alarmService: ref.watch(alarmServiceProvider),
    syncService: ref.watch(syncServiceProvider),
    analytics: ref.watch(productAnalyticsProvider),
    onFollowUpFailure: () =>
        ref.read(eventFollowUpFailureProvider.notifier).state++,
    onEventsChanged: ref.watch(calendarWidgetServiceProvider).refresh,
  );
});

final calendarImportServiceProvider = Provider<CalendarImportService>((ref) {
  return CalendarImportService(
    nativeSource: NativeCalendarSource(),
    googleSource: GoogleCalendarSource(
      authService: ref.watch(googleDriveAuthServiceProvider),
    ),
    eventRepository: ref.watch(eventRepositoryProvider),
    eventCommandService: ref.watch(eventCommandServiceProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
  );
});

final academicCalendarServiceProvider = Provider<AcademicCalendarService>((
  ref,
) {
  final settings = ref.watch(settingsRepositoryProvider);
  final service = AcademicCalendarService(
    sources: [
      EuljiAcademicSource(),
      IccuAcademicSource(),
      InjeAcademicSource(),
      HongikAcademicSource(),
      WoosongAcademicSource(),
      EwhaAcademicSource(),
      KentechAcademicSource(),
      HanseiAcademicSource(),
      HyupsungAcademicSource(),
      SungkyulAcademicSource(),
      SunmoonAcademicSource(),
      SangjiAcademicSource(),
      NambuAcademicSource(),
      KangnamAcademicSource(),
      KonyangAcademicSource(),
      DjuAcademicSource(),
      PcuAcademicSource(),
      SangmyungAcademicSource(),
      DankookAcademicSource(),
      ChonnamAcademicSource(),
      SnuAcademicSource(),
      PostechAcademicSource(),
      SejongAcademicSource(),
      AjouAcademicSource(),
      GistAcademicSource(),
      SookmyungAcademicSource(),
      SkkuAcademicSource(),
      CatholicAcademicSource(),
      KnuAcademicSource(),
      DaeguAcademicSource(),
      UlsanAcademicSource(),
      DeuAcademicSource(),
      BnueAcademicSource(),
      UtAcademicSource(),
      KookminAcademicSource(),
      UnistAcademicSource(),
      KangwonAcademicSource(),
      KaistAcademicSource(),
      CauAcademicSource(),
      YonginAcademicSource(),
      JejuAcademicSource(),
      KmuAcademicSource(),
      SsuAcademicSource(),
      SyuAcademicSource(),
      GnuAcademicSource(),
      InhaAcademicSource(),
      InuAcademicSource(),
      KwangwoonAcademicSource(),
      NsuAcademicSource(),
      CjeAcademicSource(),
      BuAcademicSource(),
      UosAcademicSource(),
      GinueAcademicSource(),
      CnueAcademicSource(),
      GjueAcademicSource(),
      MjuAcademicSource(),
      SogangAcademicSource(),
      SwuAcademicSource(),
      KoreatechAcademicSource(),
      PnuAcademicSource(),
      PknuAcademicSource(),
      HufsAcademicSource(),
      CnuAcademicSource(),
      DnueAcademicSource(),
      SnueAcademicSource(),
      GknuAcademicSource(),
      KhuAcademicSource(),
      KumohAcademicSource(),
      CueAcademicSource(),
      KoreaAcademicSource(),
      HanyangAcademicSource(),
      HanyangAcademicSource(erica: true),
      TukAcademicSource(),
      GnueAcademicSource(),
      JnueAcademicSource(),
      HoseoAcademicSource(),
      KmouAcademicSource(),
      DongaAcademicSource(),
      SeoultechAcademicSource(),
      KonkukAcademicSource(),
      KonkukAcademicSource(glocal: true),
      ChosunAcademicSource(),
      DgistAcademicSource(),
      YonseiAcademicSource(),
      GachonAcademicSource(),
      SkuAcademicSource(),
      KyonggiAcademicSource(),
      MmuAcademicSource(),
      YuAcademicSource(),
      SungshinAcademicSource(),
      CbnuAcademicSource(),
      KauAcademicSource(),
      HansungAcademicSource(),
      SuwonAcademicSource(),
      KnueKunsanAcademicSource.knue(),
      KnueKunsanAcademicSource.kunsan(),
      MokpoAcademicSource(),
      KongjuAcademicSource(),
      HanbatAcademicSource(),
      HknuAcademicSource(),
      SvAcademicSource.sunchon(),
      SvAcademicSource.changwon(),
      SchAcademicSource(),
      GeochangAcademicSource(),
      NamhaeAcademicSource(),
      JbnuAcademicSource(),
      DonggukAcademicSource(),
      DonggukAcademicSource(wise: true),
    ],
    store: settings.academicStore,
    settings: settings,
    repository: ref.watch(eventRepositoryProvider),
    commands: ref.watch(eventCommandServiceProvider),
    sync: ref.watch(syncServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final lmsControllerProvider = ChangeNotifierProvider<LmsController>((ref) {
  final presentation = ref.watch(lmsPresentationStateProvider);
  final controller = LmsController(
    settings: ref.watch(settingsRepositoryProvider),
    repository: ref.watch(eventRepositoryProvider),
    commands: ref.watch(eventCommandServiceProvider),
    analytics: ref.watch(productAnalyticsProvider),
    onIntegrationChanged: () {
      ref.read(appSettingsProvider.notifier).state = ref
          .read(settingsRepositoryProvider)
          .load();
      unawaited(
        ref
            .read(googleDriveSyncServiceProvider)
            .queueSettingsBackup()
            .catchError((_) {}),
      );
    },
  );
  presentation.controller = controller;
  ref.onDispose(() {
    if (identical(presentation.controller, controller)) {
      presentation.controller = null;
    }
  });
  return controller;
});

final scheduleParserProvider = Provider<ScheduleParser>((ref) {
  final settingsRepository = ref.watch(settingsRepositoryProvider);
  return HybridScheduleParser(
    ruleBasedParser: RuleBasedScheduleParser(),
    aiParser: GeminiScheduleParser(
      settingsRepository,
      modelName: defaultTargetPlatform == TargetPlatform.android
          ? 'gemini-3.6-flash'
          : 'gemini-2.0-flash',
    ),
    settingsRepository: settingsRepository,
  );
});

final visibleMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final calendarViewModeProvider = StateProvider<CalendarViewMode>((ref) {
  return ref.read(appSettingsProvider).defaultCalendarView;
});

final calendarSearchQueryProvider = StateProvider<String>((ref) => '');

/// How long an unused date range keeps its stream and result list (#170).
const eventsInRangeRetention = Duration(minutes: 2);

final eventsInRangeProvider = StreamProvider.autoDispose
    .family<List<CalendarEvent>, CalendarRange>((ref, range) {
      retainWhileRecentlyUsed(ref, eventsInRangeRetention);
      final lms = ref.watch(lmsControllerProvider);
      final holidayConfiguration = ref.watch(
        appSettingsProvider.select(
          (settings) => (
            id: settings.holidayCategory.id,
            label: settings.holidayCategory.label,
            colorValue: settings.holidayCategory.colorValue,
            locked: settings.holidayCategory.locked,
          ),
        ),
      );
      final holidayCategory = EventCategory(
        id: holidayConfiguration.id,
        label: holidayConfiguration.label,
        colorValue: holidayConfiguration.colorValue,
        locked: holidayConfiguration.locked,
      );
      final holidays = ref
          .watch(koreanHolidayServiceProvider)
          .holidayEventsInRange(
            range.start,
            range.end,
            category: holidayCategory,
          );
      return ref
          .watch(eventRepositoryProvider)
          .watchEventsInRange(range.start, range.end)
          .map((events) {
            return [...events.where(lms.isEventVisible), ...holidays]
              ..sort((a, b) => a.startAt.compareTo(b.startAt));
          });
    });

final eventsForSelectedDateProvider = Provider<AsyncValue<List<CalendarEvent>>>(
  (ref) {
    final selected = ref.watch(selectedDateProvider);
    final start = DateTime(selected.year, selected.month, selected.day);
    final end = start.add(const Duration(days: 1));
    return ref.watch(eventsInRangeProvider(CalendarRange(start, end)));
  },
);

extension DateTimeRangeX on DateTimeRange {
  CalendarRange toCalendarRange() => CalendarRange(start, end);
}

final timetablePeriodDefaultsProvider = FutureProvider<TimetablePeriodDefaults>(
  (ref) => TimetablePeriodDefaults.load(),
);

final timetablePeriodPreparationProvider = FutureProvider<void>((ref) async {
  final store = ref.watch(settingsRepositoryProvider).timetableStore;
  final profile = ref.watch(
    appSettingsProvider.select((s) => s.academicProfile),
  );
  final defaults = await ref.watch(timetablePeriodDefaultsProvider.future);
  // Existing pre-profile timetable caches belong to the original SMU catalog.
  // An explicitly selected university must never receive another school's dates.
  final university = profile == null
      ? 'smu'
      : profile.timetableUniversity ?? '';
  if (ref.mounted) await store.seedTermPeriods(defaults.periodsFor(university));
});

final timetableStoreProvider = Provider<TimetableStore>((ref) {
  ref.watch(timetablePeriodPreparationProvider);
  return ref.watch(settingsRepositoryProvider).timetableStore;
});
