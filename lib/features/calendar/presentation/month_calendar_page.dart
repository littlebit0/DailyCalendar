import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui show ImageFilter, TextDirection;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/app_providers.dart';
import '../../../core/analytics/product_analytics.dart';
import '../../../core/calendar/calendar_event_ordering.dart';
import '../../../core/calendar/calendar_event_movement.dart';
import '../../../core/calendar/calendar_period_label.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/siri/signal_voice_service.dart';
import '../../../core/theme/daily_ui.dart';
import '../../../core/theme/event_completion_style.dart';
import '../../../core/widgets/smooth_mouse_wheel_scroll_controller.dart';
import '../../../core/theme/calendar_date_color.dart';
import '../../chat/presentation/chat_input_bar.dart';
import '../../events/application/event_command_service.dart';
import '../../events/domain/calendar_event.dart';
import '../../events/presentation/event_completion_action.dart';
import '../../events/domain/event_category.dart';
import '../../events/domain/event_draft.dart';
import '../../events/domain/recurrence_rule.dart';
import '../../events/presentation/event_details_panel.dart';
import '../../events/presentation/event_editor_dialog.dart';
import '../../settings/presentation/settings_page.dart';
import '../widgets/calendar_event_drag_layer.dart';
import '../widgets/calendar_month_grid.dart';
import '../widgets/schedule_timeline_view.dart';

enum _BottomCenterAction { quickAccess, calendar, ai }

enum _BottomNavigationItem { quickAccess, week, month, day, siri }

enum _RecurringDragScope { onlyThis, future, all }

int _calendarContentOrder(bool quickAccessSelected, CalendarViewMode viewMode) {
  if (quickAccessSelected) {
    return 0;
  }
  return switch (viewMode) {
    CalendarViewMode.week => 1,
    CalendarViewMode.month => 2,
    CalendarViewMode.day => 3,
  };
}

int quickTodoColumnCountForPlatform(TargetPlatform platform, double width) {
  if (platform == TargetPlatform.iOS) {
    return 2;
  }
  if (_usesDesktopCalendarLayout(platform)) {
    return ((width + 12) / 292).floor().clamp(1, 4).toInt();
  }
  if (platform == TargetPlatform.android) {
    return switch (width) {
      >= 1000 => 3,
      _ => 2,
    };
  }
  return width >= 720 ? 2 : 1;
}

bool supportsCalendarPointerNavigation(TargetPlatform platform) {
  return platform == TargetPlatform.android ||
      platform == TargetPlatform.iOS ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux;
}

class _BottomBarUiState {
  const _BottomBarUiState({
    this.selectedAction,
    this.calendarViewControlSelected = false,
  });

  final _BottomCenterAction? selectedAction;
  final bool calendarViewControlSelected;
}

class MonthCalendarPage extends ConsumerStatefulWidget {
  const MonthCalendarPage({super.key});

  @override
  ConsumerState<MonthCalendarPage> createState() => _MonthCalendarPageState();
}

class _MonthCalendarPageState extends ConsumerState<MonthCalendarPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _bottomBarKey = GlobalKey();
  final _daySheetSurfaceKey = GlobalKey();
  final _calendarDragSurfaceKey = GlobalKey();
  final _eventSidebarSurfaceKey = GlobalKey();
  final _daySheetScrollController = DraggableScrollableController();
  final _daySheetRevealsCalendar = ValueNotifier(false);
  final _aiOpen = ValueNotifier(false);
  final _bottomBarUiState = ValueNotifier(const _BottomBarUiState());
  Timer? _searchDebounce;
  Timer? _eventDragEdgeTimer;
  Future<List<CalendarEvent>>? _searchResults;
  var _searchOpen = false;
  var _quickAccessSelected = false;
  var _showAllDayScheduleEvents = true;
  var _eventDragActive = false;
  var _eventDragVisualActive = false;
  int? _eventDragEdgeDirection;
  PersistentBottomSheetController? _daySheetController;
  var _daySheetOpen = false;
  Rect? _daySheetDragBounds;
  Rect? _daySheetDragReturnBounds;
  var _daySheetRevision = 0;

  @override
  void initState() {
    super.initState();
    _quickAccessSelected =
        ref.read(appSettingsProvider).appStartView == AppStartView.quickView;
    Future.microtask(() {
      if (!mounted) return;
      _recordAnalytics(AnalyticsRecord.screenView(AnalyticsScreen.calendar));
      _recordAnalytics(
        AnalyticsRecord.calendarViewChanged(
          _analyticsCalendarView(ref.read(calendarViewModeProvider)),
          trigger: AnalyticsTrigger.startup,
        ),
      );
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _eventDragEdgeTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _daySheetScrollController.dispose();
    _daySheetRevealsCalendar.dispose();
    _aiOpen.dispose();
    _bottomBarUiState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storedSettings = ref.watch(appSettingsProvider);
    final settings = storedSettings;
    final month = ref.watch(visibleMonthProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final viewMode = ref.watch(calendarViewModeProvider);
    final searchQuery = ref.watch(calendarSearchQueryProvider);
    final range = switch (viewMode) {
      CalendarViewMode.week => _weekRangeFor(
        selectedDate,
        settings.weekStartsOnMonday,
      ),
      CalendarViewMode.month => _monthRangeFor(
        month,
        settings.weekStartsOnMonday,
      ),
      CalendarViewMode.day => _dayRangeFor(selectedDate),
    };
    final eventsAsync = ref.watch(eventsInRangeProvider(range));
    final windowSize = MediaQuery.sizeOf(context);
    final platform = Theme.of(context).platform;
    final windowClass = dailyWindowClassFor(windowSize);
    final androidMedium =
        platform == TargetPlatform.android &&
        windowClass == DailyWindowClass.medium;
    final androidExpanded =
        platform == TargetPlatform.android &&
        windowClass == DailyWindowClass.expanded;
    final wide = platform == TargetPlatform.android
        ? androidExpanded
        : windowSize.width >= 880;
    final desktop = _usesDesktopCalendarLayout(platform);
    final inlineAi =
        (platform == TargetPlatform.iOS ||
            platform == TargetPlatform.android) &&
        settings.monthNavigationMode == MonthNavigationMode.horizontal;
    final showScheduleDaySidebar =
        (platform == TargetPlatform.macOS ||
            platform == TargetPlatform.linux ||
            androidExpanded) &&
        windowSize.width >= 720 &&
        viewMode == CalendarViewMode.day &&
        settings.weekDayLayoutMode == WeekDayLayoutMode.schedule;
    final showEventSidebar = wide || showScheduleDaySidebar;
    final showStableEventSidebar =
        !_quickAccessSelected &&
        showEventSidebar &&
        !(viewMode == CalendarViewMode.day && !showScheduleDaySidebar);

    return Scaffold(
      key: _scaffoldKey,
      body: Listener(
        key: const ValueKey('calendar-page-pointer-listener'),
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handlePagePointerDown,
        onPointerMove: _handleEventDragPointerMove,
        onPointerUp: (_) => _finishEventDragPointer(),
        onPointerCancel: (_) => _finishEventDragPointer(),
        child: SafeArea(
          bottom: desktop,
          child: Stack(
            children: [
              Column(
                children: [
                  _CalendarHeader(
                    month: month,
                    selectedDate: selectedDate,
                    viewMode: viewMode,
                    monthNavigationMode: settings.monthNavigationMode,
                    searchQuery: searchQuery,
                    searchOpen: _searchOpen,
                    quickAccessSelected: _quickAccessSelected,
                    onSearchPressed: _toggleSearch,
                    onQuickAccessPressed: () {
                      _closeSearch();
                      setState(() => _quickAccessSelected = true);
                    },
                    onCalendarViewSelected: _selectCalendarView,
                    onLlmPressed: _toggleAiPanel,
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          key: _calendarDragSurfaceKey,
                          child: _AndroidTabletCalendarFrame(
                            enabled: androidMedium,
                            child: _OrderedCalendarSwitcher(
                              order: _calendarContentOrder(
                                _quickAccessSelected,
                                viewMode,
                              ),
                              child: Column(
                                key: ValueKey<int>(
                                  _calendarContentOrder(
                                    _quickAccessSelected,
                                    viewMode,
                                  ),
                                ),
                                children: [
                                  if (_quickAccessSelected)
                                    Expanded(
                                      child: _QuickMonthPageView(
                                        month: month,
                                        onMonthChanged: (target) =>
                                            _setVisibleMonth(
                                              ref,
                                              target,
                                              ref.read(selectedDateProvider),
                                            ),
                                        pageBuilder: (context, pageMonth) =>
                                            Consumer(
                                              builder: (context, pageRef, _) =>
                                                  _buildQuickAccessPage(
                                                    context,
                                                    pageRef,
                                                    settings,
                                                    searchQuery,
                                                    pageMonth,
                                                  ),
                                            ),
                                      ),
                                    )
                                  else
                                    Expanded(
                                      child: _PaintOnlySearchLayout(
                                        searchOpen: _searchOpen,
                                        searchPanel: _InlineSearchPanel(
                                          controller: _searchController,
                                          focusNode: _searchFocusNode,
                                          results: _searchResults,
                                          onChanged: _handleSearchChanged,
                                          onSubmitted: _runSearch,
                                          onClose: _closeSearch,
                                          onEventSelected: _selectSearchResult,
                                        ),
                                        child: RepaintBoundary(
                                          key: const ValueKey(
                                            'calendar-content-repaint-boundary',
                                          ),
                                          child: _CalendarMainContent(
                                            month: month,
                                            selectedDate: selectedDate,
                                            viewMode: viewMode,
                                            settings: settings,
                                            searchQuery: searchQuery,
                                            showAllDayScheduleEvents:
                                                _showAllDayScheduleEvents,
                                            onShowAllDayScheduleEventsChanged:
                                                _setShowAllDayScheduleEvents,
                                            onMonthDelta: (delta) =>
                                                _moveVisibleRange(
                                                  ref,
                                                  viewMode,
                                                  month,
                                                  selectedDate,
                                                  delta,
                                                ),
                                            onDateSelected: (date, events) {
                                              ref
                                                      .read(
                                                        selectedDateProvider
                                                            .notifier,
                                                      )
                                                      .state =
                                                  date;
                                              if (viewMode !=
                                                      CalendarViewMode.day &&
                                                  !showStableEventSidebar) {
                                                _showDaySheet(
                                                  context,
                                                  date,
                                                  _eventsForDay(events, date),
                                                );
                                              }
                                            },
                                            externalEventDragActive:
                                                _eventDragVisualActive,
                                            externalEventDragInteractionActive:
                                                _eventDragActive,
                                            onEventDragStateChanged:
                                                _setEventDragVisualActive,
                                            onEventDragInteractionStateChanged:
                                                _setEventDragActive,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        _AnimatedCalendarSidebar(
                          key: const ValueKey(
                            'calendar-event-sidebar-transition',
                          ),
                          visible: showStableEventSidebar,
                          surfaceKey: _eventSidebarSurfaceKey,
                          child: KeyedSubtree(
                            key: const ValueKey('calendar-event-sidebar'),
                            child: Container(
                              width: 360,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                border: Border(
                                  left: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                                ),
                              ),
                              child: _MonthDetailsPanel(
                                eventsAsync: eventsAsync,
                                settings: settings,
                                searchQuery: searchQuery,
                                selectedDate: selectedDate,
                                onEventDragStateChanged:
                                    _setEventDragVisualActive,
                                onEventDragInteractionStateChanged:
                                    _setEventDragActive,
                                onEventDragGlobalPositionChanged:
                                    _handleAdaptiveEventDragPosition,
                                dragFeedbackSpecListenable:
                                    activeCalendarEventDragFeedbackSpec,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (inlineAi) _buildInlineAiPanel(),
                  if (!desktop)
                    ValueListenableBuilder<bool>(
                      valueListenable: _aiOpen,
                      builder: (context, aiOpen, _) {
                        return ValueListenableBuilder<_BottomBarUiState>(
                          valueListenable: _bottomBarUiState,
                          builder: (context, bottomState, _) {
                            return _CalendarBottomBar(
                              key: _bottomBarKey,
                              viewMode: viewMode,
                              calendarActive: !_quickAccessSelected,
                              activeAction: aiOpen
                                  ? _BottomCenterAction.ai
                                  : _quickAccessSelected
                                  ? _BottomCenterAction.quickAccess
                                  : _BottomCenterAction.calendar,
                              selectedAction: bottomState.selectedAction,
                              calendarViewControlSelected:
                                  bottomState.calendarViewControlSelected,
                              onCalendarViewInteractionStarted:
                                  _markCalendarViewControlSelected,
                              onCalendarViewSelected: (mode) {
                                _selectCalendarView(mode, fromBottomBar: true);
                                _markCalendarViewControlSelected();
                              },
                              onCenterActionSelected: _selectBottomAction,
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
              _buildAiOverlay(context, desktop: desktop, inline: inlineAi),
              if (_daySheetOpen && !_eventDragActive)
                Positioned.fill(
                  child: GestureDetector(
                    key: const ValueKey('day-sheet-outside-dismiss'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _dismissDaySheet,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSearch() {
    final opening = !_searchOpen;
    if (opening) {
      _closeAiPanel();
    }
    setState(() {
      _searchOpen = opening;
    });
    if (_searchOpen) {
      _recordAnalytics(
        AnalyticsRecord.featureUsed(
          AnalyticsFeature.search,
          outcome: AnalyticsOutcome.succeeded,
        ),
      );
      _recordAnalytics(AnalyticsRecord.screenView(AnalyticsScreen.search));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  void _setShowAllDayScheduleEvents(bool value) {
    if (_showAllDayScheduleEvents == value) return;
    setState(() => _showAllDayScheduleEvents = value);
  }

  void _setEventDragActive(bool value) {
    if (!mounted) return;
    if (!value) {
      _cancelEventDragEdgeNavigation();
      _daySheetRevealsCalendar.value = false;
      _daySheetDragBounds = null;
      _daySheetDragReturnBounds = null;
      activeCalendarEventDragFeedbackSpec.value =
          const CalendarEventDragFeedbackSpec.source();
    } else if (!_eventDragActive && _daySheetOpen) {
      final bounds = _daySheetBounds;
      final panel = _daySheetSurfaceKey.currentContext?.findRenderObject();
      if (bounds != null && panel is RenderBox && panel.hasSize) {
        _daySheetDragBounds = bounds;
        // The unchanged handle and safe area remain below the calendar.
        _daySheetDragReturnBounds = Rect.fromLTRB(
          bounds.left,
          bounds.bottom - (bounds.height - panel.size.height),
          bounds.right,
          bounds.bottom,
        );
      }
    }
    if (_eventDragActive == value) return;
    setState(() => _eventDragActive = value);
  }

  void _setEventDragVisualActive(bool value) {
    if (!mounted) return;
    if (!value) {
      activeCalendarEventDragFeedbackSpec.value =
          const CalendarEventDragFeedbackSpec.source();
    }
    if (_eventDragVisualActive == value) return;
    setState(() => _eventDragVisualActive = value);
  }

  void _handleEventDragPointerMove(PointerMoveEvent event) {
    _handleAdaptiveEventDragPosition(event.position);
  }

  void _handleEventDragGlobalPosition(Offset globalPosition) {
    if (!_eventDragActive) {
      return;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }
    final position = renderObject.globalToLocal(globalPosition);
    final viewMode = ref.read(calendarViewModeProvider);
    final settings = ref.read(appSettingsProvider);
    final vertical =
        viewMode == CalendarViewMode.month &&
        settings.monthNavigationMode == MonthNavigationMode.vertical;
    final threshold = _usesDesktopCalendarLayout(Theme.of(context).platform)
        ? 64.0
        : 52.0;
    final direction = vertical
        ? position.dy <= threshold
              ? -1
              : position.dy >= renderObject.size.height - threshold
              ? 1
              : null
        : position.dx <= threshold
        ? -1
        : position.dx >= renderObject.size.width - threshold
        ? 1
        : null;
    _setEventDragEdgeDirection(direction);
  }

  void _handleDaySheetEventDragPosition(Offset globalPosition) {
    _handleAdaptiveEventDragPosition(globalPosition);
    if (_eventDragActive &&
        _daySheetDragBounds != null &&
        activeCalendarEventDragFeedbackSpec.value.style ==
            CalendarEventDragFeedbackStyle.month) {
      _daySheetRevealsCalendar.value = true;
    }
  }

  Rect? get _daySheetBounds {
    if (!_daySheetOpen) return null;
    final sheetContext = _daySheetSurfaceKey.currentContext;
    // Include the drag handle and safe area, not just the event list.
    final renderObject = sheetContext
        ?.findAncestorStateOfType<State<BottomSheet>>()
        ?.context
        .findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  bool _isInsideDaySheet(Offset globalPosition) {
    if (!_daySheetOpen) return false;
    // Use the destination bounds during the animation to avoid re-opening the
    // sheet when crossing a date that its disappearing body used to cover.
    final bounds = _daySheetRevealsCalendar.value
        ? _daySheetDragReturnBounds
        : _daySheetDragBounds ?? _daySheetBounds;
    return bounds?.contains(globalPosition) ?? false;
  }

  void _handleAdaptiveEventDragPosition(Offset globalPosition) {
    if (!_eventDragActive) {
      return;
    }
    // The sheet overlays the calendar, so its visible bounds take precedence.
    if (_isInsideDaySheet(globalPosition)) {
      _cancelEventDragEdgeNavigation();
      _daySheetRevealsCalendar.value = false;
      _setActiveDragFeedbackSpec(const CalendarEventDragFeedbackSpec.source());
      return;
    }
    _handleEventDragGlobalPosition(globalPosition);

    final sidebarRenderObject = _eventSidebarSurfaceKey.currentContext
        ?.findRenderObject();
    if (sidebarRenderObject is RenderBox && sidebarRenderObject.hasSize) {
      final sidebarBounds =
          sidebarRenderObject.localToGlobal(Offset.zero) &
          sidebarRenderObject.size;
      if (sidebarBounds.contains(globalPosition)) {
        _setActiveDragFeedbackSpec(
          CalendarEventDragFeedbackSpec.target(
            style: CalendarEventDragFeedbackStyle.sidebar,
            width: math.max(160, sidebarRenderObject.size.width - 32),
            height: 76,
          ),
        );
        return;
      }
    }

    final renderObject = _calendarDragSurfaceKey.currentContext
        ?.findRenderObject();
    var nextSpec = const CalendarEventDragFeedbackSpec.source();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final bounds =
          renderObject.localToGlobal(Offset.zero) & renderObject.size;
      if (bounds.contains(globalPosition)) {
        final viewMode = ref.read(calendarViewModeProvider);
        final settings = ref.read(appSettingsProvider);
        final event = activeCalendarEventDrag.value?.event;
        switch (viewMode) {
          case CalendarViewMode.month:
            final compactMonth = MediaQuery.sizeOf(context).width < 720;
            final horizontalChrome = compactMonth ? 14.0 : 40.0;
            final cellWidth = math.max(
              1,
              (renderObject.size.width - horizontalChrome) / 7,
            );
            nextSpec = CalendarEventDragFeedbackSpec.target(
              style: CalendarEventDragFeedbackStyle.month,
              width: math.max(24, cellWidth - (compactMonth ? 2 : 10)),
              height: compactMonth ? 13 : 19,
            );
            break;
          case CalendarViewMode.week:
            if (settings.weekDayLayoutMode == WeekDayLayoutMode.schedule) {
              nextSpec = _scheduleDragFeedbackSpec(
                renderObject.size,
                dayCount: 7,
                event: event,
              );
            } else {
              nextSpec = CalendarEventDragFeedbackSpec.target(
                style: CalendarEventDragFeedbackStyle.week,
                width: math.max(56, (renderObject.size.width - 24) / 7 - 6),
                height: 32,
              );
            }
            break;
          case CalendarViewMode.day:
            if (settings.weekDayLayoutMode == WeekDayLayoutMode.schedule) {
              nextSpec = _scheduleDragFeedbackSpec(
                renderObject.size,
                dayCount: 1,
                event: event,
              );
            } else {
              nextSpec = CalendarEventDragFeedbackSpec.target(
                style: CalendarEventDragFeedbackStyle.day,
                width: math.max(120, renderObject.size.width - 32),
                height: 64,
              );
            }
            break;
        }
      }
    }
    _setActiveDragFeedbackSpec(nextSpec);
  }

  void _setActiveDragFeedbackSpec(CalendarEventDragFeedbackSpec nextSpec) {
    if (activeCalendarEventDragFeedbackSpec.value != nextSpec) {
      activeCalendarEventDragFeedbackSpec.value = nextSpec;
    }
  }

  CalendarEventDragFeedbackSpec _scheduleDragFeedbackSpec(
    Size surfaceSize, {
    required int dayCount,
    required CalendarEvent? event,
  }) {
    final gutter = dayCount > 1 ? 42.0 : 54.0;
    final dayWidth = math.max(1, (surfaceSize.width - gutter) / dayCount);
    final durationMinutes = event?.duration.inMinutes ?? 30;
    return CalendarEventDragFeedbackSpec.target(
      style: CalendarEventDragFeedbackStyle.schedule,
      width: math.max(44, dayWidth - 4),
      height: math.max(24, durationMinutes / 60 * 64 - 2),
    );
  }

  void _dismissDaySheet() {
    _daySheetController?.close();
  }

  void _setEventDragEdgeDirection(int? direction) {
    if (_eventDragEdgeDirection == direction &&
        (_eventDragEdgeTimer?.isActive ?? false)) {
      return;
    }
    _eventDragEdgeTimer?.cancel();
    _eventDragEdgeTimer = null;
    _eventDragEdgeDirection = direction;
    if (direction == null || !_eventDragActive) {
      return;
    }
    _eventDragEdgeTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => _moveDraggedEventViewport(direction),
    );
  }

  void _moveDraggedEventViewport(int direction) {
    if (!mounted || !_eventDragActive) {
      _cancelEventDragEdgeNavigation();
      return;
    }
    _moveVisibleRange(
      ref,
      ref.read(calendarViewModeProvider),
      ref.read(visibleMonthProvider),
      ref.read(selectedDateProvider),
      direction,
    );
  }

  void _cancelEventDragEdgeNavigation() {
    _eventDragEdgeTimer?.cancel();
    _eventDragEdgeTimer = null;
    _eventDragEdgeDirection = null;
  }

  void _finishEventDragPointer() {
    _cancelEventDragEdgeNavigation();
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    if (_searchOpen || _searchResults != null) {
      setState(() {
        _searchOpen = false;
        _searchResults = null;
      });
    }
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 260), () {
      _runSearch();
    });
  }

  void _runSearch() {
    final query = _searchController.text.trim();
    setState(() {
      _searchResults = query.isEmpty
          ? null
          : ref.read(eventRepositoryProvider).search(query);
    });
  }

  void _selectSearchResult(CalendarEvent event) {
    ref.read(visibleMonthProvider.notifier).state = DateTime(
      event.startAt.year,
      event.startAt.month,
    );
    ref.read(selectedDateProvider.notifier).state = DateTime(
      event.startAt.year,
      event.startAt.month,
      event.startAt.day,
    );
    _closeSearch();
  }

  void _selectCalendarView(
    CalendarViewMode viewMode, {
    bool fromBottomBar = false,
  }) {
    ref.read(calendarViewModeProvider.notifier).state = viewMode;
    _recordAnalytics(
      AnalyticsRecord.calendarViewChanged(
        _analyticsCalendarView(viewMode),
        trigger: AnalyticsTrigger.manual,
      ),
    );
    if (_quickAccessSelected) {
      setState(() => _quickAccessSelected = false);
    }
    if (!fromBottomBar) {
      _clearBottomAction();
    }
  }

  void _toggleAiPanel() {
    _toggleInlineAiPanel();
  }

  void _toggleInlineAiPanel() {
    _closeSearch();
    final opening = !_aiOpen.value;
    if (_quickAccessSelected) {
      setState(() => _quickAccessSelected = false);
    }
    _aiOpen.value = opening;
    _bottomBarUiState.value = _BottomBarUiState(
      selectedAction: opening ? _BottomCenterAction.ai : null,
    );
  }

  void _closeAiPanel() {
    if (!_aiOpen.value) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _aiOpen.value = false;
    if (_bottomBarUiState.value.selectedAction == _BottomCenterAction.ai) {
      _bottomBarUiState.value = const _BottomBarUiState();
    }
  }

  void _markBottomAction(_BottomCenterAction action) {
    final current = _bottomBarUiState.value;
    if (current.selectedAction == action &&
        !current.calendarViewControlSelected) {
      return;
    }
    _bottomBarUiState.value = _BottomBarUiState(selectedAction: action);
  }

  void _markCalendarViewControlSelected() {
    final current = _bottomBarUiState.value;
    if (current.calendarViewControlSelected && current.selectedAction == null) {
      return;
    }
    _bottomBarUiState.value = const _BottomBarUiState(
      calendarViewControlSelected: true,
    );
  }

  void _clearBottomAction() {
    final current = _bottomBarUiState.value;
    if (current.selectedAction == null &&
        !current.calendarViewControlSelected) {
      return;
    }
    _bottomBarUiState.value = const _BottomBarUiState();
  }

  void _handlePagePointerDown(PointerDownEvent event) {
    final renderObject = _bottomBarKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final localPosition = renderObject.globalToLocal(event.position);
      final bounds = Offset.zero & renderObject.size;
      if (bounds.contains(localPosition)) {
        return;
      }
    }
    _clearBottomAction();
  }

  void _selectBottomAction(_BottomCenterAction action) {
    switch (action) {
      case _BottomCenterAction.quickAccess:
        _markBottomAction(action);
        _closeSearch();
        _aiOpen.value = false;
        if (mounted && !_quickAccessSelected) {
          setState(() => _quickAccessSelected = true);
        }
        _recordAnalytics(
          AnalyticsRecord.calendarViewChanged(
            AnalyticsCalendarView.quickView,
            trigger: AnalyticsTrigger.manual,
          ),
        );
        _recordAnalytics(AnalyticsRecord.screenView(AnalyticsScreen.quickView));
      case _BottomCenterAction.calendar:
        _markBottomAction(action);
        _aiOpen.value = false;
        if (_quickAccessSelected && mounted) {
          setState(() => _quickAccessSelected = false);
        }
      case _BottomCenterAction.ai:
        _toggleAiPanel();
    }
  }

  Widget _buildInlineAiPanel() {
    return ValueListenableBuilder<bool>(
      valueListenable: _aiOpen,
      builder: (context, aiOpen, _) => AnimatedSize(
        key: const ValueKey('inline-ai-layout-panel'),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: aiOpen
            ? _assistantInput(const ValueKey('inline-ai-input'))
            : const SizedBox(width: double.infinity, height: 0),
      ),
    );
  }

  Widget _assistantInput(Key key) {
    if (Theme.of(context).platform == TargetPlatform.android) {
      return ChatInputBar(
        key: key,
        onClose: _closeAiPanel,
        includeBottomSafeArea: false,
      );
    }
    return _SignalVoicePanel(key: key, onClose: _closeAiPanel);
  }

  AnalyticsCalendarView _analyticsCalendarView(CalendarViewMode viewMode) {
    return switch (viewMode) {
      CalendarViewMode.week => AnalyticsCalendarView.week,
      CalendarViewMode.month => AnalyticsCalendarView.month,
      CalendarViewMode.day => AnalyticsCalendarView.day,
    };
  }

  void _recordAnalytics(AnalyticsRecord record) {
    unawaited(
      ref.read(productAnalyticsProvider).record(record).catchError((_) {}),
    );
  }

  Widget _buildAiOverlay(
    BuildContext context, {
    required bool desktop,
    required bool inline,
  }) {
    if (inline) {
      return const SizedBox.shrink();
    }
    final bottomInset = desktop
        ? 0.0
        : 62.0 + math.max(MediaQuery.paddingOf(context).bottom, 6.0);
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset,
      child: ValueListenableBuilder<bool>(
        valueListenable: _aiOpen,
        builder: (context, aiOpen, _) {
          return IgnorePointer(
            key: const ValueKey('inline-ai-panel-pointer'),
            ignoring: !aiOpen,
            child: ExcludeSemantics(
              excluding: !aiOpen,
              child: AnimatedOpacity(
                key: const ValueKey('inline-ai-panel-opacity'),
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                opacity: aiOpen ? 1 : 0,
                child: AnimatedSlide(
                  key: const ValueKey('inline-ai-panel'),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  offset: aiOpen ? Offset.zero : const Offset(0, 1.15),
                  child: aiOpen
                      ? _assistantInput(const ValueKey('overlay-ai-input'))
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickAccessPage(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    String query,
    DateTime currentMonth,
  ) {
    final range = _monthRangeFor(currentMonth, settings.weekStartsOnMonday);
    final eventsAsync = ref.watch(eventsInRangeProvider(range));

    return ColoredBox(
      color: DailyUi.pageBackground(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              DailyUi.isDesktop ? 24 : 16,
              DailyUi.isDesktop ? 22 : 16,
              DailyUi.isDesktop ? 24 : 16,
              18,
            ),
            child: eventsAsync.when(
              data: (events) {
                final visibleEvents = _filterVisibleEvents(
                  events,
                  settings,
                  query,
                );
                final groups = _quickTodoGroups(visibleEvents, settings);
                final monthLabel = DateFormat.yMMMM(
                  Localizations.localeOf(context).toLanguageTag(),
                ).format(currentMonth);
                return ListView(
                  key: const ValueKey('quick-view-list'),
                  primary: false,
                  children: [
                    DailyPageTitle(
                      title: context.tr('빠른 보기'),
                      subtitle: context.tr(
                        '{month} · 일정 {count}개',
                        args: {
                          'month': monthLabel,
                          'count': visibleEvents.length,
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (groups.isEmpty)
                      _QuickTodoEmptyState(message: context.tr('일정이 없습니다.'))
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          const spacing = 12.0;
                          final columns = _quickTodoColumnCount(
                            constraints.maxWidth,
                          );
                          final cardWidth =
                              (constraints.maxWidth - spacing * (columns - 1)) /
                              columns;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              for (final group in groups)
                                SizedBox(
                                  width: cardWidth,
                                  child: _QuickTodoCategoryCard(
                                    group: group,
                                    onCompletedChanged: (event, completed) =>
                                        ref
                                            .read(eventCommandServiceProvider)
                                            .setCompleted(event, completed),
                                    onOpen: (event) =>
                                        _showQuickEventDetails(context, event),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                  ],
                );
              },
              error: (error, stackTrace) => DailyInfoCallout(
                icon: Icons.error_outline_rounded,
                color: DailyUi.destructive,
                text: context.tr(
                  '일정을 불러오지 못했습니다. ({error})',
                  args: {'error': error},
                ),
              ),
              loading: () => const SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_QuickTodoGroup> _quickTodoGroups(
    List<CalendarEvent> events,
    AppSettings settings,
  ) {
    final categoryOrder = settings.categories
        .map((category) => category.id)
        .toList(growable: false);
    final sorted = sortedCalendarEvents(
      events.where(
        (event) => !event.holiday && !event.readOnly && !event.systemEvent,
      ),
      priority: settings.calendarEventSortPriority,
      categoryOrder: categoryOrder,
    );
    final byCategory = <String, List<CalendarEvent>>{};
    final categories = <String, EventCategory>{
      for (final category in settings.categories) category.id: category,
    };
    for (final event in sorted) {
      categories.putIfAbsent(event.category.id, () => event.category);
      byCategory.putIfAbsent(event.category.id, () => []).add(event);
    }
    return [
      for (final category in categories.values)
        if (byCategory[category.id]?.isNotEmpty ?? false)
          _QuickTodoGroup(category, byCategory[category.id]!),
    ];
  }

  int _quickTodoColumnCount(double width) {
    return quickTodoColumnCountForPlatform(defaultTargetPlatform, width);
  }

  Future<void> _showQuickEventDetails(
    BuildContext context,
    CalendarEvent event,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => EventDetailsPanel(
        date: event.startAt,
        events: [event],
        initialEvent: event,
      ),
    );
  }

  Future<void> _showDaySheet(
    BuildContext context,
    DateTime date,
    List<CalendarEvent> events,
  ) async {
    final revision = ++_daySheetRevision;
    final previousController = _daySheetController;
    if (previousController != null) {
      if (mounted) {
        setState(() {
          _daySheetController = null;
          _daySheetOpen = false;
        });
      }
      previousController.close();
      await previousController.closed;
    }
    if (!mounted || revision != _daySheetRevision) {
      return;
    }
    final scaffold = _scaffoldKey.currentState;
    if (scaffold == null) {
      return;
    }
    final controller = scaffold.showBottomSheet(
      (_) => SafeArea(
        top: false,
        child: ValueListenableBuilder<bool>(
          valueListenable: _daySheetRevealsCalendar,
          builder: (context, revealed, child) => IgnorePointer(
            ignoring: revealed,
            child: ClipRect(
              child: TweenAnimationBuilder<double>(
                key: const ValueKey('day-sheet-drag-reveal'),
                tween: Tween(end: revealed ? 0 : 1),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: child,
                builder: (context, factor, child) => Align(
                  alignment: Alignment.topCenter,
                  heightFactor: factor,
                  child: child,
                ),
              ),
            ),
          ),
          child: DraggableScrollableSheet(
            controller: _daySheetScrollController,
            expand: false,
            initialChildSize: 0.68,
            minChildSize: 0.4,
            maxChildSize: 0.96,
            snap: true,
            snapSizes: const [0.68],
            shouldCloseOnMinExtent: false,
            builder: (context, scrollController) => EventDetailsPanel(
              key: _daySheetSurfaceKey,
              date: date,
              events: events,
              scrollController: scrollController,
              onEventDropped: (event, targetDate, targetIndex) =>
                  _handleCalendarEventDrop(
                    context,
                    ref,
                    event,
                    targetDate,
                    targetIndex,
                  ),
              onEventDragStateChanged: _setEventDragVisualActive,
              onEventDragInteractionStateChanged: _setEventDragActive,
              onEventDragGlobalPositionChanged:
                  _handleDaySheetEventDragPosition,
            ),
          ),
        ),
      ),
      showDragHandle: true,
    );
    setState(() {
      _daySheetController = controller;
      _daySheetOpen = true;
      _daySheetRevealsCalendar.value = false;
    });
    await controller.closed;
    if (mounted && identical(_daySheetController, controller)) {
      setState(() {
        _daySheetController = null;
        _daySheetOpen = false;
      });
      _setEventDragActive(false);
    }
  }

  void _moveVisibleRange(
    WidgetRef ref,
    CalendarViewMode viewMode,
    DateTime currentMonth,
    DateTime selectedDate,
    int delta,
  ) {
    switch (viewMode) {
      case CalendarViewMode.month:
        _setVisibleMonth(
          ref,
          DateTime(currentMonth.year, currentMonth.month + delta),
          selectedDate,
        );
      case CalendarViewMode.week:
        final next = selectedDate.add(Duration(days: delta * 7));
        ref.read(selectedDateProvider.notifier).state = next;
        ref.read(visibleMonthProvider.notifier).state = DateTime(
          next.year,
          next.month,
        );
      case CalendarViewMode.day:
        final next = selectedDate.add(Duration(days: delta));
        ref.read(selectedDateProvider.notifier).state = next;
        ref.read(visibleMonthProvider.notifier).state = DateTime(
          next.year,
          next.month,
        );
    }
  }
}

class _OrderedCalendarSwitcher extends StatefulWidget {
  const _OrderedCalendarSwitcher({required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  State<_OrderedCalendarSwitcher> createState() =>
      _OrderedCalendarSwitcherState();
}

class _OrderedCalendarSwitcherState extends State<_OrderedCalendarSwitcher> {
  var _direction = 1;

  @override
  void didUpdateWidget(covariant _OrderedCalendarSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.order != oldWidget.order) {
      _direction = widget.order > oldWidget.order ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentKey = ValueKey<int>(widget.order);
    return ClipRect(
      child: AnimatedSwitcher(
        key: const ValueKey('calendar-content-switcher'),
        duration: const Duration(milliseconds: 260),
        reverseDuration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          fit: StackFit.expand,
          children: [...previousChildren, ?currentChild],
        ),
        transitionBuilder: (child, animation) {
          final entering = child.key == currentKey;
          final offset = Offset(
            (entering ? _direction : -_direction).toDouble(),
            0,
          );
          return SlideTransition(
            position: animation.drive(Tween(begin: offset, end: Offset.zero)),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _AndroidTabletCalendarFrame extends StatelessWidget {
  const _AndroidTabletCalendarFrame({
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    return ColoredBox(
      color: DailyUi.pageBackground(context),
      child: Padding(
        key: const ValueKey('android-tablet-content-frame'),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: ConstrainedBox(
            key: const ValueKey('android-tablet-content-constraint'),
            constraints: const BoxConstraints(maxWidth: 1120),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _AnimatedCalendarSidebar extends StatefulWidget {
  const _AnimatedCalendarSidebar({
    super.key,
    required this.visible,
    required this.surfaceKey,
    required this.child,
  });

  final bool visible;
  final GlobalKey surfaceKey;
  final Widget child;

  @override
  State<_AnimatedCalendarSidebar> createState() =>
      _AnimatedCalendarSidebarState();
}

class _AnimatedCalendarSidebarState extends State<_AnimatedCalendarSidebar>
    with SingleTickerProviderStateMixin {
  static const _width = 360.0;
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 210),
      value: widget.visible ? 1 : 0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _AnimatedCalendarSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: _animation,
        child: widget.child,
        builder: (context, child) {
          final factor = _animation.value;
          return SizedBox(
            key: widget.surfaceKey,
            width: _width * factor,
            height: constraints.maxHeight,
            child: ClipRect(
              child: OverflowBox(
                alignment: AlignmentDirectional.centerEnd,
                minWidth: _width,
                maxWidth: _width,
                minHeight: constraints.maxHeight,
                maxHeight: constraints.maxHeight,
                child: Offstage(
                  offstage: !widget.visible && _controller.isDismissed,
                  child: IgnorePointer(
                    ignoring: !widget.visible,
                    child: Opacity(opacity: factor, child: child),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PaintOnlySearchLayout extends StatefulWidget {
  const _PaintOnlySearchLayout({
    required this.searchOpen,
    required this.searchPanel,
    required this.child,
  });

  final bool searchOpen;
  final Widget searchPanel;
  final Widget child;

  @override
  State<_PaintOnlySearchLayout> createState() => _PaintOnlySearchLayoutState();
}

class _PaintOnlySearchLayoutState extends State<_PaintOnlySearchLayout>
    with SingleTickerProviderStateMixin {
  static const _fallbackPanelExtent = 66.0;

  late final AnimationController _controller;
  double _panelExtent = _fallbackPanelExtent;
  Widget? _retainedSearchPanel;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 160),
      value: widget.searchOpen ? 1 : 0,
    );
    _retainedSearchPanel = widget.searchOpen ? widget.searchPanel : null;
    _controller.addStatusListener(_handleAnimationStatus);
  }

  @override
  void didUpdateWidget(covariant _PaintOnlySearchLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchOpen) {
      _retainedSearchPanel = widget.searchPanel;
    }
    if (widget.searchOpen == oldWidget.searchOpen) {
      return;
    }
    if (widget.searchOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed &&
        !widget.searchOpen &&
        _retainedSearchPanel != null &&
        mounted) {
      setState(() => _retainedSearchPanel = null);
    }
  }

  void _handlePanelSize(Size size) {
    if (!mounted || size.height <= 0 || size.height == _panelExtent) {
      return;
    }
    setState(() => _panelExtent = size.height);
  }

  @override
  Widget build(BuildContext context) {
    final searchPanel = _retainedSearchPanel;
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return Stack(
      key: const ValueKey('paint-only-search-layout'),
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: _panelExtent),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: widget.child,
          builder: (context, panelExtent, child) => AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (context, child) => Transform.translate(
              key: const ValueKey('search-calendar-translation'),
              offset: Offset(0, panelExtent * animation.value),
              child: child,
            ),
          ),
        ),
        if (searchPanel != null)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ClipRect(
              child: AnimatedBuilder(
                animation: animation,
                child: _SizeReporter(
                  onSizeChanged: _handlePanelSize,
                  child: searchPanel,
                ),
                builder: (context, child) => IgnorePointer(
                  ignoring: !widget.searchOpen,
                  child: ExcludeSemantics(
                    excluding: !widget.searchOpen,
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: animation.value,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSizeChanged, required super.child});

  final ValueChanged<Size> onSizeChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _SizeReporterRenderObject(onSizeChanged);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _SizeReporterRenderObject renderObject,
  ) {
    renderObject.onSizeChanged = onSizeChanged;
  }
}

class _SizeReporterRenderObject extends RenderProxyBox {
  _SizeReporterRenderObject(this.onSizeChanged);

  ValueChanged<Size> onSizeChanged;
  Size? _reportedSize;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _reportedSize) {
      return;
    }
    _reportedSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSizeChanged(size));
  }
}

enum _SignalVoiceState {
  listening,
  processing,
  awaitingConfirmation,
  completed,
  failed,
}

class _SignalVoicePanel extends ConsumerStatefulWidget {
  const _SignalVoicePanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<_SignalVoicePanel> createState() => _SignalVoicePanelState();
}

class _SignalVoicePanelState extends ConsumerState<_SignalVoicePanel>
    with WidgetsBindingObserver {
  final _voice = SignalVoiceService.instance;
  final _textController = TextEditingController();
  final _textFocusNode = FocusNode();
  _SignalVoiceState _state = _SignalVoiceState.listening;
  String _transcript = '';
  String _response = '';
  String _conversation = '';
  String _pendingCommand = '';
  bool _closing = false;
  bool _nativeListening = false;
  bool _showTextInput = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voice.setHandlers(
      onTranscriptChanged: (transcript) {
        if (mounted) setState(() => _transcript = transcript);
      },
      onListeningStarted: () {
        if (mounted) setState(() => _nativeListening = true);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
    _closing = true;
    WidgetsBinding.instance.removeObserver(this);
    _voice.setHandlers();
    _voice.cancelListening().catchError((_) {});
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_nativeListening || _closing) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _nativeListening = false;
      unawaited(_voice.cancelListening().catchError((_) {}));
      if (mounted) {
        setState(() {
          _response = context.tr('음성 듣기가 중단되었습니다.');
          _state = _SignalVoiceState.failed;
        });
      }
    }
  }

  Future<void> _listen() async {
    if (!mounted) return;
    setState(() {
      _state = _SignalVoiceState.listening;
      _transcript = '';
      _response = '';
      _pendingCommand = '';
      _showTextInput = false;
    });
    try {
      final spoken = await _voice.startListening();
      if (!mounted || _closing) return;
      _nativeListening = false;
      await _acceptCommand(spoken);
    } on PlatformException catch (error) {
      _nativeListening = false;
      if (!mounted || _closing || error.code == 'listening_cancelled') return;
      _showPlatformError(error);
    } catch (_) {
      _nativeListening = false;
      if (!mounted || _closing) return;
      setState(() {
        _response = context.tr('음성 명령을 처리하지 못했습니다.');
        _state = _SignalVoiceState.failed;
      });
    }
  }

  Future<void> _acceptCommand(String spoken) async {
    final command = [
      _conversation,
      spoken.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    if (command.isEmpty) return;
    setState(() => _transcript = spoken.trim());
    // Native parsing asks for missing required fields first. Once the command
    // is complete it returns signal_confirmation_required immediately before
    // the mutation, so users confirm exactly once at the correct point.
    await _execute(command, confirmed: false);
  }

  Future<void> _execute(String command, {required bool confirmed}) async {
    setState(() {
      _pendingCommand = '';
      _state = _SignalVoiceState.processing;
    });
    try {
      final result = await _voice.runSignal(command, confirmed: confirmed);
      if (!mounted || _closing) return;
      if (result.success) {
        ref.invalidate(eventsInRangeProvider);
        ref.invalidate(eventsForSelectedDateProvider);
        unawaited(ref.read(calendarWidgetServiceProvider).refresh());
      }
      setState(() {
        _conversation = '';
        _response = result.message;
        _state = result.success
            ? _SignalVoiceState.completed
            : _SignalVoiceState.failed;
      });
      if (result.message.isNotEmpty) {
        await _voice.speak(result.message);
      }
    } on PlatformException catch (error) {
      if (!mounted || _closing) return;
      _showPlatformError(error, command: command);
    } catch (_) {
      if (!mounted || _closing) return;
      setState(() {
        _response = context.tr('음성 명령을 처리하지 못했습니다.');
        _state = _SignalVoiceState.failed;
      });
    }
  }

  void _showPlatformError(PlatformException error, {String? command}) {
    if (error.code == 'signal_confirmation_required') {
      final pending = command ?? _transcript;
      final message = context.tr('이 명령을 실행할까요?');
      setState(() {
        _pendingCommand = pending;
        _response = message;
        _state = _SignalVoiceState.awaitingConfirmation;
      });
      unawaited(_voice.speak(message));
      return;
    }
    final needsMoreInformation = error.code == 'signal_needs_input';
    final message = switch (error.code) {
      'signal_auth_cancelled' ||
      'signal_cancelled' => context.tr('인증 또는 작업이 취소되었습니다.'),
      'signal_auth_failed' => context.tr('기기 인증을 완료하지 못했습니다.'),
      'signal_execution_failed' =>
        error.message ?? context.tr('음성 명령을 처리하지 못했습니다.'),
      _ when needsMoreInformation => context.tr('필요한 정보를 이어서 말씀해 주세요.'),
      _ => error.message ?? context.tr('음성 명령을 처리하지 못했습니다.'),
    };
    setState(() {
      if (needsMoreInformation && (command ?? _transcript).trim().isNotEmpty) {
        _conversation = (command ?? _transcript).trim();
      }
      _response = message;
      _state = _SignalVoiceState.failed;
    });
    if (needsMoreInformation) unawaited(_voice.speak(message));
  }

  Future<void> _finishListening() async {
    try {
      await _voice.finishListening();
    } catch (_) {}
  }

  Future<void> _confirmCommand() async {
    final command = _pendingCommand;
    if (command.isEmpty) return;
    await _execute(command, confirmed: true);
  }

  void _cancelCommand() {
    setState(() {
      _pendingCommand = '';
      _conversation = '';
      _response = context.tr('작업을 취소했습니다.');
      _state = _SignalVoiceState.failed;
    });
  }

  Future<void> _toggleTextInput() async {
    if (_nativeListening) {
      _nativeListening = false;
      await _voice.cancelListening().catchError((_) {});
    }
    if (!mounted) return;
    setState(() => _showTextInput = !_showTextInput);
    if (_showTextInput) _textFocusNode.requestFocus();
  }

  Future<void> _submitTyped(String value) async {
    final input = value.trim();
    if (input.isEmpty) return;
    _textController.clear();
    await _acceptCommand(input);
  }

  @override
  Widget build(BuildContext context) {
    final listening = _state == _SignalVoiceState.listening;
    final processing = _state == _SignalVoiceState.processing;
    final awaitingConfirmation =
        _state == _SignalVoiceState.awaitingConfirmation;
    final status = switch (_state) {
      _SignalVoiceState.listening => context.tr('지금 듣는 중...'),
      _SignalVoiceState.processing => context.tr('시그널 처리 중...'),
      _SignalVoiceState.awaitingConfirmation => context.tr('실행 확인'),
      _SignalVoiceState.completed => context.tr('완료'),
      _SignalVoiceState.failed => context.tr('다시 말씀해 주세요'),
    };

    return Material(
      color: DailyUi.pageBackground(context),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Material(
            color: DailyUi.groupedSurface(context),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: DailyUi.separator(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton.filled(
                          tooltip: listening
                              ? context.tr('듣기 완료')
                              : context.tr('다시 듣기'),
                          onPressed: processing || awaitingConfirmation
                              ? null
                              : listening
                              ? _finishListening
                              : _listen,
                          style: IconButton.styleFrom(
                            backgroundColor: DailyUi.purple,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: DailyUi.purple.withValues(
                              alpha: 0.35,
                            ),
                          ),
                          icon: processing
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  listening
                                      ? Icons.stop_rounded
                                      : Icons.mic_rounded,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                status,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                              if (_transcript.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _transcript,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                              if (_response.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _response,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: DailyUi.primary,
                                        height: 1.35,
                                      ),
                                ),
                              ],
                              if (awaitingConfirmation) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    FilledButton(
                                      onPressed: _confirmCommand,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: DailyUi.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: Text(context.tr('실행')),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: _cancelCommand,
                                      child: Text(context.tr('취소')),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      DailyIconAction(
                        tooltip: context.tr('텍스트로 입력'),
                        onPressed: processing ? null : _toggleTextInput,
                        selected: _showTextInput,
                        icon: _showTextInput
                            ? Icons.keyboard_hide_rounded
                            : Icons.keyboard_alt_outlined,
                      ),
                      DailyIconAction(
                        tooltip: context.tr('AI 입력 닫기'),
                        onPressed: widget.onClose,
                        icon: Icons.close_rounded,
                      ),
                    ],
                  ),
                  if (_showTextInput) ...[
                    const SizedBox(height: 10),
                    TextField(
                      key: const ValueKey('signal-text-input'),
                      controller: _textController,
                      focusNode: _textFocusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _submitTyped,
                      decoration: InputDecoration(
                        hintText: context.tr('Daily에 요청할 내용을 입력하세요.'),
                        prefixIcon: const Icon(Icons.keyboard_alt_outlined),
                        suffixIcon: DailyIconAction(
                          tooltip: context.tr('실행'),
                          onPressed: () => _submitTyped(_textController.text),
                          icon: Icons.arrow_upward_rounded,
                          size: 36,
                        ),
                        fillColor: DailyUi.elevatedSurface(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: DailyUi.separator(context),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: DailyUi.separator(context),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: DailyUi.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineSearchPanel extends StatelessWidget {
  const _InlineSearchPanel({
    required this.controller,
    required this.focusNode,
    required this.results,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClose,
    required this.onEventSelected,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<List<CalendarEvent>>? results;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onClose;
  final ValueChanged<CalendarEvent> onEventSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        color: DailyUi.pageBackground(context),
        border: Border(bottom: BorderSide(color: DailyUi.separator(context))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.search,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmitted(),
            decoration: InputDecoration(
              hintText: context.tr('제목, 메모, 장소 검색'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DailyIconAction(
                    tooltip: context.tr('검색'),
                    onPressed: onSubmitted,
                    icon: Icons.arrow_forward_rounded,
                    size: 36,
                  ),
                  DailyIconAction(
                    tooltip: context.tr('닫기'),
                    onPressed: onClose,
                    icon: Icons.close_rounded,
                    size: 36,
                  ),
                ],
              ),
              fillColor: DailyUi.groupedSurface(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: DailyUi.separator(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: DailyUi.separator(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: DailyUi.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          FutureBuilder<List<CalendarEvent>>(
            future: results,
            builder: (context, snapshot) {
              if (results == null) {
                return const SizedBox.shrink();
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: LinearProgressIndicator(minHeight: 2),
                );
              }
              final events = snapshot.data ?? const <CalendarEvent>[];
              if (events.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.tr('검색 결과가 없습니다.'),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(top: 10),
                  itemBuilder: (context, index) => _InlineSearchResultTile(
                    event: events[index],
                    onTap: () => onEventSelected(events[index]),
                    onCompletedChanged: onSubmitted,
                  ),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemCount: events.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InlineSearchResultTile extends StatelessWidget {
  const _InlineSearchResultTile({
    required this.event,
    required this.onTap,
    required this.onCompletedChanged,
  });

  final CalendarEvent event;
  final VoidCallback onTap;
  final VoidCallback onCompletedChanged;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMMd(locale).format(event.startAt);
    final time = event.allDay
        ? context.tr('종일')
        : DateFormat.Hm(locale).format(event.startAt);
    final color = Color(event.colorValue);
    return Material(
      color: DailyUi.groupedSurface(context),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: DailyUi.separator(context)),
      ),
      child: EventCompletionAction(
        event: event,
        onCompletedChanged: (_) => onCompletedChanged(),
        builder: (onDoubleTap) => InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 2,
            ),
            leading: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.event_outlined, color: color, size: 19),
            ),
            title: Text(
              context.l10n.eventTitle(event.title, holiday: event.holiday),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: calendarEventCompletionStyle(
                context,
                Theme.of(context).textTheme.titleMedium,
                completed: event.completed,
                eventColor: color,
              ),
            ),
            subtitle: Text('$date  $time'),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: DailyUi.tertiaryText(context),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthDetailsPanel extends ConsumerWidget {
  const _MonthDetailsPanel({
    required this.eventsAsync,
    required this.settings,
    required this.searchQuery,
    required this.selectedDate,
    required this.onEventDragStateChanged,
    required this.onEventDragInteractionStateChanged,
    required this.onEventDragGlobalPositionChanged,
    required this.dragFeedbackSpecListenable,
  });

  final AsyncValue<List<CalendarEvent>> eventsAsync;
  final AppSettings settings;
  final String searchQuery;
  final DateTime selectedDate;
  final ValueChanged<bool> onEventDragStateChanged;
  final ValueChanged<bool> onEventDragInteractionStateChanged;
  final ValueChanged<Offset> onEventDragGlobalPositionChanged;
  final ValueListenable<CalendarEventDragFeedbackSpec>
  dragFeedbackSpecListenable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return eventsAsync.when(
      data: (events) => _buildPanel(context, ref, events),
      error: (error, stackTrace) => Center(child: Text('$error')),
      loading: () => EventDetailsPanel(
        date: selectedDate,
        events: const <CalendarEvent>[],
      ),
    );
  }

  Widget _buildPanel(
    BuildContext context,
    WidgetRef ref,
    List<CalendarEvent> events,
  ) {
    return EventDetailsPanel(
      date: selectedDate,
      events: _eventsForDay(
        _filterVisibleEvents(events, settings, searchQuery),
        selectedDate,
      ),
      onEventDropped: (event, targetDate, targetIndex) =>
          _handleCalendarEventDrop(
            context,
            ref,
            event,
            targetDate,
            targetIndex,
          ),
      onEventDragStateChanged: onEventDragStateChanged,
      onEventDragInteractionStateChanged: onEventDragInteractionStateChanged,
      onEventDragGlobalPositionChanged: onEventDragGlobalPositionChanged,
      dragFeedbackSpecListenable: dragFeedbackSpecListenable,
      dragOrigin: CalendarEventDragOrigin.sidebar,
    );
  }
}

class _CalendarMainContent extends StatelessWidget {
  const _CalendarMainContent({
    required this.month,
    required this.selectedDate,
    required this.viewMode,
    required this.settings,
    required this.searchQuery,
    required this.showAllDayScheduleEvents,
    required this.onShowAllDayScheduleEventsChanged,
    required this.onMonthDelta,
    required this.onDateSelected,
    required this.externalEventDragActive,
    required this.externalEventDragInteractionActive,
    required this.onEventDragStateChanged,
    required this.onEventDragInteractionStateChanged,
  });

  final DateTime month;
  final DateTime selectedDate;
  final CalendarViewMode viewMode;
  final AppSettings settings;
  final String searchQuery;
  final bool showAllDayScheduleEvents;
  final ValueChanged<bool> onShowAllDayScheduleEventsChanged;
  final ValueChanged<int> onMonthDelta;
  final void Function(DateTime date, List<CalendarEvent> events) onDateSelected;
  final bool externalEventDragActive;
  final bool externalEventDragInteractionActive;
  final ValueChanged<bool> onEventDragStateChanged;
  final ValueChanged<bool> onEventDragInteractionStateChanged;

  @override
  Widget build(BuildContext context) {
    return switch (viewMode) {
      CalendarViewMode.month => _MonthPageView(
        month: month,
        selectedDate: selectedDate,
        settings: settings,
        searchQuery: searchQuery,
        onMonthDelta: onMonthDelta,
        onDateSelected: onDateSelected,
        externalEventDragActive: externalEventDragActive,
        externalEventDragInteractionActive: externalEventDragInteractionActive,
        onEventDragStateChanged: onEventDragStateChanged,
        onEventDragInteractionStateChanged: onEventDragInteractionStateChanged,
      ),
      CalendarViewMode.week => _WeekPageView(
        selectedDate: selectedDate,
        settings: settings,
        searchQuery: searchQuery,
        showAllDayScheduleEvents: showAllDayScheduleEvents,
        onShowAllDayScheduleEventsChanged: onShowAllDayScheduleEventsChanged,
        onWeekDelta: onMonthDelta,
        onDateSelected: onDateSelected,
        externalEventDragActive: externalEventDragActive,
        externalEventDragInteractionActive: externalEventDragInteractionActive,
        onEventDragStateChanged: onEventDragStateChanged,
        onEventDragInteractionStateChanged: onEventDragInteractionStateChanged,
      ),
      CalendarViewMode.day => _DayPageView(
        selectedDate: selectedDate,
        settings: settings,
        searchQuery: searchQuery,
        showAllDayScheduleEvents: showAllDayScheduleEvents,
        onShowAllDayScheduleEventsChanged: onShowAllDayScheduleEventsChanged,
        onDayDelta: onMonthDelta,
        onDateSelected: (date) => onDateSelected(date, const []),
        externalEventDragActive: externalEventDragActive,
        externalEventDragInteractionActive: externalEventDragInteractionActive,
        onEventDragStateChanged: onEventDragStateChanged,
        onEventDragInteractionStateChanged: onEventDragInteractionStateChanged,
      ),
    };
  }
}

class _WeekPageView extends StatefulWidget {
  const _WeekPageView({
    required this.selectedDate,
    required this.settings,
    required this.searchQuery,
    required this.showAllDayScheduleEvents,
    required this.onShowAllDayScheduleEventsChanged,
    required this.onWeekDelta,
    required this.onDateSelected,
    required this.externalEventDragActive,
    required this.externalEventDragInteractionActive,
    required this.onEventDragStateChanged,
    required this.onEventDragInteractionStateChanged,
  });

  final DateTime selectedDate;
  final AppSettings settings;
  final String searchQuery;
  final bool showAllDayScheduleEvents;
  final ValueChanged<bool> onShowAllDayScheduleEventsChanged;
  final ValueChanged<int> onWeekDelta;
  final void Function(DateTime date, List<CalendarEvent> events) onDateSelected;
  final bool externalEventDragActive;
  final bool externalEventDragInteractionActive;
  final ValueChanged<bool> onEventDragStateChanged;
  final ValueChanged<bool> onEventDragInteractionStateChanged;

  @override
  State<_WeekPageView> createState() => _WeekPageViewState();
}

class _WeekPageViewState extends State<_WeekPageView> {
  static const _initialPage = 12000;

  late final PageController _controller;
  late final DateTime _anchorDate;
  var _currentPage = _initialPage;
  var _reportedPage = _initialPage;
  var _applyingExternalDate = false;
  var _externalAnimationRevision = 0;
  var _settleCommitRevision = 0;
  DateTime? _lastPointerWeekMoveAt;
  final _mouseWheelNavigation = _MouseWheelPageNavigation();

  @override
  void initState() {
    super.initState();
    _anchorDate = _dateOnly(widget.selectedDate);
    _controller = PageController(initialPage: _initialPage);
  }

  @override
  void didUpdateWidget(covariant _WeekPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_controller.hasClients) {
      return;
    }
    final targetPage =
        _initialPage + _weekDelta(_anchorDate, widget.selectedDate);
    if (targetPage == _currentPage) {
      return;
    }
    _animateToExternalPage(targetPage);
  }

  @override
  void dispose() {
    _mouseWheelNavigation.reset();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: const ValueKey('week-pointer-navigation'),
      behavior: HitTestBehavior.opaque,
      onPointerSignal: _handlePointerSignal,
      onPointerPanZoomStart: (_) => _mouseWheelNavigation.reset(),
      child: NotificationListener<ScrollEndNotification>(
        onNotification: _handlePageScrollEnd,
        child: PageView.builder(
          controller: _controller,
          allowImplicitScrolling: true,
          physics: _calendarPagePhysics(context),
          onPageChanged: (index) {
            if (_applyingExternalDate || index == _currentPage) {
              return;
            }
            final delta = index - _currentPage;
            _currentPage = index;
            if (!_defersPageStateCommitUntilScrollEnd(context)) {
              _reportedPage = index;
              widget.onWeekDelta(delta);
            }
          },
          itemBuilder: (context, index) {
            final pageDate = _anchorDate.add(
              Duration(days: (index - _initialPage) * 7),
            );
            return _desktopMouseWheelSignalRegion(
              context,
              onPointerSignal: _handlePointerSignal,
              child: _CalendarWeekPage(
                selectedDate: pageDate,
                settings: widget.settings,
                searchQuery: widget.searchQuery,
                showAllDayScheduleEvents: widget.showAllDayScheduleEvents,
                onShowAllDayScheduleEventsChanged:
                    widget.onShowAllDayScheduleEventsChanged,
                onDateSelected: widget.onDateSelected,
                externalEventDragActive: widget.externalEventDragActive,
                externalEventDragInteractionActive:
                    widget.externalEventDragInteractionActive,
                onEventDragStateChanged: widget.onEventDragStateChanged,
                onEventDragInteractionStateChanged:
                    widget.onEventDragInteractionStateChanged,
              ),
            );
          },
        ),
      ),
    );
  }

  bool _handlePageScrollEnd(ScrollEndNotification notification) {
    if (notification.depth != 0 ||
        !_defersPageStateCommitUntilScrollEnd(context)) {
      return false;
    }
    final revision = ++_settleCommitRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          revision != _settleCommitRevision ||
          _applyingExternalDate ||
          !_controller.hasClients ||
          _controller.position.isScrollingNotifier.value) {
        return;
      }
      final page = _controller.page;
      if (page == null || (page - page.round()).abs() > 0.001) {
        return;
      }
      _currentPage = page.round();
      if (_reportedPage == _currentPage) {
        return;
      }
      final delta = _currentPage - _reportedPage;
      _reportedPage = _currentPage;
      widget.onWeekDelta(delta);
    });
    return false;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    final navigationDelta = _pointerPageNavigationDelta(
      context,
      event,
      allowVerticalMouseWheel:
          widget.settings.weekDayLayoutMode == WeekDayLayoutMode.list,
    );
    if (navigationDelta == null || !_controller.hasClients) {
      return;
    }
    final scroll = event as PointerScrollEvent;
    final direction = navigationDelta > 0 ? 1 : -1;
    if (scroll.kind == PointerDeviceKind.mouse) {
      GestureBinding.instance.pointerSignalResolver.register(event, (_) {
        if (!mounted || !_controller.hasClients) {
          return;
        }
        event.respond(allowPlatformDefault: false);
        if (_isWindowsMouseWheel(context, scroll)) {
          _mouseWheelNavigation.scheduleWindowsBurst(
            controller: _controller,
            currentPage: _currentPage,
            axis: _primaryMouseWheelAxis(scroll),
            direction: direction,
          );
        } else {
          _mouseWheelNavigation.animateUncoalesced(
            controller: _controller,
            currentPage: _currentPage,
            direction: direction,
          );
        }
      });
      return;
    }
    _navigateFromTrackpad(direction);
  }

  void _navigateFromTrackpad(int direction) {
    final now = DateTime.now();
    final lastMoveAt = _lastPointerWeekMoveAt;
    if (lastMoveAt != null &&
        now.difference(lastMoveAt) < const Duration(milliseconds: 280)) {
      return;
    }
    _lastPointerWeekMoveAt = now;
    final nextPage = _currentPage + direction;
    unawaited(
      _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _animateToExternalPage(int targetPage) {
    _mouseWheelNavigation.reset();
    _settleCommitRevision += 1;
    final revision = ++_externalAnimationRevision;
    _applyingExternalDate = true;
    _currentPage = targetPage;
    _reportedPage = targetPage;
    unawaited(
      _controller
          .animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (mounted && revision == _externalAnimationRevision) {
              _applyingExternalDate = false;
            }
          }),
    );
  }

  int _weekDelta(DateTime from, DateTime to) {
    final fromStart = _weekRangeFor(
      from,
      widget.settings.weekStartsOnMonday,
    ).start;
    final toStart = _weekRangeFor(to, widget.settings.weekStartsOnMonday).start;
    return toStart.difference(fromStart).inDays ~/ 7;
  }
}

class _CalendarWeekPage extends ConsumerWidget {
  const _CalendarWeekPage({
    required this.selectedDate,
    required this.settings,
    required this.searchQuery,
    required this.showAllDayScheduleEvents,
    required this.onShowAllDayScheduleEventsChanged,
    required this.onDateSelected,
    required this.externalEventDragActive,
    required this.externalEventDragInteractionActive,
    required this.onEventDragStateChanged,
    required this.onEventDragInteractionStateChanged,
  });

  final DateTime selectedDate;
  final AppSettings settings;
  final String searchQuery;
  final bool showAllDayScheduleEvents;
  final ValueChanged<bool> onShowAllDayScheduleEventsChanged;
  final void Function(DateTime date, List<CalendarEvent> events) onDateSelected;
  final bool externalEventDragActive;
  final bool externalEventDragInteractionActive;
  final ValueChanged<bool> onEventDragStateChanged;
  final ValueChanged<bool> onEventDragInteractionStateChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = _weekRangeFor(selectedDate, settings.weekStartsOnMonday);
    final eventsAsync = ref.watch(eventsInRangeProvider(range));
    return eventsAsync.when(
      data: (events) {
        final visibleEvents = _filterVisibleEvents(
          events,
          settings,
          searchQuery,
        );
        if (settings.weekDayLayoutMode == WeekDayLayoutMode.schedule) {
          final days = List.generate(
            7,
            (index) => range.start.add(Duration(days: index)),
          );
          return ScheduleTimelineView(
            days: days,
            holidayDates: {
              for (final day in days)
                if (settings.calendarShowHolidays &&
                    ref.read(koreanHolidayServiceProvider).isPublicHoliday(day))
                  _dateOnly(day),
            },
            events: visibleEvents,
            selectedDate: selectedDate,
            use24HourTime: settings.use24HourTime,
            showAllDayEvents: showAllDayScheduleEvents,
            holidayBackgroundEnabled: settings.calendarHolidayBackgroundEnabled,
            holidayColorValue: settings.holidayCategory.colorValue,
            centerEventTitles:
                settings.calendarEventTitleAlignment ==
                CalendarEventTitleAlignment.center,
            eventSortPriority: settings.calendarEventSortPriority,
            categoryOrder: settings.categories
                .map((category) => category.id)
                .toList(),
            weekStartsOnMonday: settings.weekStartsOnMonday,
            onEventDropped: (event, targetDate, targetIndex) =>
                _handleCalendarEventDrop(
                  context,
                  ref,
                  event,
                  targetDate,
                  targetIndex,
                ),
            onEventTimeDropped: (event, targetStart) =>
                _handleCalendarEventTimeDrop(context, ref, event, targetStart),
            onEventDragStateChanged: onEventDragStateChanged,
            onEventDragInteractionStateChanged:
                onEventDragInteractionStateChanged,
            externalEventDragActive: externalEventDragActive,
            externalEventDragInteractionActive:
                externalEventDragInteractionActive,
            onShowAllDayEventsChanged: onShowAllDayScheduleEventsChanged,
            onDateSelected: (date) =>
                onDateSelected(date, _eventsForDay(visibleEvents, date)),
          );
        }
        return _CalendarWeekView(
          selectedDate: selectedDate,
          weekStartsOnMonday: settings.weekStartsOnMonday,
          showLunarDates: settings.showLunarDates,
          centerEventTitles:
              settings.calendarEventTitleAlignment ==
              CalendarEventTitleAlignment.center,
          eventSortPriority: settings.calendarEventSortPriority,
          categoryOrder: settings.categories
              .map((category) => category.id)
              .toList(),
          manualEventOrders: settings.calendarManualEventOrders,
          events: visibleEvents,
          externalEventDragActive: externalEventDragActive,
          onEventDropped: (event, targetDate, targetIndex) =>
              _handleCalendarEventDrop(
                context,
                ref,
                event,
                targetDate,
                targetIndex,
              ),
          onEventDragStateChanged: onEventDragStateChanged,
          onEventDragInteractionStateChanged:
              onEventDragInteractionStateChanged,
          onDateSelected: onDateSelected,
        );
      },
      error: (error, stackTrace) => Center(child: Text('$error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _DayPageView extends StatefulWidget {
  const _DayPageView({
    required this.selectedDate,
    required this.settings,
    required this.searchQuery,
    required this.showAllDayScheduleEvents,
    required this.onShowAllDayScheduleEventsChanged,
    required this.onDayDelta,
    required this.onDateSelected,
    required this.externalEventDragActive,
    required this.externalEventDragInteractionActive,
    required this.onEventDragStateChanged,
    required this.onEventDragInteractionStateChanged,
  });

  final DateTime selectedDate;
  final AppSettings settings;
  final String searchQuery;
  final bool showAllDayScheduleEvents;
  final ValueChanged<bool> onShowAllDayScheduleEventsChanged;
  final ValueChanged<int> onDayDelta;
  final ValueChanged<DateTime> onDateSelected;
  final bool externalEventDragActive;
  final bool externalEventDragInteractionActive;
  final ValueChanged<bool> onEventDragStateChanged;
  final ValueChanged<bool> onEventDragInteractionStateChanged;

  @override
  State<_DayPageView> createState() => _DayPageViewState();
}

class _DayPageViewState extends State<_DayPageView> {
  static const _initialPage = 12000;

  late final PageController _controller;
  late final DateTime _anchorDate;
  var _currentPage = _initialPage;
  var _reportedPage = _initialPage;
  var _applyingExternalDate = false;
  var _externalAnimationRevision = 0;
  var _settleCommitRevision = 0;
  DateTime? _lastPointerDayMoveAt;
  final _mouseWheelNavigation = _MouseWheelPageNavigation();

  @override
  void initState() {
    super.initState();
    _anchorDate = _dateOnly(widget.selectedDate);
    _controller = PageController(initialPage: _initialPage);
  }

  @override
  void didUpdateWidget(covariant _DayPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_controller.hasClients) {
      return;
    }
    final targetPage =
        _initialPage + _dayDelta(_anchorDate, widget.selectedDate);
    if (targetPage == _currentPage) {
      return;
    }
    _animateToExternalPage(targetPage);
  }

  @override
  void dispose() {
    _mouseWheelNavigation.reset();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: const ValueKey('day-pointer-navigation'),
      behavior: HitTestBehavior.opaque,
      onPointerSignal: _handlePointerSignal,
      onPointerPanZoomStart: (_) => _mouseWheelNavigation.reset(),
      child: NotificationListener<ScrollEndNotification>(
        onNotification: _handlePageScrollEnd,
        child: PageView.builder(
          controller: _controller,
          allowImplicitScrolling: true,
          physics: _calendarPagePhysics(context),
          onPageChanged: (index) {
            if (_applyingExternalDate || index == _currentPage) {
              return;
            }
            final delta = index - _currentPage;
            _currentPage = index;
            if (!_defersPageStateCommitUntilScrollEnd(context)) {
              _reportedPage = index;
              widget.onDayDelta(delta);
            }
          },
          itemBuilder: (context, index) {
            final pageDate = _anchorDate.add(
              Duration(days: index - _initialPage),
            );
            return _desktopMouseWheelSignalRegion(
              context,
              onPointerSignal: _handlePointerSignal,
              child: _CalendarDayPage(
                date: pageDate,
                settings: widget.settings,
                searchQuery: widget.searchQuery,
                showAllDayScheduleEvents: widget.showAllDayScheduleEvents,
                onShowAllDayScheduleEventsChanged:
                    widget.onShowAllDayScheduleEventsChanged,
                onDateSelected: widget.onDateSelected,
                externalEventDragActive: widget.externalEventDragActive,
                externalEventDragInteractionActive:
                    widget.externalEventDragInteractionActive,
                onEventDragStateChanged: widget.onEventDragStateChanged,
                onEventDragInteractionStateChanged:
                    widget.onEventDragInteractionStateChanged,
              ),
            );
          },
        ),
      ),
    );
  }

  bool _handlePageScrollEnd(ScrollEndNotification notification) {
    if (notification.depth != 0 ||
        !_defersPageStateCommitUntilScrollEnd(context)) {
      return false;
    }
    final revision = ++_settleCommitRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          revision != _settleCommitRevision ||
          _applyingExternalDate ||
          !_controller.hasClients ||
          _controller.position.isScrollingNotifier.value) {
        return;
      }
      final page = _controller.page;
      if (page == null || (page - page.round()).abs() > 0.001) {
        return;
      }
      _currentPage = page.round();
      if (_reportedPage == _currentPage) {
        return;
      }
      final delta = _currentPage - _reportedPage;
      _reportedPage = _currentPage;
      widget.onDayDelta(delta);
    });
    return false;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    final navigationDelta = _pointerPageNavigationDelta(
      context,
      event,
      allowVerticalMouseWheel:
          widget.settings.weekDayLayoutMode == WeekDayLayoutMode.list,
    );
    if (navigationDelta == null || !_controller.hasClients) {
      return;
    }
    final scroll = event as PointerScrollEvent;
    final direction = navigationDelta > 0 ? 1 : -1;
    if (scroll.kind == PointerDeviceKind.mouse) {
      GestureBinding.instance.pointerSignalResolver.register(event, (_) {
        if (!mounted || !_controller.hasClients) {
          return;
        }
        event.respond(allowPlatformDefault: false);
        if (_isWindowsMouseWheel(context, scroll)) {
          _mouseWheelNavigation.scheduleWindowsBurst(
            controller: _controller,
            currentPage: _currentPage,
            axis: _primaryMouseWheelAxis(scroll),
            direction: direction,
          );
        } else {
          _mouseWheelNavigation.animateUncoalesced(
            controller: _controller,
            currentPage: _currentPage,
            direction: direction,
          );
        }
      });
      return;
    }
    _navigateFromTrackpad(direction);
  }

  void _navigateFromTrackpad(int direction) {
    final now = DateTime.now();
    final lastMoveAt = _lastPointerDayMoveAt;
    if (lastMoveAt != null &&
        now.difference(lastMoveAt) < const Duration(milliseconds: 280)) {
      return;
    }
    _lastPointerDayMoveAt = now;
    final nextPage = _currentPage + direction;
    unawaited(
      _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _animateToExternalPage(int targetPage) {
    _mouseWheelNavigation.reset();
    _settleCommitRevision += 1;
    final revision = ++_externalAnimationRevision;
    _applyingExternalDate = true;
    _currentPage = targetPage;
    _reportedPage = targetPage;
    unawaited(
      _controller
          .animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (mounted && revision == _externalAnimationRevision) {
              _applyingExternalDate = false;
            }
          }),
    );
  }

  int _dayDelta(DateTime from, DateTime to) {
    return _dateOnly(to).difference(_dateOnly(from)).inDays;
  }
}

class _CalendarDayPage extends ConsumerWidget {
  const _CalendarDayPage({
    required this.date,
    required this.settings,
    required this.searchQuery,
    required this.showAllDayScheduleEvents,
    required this.onShowAllDayScheduleEventsChanged,
    required this.onDateSelected,
    required this.externalEventDragActive,
    required this.externalEventDragInteractionActive,
    required this.onEventDragStateChanged,
    required this.onEventDragInteractionStateChanged,
  });

  final DateTime date;
  final AppSettings settings;
  final String searchQuery;
  final bool showAllDayScheduleEvents;
  final ValueChanged<bool> onShowAllDayScheduleEventsChanged;
  final ValueChanged<DateTime> onDateSelected;
  final bool externalEventDragActive;
  final bool externalEventDragInteractionActive;
  final ValueChanged<bool> onEventDragStateChanged;
  final ValueChanged<bool> onEventDragInteractionStateChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsInRangeProvider(_dayRangeFor(date)));
    return eventsAsync.when(
      data: (events) {
        final visibleEvents = _eventsForDay(
          _filterVisibleEvents(events, settings, searchQuery),
          date,
        );
        if (settings.weekDayLayoutMode == WeekDayLayoutMode.schedule) {
          return ScheduleTimelineView(
            days: [date],
            showDateHeader: false,
            events: visibleEvents,
            selectedDate: date,
            use24HourTime: settings.use24HourTime,
            showAllDayEvents: showAllDayScheduleEvents,
            holidayBackgroundEnabled: settings.calendarHolidayBackgroundEnabled,
            holidayColorValue: settings.holidayCategory.colorValue,
            centerEventTitles:
                settings.calendarEventTitleAlignment ==
                CalendarEventTitleAlignment.center,
            eventSortPriority: settings.calendarEventSortPriority,
            categoryOrder: settings.categories
                .map((category) => category.id)
                .toList(),
            weekStartsOnMonday: settings.weekStartsOnMonday,
            onEventDropped: (event, targetDate, targetIndex) =>
                _handleCalendarEventDrop(
                  context,
                  ref,
                  event,
                  targetDate,
                  targetIndex,
                ),
            onEventTimeDropped: (event, targetStart) =>
                _handleCalendarEventTimeDrop(context, ref, event, targetStart),
            onEventDragStateChanged: onEventDragStateChanged,
            onEventDragInteractionStateChanged:
                onEventDragInteractionStateChanged,
            externalEventDragActive: externalEventDragActive,
            externalEventDragInteractionActive:
                externalEventDragInteractionActive,
            onShowAllDayEventsChanged: onShowAllDayScheduleEventsChanged,
            onDateSelected: onDateSelected,
          );
        }
        return EventDetailsPanel(
          date: date,
          colorWeekdayOnly: true,
          events: _orderedEventsForDay(
            visibleEvents,
            date,
            priority: settings.calendarEventSortPriority,
            categoryOrder: settings.categories
                .map((category) => category.id)
                .toList(),
            manualEventOrders: settings.calendarManualEventOrders,
          ),
          onEventDropped: (event, targetDate, targetIndex) =>
              _handleCalendarEventDrop(
                context,
                ref,
                event,
                targetDate,
                targetIndex,
              ),
          onEventDragStateChanged: onEventDragStateChanged,
          onEventDragInteractionStateChanged:
              onEventDragInteractionStateChanged,
        );
      },
      error: (error, stackTrace) => Center(child: Text('$error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _QuickMonthPageView extends StatefulWidget {
  const _QuickMonthPageView({
    required this.month,
    required this.onMonthChanged,
    required this.pageBuilder,
  });

  final DateTime month;
  final ValueChanged<DateTime> onMonthChanged;
  final Widget Function(BuildContext, DateTime) pageBuilder;

  @override
  State<_QuickMonthPageView> createState() => _QuickMonthPageViewState();
}

class _QuickMonthPageViewState extends State<_QuickMonthPageView> {
  static const _initialPage = 12000;
  late final DateTime _anchorMonth;
  late final PageController _controller;
  final _wheelNavigation = _MouseWheelPageNavigation();
  int _currentPage = _initialPage;
  bool _applyingExternalMonth = false;
  int _externalRevision = 0;
  DateTime? _lastTrackpadMove;

  @override
  void initState() {
    super.initState();
    _anchorMonth = DateTime(widget.month.year, widget.month.month);
    _controller = PageController(initialPage: _initialPage);
  }

  DateTime _monthForPage(int page) =>
      DateTime(_anchorMonth.year, _anchorMonth.month + page - _initialPage);

  @override
  void didUpdateWidget(covariant _QuickMonthPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target =
        _initialPage +
        (widget.month.year - _anchorMonth.year) * 12 +
        widget.month.month -
        _anchorMonth.month;
    if (target == _currentPage || !_controller.hasClients) return;
    _wheelNavigation.reset();
    _currentPage = target;
    _applyingExternalMonth = true;
    final revision = ++_externalRevision;
    unawaited(
      _controller
          .animateToPage(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (mounted && revision == _externalRevision) {
              _applyingExternalMonth = false;
            }
          }),
    );
  }

  @override
  void dispose() {
    _wheelNavigation.reset();
    _controller.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        !supportsCalendarPointerNavigation(Theme.of(context).platform) ||
        !_controller.hasClients) {
      return;
    }
    final delta = event.scrollDelta.dx.abs() >= event.scrollDelta.dy.abs()
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    if (delta.abs() <= (event.kind == PointerDeviceKind.mouse ? 0 : 18)) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (!mounted || !_controller.hasClients) return;
      event.respond(allowPlatformDefault: false);
      if (_isWindowsMouseWheel(context, event)) {
        _wheelNavigation.scheduleWindowsBurst(
          controller: _controller,
          currentPage: _currentPage,
          axis: _primaryMouseWheelAxis(event),
          direction: delta.sign.toInt(),
        );
      } else {
        if (event.kind != PointerDeviceKind.mouse) {
          final now = DateTime.now();
          if (_lastTrackpadMove != null &&
              now.difference(_lastTrackpadMove!) <
                  const Duration(milliseconds: 280)) {
            return;
          }
          _lastTrackpadMove = now;
        }
        _wheelNavigation.animateUncoalesced(
          controller: _controller,
          currentPage: _currentPage,
          direction: delta.sign.toInt(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Listener(
    key: const ValueKey('quick-view-pointer-navigation'),
    behavior: HitTestBehavior.opaque,
    onPointerSignal: _handlePointerSignal,
    onPointerPanZoomStart: (_) => _wheelNavigation.reset(),
    child: PageView.builder(
      key: const ValueKey('quick-view-month-pages'),
      controller: _controller,
      scrollDirection: Axis.horizontal,
      physics: _calendarPagePhysics(context),
      onPageChanged: (index) {
        if (_applyingExternalMonth || index == _currentPage) return;
        _currentPage = index;
        widget.onMonthChanged(_monthForPage(index));
      },
      itemBuilder: (context, index) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerSignal: _handlePointerSignal,
        child: widget.pageBuilder(context, _monthForPage(index)),
      ),
    ),
  );
}

class _MonthPageView extends ConsumerStatefulWidget {
  const _MonthPageView({
    required this.month,
    required this.selectedDate,
    required this.settings,
    required this.searchQuery,
    required this.onMonthDelta,
    required this.onDateSelected,
    required this.externalEventDragActive,
    required this.externalEventDragInteractionActive,
    required this.onEventDragStateChanged,
    required this.onEventDragInteractionStateChanged,
  });

  final DateTime month;
  final DateTime selectedDate;
  final AppSettings settings;
  final String searchQuery;
  final ValueChanged<int> onMonthDelta;
  final void Function(DateTime date, List<CalendarEvent> events) onDateSelected;
  final bool externalEventDragActive;
  final bool externalEventDragInteractionActive;
  final ValueChanged<bool> onEventDragStateChanged;
  final ValueChanged<bool> onEventDragInteractionStateChanged;

  @override
  ConsumerState<_MonthPageView> createState() => _MonthPageViewState();
}

class _MonthPageViewState extends ConsumerState<_MonthPageView> {
  static const _initialPage = 12000;

  late final PageController _controller;
  SmoothMouseWheelScrollController? _verticalController;
  double? _verticalItemExtent;
  Size? _verticalHostSize;
  double? _verticalStableItemExtent;
  late final DateTime _anchorMonth;
  var _currentPage = _initialPage;
  var _reportedPage = _initialPage;
  var _applyingExternalMonth = false;
  var _externalAnimationRevision = 0;
  var _settleCommitRevision = 0;
  var _verticalExtentRevision = 0;
  var _preservingVerticalExtent = false;
  DateTime? _lastPointerMonthMoveAt;
  final _mouseWheelNavigation = _MouseWheelPageNavigation();
  final Map<int, RenderBox> _continuousGridBoxes = {};
  final ValueNotifier<(DateTime?, DateTime?)> _continuousRangeNotifier =
      ValueNotifier((null, null));
  DateTime? _continuousRangeStart;
  DateTime? _continuousRangeEnd;
  bool _continuousMouseRangeActive = false;
  bool _continuousEventDragActive = false;

  @override
  void initState() {
    super.initState();
    _anchorMonth = DateTime(widget.month.year, widget.month.month);
    _controller = PageController(initialPage: _initialPage);
  }

  @override
  void didUpdateWidget(covariant _MonthPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final activeController =
        widget.settings.monthNavigationMode == MonthNavigationMode.vertical
        ? _verticalController
        : _controller;
    if (_sameMonth(_monthForPage(_currentPage), widget.month) ||
        activeController == null ||
        !activeController.hasClients) {
      return;
    }
    final targetPage =
        _currentPage + _monthDelta(_monthForPage(_currentPage), widget.month);
    _animateToExternalPage(targetPage);
  }

  @override
  void dispose() {
    _mouseWheelNavigation.reset();
    _controller.dispose();
    _verticalController?.dispose();
    _continuousRangeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.settings.monthNavigationMode == MonthNavigationMode.vertical) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: CalendarWeekdayHeader(
              weekStartsOnMonday: widget.settings.weekStartsOnMonday,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemExtent = _stableVerticalItemExtent(
                  context,
                  constraints,
                );
                final verticalController = _verticalControllerFor(itemExtent);
                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollUpdateNotification &&
                        !_applyingExternalMonth &&
                        !_preservingVerticalExtent) {
                      final index = (verticalController.offset / itemExtent)
                          .round();
                      _currentPage = index;
                    } else if (notification is ScrollEndNotification &&
                        !_applyingExternalMonth &&
                        !_preservingVerticalExtent) {
                      final index = (verticalController.offset / itemExtent)
                          .round();
                      _currentPage = index;
                      if (index != _reportedPage) {
                        final delta = index - _reportedPage;
                        _reportedPage = index;
                        widget.onMonthDelta(delta);
                      }
                    }
                    return false;
                  },
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _handleContinuousPointerDown,
                    onPointerMove: _handleContinuousPointerMove,
                    onPointerUp: _handleContinuousPointerUp,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      supportedDevices: const {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.stylus,
                        PointerDeviceKind.invertedStylus,
                      },
                      onLongPressStart: (details) =>
                          _startContinuousRange(details.globalPosition),
                      onLongPressMoveUpdate: (details) =>
                          _updateContinuousRange(details.globalPosition),
                      onLongPressEnd: (details) {
                        if (_continuousDateAt(details.globalPosition) == null) {
                          _cancelContinuousRange();
                        } else {
                          _commitContinuousRange();
                        }
                      },
                      onLongPressCancel: _cancelContinuousRange,
                      child: ListView.builder(
                        key: const ValueKey('continuous-month-scroll'),
                        controller: verticalController,
                        itemExtent: itemExtent,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        itemBuilder: (context, index) {
                          final pageMonth = _monthForPage(index);
                          return Column(
                            key: ValueKey(
                              'continuous-month-${pageMonth.year}-${pageMonth.month}',
                            ),
                            children: [
                              _MonthBoundaryLabel(month: pageMonth),
                              Expanded(
                                child: ValueListenableBuilder<(DateTime?, DateTime?)>(
                                  valueListenable: _continuousRangeNotifier,
                                  builder: (context, range, _) =>
                                      _CalendarMonthPage(
                                        month: pageMonth,
                                        selectedDate: widget.selectedDate,
                                        settings: widget.settings,
                                        searchQuery: widget.searchQuery,
                                        continuous: true,
                                        showWeekdayHeader: false,
                                        onRangeHitTestBoxChanged: (box) {
                                          if (box == null) {
                                            _continuousGridBoxes.remove(index);
                                          } else {
                                            _continuousGridBoxes[index] = box;
                                          }
                                        },
                                        externalRangeStart: range.$1,
                                        externalRangeEnd: range.$2,
                                        enableRangeGestures: false,
                                        onEventDragStateChanged:
                                            widget.onEventDragStateChanged,
                                        onEventDragInteractionStateChanged:
                                            _setContinuousEventDragActive,
                                        externalEventDragActive:
                                            widget.externalEventDragActive,
                                        externalEventDragInteractionActive: widget
                                            .externalEventDragInteractionActive,
                                        onDateSelected: widget.onDateSelected,
                                      ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }
    return Listener(
      key: const ValueKey('month-pointer-navigation'),
      behavior: HitTestBehavior.opaque,
      onPointerSignal: _handlePointerSignal,
      onPointerPanZoomStart: (_) => _mouseWheelNavigation.reset(),
      child: NotificationListener<ScrollEndNotification>(
        onNotification: _handleHorizontalPageScrollEnd,
        child: PageView.builder(
          controller: _controller,
          allowImplicitScrolling: true,
          physics: _calendarPagePhysics(context),
          onPageChanged: (index) {
            if (_applyingExternalMonth || index == _currentPage) {
              return;
            }
            final delta = index - _currentPage;
            _currentPage = index;
            if (!_defersPageStateCommitUntilScrollEnd(context)) {
              _reportedPage = index;
              widget.onMonthDelta(delta);
            }
          },
          itemBuilder: (context, index) {
            final pageMonth = _monthForPage(index);
            return _desktopMouseWheelSignalRegion(
              context,
              onPointerSignal: _handlePointerSignal,
              child: _CalendarMonthPage(
                month: pageMonth,
                selectedDate: widget.selectedDate,
                settings: widget.settings,
                searchQuery: widget.searchQuery,
                externalEventDragActive: widget.externalEventDragActive,
                externalEventDragInteractionActive:
                    widget.externalEventDragInteractionActive,
                onEventDragStateChanged: widget.onEventDragStateChanged,
                onEventDragInteractionStateChanged:
                    widget.onEventDragInteractionStateChanged,
                onDateSelected: widget.onDateSelected,
              ),
            );
          },
        ),
      ),
    );
  }

  bool _handleHorizontalPageScrollEnd(ScrollEndNotification notification) {
    if (notification.depth != 0 ||
        !_defersPageStateCommitUntilScrollEnd(context)) {
      return false;
    }
    final revision = ++_settleCommitRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          revision != _settleCommitRevision ||
          _applyingExternalMonth ||
          !_controller.hasClients ||
          _controller.position.isScrollingNotifier.value) {
        return;
      }
      final page = _controller.page;
      if (page == null || (page - page.round()).abs() > 0.001) {
        return;
      }
      _currentPage = page.round();
      if (_reportedPage == _currentPage) {
        return;
      }
      final delta = _currentPage - _reportedPage;
      _reportedPage = _currentPage;
      widget.onMonthDelta(delta);
    });
    return false;
  }

  void _handleContinuousPointerDown(PointerDownEvent event) {
    if (_continuousEventDragActive) {
      return;
    }
    if ((event.kind != PointerDeviceKind.mouse &&
            event.kind != PointerDeviceKind.trackpad) ||
        (event.buttons != 0 && (event.buttons & kPrimaryMouseButton) == 0)) {
      return;
    }
    _continuousMouseRangeActive = false;
    _startContinuousRange(event.position, showImmediately: false);
  }

  void _handleContinuousPointerMove(PointerMoveEvent event) {
    if (_continuousEventDragActive) {
      return;
    }
    final start = _continuousRangeStart;
    if (start == null ||
        (event.kind != PointerDeviceKind.mouse &&
            event.kind != PointerDeviceKind.trackpad)) {
      return;
    }
    final target = _continuousDateAt(event.position);
    if (target == null || _sameDay(target, start)) {
      return;
    }
    _continuousMouseRangeActive = true;
    _updateContinuousRange(event.position);
  }

  void _handleContinuousPointerUp(PointerUpEvent event) {
    if (_continuousEventDragActive) {
      return;
    }
    if (event.kind != PointerDeviceKind.mouse &&
        event.kind != PointerDeviceKind.trackpad) {
      return;
    }
    if (_continuousMouseRangeActive &&
        _continuousDateAt(event.position) != null) {
      _commitContinuousRange();
    } else {
      _cancelContinuousRange();
    }
    _continuousMouseRangeActive = false;
  }

  void _startContinuousRange(
    Offset globalPosition, {
    bool showImmediately = true,
  }) {
    if (_continuousEventDragActive) {
      return;
    }
    final date = _continuousDateAt(globalPosition);
    if (date == null) {
      _cancelContinuousRange();
      return;
    }
    _continuousRangeStart = date;
    _continuousRangeEnd = showImmediately ? date : null;
    _publishContinuousRange();
  }

  void _updateContinuousRange(Offset globalPosition) {
    if (_continuousEventDragActive) {
      return;
    }
    final start = _continuousRangeStart;
    final end = _continuousRangeEnd;
    final date = _continuousDateAt(globalPosition);
    if (start == null || date == null || (end != null && _sameDay(date, end))) {
      return;
    }
    _continuousRangeEnd = date;
    _publishContinuousRange();
  }

  void _cancelContinuousRange() {
    if (_continuousRangeStart == null && _continuousRangeEnd == null) {
      return;
    }
    _continuousRangeStart = null;
    _continuousRangeEnd = null;
    _publishContinuousRange();
  }

  void _publishContinuousRange() {
    _continuousRangeNotifier.value = (
      _continuousRangeStart,
      _continuousRangeEnd,
    );
  }

  void _commitContinuousRange() {
    if (_continuousEventDragActive) {
      _cancelContinuousRange();
      return;
    }
    final start = _continuousRangeStart;
    final end = _continuousRangeEnd;
    _cancelContinuousRange();
    if (start == null || end == null || _sameDay(start, end)) {
      return;
    }
    final normalizedStart = start.isBefore(end) ? start : end;
    final normalizedEnd = start.isBefore(end) ? end : start;
    unawaited(
      _openRangeEventEditor(
        context,
        ref,
        normalizedStart,
        normalizedEnd,
        widget.settings.categories,
        widget.settings.defaultReminderMinutesList,
      ),
    );
  }

  DateTime? _continuousDateAt(Offset globalPosition) {
    for (final entry in _continuousGridBoxes.entries) {
      final renderObject = entry.value;
      if (!renderObject.hasSize || !renderObject.attached) {
        continue;
      }
      final local = renderObject.globalToLocal(globalPosition);
      if (local.dx < 0 ||
          local.dy < 0 ||
          local.dx >= renderObject.size.width ||
          local.dy >= renderObject.size.height) {
        continue;
      }
      final month = _monthForPage(entry.key);
      final first = DateTime(month.year, month.month);
      final leadingDays = widget.settings.weekStartsOnMonday
          ? first.weekday - 1
          : first.weekday % 7;
      final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
      final weekCount = ((leadingDays + daysInMonth) / 7).ceil();
      final column = (local.dx / (renderObject.size.width / 7)).floor();
      final row = (local.dy / (renderObject.size.height / weekCount)).floor();
      final date = first
          .subtract(Duration(days: leadingDays))
          .add(Duration(days: row * 7 + column));
      if (date.year != month.year || date.month != month.month) {
        return null;
      }
      return date;
    }
    return null;
  }

  void _setContinuousEventDragActive(bool active) {
    if (_continuousEventDragActive == active) {
      return;
    }
    _continuousEventDragActive = active;
    widget.onEventDragInteractionStateChanged(active);
    if (active) {
      _continuousMouseRangeActive = false;
      _cancelContinuousRange();
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!supportsCalendarPointerNavigation(Theme.of(context).platform) ||
        event is! PointerScrollEvent ||
        !_controller.hasClients) {
      return;
    }
    final primaryDelta =
        event.scrollDelta.dx.abs() >= event.scrollDelta.dy.abs()
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    final minimumDelta = event.kind == PointerDeviceKind.mouse ? 0.0 : 18.0;
    if (primaryDelta.abs() <= minimumDelta) {
      return;
    }
    final direction = primaryDelta > 0 ? 1 : -1;
    if (event.kind == PointerDeviceKind.mouse) {
      GestureBinding.instance.pointerSignalResolver.register(event, (_) {
        if (!mounted || !_controller.hasClients) {
          return;
        }
        event.respond(allowPlatformDefault: false);
        if (_isWindowsMouseWheel(context, event)) {
          _mouseWheelNavigation.scheduleWindowsBurst(
            controller: _controller,
            currentPage: _currentPage,
            axis: _primaryMouseWheelAxis(event),
            direction: direction,
          );
        } else {
          _mouseWheelNavigation.animateUncoalesced(
            controller: _controller,
            currentPage: _currentPage,
            direction: direction,
          );
        }
      });
      return;
    }
    _navigateFromTrackpad(direction);
  }

  void _navigateFromTrackpad(int direction) {
    final now = DateTime.now();
    final lastMoveAt = _lastPointerMonthMoveAt;
    if (lastMoveAt != null &&
        now.difference(lastMoveAt) < const Duration(milliseconds: 280)) {
      return;
    }
    _lastPointerMonthMoveAt = now;
    final nextPage = _currentPage + direction;
    unawaited(
      _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _animateToExternalPage(int targetPage) {
    _mouseWheelNavigation.reset();
    _settleCommitRevision += 1;
    final revision = ++_externalAnimationRevision;
    _applyingExternalMonth = true;
    _currentPage = targetPage;
    _reportedPage = targetPage;
    final animation =
        widget.settings.monthNavigationMode == MonthNavigationMode.vertical
        ? _verticalController!.animateTo(
            targetPage * _verticalItemExtent!,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
        : _controller.animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
    unawaited(
      animation.whenComplete(() {
        if (mounted && revision == _externalAnimationRevision) {
          _applyingExternalMonth = false;
        }
      }),
    );
  }

  SmoothMouseWheelScrollController _verticalControllerFor(double itemExtent) {
    final current = _verticalController;
    final previousExtent = _verticalItemExtent;
    if (current != null && previousExtent == itemExtent) {
      return current;
    }
    final logicalPage =
        current != null && previousExtent != null && current.hasClients
        ? current.offset / previousExtent
        : _currentPage.toDouble();
    final replacement = SmoothMouseWheelScrollController(
      initialScrollOffset: logicalPage * itemExtent,
      keepScrollOffset: false,
    );
    final revision = ++_verticalExtentRevision;
    _preservingVerticalExtent = true;
    _verticalController = replacement;
    _verticalItemExtent = itemExtent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      current?.dispose();
      if (mounted && revision == _verticalExtentRevision) {
        if (replacement.hasClients) {
          replacement.jumpTo(logicalPage * itemExtent);
        }
        _preservingVerticalExtent = false;
      }
    });
    return replacement;
  }

  double _stableVerticalItemExtent(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final hostSize = MediaQuery.sizeOf(context);
    if (_verticalHostSize != hostSize) {
      _verticalHostSize = hostSize;
      _verticalStableItemExtent = constraints.maxHeight;
    } else if (_verticalStableItemExtent == null ||
        constraints.maxHeight > _verticalStableItemExtent!) {
      _verticalStableItemExtent = constraints.maxHeight;
    }
    return _verticalStableItemExtent!;
  }

  bool _sameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  DateTime _monthForPage(int page) {
    return DateTime(
      _anchorMonth.year,
      _anchorMonth.month + page - _initialPage,
    );
  }

  int _monthDelta(DateTime from, DateTime to) {
    return (to.year - from.year) * 12 + to.month - from.month;
  }
}

enum _MouseWheelAxis { horizontal, vertical }

class _MouseWheelPageNavigation {
  // Windows can split one physical wheel detent into a short burst of pointer
  // signals. Let that burst settle before starting one adjacent-page animation.
  static const _burstQuietPeriod = Duration(milliseconds: 48);
  static const _animationDuration = Duration(milliseconds: 240);

  Timer? _burstTimer;
  int? _burstDirection;
  _MouseWheelAxis? _burstAxis;
  final List<int> _pendingDirections = [];
  var _animationActive = false;
  var _revision = 0;
  int? _uncoalescedTargetPage;
  var _uncoalescedAnimationRevision = 0;

  void scheduleWindowsBurst({
    required PageController controller,
    required int currentPage,
    required _MouseWheelAxis axis,
    required int direction,
  }) {
    if (!controller.hasClients || direction == 0) {
      return;
    }
    if (_burstDirection != null &&
        (_burstAxis != axis || _burstDirection != direction.sign)) {
      _commitBurst(
        controller: controller,
        fallbackPage: currentPage,
        revision: _revision,
      );
    }
    _burstAxis = axis;
    _burstDirection = direction.sign;
    _burstTimer?.cancel();
    final revision = _revision;
    _burstTimer = Timer(_burstQuietPeriod, () {
      if (revision != _revision) {
        return;
      }
      _commitBurst(
        controller: controller,
        fallbackPage: currentPage,
        revision: revision,
      );
    });
  }

  void _commitBurst({
    required PageController controller,
    required int fallbackPage,
    required int revision,
  }) {
    final burstDirection = _burstDirection;
    _burstTimer?.cancel();
    _burstTimer = null;
    _burstDirection = null;
    _burstAxis = null;
    if (revision != _revision || burstDirection == null) {
      return;
    }
    _pendingDirections.add(burstDirection);
    _animateNext(
      controller: controller,
      fallbackPage: fallbackPage,
      revision: revision,
    );
  }

  void _animateNext({
    required PageController controller,
    required int fallbackPage,
    required int revision,
  }) {
    if (revision != _revision ||
        _animationActive ||
        _pendingDirections.isEmpty) {
      return;
    }
    if (!controller.hasClients) {
      _pendingDirections.clear();
      return;
    }
    _animationActive = true;
    final direction = _pendingDirections.removeAt(0);
    final visiblePage = controller.page ?? fallbackPage.toDouble();
    final targetPage = visiblePage.round() + direction;
    unawaited(
      controller
          .animateToPage(
            targetPage,
            duration: _animationDuration,
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (revision != _revision) {
              return;
            }
            _animationActive = false;
            _animateNext(
              controller: controller,
              fallbackPage: targetPage,
              revision: revision,
            );
          }),
    );
  }

  void animateUncoalesced({
    required PageController controller,
    required int currentPage,
    required int direction,
  }) {
    if (!controller.hasClients || direction == 0) {
      return;
    }
    final visiblePage = controller.page ?? currentPage.toDouble();
    final targetPage =
        (_uncoalescedTargetPage ?? visiblePage.round()) + direction.sign;
    _uncoalescedTargetPage = targetPage;
    final revision = ++_uncoalescedAnimationRevision;
    final pendingDistance = (targetPage - visiblePage).abs();
    final duration = Duration(
      milliseconds: (140 + math.min(pendingDistance, 4) * 20).round(),
    );
    unawaited(
      controller
          .animateToPage(
            targetPage,
            duration: duration,
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            if (revision == _uncoalescedAnimationRevision) {
              _uncoalescedTargetPage = null;
            }
          }),
    );
    // Driven paging normally hides its children from pointer hit testing.
    // Keep the inner wheel receiver reachable for the next physical detent.
    controller.position.context.setIgnorePointer(false);
  }

  void reset() {
    _revision += 1;
    _burstTimer?.cancel();
    _burstTimer = null;
    _burstDirection = null;
    _burstAxis = null;
    _pendingDirections.clear();
    _animationActive = false;
    _uncoalescedAnimationRevision += 1;
    _uncoalescedTargetPage = null;
  }
}

ScrollPhysics _calendarPagePhysics(BuildContext context) {
  return const _ResponsiveMonthPagePhysics();
}

class _ResponsiveMonthPagePhysics extends PageScrollPhysics {
  const _ResponsiveMonthPagePhysics({super.parent});

  @override
  _ResponsiveMonthPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _ResponsiveMonthPagePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
    mass: 0.75,
    stiffness: 520,
    ratio: 1.05,
  );
}

class _MonthBoundaryLabel extends StatelessWidget {
  const _MonthBoundaryLabel({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 10),
      child: Row(
        children: [
          Text(
            DateFormat.MMMM(
              Localizations.localeOf(context).toLanguageTag(),
            ).format(month),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: colorScheme.onSurface,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Divider(color: colorScheme.outlineVariant)),
        ],
      ),
    );
  }
}

Widget _desktopMouseWheelSignalRegion(
  BuildContext context, {
  required void Function(PointerSignalEvent) onPointerSignal,
  required Widget child,
}) {
  final platform = Theme.of(context).platform;
  if (!_usesDesktopCalendarLayout(platform)) {
    return child;
  }
  // This Listener is inside PageView's Scrollable, so it wins pointer-signal
  // resolution before PageView can also apply horizontal pixel scrolling.
  return Listener(
    behavior: HitTestBehavior.translucent,
    onPointerSignal: (event) {
      if (event.kind == PointerDeviceKind.mouse) {
        onPointerSignal(event);
      }
    },
    child: child,
  );
}

bool _isWindowsMouseWheel(BuildContext context, PointerScrollEvent event) {
  return Theme.of(context).platform == TargetPlatform.windows &&
      event.kind == PointerDeviceKind.mouse;
}

bool _defersPageStateCommitUntilScrollEnd(BuildContext context) {
  return Theme.of(context).platform == TargetPlatform.windows;
}

_MouseWheelAxis _primaryMouseWheelAxis(PointerScrollEvent event) {
  return event.scrollDelta.dx.abs() >= event.scrollDelta.dy.abs()
      ? _MouseWheelAxis.horizontal
      : _MouseWheelAxis.vertical;
}

double? _pointerPageNavigationDelta(
  BuildContext context,
  PointerSignalEvent event, {
  required bool allowVerticalMouseWheel,
}) {
  if (!supportsCalendarPointerNavigation(Theme.of(context).platform) ||
      event is! PointerScrollEvent) {
    return null;
  }
  final horizontal = event.scrollDelta.dx.abs();
  final vertical = event.scrollDelta.dy.abs();
  final minimumDelta = event.kind == PointerDeviceKind.mouse ? 0.0 : 18.0;
  if (horizontal > minimumDelta && horizontal > vertical) {
    return event.scrollDelta.dx;
  }
  if (allowVerticalMouseWheel &&
      event.kind == PointerDeviceKind.mouse &&
      vertical > minimumDelta &&
      vertical > horizontal) {
    return event.scrollDelta.dy;
  }
  return null;
}

bool _usesDesktopCalendarLayout(TargetPlatform platform) {
  return platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux;
}

class _CalendarMonthPage extends ConsumerWidget {
  const _CalendarMonthPage({
    required this.month,
    required this.selectedDate,
    required this.settings,
    required this.searchQuery,
    required this.onDateSelected,
    this.continuous = false,
    this.showWeekdayHeader = true,
    this.onRangeHitTestBoxChanged,
    this.externalRangeStart,
    this.externalRangeEnd,
    this.enableRangeGestures = true,
    this.onEventDragStateChanged,
    this.onEventDragInteractionStateChanged,
    this.externalEventDragActive = false,
    this.externalEventDragInteractionActive = false,
  });

  final DateTime month;
  final DateTime selectedDate;
  final AppSettings settings;
  final String searchQuery;
  final void Function(DateTime date, List<CalendarEvent> events) onDateSelected;
  final bool continuous;
  final bool showWeekdayHeader;
  final ValueChanged<RenderBox?>? onRangeHitTestBoxChanged;
  final DateTime? externalRangeStart;
  final DateTime? externalRangeEnd;
  final bool enableRangeGestures;
  final ValueChanged<bool>? onEventDragStateChanged;
  final ValueChanged<bool>? onEventDragInteractionStateChanged;
  final bool externalEventDragActive;
  final bool externalEventDragInteractionActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(
      eventsInRangeProvider(_monthRangeFor(month, settings.weekStartsOnMonday)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : null;
        return eventsAsync.when(
          data: (events) {
            final visibleEvents = _filterVisibleEvents(
              events,
              settings,
              searchQuery,
            );
            return CalendarMonthGrid(
              availableWidth: availableWidth,
              month: month,
              selectedDate: selectedDate,
              events: visibleEvents,
              weekStartsOnMonday: settings.weekStartsOnMonday,
              showLunarDates: settings.showLunarDates,
              holidayBackgroundEnabled:
                  settings.calendarHolidayBackgroundEnabled,
              holidayColorValue: settings.holidayCategory.colorValue,
              centerEventTitles:
                  settings.calendarEventTitleAlignment ==
                  CalendarEventTitleAlignment.center,
              eventSortPriority: settings.calendarEventSortPriority,
              categoryOrder: settings.categories
                  .map((category) => category.id)
                  .toList(),
              manualEventOrders: settings.calendarManualEventOrders,
              showAdjacentMonthDates:
                  !continuous && settings.showAdjacentMonthDates,
              continuous: continuous,
              showWeekdayHeader: showWeekdayHeader,
              onRangeHitTestBoxChanged: onRangeHitTestBoxChanged,
              externalRangeStart: externalRangeStart,
              externalRangeEnd: externalRangeEnd,
              enableRangeGestures: enableRangeGestures,
              onEventDragStateChanged: onEventDragStateChanged,
              onEventDragInteractionStateChanged:
                  onEventDragInteractionStateChanged,
              externalEventDragActive: externalEventDragActive,
              externalEventDragInteractionActive:
                  externalEventDragInteractionActive,
              onDateSelected: (date) {
                onDateSelected(date, _eventsForDay(visibleEvents, date));
              },
              onDateRangeSelected: (start, end) => _addEventForRange(
                context,
                ref,
                start,
                end,
                settings.categories,
                settings.defaultReminderMinutesList,
              ),
              onEventDropped: (event, targetDate, targetIndex) =>
                  _handleEventDrop(
                    context,
                    ref,
                    event,
                    targetDate,
                    targetIndex,
                    visibleEvents,
                    settings,
                  ),
            );
          },
          error: (error, stackTrace) => Center(child: Text('$error')),
          loading: () => CalendarMonthGrid(
            availableWidth: availableWidth,
            month: month,
            selectedDate: selectedDate,
            events: const [],
            weekStartsOnMonday: settings.weekStartsOnMonday,
            showLunarDates: settings.showLunarDates,
            holidayBackgroundEnabled: settings.calendarHolidayBackgroundEnabled,
            holidayColorValue: settings.holidayCategory.colorValue,
            centerEventTitles:
                settings.calendarEventTitleAlignment ==
                CalendarEventTitleAlignment.center,
            eventSortPriority: settings.calendarEventSortPriority,
            categoryOrder: settings.categories
                .map((category) => category.id)
                .toList(),
            manualEventOrders: settings.calendarManualEventOrders,
            showAdjacentMonthDates:
                !continuous && settings.showAdjacentMonthDates,
            continuous: continuous,
            showWeekdayHeader: showWeekdayHeader,
            onRangeHitTestBoxChanged: onRangeHitTestBoxChanged,
            externalRangeStart: externalRangeStart,
            externalRangeEnd: externalRangeEnd,
            enableRangeGestures: enableRangeGestures,
            externalEventDragActive: externalEventDragActive,
            externalEventDragInteractionActive:
                externalEventDragInteractionActive,
            onEventDragStateChanged: onEventDragStateChanged,
            onEventDragInteractionStateChanged:
                onEventDragInteractionStateChanged,
            onDateSelected: (date) {
              onDateSelected(date, const <CalendarEvent>[]);
            },
            onDateRangeSelected: (start, end) => _addEventForRange(
              context,
              ref,
              start,
              end,
              settings.categories,
              settings.defaultReminderMinutesList,
            ),
          ),
        );
      },
    );
  }

  Future<void> _addEventForRange(
    BuildContext context,
    WidgetRef ref,
    DateTime start,
    DateTime end,
    List<EventCategory> categories,
    List<int> defaultReminderMinutesList,
  ) => _openRangeEventEditor(
    context,
    ref,
    start,
    end,
    categories,
    defaultReminderMinutesList,
  );

  Future<void> _handleEventDrop(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
    DateTime targetDate,
    int targetIndex,
    List<CalendarEvent> visibleEvents,
    AppSettings settings,
  ) async {
    if (event.readOnly || event.systemEvent || event.holiday) {
      return;
    }
    final sourceDate = _dateOnly(event.startAt);
    final normalizedTarget = _dateOnly(targetDate);
    var movedEvent = event;

    if (!_sameDay(sourceDate, normalizedTarget)) {
      if (event.isRecurring) {
        final scope = await _showRecurringDragScopeDialog(context);
        if (scope == null || !context.mounted) {
          return;
        }
        final result = await _moveRecurringEvent(
          ref,
          event,
          normalizedTarget,
          scope,
        );
        if (result == null) {
          return;
        }
        movedEvent = result;
      } else {
        movedEvent = shiftCalendarEventToDate(event, normalizedTarget);
        await ref.read(eventCommandServiceProvider).save(movedEvent);
      }
    }

    await _saveManualOrderAfterDrop(
      ref,
      sourceDate: sourceDate,
      targetDate: normalizedTarget,
      targetIndex: targetIndex,
      originalEvent: event,
      movedEvent: movedEvent,
      visibleEvents: visibleEvents,
      settings: settings,
    );
  }

  Future<CalendarEvent?> _moveRecurringEvent(
    WidgetRef ref,
    CalendarEvent occurrence,
    DateTime targetDate,
    _RecurringDragScope scope,
  ) async {
    final repository = ref.read(eventRepositoryProvider);
    final commandService = ref.read(eventCommandServiceProvider);
    final base = await repository.findById(occurrence.id);
    if (base == null) {
      return null;
    }
    final shiftedOccurrence = shiftCalendarEventToDate(occurrence, targetDate);

    switch (scope) {
      case _RecurringDragScope.onlyThis:
        await commandService.save(_excludeOccurrence(base, occurrence.startAt));
        return commandService.create(
          _eventDraftFrom(
            shiftedOccurrence,
            recurrence: const RecurrenceRule(),
          ),
        );
      case _RecurringDragScope.future:
        await commandService.save(_endBefore(base, occurrence.startAt));
        final futureRule = recurrenceRuleForMovedFuture(
          base: base,
          occurrence: occurrence,
          targetDate: targetDate,
        );
        final created = await commandService.create(
          _eventDraftFrom(shiftedOccurrence, recurrence: futureRule),
        );
        return created.copyWith(
          occurrenceId: '${created.id}@${created.startAt.toIso8601String()}',
        );
      case _RecurringDragScope.all:
        final dayDelta = calendarDayDifference(targetDate, occurrence.startAt);
        final shiftedBaseEvent = shiftCalendarEventToDate(
          base,
          shiftCalendarDateByDays(base.startAt, dayDelta),
        );
        final shiftedBase = shiftedBaseEvent.copyWith(
          recurrence: shiftRecurrenceRuleByDays(base.recurrence, dayDelta),
        );
        await commandService.save(shiftedBase);
        final shiftedStart = shiftCalendarDateByDays(
          occurrence.startAt,
          dayDelta,
        );
        return occurrence.copyWith(
          occurrenceId: '${base.id}@${shiftedStart.toIso8601String()}',
          startAt: shiftedStart,
          endAt: shiftedStart.add(occurrence.duration),
        );
    }
  }

  Future<void> _saveManualOrderAfterDrop(
    WidgetRef ref, {
    required DateTime sourceDate,
    required DateTime targetDate,
    required int targetIndex,
    required CalendarEvent originalEvent,
    required CalendarEvent movedEvent,
    required List<CalendarEvent> visibleEvents,
    required AppSettings settings,
  }) async {
    final sourceKey = calendarDateKey(sourceDate);
    final targetKey = calendarDateKey(targetDate);
    final originalOrderKey = calendarEventOrderKey(originalEvent);
    final movedOrderKey = calendarEventOrderKey(movedEvent);
    final categoryOrder = settings.categories
        .map((category) => category.id)
        .toList();
    final manualOrders = <String, CalendarManualEventOrder>{
      ...settings.calendarManualEventOrders,
    };
    final deviceId = await ref.read(settingsRepositoryProvider).deviceId();
    final now = DateTime.now();

    if (sourceKey != targetKey) {
      final sourceEvents = _eventsForDay(visibleEvents, sourceDate)
          .where(
            (candidate) =>
                calendarEventOrderKey(candidate) != originalOrderKey &&
                candidate.id != originalEvent.id,
          )
          .toList();
      manualOrders[sourceKey] = CalendarManualEventOrder(
        eventKeys: sourceEvents.map(calendarEventOrderKey).toList(),
        updatedAt: now,
        deviceId: deviceId,
      );
    }

    final existingTarget = _eventsForDay(visibleEvents, targetDate)
        .where(
          (candidate) =>
              calendarEventOrderKey(candidate) != originalOrderKey &&
              calendarEventOrderKey(candidate) != movedOrderKey &&
              candidate.id != originalEvent.id,
        )
        .toList();
    final sortedTarget = sortedCalendarEvents(
      existingTarget,
      priority: settings.calendarEventSortPriority,
      categoryOrder: categoryOrder,
      manualOrder:
          settings.calendarManualEventOrders[targetKey]?.eventKeys ??
          const <String>[],
    );
    final insertionIndex = targetIndex.clamp(0, sortedTarget.length);
    sortedTarget.insert(insertionIndex, movedEvent);
    manualOrders[targetKey] = CalendarManualEventOrder(
      eventKeys: sortedTarget.map(calendarEventOrderKey).toList(),
      updatedAt: now,
      deviceId: deviceId,
    );

    final updatedSettings = settings.copyWith(
      calendarManualEventOrders: manualOrders,
    );
    await _persistCalendarManualOrder(
      ref,
      previous: settings,
      updated: updatedSettings,
    );
  }

  EventDraft _eventDraftFrom(
    CalendarEvent event, {
    required RecurrenceRule recurrence,
  }) {
    return EventDraft(
      title: event.title,
      memo: event.memo,
      location: event.location,
      url: event.url,
      weather: event.weather,
      startAt: event.startAt,
      endAt: event.endAt,
      allDay: event.allDay,
      category: event.category,
      colorValue: event.colorValue,
      reminderMinutesBeforeList: event.reminderMinutesBeforeList,
      recurrence: recurrence,
      showDday: event.showDday,
      alarmEnabled: event.alarmEnabled,
      allDayAlarmMinutes: event.allDayAlarmMinutes,
    );
  }

  CalendarEvent _excludeOccurrence(CalendarEvent base, DateTime occurrence) {
    final excludedDate = _dateOnly(occurrence);
    final excluded = {
      ...base.recurrence.excludedDates.map(_dateOnly),
      excludedDate,
    }.toList()..sort();
    return base.copyWith(
      recurrence: base.recurrence.copyWith(excludedDates: excluded),
    );
  }

  CalendarEvent _endBefore(CalendarEvent base, DateTime occurrence) {
    return base.copyWith(
      recurrence: base.recurrence.copyWith(
        until: _dateOnly(occurrence).subtract(const Duration(days: 1)),
        clearCount: true,
      ),
    );
  }

  Future<_RecurringDragScope?> _showRecurringDragScopeDialog(
    BuildContext context,
  ) {
    return showDialog<_RecurringDragScope>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('반복 일정 이동')),
        content: Text(context.tr('이 반복 일정의 어느 범위를 이동할까요?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('취소')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_RecurringDragScope.onlyThis),
            child: Text(context.tr('이 일정만')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_RecurringDragScope.future),
            child: Text(context.tr('이후 일정')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_RecurringDragScope.all),
            child: Text(context.tr('전체 반복')),
          ),
        ],
      ),
    );
  }
}

Future<void> _handleCalendarEventDrop(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent event,
  DateTime targetDate,
  int targetIndex,
) async {
  if (!calendarEventCanMove(event)) {
    return;
  }
  final sourceDate = _dateOnly(event.startAt);
  final normalizedTarget = _dateOnly(targetDate);
  final rangeStart = sourceDate.isBefore(normalizedTarget)
      ? sourceDate
      : normalizedTarget;
  final rangeLastDate = sourceDate.isAfter(normalizedTarget)
      ? sourceDate
      : normalizedTarget;
  final rangeEnd = rangeLastDate.add(const Duration(days: 1));
  final settings = ref.read(appSettingsProvider);
  final repository = ref.read(eventRepositoryProvider);
  final storedEvents = await repository.eventsInRange(rangeStart, rangeEnd);
  final holidayEvents = ref
      .read(koreanHolidayServiceProvider)
      .holidayEventsInRange(
        rangeStart,
        rangeEnd,
        category: settings.holidayCategory,
      );
  final visibleEvents = _filterVisibleEvents(
    [...storedEvents, ...holidayEvents],
    settings,
    '',
  );
  if (!context.mounted) {
    return;
  }

  var movedEvent = event;
  if (!_sameDay(sourceDate, normalizedTarget)) {
    if (event.isRecurring) {
      final scope = await _showCalendarRecurringDragScopeDialog(context);
      if (scope == null || !context.mounted) {
        return;
      }
      final result = await _moveRecurringCalendarEvent(
        ref,
        event,
        normalizedTarget,
        scope,
      );
      if (result == null) {
        return;
      }
      movedEvent = result;
    } else {
      movedEvent = shiftCalendarEventToDate(event, normalizedTarget);
      await ref.read(eventCommandServiceProvider).save(movedEvent);
    }
  }

  await _saveCalendarManualOrderAfterDrop(
    ref,
    sourceDate: sourceDate,
    targetDate: normalizedTarget,
    targetIndex: targetIndex,
    originalEvent: event,
    movedEvent: movedEvent,
    visibleEvents: visibleEvents,
    settings: settings,
  );
}

Future<void> _handleCalendarEventTimeDrop(
  BuildContext context,
  WidgetRef ref,
  CalendarEvent event,
  DateTime targetStart,
) async {
  if (!calendarEventCanMove(event) || event.allDay) {
    return;
  }
  final sourceDate = _dateOnly(event.startAt);
  final targetDate = _dateOnly(targetStart);
  final rangeStart = sourceDate.isBefore(targetDate) ? sourceDate : targetDate;
  final rangeLastDate = sourceDate.isAfter(targetDate)
      ? sourceDate
      : targetDate;
  final rangeEnd = rangeLastDate.add(const Duration(days: 1));
  final settings = ref.read(appSettingsProvider);
  final repository = ref.read(eventRepositoryProvider);
  final storedEvents = await repository.eventsInRange(rangeStart, rangeEnd);
  final holidayEvents = ref
      .read(koreanHolidayServiceProvider)
      .holidayEventsInRange(
        rangeStart,
        rangeEnd,
        category: settings.holidayCategory,
      );
  final visibleEvents = _filterVisibleEvents(
    [...storedEvents, ...holidayEvents],
    settings,
    '',
  );
  if (!context.mounted) {
    return;
  }

  var movedEvent = event;
  if (event.startAt != targetStart) {
    if (event.isRecurring) {
      final scope = await _showCalendarRecurringDragScopeDialog(context);
      if (scope == null || !context.mounted) {
        return;
      }
      final result = await _moveRecurringCalendarEventToStart(
        ref,
        event,
        targetStart,
        scope,
      );
      if (result == null) {
        return;
      }
      movedEvent = result;
    } else {
      movedEvent = shiftCalendarEventToStart(event, targetStart);
      await ref.read(eventCommandServiceProvider).save(movedEvent);
    }
  }

  final existingTarget =
      _eventsForDay(
          visibleEvents,
          targetDate,
        ).where((candidate) => !_isSameCalendarEvent(candidate, event)).toList()
        ..add(movedEvent);
  final sortedTarget = sortedCalendarEvents(
    existingTarget,
    priority: settings.calendarEventSortPriority,
    categoryOrder: settings.categories.map((category) => category.id).toList(),
  );
  final targetIndex = sortedTarget.indexWhere(
    (candidate) => _isSameCalendarEvent(candidate, movedEvent),
  );
  await _saveCalendarManualOrderAfterDrop(
    ref,
    sourceDate: sourceDate,
    targetDate: targetDate,
    targetIndex: targetIndex < 0 ? sortedTarget.length : targetIndex,
    originalEvent: event,
    movedEvent: movedEvent,
    visibleEvents: visibleEvents,
    settings: settings,
  );
}

Future<CalendarEvent?> _moveRecurringCalendarEvent(
  WidgetRef ref,
  CalendarEvent occurrence,
  DateTime targetDate,
  _RecurringDragScope scope,
) async {
  final repository = ref.read(eventRepositoryProvider);
  final commandService = ref.read(eventCommandServiceProvider);
  final base = await repository.findById(occurrence.id);
  if (base == null) {
    return null;
  }
  final shiftedOccurrence = shiftCalendarEventToDate(occurrence, targetDate);

  switch (scope) {
    case _RecurringDragScope.onlyThis:
      await commandService.save(
        _excludeCalendarOccurrence(base, occurrence.startAt),
      );
      return _createMovedCalendarOccurrence(
        commandService,
        shiftedOccurrence,
        const RecurrenceRule(),
      );
    case _RecurringDragScope.future:
      await commandService.save(
        _endCalendarRecurrenceBefore(base, occurrence.startAt),
      );
      final futureRule = recurrenceRuleForMovedFuture(
        base: base,
        occurrence: occurrence,
        targetDate: targetDate,
      );
      final created = await _createMovedCalendarOccurrence(
        commandService,
        shiftedOccurrence,
        futureRule,
      );
      return created.copyWith(
        occurrenceId: '${created.id}@${created.startAt.toIso8601String()}',
      );
    case _RecurringDragScope.all:
      final dayDelta = calendarDayDifference(targetDate, occurrence.startAt);
      final shiftedBaseEvent = shiftCalendarEventToDate(
        base,
        shiftCalendarDateByDays(base.startAt, dayDelta),
      );
      final shiftedBase = shiftedBaseEvent.copyWith(
        recurrence: shiftRecurrenceRuleByDays(base.recurrence, dayDelta),
      );
      await commandService.save(shiftedBase);
      final shiftedStart = shiftCalendarDateByDays(
        occurrence.startAt,
        dayDelta,
      );
      return occurrence.copyWith(
        occurrenceId: '${base.id}@${shiftedStart.toIso8601String()}',
        startAt: shiftedStart,
        endAt: shiftedStart.add(occurrence.duration),
      );
  }
}

Future<CalendarEvent?> _moveRecurringCalendarEventToStart(
  WidgetRef ref,
  CalendarEvent occurrence,
  DateTime targetStart,
  _RecurringDragScope scope,
) async {
  final repository = ref.read(eventRepositoryProvider);
  final commandService = ref.read(eventCommandServiceProvider);
  final base = await repository.findById(occurrence.id);
  if (base == null) {
    return null;
  }
  final shiftedOccurrence = shiftCalendarEventToStart(occurrence, targetStart);

  switch (scope) {
    case _RecurringDragScope.onlyThis:
      await commandService.save(
        _excludeCalendarOccurrence(base, occurrence.startAt),
      );
      return _createMovedCalendarOccurrence(
        commandService,
        shiftedOccurrence,
        const RecurrenceRule(),
      );
    case _RecurringDragScope.future:
      await commandService.save(
        _endCalendarRecurrenceBefore(base, occurrence.startAt),
      );
      final futureRule = recurrenceRuleForMovedFuture(
        base: base,
        occurrence: occurrence,
        targetDate: targetStart,
      );
      final created = await _createMovedCalendarOccurrence(
        commandService,
        shiftedOccurrence,
        futureRule,
      );
      return created.copyWith(
        occurrenceId: '${created.id}@${created.startAt.toIso8601String()}',
      );
    case _RecurringDragScope.all:
      final dayDelta = calendarDayDifference(targetStart, occurrence.startAt);
      final shiftedBaseDate = shiftCalendarDateByDays(base.startAt, dayDelta);
      final shiftedBaseStart = DateTime(
        shiftedBaseDate.year,
        shiftedBaseDate.month,
        shiftedBaseDate.day,
        targetStart.hour,
        targetStart.minute,
        targetStart.second,
        targetStart.millisecond,
        targetStart.microsecond,
      );
      final shiftedBase = base.copyWith(
        startAt: shiftedBaseStart,
        endAt: shiftedBaseStart.add(base.duration),
        recurrence: shiftRecurrenceRuleByDays(base.recurrence, dayDelta),
      );
      await commandService.save(shiftedBase);
      return occurrence.copyWith(
        occurrenceId: '${base.id}@${targetStart.toIso8601String()}',
        startAt: targetStart,
        endAt: targetStart.add(occurrence.duration),
      );
  }
}

Future<CalendarEvent> _createMovedCalendarOccurrence(
  EventCommandService commandService,
  CalendarEvent event,
  RecurrenceRule recurrence,
) async {
  final created = await commandService.create(
    _calendarEventDraftFrom(event, recurrence: recurrence),
  );
  if (!event.completed) {
    return created;
  }
  final completed = created.copyWith(completed: true);
  await commandService.save(completed);
  return completed;
}

Future<void> _saveCalendarManualOrderAfterDrop(
  WidgetRef ref, {
  required DateTime sourceDate,
  required DateTime targetDate,
  required int targetIndex,
  required CalendarEvent originalEvent,
  required CalendarEvent movedEvent,
  required List<CalendarEvent> visibleEvents,
  required AppSettings settings,
}) async {
  final sourceKey = calendarDateKey(sourceDate);
  final targetKey = calendarDateKey(targetDate);
  final originalOrderKey = calendarEventOrderKey(originalEvent);
  final movedOrderKey = calendarEventOrderKey(movedEvent);
  final categoryOrder = settings.categories
      .map((category) => category.id)
      .toList();
  final manualOrders = <String, CalendarManualEventOrder>{
    ...settings.calendarManualEventOrders,
  };
  final deviceId = await ref.read(settingsRepositoryProvider).deviceId();
  final now = DateTime.now();

  if (sourceKey != targetKey) {
    final sourceEvents = _eventsForDay(visibleEvents, sourceDate)
        .where(
          (candidate) =>
              calendarEventOrderKey(candidate) != originalOrderKey &&
              candidate.id != originalEvent.id,
        )
        .toList();
    manualOrders[sourceKey] = CalendarManualEventOrder(
      eventKeys: sourceEvents.map(calendarEventOrderKey).toList(),
      updatedAt: now,
      deviceId: deviceId,
    );
  }

  final existingTarget = _eventsForDay(visibleEvents, targetDate)
      .where(
        (candidate) =>
            calendarEventOrderKey(candidate) != originalOrderKey &&
            calendarEventOrderKey(candidate) != movedOrderKey &&
            candidate.id != originalEvent.id,
      )
      .toList();
  final sortedTarget = sortedCalendarEvents(
    existingTarget,
    priority: settings.calendarEventSortPriority,
    categoryOrder: categoryOrder,
    manualOrder:
        settings.calendarManualEventOrders[targetKey]?.eventKeys ??
        const <String>[],
  );
  final insertionIndex = targetIndex.clamp(0, sortedTarget.length);
  sortedTarget.insert(insertionIndex, movedEvent);
  manualOrders[targetKey] = CalendarManualEventOrder(
    eventKeys: sortedTarget.map(calendarEventOrderKey).toList(),
    updatedAt: now,
    deviceId: deviceId,
  );

  final updatedSettings = settings.copyWith(
    calendarManualEventOrders: manualOrders,
  );
  await _persistCalendarManualOrder(
    ref,
    previous: settings,
    updated: updatedSettings,
  );
}

Future<void> _persistCalendarManualOrder(
  WidgetRef ref, {
  required AppSettings previous,
  required AppSettings updated,
}) async {
  ref.read(appSettingsProvider.notifier).state = updated;
  try {
    await ref
        .read(settingsRepositoryProvider)
        .save(updated, changedFrom: previous);
    await ref.read(syncServiceProvider).queueSettingsBackup();
  } on Object {
    final current = ref.read(appSettingsProvider);
    if (identical(
      current.calendarManualEventOrders,
      updated.calendarManualEventOrders,
    )) {
      ref.read(appSettingsProvider.notifier).state = previous;
    }
    rethrow;
  }
}

EventDraft _calendarEventDraftFrom(
  CalendarEvent event, {
  required RecurrenceRule recurrence,
}) {
  return EventDraft(
    title: event.title,
    memo: event.memo,
    location: event.location,
    url: event.url,
    weather: event.weather,
    startAt: event.startAt,
    endAt: event.endAt,
    allDay: event.allDay,
    category: event.category,
    colorValue: event.colorValue,
    reminderMinutesBeforeList: event.reminderMinutesBeforeList,
    recurrence: recurrence,
    showDday: event.showDday,
    alarmEnabled: event.alarmEnabled,
    allDayAlarmMinutes: event.allDayAlarmMinutes,
  );
}

CalendarEvent _excludeCalendarOccurrence(
  CalendarEvent base,
  DateTime occurrence,
) {
  final excludedDate = _dateOnly(occurrence);
  final excluded = {
    ...base.recurrence.excludedDates.map(_dateOnly),
    excludedDate,
  }.toList()..sort();
  return base.copyWith(
    recurrence: base.recurrence.copyWith(excludedDates: excluded),
  );
}

CalendarEvent _endCalendarRecurrenceBefore(
  CalendarEvent base,
  DateTime occurrence,
) {
  return base.copyWith(
    recurrence: base.recurrence.copyWith(
      until: _dateOnly(occurrence).subtract(const Duration(days: 1)),
      clearCount: true,
    ),
  );
}

Future<_RecurringDragScope?> _showCalendarRecurringDragScopeDialog(
  BuildContext context,
) {
  return showDialog<_RecurringDragScope>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr('반복 일정 이동')),
      content: Text(context.tr('이 반복 일정의 어느 범위를 이동할까요?')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('취소')),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_RecurringDragScope.onlyThis),
          child: Text(context.tr('이 일정만')),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_RecurringDragScope.future),
          child: Text(context.tr('이후 일정')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_RecurringDragScope.all),
          child: Text(context.tr('전체 반복')),
        ),
      ],
    ),
  );
}

Future<void> _openRangeEventEditor(
  BuildContext context,
  WidgetRef ref,
  DateTime start,
  DateTime end,
  List<EventCategory> categories,
  List<int> defaultReminderMinutesList,
) async {
  final analytics = ref.read(productAnalyticsProvider);
  final stopwatch = Stopwatch()..start();
  unawaited(
    analytics
        .record(
          AnalyticsRecord.eventEditorOpened(
            AnalyticsEditorMode.create,
            trigger: AnalyticsTrigger.manual,
          ),
        )
        .catchError((_) {}),
  );
  final draft = await showDialog<EventDraft>(
    context: context,
    builder: (_) => EventEditorDialog(
      initialDate: start,
      initialEndDate: end,
      initialAllDay: true,
      categories: categories,
      defaultReminderMinutesList: defaultReminderMinutesList,
      alarmService: ref.read(alarmServiceProvider),
    ),
  );
  unawaited(
    analytics
        .record(
          AnalyticsRecord.eventEditorCompleted(
            AnalyticsEditorMode.create,
            outcome: draft == null
                ? AnalyticsOutcome.canceled
                : AnalyticsOutcome.succeeded,
            durationMs: stopwatch.elapsedMilliseconds,
          ),
        )
        .catchError((_) {}),
  );
  if (draft != null) {
    await ref.read(eventCommandServiceProvider).create(draft);
  }
}

class _CalendarHeader extends ConsumerWidget {
  const _CalendarHeader({
    required this.month,
    required this.selectedDate,
    required this.viewMode,
    required this.monthNavigationMode,
    required this.searchQuery,
    required this.searchOpen,
    required this.quickAccessSelected,
    required this.onSearchPressed,
    required this.onQuickAccessPressed,
    required this.onCalendarViewSelected,
    required this.onLlmPressed,
  });

  final DateTime month;
  final DateTime selectedDate;
  final CalendarViewMode viewMode;
  final MonthNavigationMode monthNavigationMode;
  final String searchQuery;
  final bool searchOpen;
  final bool quickAccessSelected;
  final VoidCallback onSearchPressed;
  final VoidCallback onQuickAccessPressed;
  final ValueChanged<CalendarViewMode> onCalendarViewSelected;
  final VoidCallback onLlmPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windowSize = MediaQuery.sizeOf(context);
    final compact = windowSize.width < 680;
    final platform = Theme.of(context).platform;
    final ios = platform == TargetPlatform.iOS;
    final mobile = ios || platform == TargetPlatform.android;
    final desktop = _usesDesktopCalendarLayout(platform);
    final androidTablet =
        platform == TargetPlatform.android &&
        dailyWindowClassFor(windowSize) != DailyWindowClass.compact;
    final actionSize = androidTablet ? 48.0 : 40.0;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final settings = ref.watch(appSettingsProvider);
    final fullDayLabel =
        viewMode == CalendarViewMode.day &&
        settings.weekDayLayoutMode == WeekDayLayoutMode.schedule &&
        !quickAccessSelected;
    final label = calendarPeriodLabel(
      visibleMonth: month,
      selectedDate: selectedDate,
      viewMode: quickAccessSelected ? CalendarViewMode.month : viewMode,
      navigationMode: quickAccessSelected
          ? MonthNavigationMode.horizontal
          : monthNavigationMode,
      locale: locale,
      weekStartsOnMonday: settings.weekStartsOnMonday,
      compactHorizontalYearOnly: compact && !mobile,
      showFullDay: fullDayLabel,
    );
    final periodLabelMaxWidth = fullDayLabel && mobile
        ? math.max(40.0, windowSize.width - 20 - actionSize * 4 - 44)
        : mobile &&
              monthNavigationMode == MonthNavigationMode.vertical &&
              viewMode == CalendarViewMode.week
        ? 164.0
        : 126.0;
    final colorScheme = Theme.of(context).colorScheme;
    final periodColor = fullDayLabel
        ? calendarDateAccent(
            selectedDate,
            isHoliday:
                settings.calendarShowHolidays &&
                ref
                    .read(koreanHolidayServiceProvider)
                    .isPublicHoliday(selectedDate),
            holidayColorValue: settings.holidayCategory.colorValue,
          )
        : null;
    final weekday = DateFormat.EEEE(locale).format(selectedDate);
    final weekdayIndex = fullDayLabel ? label.indexOf(weekday) : -1;
    final monthButton = TextButton.icon(
      key: const ValueKey('calendar-period-button'),
      onPressed: () => _showMonthPicker(context, ref),
      icon: Icon(
        Icons.date_range_rounded,
        size: 20,
        color: colorScheme.onSurface,
      ),
      label: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: mobile
              ? (compact
                    ? (windowSize.width - 20 - actionSize * 4 - 44).clamp(
                        40.0,
                        periodLabelMaxWidth,
                      )
                    : periodLabelMaxWidth)
              : double.infinity,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                if (weekdayIndex >= 0 && periodColor != null) ...[
                  TextSpan(text: label.substring(0, weekdayIndex)),
                  TextSpan(
                    text: weekday,
                    style: TextStyle(color: periodColor),
                  ),
                  TextSpan(
                    text: label.substring(weekdayIndex + weekday.length),
                  ),
                ] else
                  TextSpan(text: label),
              ],
            ),
            maxLines: 1,
            style: compact
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    color: colorScheme.onSurface,
                  )
                : Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
          ),
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: mobile && !androidTablet
            ? const Size(0, 44)
            : androidTablet
            ? const Size(0, 48)
            : null,
        maximumSize: mobile && !androidTablet
            ? Size(periodLabelMaxWidth + 44, 44)
            : null,
        tapTargetSize: mobile
            ? MaterialTapTargetSize.shrinkWrap
            : MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    final navigationActions = [
      DailyIconAction(
        tooltip: context.tr('이전'),
        onPressed: () => _moveVisibleRange(ref, -1),
        icon: Icons.arrow_back_ios_new_rounded,
        size: actionSize,
        borderless: true,
      ),
      DailyIconAction(
        tooltip: context.tr('다음'),
        onPressed: () => _moveVisibleRange(ref, 1),
        icon: Icons.arrow_forward_ios_rounded,
        size: actionSize,
        borderless: true,
      ),
      DailyIconAction(
        tooltip: context.tr('오늘'),
        onPressed: () => _goToday(ref),
        icon: Icons.calendar_today_rounded,
        size: actionSize,
        borderless: true,
      ),
    ];
    final utilityActions = [
      DailyIconAction(
        tooltip: context.tr(searchOpen ? '검색 닫기' : '검색'),
        onPressed: onSearchPressed,
        selected: searchOpen,
        icon: Icons.search_rounded,
        size: actionSize,
        borderless: true,
      ),
      DailyIconAction(
        tooltip: context.tr('검색/필터'),
        onPressed: () => _showFilterSheet(context, ref),
        selected: searchQuery.isNotEmpty,
        icon: Icons.tune_rounded,
        size: actionSize,
        borderless: true,
      ),
      DailyIconAction(
        tooltip: context.tr('설정'),
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
        icon: Icons.settings_rounded,
        size: actionSize,
        borderless: true,
      ),
    ];

    if (desktop) {
      final assistantLabel = platform == TargetPlatform.macOS ? 'Siri' : 'LLM';
      final viewSwitch = SegmentedButton<CalendarViewMode>(
        selected: quickAccessSelected ? const {} : {viewMode},
        emptySelectionAllowed: quickAccessSelected,
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 8),
          ),
          minimumSize: WidgetStateProperty.all(const Size(38, 34)),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : colorScheme.onSurfaceVariant,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? DailyUi.primary
                : DailyUi.groupedSurface(context),
          ),
          side: WidgetStateProperty.all(BorderSide.none),
        ),
        segments: [
          ButtonSegment(
            value: CalendarViewMode.week,
            label: Text(
              context.l10n.compactCalendarViewName(CalendarViewMode.week),
            ),
          ),
          ButtonSegment(
            value: CalendarViewMode.month,
            label: Text(
              context.l10n.compactCalendarViewName(CalendarViewMode.month),
            ),
          ),
          ButtonSegment(
            value: CalendarViewMode.day,
            label: Text(
              context.l10n.compactCalendarViewName(CalendarViewMode.day),
            ),
          ),
        ],
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) {
            onCalendarViewSelected(selection.first);
          }
        },
      );
      final quickAccessButton = DailyIconAction(
        tooltip: context.tr('빠른 보기'),
        selected: quickAccessSelected,
        onPressed: onQuickAccessPressed,
        icon: Icons.view_agenda_outlined,
        selectedIcon: Icons.view_agenda_rounded,
        borderless: true,
      );
      final llmButton = DailyIconAction(
        tooltip: assistantLabel,
        onPressed: onLlmPressed,
        icon: Icons.stars_rounded,
        accentColor: DailyUi.purple,
        borderless: true,
      );

      return Padding(
        key: const ValueKey('macos-calendar-toolbar'),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(
          children: [
            monthButton,
            const Spacer(),
            quickAccessButton,
            const SizedBox(width: 6),
            viewSwitch,
            const SizedBox(width: 6),
            ...navigationActions,
            ...utilityActions,
            llmButton,
          ],
        ),
      );
    }

    if (compact) {
      return Padding(
        key: mobile
            ? ValueKey('${ios ? 'ios' : 'android'}-calendar-toolbar')
            : null,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (mobile) ...[
              monthButton,
              Expanded(
                child: SizedBox(
                  key: ValueKey(
                    '${ios ? 'ios' : 'android'}-calendar-header-reserved-space',
                  ),
                ),
              ),
            ] else ...[
              Expanded(child: monthButton),
              ...navigationActions.take(2),
            ],
            navigationActions[2],
            utilityActions[0],
            utilityActions[1],
            utilityActions[2],
          ],
        ),
      );
    }

    return Padding(
      key: mobile
          ? ValueKey('${ios ? 'ios' : 'android'}-calendar-toolbar')
          : null,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          monthButton,
          const Spacer(),
          if (!mobile) ...navigationActions.take(2),
          navigationActions[2],
          const SizedBox(width: 6),
          ...utilityActions,
        ],
      ),
    );
  }

  Future<void> _showMonthPicker(BuildContext context, WidgetRef ref) async {
    final picked = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _YearOverviewPage(
          initialMonth: month,
          navigationMode: monthNavigationMode,
        ),
      ),
    );
    if (picked == null) {
      return;
    }
    _setVisibleMonth(ref, picked, selectedDate);
  }

  void _moveVisibleRange(WidgetRef ref, int delta) {
    switch (quickAccessSelected ? CalendarViewMode.month : viewMode) {
      case CalendarViewMode.month:
        _setVisibleMonth(
          ref,
          DateTime(month.year, month.month + delta),
          selectedDate,
        );
      case CalendarViewMode.week:
        final next = selectedDate.add(Duration(days: delta * 7));
        ref.read(selectedDateProvider.notifier).state = next;
        ref.read(visibleMonthProvider.notifier).state = DateTime(
          next.year,
          next.month,
        );
      case CalendarViewMode.day:
        final next = selectedDate.add(Duration(days: delta));
        ref.read(selectedDateProvider.notifier).state = next;
        ref.read(visibleMonthProvider.notifier).state = DateTime(
          next.year,
          next.month,
        );
    }
  }

  void _goToday(WidgetRef ref) {
    final now = DateTime.now();
    ref.read(visibleMonthProvider.notifier).state = DateTime(
      now.year,
      now.month,
    );
    ref.read(selectedDateProvider.notifier).state = DateTime(
      now.year,
      now.month,
      now.day,
    );
  }

  Future<void> _showFilterSheet(BuildContext context, WidgetRef ref) {
    final settings = ref.read(appSettingsProvider);
    final queryController = TextEditingController(
      text: ref.read(calendarSearchQueryProvider),
    );
    var hidden = settings.hiddenCategoryIds.toSet();
    var showHolidays = settings.calendarShowHolidays;
    var ddayOnly = settings.calendarDdayOnly;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: DailyUi.pageBackground(context),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final viewInsets = MediaQuery.viewInsetsOf(context);
          final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
          return Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  DailyUi.isDesktop ? 24 : 16,
                  10,
                  DailyUi.isDesktop ? 24 : 16,
                  20,
                ),
                shrinkWrap: true,
                children: [
                  const DailySheetHandle(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const DailySettingsIcon(icon: Icons.filter_alt_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr('검색/필터'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      DailyIconAction(
                        tooltip: context.tr('닫기'),
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.of(context).pop();
                        },
                        icon: Icons.close_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: queryController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: context.tr('현재 보기에서 검색'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      fillColor: DailyUi.groupedSurface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: DailyUi.separator(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: DailyUi.separator(context),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: DailyUi.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (value) =>
                        ref.read(calendarSearchQueryProvider.notifier).state =
                            value.trim(),
                  ),
                  const SizedBox(height: 4),
                  DailyGroupedSection(
                    label: context.tr('표시 옵션'),
                    children: [
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        secondary: const Icon(Icons.flag_outlined),
                        value: ddayOnly,
                        title: Text(context.tr('D-day 일정만 보기')),
                        onChanged: (value) async {
                          setState(() => ddayOnly = value);
                          final currentSettings = ref.read(appSettingsProvider);
                          final updated = currentSettings.copyWith(
                            calendarDdayOnly: value,
                          );
                          final settingsRepository = ref.read(
                            settingsRepositoryProvider,
                          );
                          await settingsRepository.save(
                            updated,
                            changedFrom: currentSettings,
                          );
                          ref.read(appSettingsProvider.notifier).state =
                              settingsRepository.load();
                        },
                      ),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        secondary: const Icon(Icons.celebration_outlined),
                        value: showHolidays,
                        title: Text(context.tr('공휴일 표시')),
                        onChanged: (value) async {
                          setState(() => showHolidays = value);
                          final currentSettings = ref.read(appSettingsProvider);
                          final updated = currentSettings.copyWith(
                            calendarShowHolidays: value,
                          );
                          final settingsRepository = ref.read(
                            settingsRepositoryProvider,
                          );
                          await settingsRepository.save(
                            updated,
                            changedFrom: currentSettings,
                          );
                          ref.read(appSettingsProvider.notifier).state =
                              settingsRepository.load();
                        },
                      ),
                    ],
                  ),
                  DailySectionLabel(context.tr('분류 표시')),
                  Material(
                    color: DailyUi.groupedSurface(context),
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: DailyUi.separator(context)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final category in settings.categories)
                            FilterChip(
                              avatar: CircleAvatar(
                                radius: 5,
                                backgroundColor: Color(category.colorValue),
                              ),
                              label: Text(
                                context.l10n.categoryName(
                                  id: category.id,
                                  label: category.label,
                                ),
                              ),
                              selected: !hidden.contains(category.id),
                              selectedColor: DailyUi.primary.withValues(
                                alpha:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? 0.28
                                    : 0.13,
                              ),
                              checkmarkColor: DailyUi.primary,
                              shape: const StadiumBorder(),
                              onSelected: (selected) async {
                                setState(() {
                                  if (selected) {
                                    hidden.remove(category.id);
                                  } else {
                                    hidden.add(category.id);
                                  }
                                });
                                final currentSettings = ref.read(
                                  appSettingsProvider,
                                );
                                final updated = currentSettings.copyWith(
                                  hiddenCategoryIds: hidden.toList(),
                                );
                                final settingsRepository = ref.read(
                                  settingsRepositoryProvider,
                                );
                                await settingsRepository.save(
                                  updated,
                                  changedFrom: currentSettings,
                                );
                                ref.read(appSettingsProvider.notifier).state =
                                    settingsRepository.load();
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            queryController.clear();
                            ref
                                    .read(calendarSearchQueryProvider.notifier)
                                    .state =
                                '';
                          },
                          icon: const Icon(Icons.clear_rounded),
                          label: Text(context.tr('검색어 지우기')),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            Navigator.of(context).pop();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: DailyUi.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(context.tr('완료')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      unawaited(
        ref
            .read(productAnalyticsProvider)
            .record(
              AnalyticsRecord.featureUsed(
                AnalyticsFeature.filter,
                outcome: AnalyticsOutcome.succeeded,
              ),
            )
            .catchError((_) {}),
      );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => queryController.dispose(),
      );
    });
  }
}

class _CalendarBottomBar extends StatefulWidget {
  const _CalendarBottomBar({
    super.key,
    required this.viewMode,
    required this.calendarActive,
    required this.activeAction,
    required this.selectedAction,
    required this.calendarViewControlSelected,
    required this.onCalendarViewInteractionStarted,
    required this.onCalendarViewSelected,
    required this.onCenterActionSelected,
  });

  final CalendarViewMode viewMode;
  final bool calendarActive;
  final _BottomCenterAction activeAction;
  final _BottomCenterAction? selectedAction;
  final bool calendarViewControlSelected;
  final VoidCallback onCalendarViewInteractionStarted;
  final ValueChanged<CalendarViewMode> onCalendarViewSelected;
  final ValueChanged<_BottomCenterAction> onCenterActionSelected;

  @override
  State<_CalendarBottomBar> createState() => _CalendarBottomBarState();
}

class _CalendarBottomBarState extends State<_CalendarBottomBar> {
  _BottomNavigationItem? _dragItem;
  _BottomNavigationItem? _pressedItem;

  _BottomNavigationItem get _activeItem {
    final selectedAction = widget.selectedAction;
    if (selectedAction == _BottomCenterAction.ai) {
      return _BottomNavigationItem.siri;
    }
    if (selectedAction == _BottomCenterAction.quickAccess) {
      return _BottomNavigationItem.quickAccess;
    }
    if (!widget.calendarActive ||
        widget.activeAction == _BottomCenterAction.quickAccess) {
      return _BottomNavigationItem.quickAccess;
    }
    if (widget.activeAction == _BottomCenterAction.ai) {
      return _BottomNavigationItem.siri;
    }
    return switch (widget.viewMode) {
      CalendarViewMode.week => _BottomNavigationItem.week,
      CalendarViewMode.month => _BottomNavigationItem.month,
      CalendarViewMode.day => _BottomNavigationItem.day,
    };
  }

  _BottomNavigationItem get _visibleItem =>
      _dragItem ?? _pressedItem ?? _activeItem;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    if (platform != TargetPlatform.iOS && platform != TargetPlatform.android) {
      return _LegacyCalendarBottomBar(
        viewMode: widget.viewMode,
        calendarActive: widget.calendarActive,
        activeAction: widget.activeAction,
        selectedAction: widget.selectedAction,
        calendarViewControlSelected: widget.calendarViewControlSelected,
        onCalendarViewInteractionStarted:
            widget.onCalendarViewInteractionStarted,
        onCalendarViewSelected: widget.onCalendarViewSelected,
        onCenterActionSelected: widget.onCenterActionSelected,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final emphasized =
        widget.selectedAction != null || widget.calendarViewControlSelected;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        key: const ValueKey('calendar-bottom-bar'),
        height: 62,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final expandedWidth = (constraints.maxWidth - 32).clamp(
              260.0,
              320.0,
            );
            final width = emphasized
                ? expandedWidth
                : (expandedWidth * 0.88).clamp(228.0, 282.0);
            final height = emphasized ? 50.0 : 42.0;
            return Center(
              child: GestureDetector(
                key: const ValueKey('bottom-mode-switcher'),
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (details) {
                  setState(() => _pressedItem = null);
                  _updateDrag(details.localPosition.dx, width);
                },
                onHorizontalDragUpdate: (details) =>
                    _updateDrag(details.localPosition.dx, width),
                onHorizontalDragEnd: (_) {
                  final item = _dragItem;
                  setState(() => _dragItem = null);
                  if (item != null) {
                    _select(item);
                  }
                },
                onHorizontalDragCancel: () => setState(() => _dragItem = null),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: AnimatedContainer(
                      key: const ValueKey('bottom-mode-track'),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: width,
                      height: height,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: DailyUi.elevatedSurface(
                          context,
                        ).withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: scheme.onSurface.withValues(alpha: 0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: LayoutBuilder(
                        builder: (context, innerConstraints) {
                          final segmentWidth = innerConstraints.maxWidth / 5;
                          final visibleItem = _visibleItem;
                          return Stack(
                            key: const ValueKey('bottom-mode-thumb-layer'),
                            children: [
                              AnimatedPositioned(
                                key: const ValueKey('bottom-mode-thumb'),
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutBack,
                                left:
                                    _BottomNavigationItem.values.indexOf(
                                          visibleItem,
                                        ) *
                                        segmentWidth +
                                    2,
                                top: 2,
                                width: segmentWidth - 4,
                                height: innerConstraints.maxHeight - 4,
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 110),
                                  curve: Curves.easeOutCubic,
                                  scale: _pressedItem == null ? 1 : 0.92,
                                  child: DecoratedBox(
                                    key: const ValueKey(
                                      'bottom-mode-thumb-circle',
                                    ),
                                    decoration: BoxDecoration(
                                      color: DailyUi.primary.withValues(
                                        alpha: 0.94,
                                      ),
                                      borderRadius: BorderRadius.circular(21),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: DailyUi.primary.withValues(
                                            alpha: 0.28,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  for (final item
                                      in _BottomNavigationItem.values)
                                    _UnifiedBottomNavigationButton(
                                      item: item,
                                      selected: item == visibleItem,
                                      onTapDown: () =>
                                          setState(() => _pressedItem = item),
                                      onPressed: () {
                                        final selected = _pressedItem ?? item;
                                        setState(() => _pressedItem = null);
                                        _select(selected);
                                      },
                                      onTapCancel: () =>
                                          setState(() => _pressedItem = null),
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _updateDrag(double dx, double width) {
    final index = (dx / (width / 5)).floor().clamp(0, 4);
    final item = _BottomNavigationItem.values[index];
    if (_dragItem != item) {
      setState(() => _dragItem = item);
    }
  }

  void _select(_BottomNavigationItem item) {
    switch (item) {
      case _BottomNavigationItem.quickAccess:
        widget.onCenterActionSelected(_BottomCenterAction.quickAccess);
      case _BottomNavigationItem.week:
        widget.onCalendarViewInteractionStarted();
        widget.onCalendarViewSelected(CalendarViewMode.week);
      case _BottomNavigationItem.month:
        widget.onCalendarViewInteractionStarted();
        widget.onCalendarViewSelected(CalendarViewMode.month);
      case _BottomNavigationItem.day:
        widget.onCalendarViewInteractionStarted();
        widget.onCalendarViewSelected(CalendarViewMode.day);
      case _BottomNavigationItem.siri:
        widget.onCenterActionSelected(_BottomCenterAction.ai);
    }
  }
}

class _UnifiedBottomNavigationButton extends StatelessWidget {
  const _UnifiedBottomNavigationButton({
    required this.item,
    required this.selected,
    required this.onTapDown,
    required this.onPressed,
    required this.onTapCancel,
  });

  final _BottomNavigationItem item;
  final bool selected;
  final VoidCallback onTapDown;
  final VoidCallback onPressed;
  final VoidCallback onTapCancel;

  @override
  Widget build(BuildContext context) {
    final tooltip = switch (item) {
      _BottomNavigationItem.quickAccess => context.tr('빠른 보기'),
      _BottomNavigationItem.week => context.l10n.calendarViewName(
        CalendarViewMode.week,
      ),
      _BottomNavigationItem.month => context.l10n.calendarViewName(
        CalendarViewMode.month,
      ),
      _BottomNavigationItem.day => context.l10n.calendarViewName(
        CalendarViewMode.day,
      ),
      _BottomNavigationItem.siri =>
        Theme.of(context).platform == TargetPlatform.android ? 'LLM' : 'Siri',
    };
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => onTapDown(),
          onTap: onPressed,
          onTapCancel: onTapCancel,
          child: Center(child: _content(context)),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final color = selected ? Colors.white : DailyUi.secondaryText(context);
    if (item == _BottomNavigationItem.quickAccess) {
      return Icon(Icons.view_agenda_outlined, size: 20, color: color);
    }
    if (item == _BottomNavigationItem.siri) {
      return Icon(Icons.graphic_eq_rounded, size: 21, color: color);
    }
    final mode = switch (item) {
      _BottomNavigationItem.week => CalendarViewMode.week,
      _BottomNavigationItem.month => CalendarViewMode.month,
      _BottomNavigationItem.day => CalendarViewMode.day,
      _ => throw StateError('Unsupported calendar navigation item: $item'),
    };
    return Text(
      context.l10n.compactCalendarViewName(mode),
      maxLines: 1,
      overflow: TextOverflow.fade,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }
}

class _LegacyCalendarBottomBar extends StatelessWidget {
  const _LegacyCalendarBottomBar({
    required this.viewMode,
    required this.calendarActive,
    required this.activeAction,
    required this.selectedAction,
    required this.calendarViewControlSelected,
    required this.onCalendarViewInteractionStarted,
    required this.onCalendarViewSelected,
    required this.onCenterActionSelected,
  });

  final CalendarViewMode viewMode;
  final bool calendarActive;
  final _BottomCenterAction activeAction;
  final _BottomCenterAction? selectedAction;
  final bool calendarViewControlSelected;
  final VoidCallback onCalendarViewInteractionStarted;
  final ValueChanged<CalendarViewMode> onCalendarViewSelected;
  final ValueChanged<_BottomCenterAction> onCenterActionSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        key: const ValueKey('calendar-bottom-bar'),
        height: 62,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const horizontalInset = 16.0;
            const gap = 8.0;
            final centerExpanded = selectedAction != null;
            final centerWidth = centerExpanded ? 152.0 : 124.0;
            final centerHeight = centerExpanded ? 48.0 : 40.0;
            final centerLeft = (constraints.maxWidth - centerWidth) / 2;
            final desiredViewWidth = calendarViewControlSelected ? 96.0 : 76.0;
            final desiredViewHeight = calendarViewControlSelected ? 48.0 : 40.0;
            final viewWidth = (centerLeft - horizontalInset - gap).clamp(
              60.0,
              desiredViewWidth,
            );
            final viewHeight =
                desiredViewHeight * (viewWidth / desiredViewWidth);
            return Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                if (calendarActive)
                  Positioned(
                    left: horizontalInset,
                    top: (62 - viewHeight) / 2,
                    child: _LegacyThreeSegmentSlider<CalendarViewMode>(
                      gestureKey: const ValueKey('calendar-view-button'),
                      trackKey: const ValueKey('calendar-view-track'),
                      thumbLayerKey: const ValueKey(
                        'calendar-view-thumb-layer',
                      ),
                      thumbKey: const ValueKey('calendar-view-thumb'),
                      thumbShapeKey: const ValueKey(
                        'calendar-view-thumb-circle',
                      ),
                      values: CalendarViewMode.values,
                      value: viewMode,
                      width: viewWidth,
                      height: viewHeight,
                      tooltipBuilder: (mode) =>
                          context.l10n.calendarViewName(mode),
                      itemBuilder: (context, mode, selected) => Text(
                        context.l10n.compactCalendarViewName(mode),
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : DailyUi.secondaryText(context),
                          fontSize: calendarViewControlSelected ? 13 : 11,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      onInteractionStarted: onCalendarViewInteractionStarted,
                      onChanged: onCalendarViewSelected,
                    ),
                  ),
                Align(
                  alignment: Alignment.center,
                  child: _LegacyThreeSegmentSlider<_BottomCenterAction>(
                    gestureKey: const ValueKey('bottom-mode-switcher'),
                    trackKey: const ValueKey('bottom-mode-track'),
                    thumbLayerKey: const ValueKey('bottom-mode-thumb-layer'),
                    thumbKey: const ValueKey('bottom-mode-thumb'),
                    thumbShapeKey: const ValueKey('bottom-mode-thumb-circle'),
                    values: _BottomCenterAction.values,
                    value: selectedAction ?? activeAction,
                    width: centerWidth,
                    height: centerHeight,
                    tooltipBuilder: (action) => switch (action) {
                      _BottomCenterAction.quickAccess => context.tr('빠른 보기'),
                      _BottomCenterAction.calendar => context.tr('달력'),
                      _BottomCenterAction.ai => 'AI',
                    },
                    itemBuilder: (context, action, selected) => Icon(
                      switch (action) {
                        _BottomCenterAction.quickAccess =>
                          Icons.view_agenda_outlined,
                        _BottomCenterAction.calendar =>
                          Icons.date_range_rounded,
                        _BottomCenterAction.ai => Icons.stars_rounded,
                      },
                      size: 20,
                      color: selected
                          ? Colors.white
                          : DailyUi.secondaryText(context),
                    ),
                    onChanged: onCenterActionSelected,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LegacyThreeSegmentSlider<T> extends StatefulWidget {
  const _LegacyThreeSegmentSlider({
    required this.gestureKey,
    required this.trackKey,
    required this.thumbLayerKey,
    required this.thumbKey,
    required this.thumbShapeKey,
    required this.values,
    required this.value,
    required this.width,
    required this.height,
    required this.tooltipBuilder,
    required this.itemBuilder,
    this.onInteractionStarted,
    required this.onChanged,
  });

  final Key gestureKey;
  final Key trackKey;
  final Key thumbLayerKey;
  final Key thumbKey;
  final Key thumbShapeKey;
  final List<T> values;
  final T value;
  final double width;
  final double height;
  final String Function(T value) tooltipBuilder;
  final Widget Function(BuildContext context, T value, bool selected)
  itemBuilder;
  final VoidCallback? onInteractionStarted;
  final ValueChanged<T> onChanged;

  @override
  State<_LegacyThreeSegmentSlider<T>> createState() =>
      _LegacyThreeSegmentSliderState<T>();
}

class _LegacyThreeSegmentSliderState<T>
    extends State<_LegacyThreeSegmentSlider<T>> {
  T? _dragValue;
  T? _pressedValue;

  T get _visibleValue => _dragValue ?? _pressedValue ?? widget.value;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: widget.gestureKey,
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (details) {
        setState(() => _pressedValue = null);
        widget.onInteractionStarted?.call();
        _updateDrag(details.localPosition.dx);
      },
      onHorizontalDragUpdate: (details) =>
          _updateDrag(details.localPosition.dx),
      onHorizontalDragEnd: (_) {
        final selected = _dragValue;
        setState(() => _dragValue = null);
        if (selected != null) {
          widget.onChanged(selected);
        }
      },
      onHorizontalDragCancel: () => setState(() => _dragValue = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: widget.width,
        height: widget.height,
        child: Container(
          key: widget.trackKey,
          decoration: ShapeDecoration(
            color: DailyUi.elevatedSurface(context),
            shape: const StadiumBorder(),
          ),
          clipBehavior: Clip.none,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final segmentWidth =
                    constraints.maxWidth / widget.values.length;
                final thumbSize = constraints.maxHeight;
                final selectedIndex = widget.values.indexOf(_visibleValue);
                return Stack(
                  key: widget.thumbLayerKey,
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedPositioned(
                      key: widget.thumbKey,
                      duration: const Duration(milliseconds: 170),
                      curve: Curves.easeOutCubic,
                      left:
                          selectedIndex * segmentWidth +
                          (segmentWidth - thumbSize) / 2,
                      top: 0,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 110),
                        scale: _pressedValue == null ? 1 : 0.9,
                        child: SizedBox.square(
                          key: widget.thumbShapeKey,
                          dimension: thumbSize,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              color: DailyUi.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x1a0f172a),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final value in widget.values)
                          Expanded(
                            child: Tooltip(
                              message: widget.tooltipBuilder(value),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (_) {
                                  widget.onInteractionStarted?.call();
                                  setState(() => _pressedValue = value);
                                },
                                onTap: () {
                                  final selected = _pressedValue ?? value;
                                  setState(() => _pressedValue = null);
                                  widget.onChanged(selected);
                                },
                                onTapCancel: () =>
                                    setState(() => _pressedValue = null),
                                child: Center(
                                  child: widget.itemBuilder(
                                    context,
                                    value,
                                    value == _visibleValue,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
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

  void _updateDrag(double dx) {
    final index = (dx / (widget.width / widget.values.length)).floor().clamp(
      0,
      widget.values.length - 1,
    );
    final value = widget.values[index];
    if (_dragValue != value) {
      setState(() => _dragValue = value);
    }
  }
}

class _QuickTodoGroup {
  const _QuickTodoGroup(this.category, this.events);

  final EventCategory category;
  final List<CalendarEvent> events;
}

class _QuickTodoEmptyState extends StatelessWidget {
  const _QuickTodoEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DailyUi.groupedSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: DailyUi.separator(context).withValues(alpha: 0.78),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: DailyUi.tertiaryText(context),
              size: 34,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: DailyUi.secondaryText(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickTodoCategoryCard extends StatelessWidget {
  const _QuickTodoCategoryCard({
    required this.group,
    required this.onCompletedChanged,
    required this.onOpen,
  });

  final _QuickTodoGroup group;
  final Future<void> Function(CalendarEvent event, bool completed)
  onCompletedChanged;
  final ValueChanged<CalendarEvent> onOpen;

  @override
  Widget build(BuildContext context) {
    final categoryColor = Color(group.category.colorValue);
    return Material(
      key: ValueKey('quick-todo-category-${group.category.id}'),
      color: DailyUi.groupedSurface(context),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: DailyUi.separator(context).withValues(alpha: 0.78),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              color: categoryColor.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.16
                    : 0.09,
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: categoryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.categoryName(
                        id: group.category.id,
                        label: group.category.label,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  Text(
                    '${group.events.where((event) => event.completed).length}/${group.events.length}',
                    style: TextStyle(
                      color: DailyUi.secondaryText(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            for (var index = 0; index < group.events.length; index++) ...[
              _QuickTodoRow(
                event: group.events[index],
                onCompletedChanged: onCompletedChanged,
                onOpen: onOpen,
              ),
              if (index != group.events.length - 1)
                Divider(
                  height: 1,
                  indent: 46,
                  color: DailyUi.separator(context),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickTodoRow extends StatelessWidget {
  const _QuickTodoRow({
    required this.event,
    required this.onCompletedChanged,
    required this.onOpen,
  });

  final CalendarEvent event;
  final Future<void> Function(CalendarEvent event, bool completed)
  onCompletedChanged;
  final ValueChanged<CalendarEvent> onOpen;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateLabel = DateFormat.Md(locale).format(event.startAt);
    final timeLabel = event.allDay
        ? context.tr('종일')
        : DateFormat.Hm(locale).format(event.startAt);
    final titleStyle = calendarEventCompletionStyle(
      context,
      Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      completed: event.completed,
      eventColor: Color(event.colorValue),
    );
    final eventKey = event.occurrenceId ?? event.id;
    return Row(
      children: [
        Checkbox(
          key: ValueKey('quick-todo-checkbox-$eventKey'),
          value: event.completed,
          shape: const CircleBorder(),
          side: BorderSide(color: DailyUi.tertiaryText(context), width: 1.8),
          activeColor: DailyUi.success,
          onChanged: (value) {
            if (value != null) {
              unawaited(onCompletedChanged(event, value));
            }
          },
        ),
        Expanded(
          child: EventCompletionAction(
            event: event,
            builder: (onDoubleTap) => InkWell(
              key: ValueKey('quick-todo-open-$eventKey'),
              onTap: () => onOpen(event),
              onDoubleTap: onDoubleTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 11, 11, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        context.l10n.eventTitle(
                          event.title,
                          holiday: event.holiday,
                        ),
                        textAlign: TextAlign.start,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle.copyWith(
                          fontSize: 14,
                          height: 1.25,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        '$dateLabel · $timeLabel',
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          color: DailyUi.secondaryText(context),
                          fontSize: 11,
                          height: 1.25,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _YearOverviewPage extends StatefulWidget {
  const _YearOverviewPage({
    required this.initialMonth,
    required this.navigationMode,
  });

  final DateTime initialMonth;
  final MonthNavigationMode navigationMode;

  @override
  State<_YearOverviewPage> createState() => _YearOverviewPageState();
}

class _YearOverviewPageState extends State<_YearOverviewPage> {
  static const _initialPage = 12000;
  static const _yearBuffer = 200;

  late final PageController _horizontalController;
  late final ScrollController _verticalController;
  final _verticalCenterKey = GlobalKey();
  late final int _anchorYear;
  double _verticalYearExtent = 1;
  DateTime? _lastPointerYearMoveAt;

  @override
  void initState() {
    super.initState();
    _anchorYear = widget.initialMonth.year;
    _horizontalController = PageController(initialPage: _initialPage);
    _verticalController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vertical = widget.navigationMode == MonthNavigationMode.vertical;
    final platform = Theme.of(context).platform;
    final desktop = _usesDesktopCalendarLayout(platform);
    final androidExpanded =
        platform == TargetPlatform.android &&
        dailyWindowClassFor(MediaQuery.sizeOf(context)) ==
            DailyWindowClass.expanded;
    final spacious = desktop || androidExpanded;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.tr('닫기'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = spacious && constraints.maxWidth >= 1000 ? 2 : 1;
          final horizontalRows = spacious && constraints.maxHeight >= 1040
              ? 2
              : 1;
          return vertical
              ? _buildVerticalYears(
                  columns: columns,
                  desktop: spacious,
                  viewportHeight: constraints.maxHeight,
                )
              : _buildHorizontalYears(columns: columns, rows: horizontalRows);
        },
      ),
    );
  }

  Widget _buildHorizontalYears({required int columns, required int rows}) {
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent || !_horizontalController.hasClients) {
          return;
        }
        final primaryDelta =
            event.scrollDelta.dx.abs() >= event.scrollDelta.dy.abs()
            ? event.scrollDelta.dx
            : event.scrollDelta.dy;
        if (primaryDelta.abs() < 8) {
          return;
        }
        final now = DateTime.now();
        if (_lastPointerYearMoveAt != null &&
            now.difference(_lastPointerYearMoveAt!) <
                const Duration(milliseconds: 300)) {
          return;
        }
        _lastPointerYearMoveAt = now;
        final currentPage = _horizontalController.page?.round() ?? _initialPage;
        unawaited(
          _horizontalController.animateToPage(
            currentPage + (primaryDelta > 0 ? 1 : -1),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          ),
        );
      },
      child: PageView.builder(
        key: const ValueKey('year-overview-page-view'),
        controller: _horizontalController,
        physics: const _ResponsiveMonthPagePhysics(),
        itemBuilder: (context, page) => _yearGrid(
          firstYear: _yearForPage(page),
          columns: columns,
          rows: rows,
        ),
      ),
    );
  }

  Widget _buildVerticalYears({
    required int columns,
    required bool desktop,
    required double viewportHeight,
  }) {
    _verticalYearExtent = desktop
        ? math.min(viewportHeight, 680)
        : viewportHeight;
    return CustomScrollView(
      key: const ValueKey('year-overview-continuous-scroll'),
      controller: _verticalController,
      center: _verticalCenterKey,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverList.builder(
          itemCount: _yearBuffer,
          itemBuilder: (context, index) => SizedBox(
            height: _verticalYearExtent,
            child: _yearGrid(
              firstYear: _anchorYear - (index + 1) * columns,
              columns: columns,
              rows: 1,
            ),
          ),
        ),
        SliverList.builder(
          key: _verticalCenterKey,
          itemBuilder: (context, index) => SizedBox(
            height: _verticalYearExtent,
            child: _yearGrid(
              firstYear: _anchorYear + index * columns,
              columns: columns,
              rows: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _yearPage(int year) {
    return _YearCalendarPage(
      year: year,
      weekStartsOnMonday: false,
      onMonthSelected: (month) =>
          Navigator.of(context).pop(DateTime(year, month)),
    );
  }

  Widget _yearGrid({
    required int firstYear,
    required int columns,
    required int rows,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          for (var row = 0; row < rows; row++) ...[
            if (row > 0) const SizedBox(height: 6),
            Expanded(
              child: Row(
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _yearPage(firstYear + row * columns + column),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _yearForPage(int page) => _anchorYear + page - _initialPage;
}

class _YearCalendarPage extends StatelessWidget {
  const _YearCalendarPage({
    required this.year,
    required this.weekStartsOnMonday,
    required this.onMonthSelected,
  });

  final int year;
  final bool weekStartsOnMonday;
  final ValueChanged<int> onMonthSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900 ? 4 : 3;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      '$year년',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildMonthGrid(width, columns)),
          ],
        );
      },
    );
  }

  Widget _buildMonthGrid(double width, int columns) {
    final spacing = width < 500 ? 8.0 : 14.0;
    final rowCount = (12 / columns).ceil();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        width < 500 ? 10 : 20,
        0,
        width < 500 ? 10 : 20,
        18,
      ),
      child: Column(
        children: [
          for (var row = 0; row < rowCount; row++) ...[
            if (row > 0) SizedBox(height: spacing),
            Expanded(
              child: Row(
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) SizedBox(width: spacing),
                    Expanded(
                      child: row * columns + column < 12
                          ? _MiniMonthCalendar(
                              year: year,
                              month: row * columns + column + 1,
                              weekStartsOnMonday: weekStartsOnMonday,
                              onTap: () =>
                                  onMonthSelected(row * columns + column + 1),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniMonthCalendar extends StatelessWidget {
  const _MiniMonthCalendar({
    required this.year,
    required this.month,
    required this.weekStartsOnMonday,
    required this.onTap,
  });

  final int year;
  final int month;
  final bool weekStartsOnMonday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final monthDate = DateTime(year, month);
    final monthLabel = DateFormat.MMMM(locale).format(monthDate);
    return Semantics(
      label: DateFormat.yMMMM(locale).format(monthDate),
      button: true,
      child: InkWell(
        key: ValueKey('mini-month-$year-$month'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox.expand(
          child: CustomPaint(
            key: ValueKey('mini-month-canvas-$year-$month'),
            painter: _MiniMonthPainter(
              year: year,
              month: month,
              monthLabel: monthLabel,
              weekdayLabels: _localizedWeekdayLabels(
                context,
                weekStartsOnMonday: weekStartsOnMonday,
              ),
              weekStartsOnMonday: weekStartsOnMonday,
              today: DateTime(now.year, now.month, now.day),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              monthStyle: (theme.textTheme.labelLarge ?? const TextStyle())
                  .copyWith(fontWeight: FontWeight.w800),
              weekdayStyle: (theme.textTheme.labelSmall ?? const TextStyle())
                  .copyWith(fontSize: 8),
              dayStyle: TextStyle(
                fontSize: 8,
                height: 1,
                color: colorScheme.onSurface,
              ),
              sundayColor: colorScheme.error,
              saturdayColor: colorScheme.primary,
              weekdayColor: colorScheme.onSurfaceVariant,
              todayBackground: colorScheme.primary,
              todayForeground: colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMonthPainter extends CustomPainter {
  const _MiniMonthPainter({
    required this.year,
    required this.month,
    required this.monthLabel,
    required this.weekdayLabels,
    required this.weekStartsOnMonday,
    required this.today,
    required this.textDirection,
    required this.textScaler,
    required this.monthStyle,
    required this.weekdayStyle,
    required this.dayStyle,
    required this.sundayColor,
    required this.saturdayColor,
    required this.weekdayColor,
    required this.todayBackground,
    required this.todayForeground,
  });

  final int year;
  final int month;
  final String monthLabel;
  final List<String> weekdayLabels;
  final bool weekStartsOnMonday;
  final DateTime today;
  final ui.TextDirection textDirection;
  final TextScaler textScaler;
  final TextStyle monthStyle;
  final TextStyle weekdayStyle;
  final TextStyle dayStyle;
  final Color sundayColor;
  final Color saturdayColor;
  final Color weekdayColor;
  final Color todayBackground;
  final Color todayForeground;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 4.0;
    final contentWidth = math.max(0.0, size.width - inset * 2);
    final monthPainter = _textPainter(monthLabel, monthStyle);
    monthPainter.paint(canvas, Offset(inset, inset));

    final weekdayTop = inset + monthPainter.height + 3;
    final weekdayHeight = _scaledFontHeight(weekdayStyle);
    final cellWidth = contentWidth / 7;
    for (var column = 0; column < 7; column++) {
      final color = column == 0
          ? sundayColor
          : column == 6
          ? saturdayColor
          : weekdayColor;
      final painter = _textPainter(
        weekdayLabels[column],
        weekdayStyle.copyWith(color: color),
      );
      painter.paint(
        canvas,
        Offset(
          inset + column * cellWidth + (cellWidth - painter.width) / 2,
          weekdayTop + (weekdayHeight - painter.height) / 2,
        ),
      );
    }

    final gridTop = weekdayTop + weekdayHeight + 2;
    final gridHeight = math.max(0.0, size.height - gridTop - inset);
    final cellHeight = gridHeight / 6;
    final first = DateTime(year, month);
    final leading = weekStartsOnMonday ? first.weekday - 1 : first.weekday % 7;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    for (var day = 1; day <= daysInMonth; day++) {
      final index = leading + day - 1;
      final row = index ~/ 7;
      final column = index % 7;
      final center = Offset(
        inset + (column + 0.5) * cellWidth,
        gridTop + (row + 0.5) * cellHeight,
      );
      final isToday =
          today.year == year && today.month == month && today.day == day;
      if (isToday) {
        canvas.drawCircle(
          center,
          math.min(8.5, math.min(cellWidth, cellHeight) / 2),
          Paint()..color = todayBackground,
        );
      }
      final painter = _textPainter(
        '$day',
        dayStyle.copyWith(
          color: isToday ? todayForeground : dayStyle.color,
          fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
        ),
      );
      painter.paint(
        canvas,
        Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
      );
    }
  }

  TextPainter _textPainter(String text, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
  }

  double _scaledFontHeight(TextStyle style) {
    final painter = _textPainter('월', style);
    return painter.height;
  }

  @override
  bool shouldRepaint(covariant _MiniMonthPainter oldDelegate) {
    return year != oldDelegate.year ||
        month != oldDelegate.month ||
        monthLabel != oldDelegate.monthLabel ||
        !listEquals(weekdayLabels, oldDelegate.weekdayLabels) ||
        weekStartsOnMonday != oldDelegate.weekStartsOnMonday ||
        today != oldDelegate.today ||
        textDirection != oldDelegate.textDirection ||
        textScaler != oldDelegate.textScaler ||
        monthStyle != oldDelegate.monthStyle ||
        weekdayStyle != oldDelegate.weekdayStyle ||
        dayStyle != oldDelegate.dayStyle ||
        sundayColor != oldDelegate.sundayColor ||
        saturdayColor != oldDelegate.saturdayColor ||
        weekdayColor != oldDelegate.weekdayColor ||
        todayBackground != oldDelegate.todayBackground ||
        todayForeground != oldDelegate.todayForeground;
  }
}

List<String> _localizedWeekdayLabels(
  BuildContext context, {
  required bool weekStartsOnMonday,
}) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final firstDay = weekStartsOnMonday ? DateTime.monday : DateTime.sunday;
  return List.generate(
    DateTime.daysPerWeek,
    (index) => DateFormat.E(
      locale,
    ).format(DateTime(2024, 1, 1 + (firstDay - 1 + index) % 7)),
  );
}

class _CalendarWeekView extends StatefulWidget {
  const _CalendarWeekView({
    required this.selectedDate,
    required this.weekStartsOnMonday,
    required this.showLunarDates,
    required this.centerEventTitles,
    required this.eventSortPriority,
    required this.categoryOrder,
    required this.manualEventOrders,
    required this.events,
    required this.externalEventDragActive,
    required this.onEventDropped,
    required this.onEventDragStateChanged,
    required this.onEventDragInteractionStateChanged,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final bool weekStartsOnMonday;
  final bool showLunarDates;
  final bool centerEventTitles;
  final CalendarEventSortPriority eventSortPriority;
  final List<String> categoryOrder;
  final Map<String, CalendarManualEventOrder> manualEventOrders;
  final List<CalendarEvent> events;
  final bool externalEventDragActive;
  final CalendarEventDropCallback onEventDropped;
  final ValueChanged<bool> onEventDragStateChanged;
  final ValueChanged<bool> onEventDragInteractionStateChanged;
  final void Function(DateTime date, List<CalendarEvent> events) onDateSelected;

  @override
  State<_CalendarWeekView> createState() => _CalendarWeekViewState();
}

class _CalendarWeekViewState extends State<_CalendarWeekView> {
  static const _fallbackDraggedExtent = 42.0;

  final Map<String, GlobalKey> _itemMeasureKeys = {};
  CalendarEvent? _draggingEvent;
  DateTime? _hoverDate;
  int? _hoverIndex;
  double _draggedExtent = _fallbackDraggedExtent;
  bool _eventDropAccepted = false;
  bool _settlingAcceptedDrop = false;

  @override
  void didUpdateWidget(covariant _CalendarWeekView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.externalEventDragActive &&
        !widget.externalEventDragActive &&
        _draggingEvent == null &&
        (_hoverDate != null || _hoverIndex != null || _eventDropAccepted)) {
      final settleAcceptedDrop = _eventDropAccepted;
      _hoverDate = null;
      _hoverIndex = null;
      _eventDropAccepted = false;
      _draggedExtent = _fallbackDraggedExtent;
      _settlingAcceptedDrop = settleAcceptedDrop;
      if (settleAcceptedDrop) {
        _finishAcceptedDropSettlement();
      }
    }
    if (_draggingEvent == null && !identical(oldWidget.events, widget.events)) {
      _itemMeasureKeys.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final draggingEvent = _effectiveDraggingEvent;
    final range = _weekRangeFor(widget.selectedDate, widget.weekStartsOnMonday);
    final days = List.generate(
      7,
      (index) => range.start.add(Duration(days: index)),
    );
    final compact = MediaQuery.sizeOf(context).width < 720;

    if (compact) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemBuilder: (context, index) {
          final day = days[index];
          final dayEvents = _orderedEventsForDay(
            widget.events,
            day,
            priority: widget.eventSortPriority,
            categoryOrder: widget.categoryOrder,
            manualEventOrders: widget.manualEventOrders,
          );
          return _WeekDayPanel(
            day: day,
            selected: _sameDay(day, widget.selectedDate),
            events: dayEvents,
            centerEventTitles: widget.centerEventTitles,
            compact: true,
            draggingEvent: draggingEvent,
            hoverDate: _hoverDate,
            hoverIndex: _hoverIndex,
            draggedExtent: _draggedExtent,
            itemMeasureKeys: _itemMeasureKeys,
            onEventDropped: widget.onEventDropped,
            onEventDragStateChanged: _setEventDragging,
            onEventDragInteractionStateChanged:
                widget.onEventDragInteractionStateChanged,
            eventDropAccepted: _eventDropAccepted,
            settlingAcceptedDrop: _settlingAcceptedDrop,
            onEventDropAccepted: _setEventDropAccepted,
            onDropHoverChanged: _setDropHover,
            onTap: () => widget.onDateSelected(day, dayEvents),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemCount: days.length,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final day in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Builder(
                  builder: (context) {
                    final dayEvents = _orderedEventsForDay(
                      widget.events,
                      day,
                      priority: widget.eventSortPriority,
                      categoryOrder: widget.categoryOrder,
                      manualEventOrders: widget.manualEventOrders,
                    );
                    return _WeekDayPanel(
                      day: day,
                      selected: _sameDay(day, widget.selectedDate),
                      events: dayEvents,
                      centerEventTitles: widget.centerEventTitles,
                      compact: false,
                      draggingEvent: draggingEvent,
                      hoverDate: _hoverDate,
                      hoverIndex: _hoverIndex,
                      draggedExtent: _draggedExtent,
                      itemMeasureKeys: _itemMeasureKeys,
                      onEventDropped: widget.onEventDropped,
                      onEventDragStateChanged: _setEventDragging,
                      onEventDragInteractionStateChanged:
                          widget.onEventDragInteractionStateChanged,
                      eventDropAccepted: _eventDropAccepted,
                      settlingAcceptedDrop: _settlingAcceptedDrop,
                      onEventDropAccepted: _setEventDropAccepted,
                      onDropHoverChanged: _setDropHover,
                      onTap: () => widget.onDateSelected(day, dayEvents),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  CalendarEvent? get _effectiveDraggingEvent {
    if (_draggingEvent != null) {
      return _draggingEvent;
    }
    if (!widget.externalEventDragActive) {
      return null;
    }
    return activeCalendarEventDrag.value?.event;
  }

  void _setEventDragging(
    CalendarEvent event,
    DateTime sourceDate,
    bool dragging,
  ) {
    if (dragging) {
      final measureKey = _weekEventMeasureKey(event, sourceDate);
      final renderObject = _itemMeasureKeys[measureKey]?.currentContext
          ?.findRenderObject();
      final measuredHeight = renderObject is RenderBox
          ? renderObject.size.height
          : _fallbackDraggedExtent;
      final sourceEvents = _orderedEventsForDay(
        widget.events,
        sourceDate,
        priority: widget.eventSortPriority,
        categoryOrder: widget.categoryOrder,
        manualEventOrders: widget.manualEventOrders,
      );
      final sourceIndex = sourceEvents.indexWhere(
        (candidate) => _isSameCalendarEvent(candidate, event),
      );
      setState(() {
        _draggingEvent = event;
        _hoverDate = _dateOnly(sourceDate);
        _hoverIndex = sourceIndex < 0 ? sourceEvents.length : sourceIndex;
        _draggedExtent = measuredHeight + 6;
        _eventDropAccepted = false;
        _settlingAcceptedDrop = false;
      });
      widget.onEventDragStateChanged(true);
      return;
    }
    if (!_isSameCalendarEventOrNull(_draggingEvent, event)) {
      return;
    }
    final settleAcceptedDrop = _eventDropAccepted;
    setState(() {
      _draggingEvent = null;
      _hoverDate = null;
      _hoverIndex = null;
      _draggedExtent = _fallbackDraggedExtent;
      _eventDropAccepted = false;
      _settlingAcceptedDrop = settleAcceptedDrop;
    });
    if (settleAcceptedDrop) {
      _finishAcceptedDropSettlement();
    }
    widget.onEventDragStateChanged(false);
  }

  void _finishAcceptedDropSettlement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _settlingAcceptedDrop) {
        setState(() => _settlingAcceptedDrop = false);
      }
    });
  }

  void _setDropHover(DateTime? date, int? index) {
    if (date == null || index == null) {
      if (_hoverDate == null && _hoverIndex == null) return;
      setState(() {
        _hoverDate = null;
        _hoverIndex = null;
      });
      return;
    }
    if (_hoverDate != null &&
        _sameDay(_hoverDate!, date) &&
        _hoverIndex == index) {
      return;
    }
    setState(() {
      _hoverDate = date;
      _hoverIndex = index;
    });
  }

  void _setEventDropAccepted(CalendarEvent event) {
    final draggingEvent = _effectiveDraggingEvent;
    if (_eventDropAccepted) {
      return;
    }
    if (draggingEvent == null) {
      setState(() {
        _hoverDate = null;
        _hoverIndex = null;
      });
      return;
    }
    if (!_isSameCalendarEventOrNull(draggingEvent, event)) return;
    setState(() => _eventDropAccepted = true);
  }
}

class _WeekDayPanel extends ConsumerWidget {
  const _WeekDayPanel({
    required this.day,
    required this.selected,
    required this.events,
    required this.centerEventTitles,
    required this.compact,
    required this.draggingEvent,
    required this.hoverDate,
    required this.hoverIndex,
    required this.draggedExtent,
    required this.itemMeasureKeys,
    required this.onEventDropped,
    required this.onEventDragStateChanged,
    required this.onEventDragInteractionStateChanged,
    required this.eventDropAccepted,
    required this.settlingAcceptedDrop,
    required this.onEventDropAccepted,
    required this.onDropHoverChanged,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final List<CalendarEvent> events;
  final bool centerEventTitles;
  final bool compact;
  final CalendarEvent? draggingEvent;
  final DateTime? hoverDate;
  final int? hoverIndex;
  final double draggedExtent;
  final Map<String, GlobalKey> itemMeasureKeys;
  final CalendarEventDropCallback onEventDropped;
  final void Function(CalendarEvent event, DateTime sourceDate, bool dragging)
  onEventDragStateChanged;
  final ValueChanged<bool> onEventDragInteractionStateChanged;
  final bool eventDropAccepted;
  final bool settlingAcceptedDrop;
  final ValueChanged<CalendarEvent> onEventDropAccepted;
  final void Function(DateTime? date, int? index) onDropHoverChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(appSettingsProvider);
    final color =
        calendarDateAccent(
          day,
          isHoliday:
              settings.calendarShowHolidays &&
              ref.read(koreanHolidayServiceProvider).isPublicHoliday(day),
          holidayColorValue: settings.holidayCategory.colorValue,
        ) ??
        colorScheme.onSurface;
    final visibleEvents = compact ? events.take(4).toList() : events;
    final eventChildren = _eventChildren(context, visibleEvents);
    return _WeekDayDropTarget(
      date: day,
      events: visibleEvents,
      draggingEvent: draggingEvent,
      itemMeasureKeys: itemMeasureKeys,
      onEventDropped: onEventDropped,
      onEventDropAccepted: onEventDropAccepted,
      onDropHoverChanged: onDropHoverChanged,
      child: Material(
        key: ValueKey('week-day-panel-${day.year}-${day.month}-${day.day}'),
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      key: ValueKey(
                        'week-list-weekday-${day.year}-${day.month}-${day.day}',
                      ),
                      DateFormat.E(
                        Localizations.localeOf(context).toLanguageTag(),
                      ).format(day),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${day.month}/${day.day}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (events.isEmpty &&
                    !(hoverDate != null && _sameDay(hoverDate!, day)))
                  Text(
                    context.tr('일정 없음'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.outline,
                    ),
                  )
                else if (compact)
                  Column(
                    children: [
                      ...eventChildren,
                      if (events.length > visibleEvents.length)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '+${events.length - visibleEvents.length}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                    ],
                  )
                else
                  Expanded(
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: eventChildren,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _eventChildren(
    BuildContext context,
    List<CalendarEvent> visibleEvents,
  ) {
    final draggedKey = draggingEvent == null
        ? null
        : calendarEventOrderKey(draggingEvent!);
    final targetActive = hoverDate != null && _sameDay(hoverDate!, day);
    final remainingCount = visibleEvents
        .where((event) => calendarEventOrderKey(event) != draggedKey)
        .length;
    final insertionIndex = targetActive
        ? (hoverIndex ?? remainingCount).clamp(0, remainingCount).toInt()
        : null;
    final children = <Widget>[];
    var remainingIndex = 0;
    for (final event in visibleEvents) {
      final eventKey = calendarEventOrderKey(event);
      final dragged = eventKey == draggedKey;
      if (!dragged) {
        children.add(
          _WeekEventInsertionGap(
            key: ValueKey(
              'week-event-gap-${day.toIso8601String()}-$remainingIndex',
            ),
            active: insertionIndex == remainingIndex,
            extent: draggedExtent,
            animate: !settlingAcceptedDrop,
            child:
                eventDropAccepted &&
                    insertionIndex == remainingIndex &&
                    draggingEvent != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: IgnorePointer(
                      child: KeyedSubtree(
                        key: ValueKey(
                          'week-event-accepted-preview-${calendarEventOrderKey(draggingEvent!)}',
                        ),
                        child: _WeekEventFlag(
                          event: draggingEvent!,
                          centerTitle: centerEventTitles,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        );
      }
      final segmentKey = _weekEventMeasureKey(event, day);
      final measureKey = itemMeasureKeys.putIfAbsent(segmentKey, GlobalKey.new);
      final entry = Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: SizedBox(
          key: measureKey,
          child: CalendarEventDraggable(
            key: ValueKey('week-event-drag-$segmentKey'),
            event: event,
            onDragStateChanged: (active) =>
                onEventDragStateChanged(event, day, active),
            onDragInteractionStateChanged: onEventDragInteractionStateChanged,
            child: EventCompletionAction(
              event: event,
              builder: (onDoubleTap) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                onDoubleTap: onDoubleTap,
                child: _WeekEventFlag(
                  event: event,
                  centerTitle: centerEventTitles,
                ),
              ),
            ),
          ),
        ),
      );
      children.add(
        settlingAcceptedDrop
            ? entry
            : TweenAnimationBuilder<double>(
                key: ValueKey('week-event-entry-$eventKey'),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(end: dragged ? 0 : 1),
                child: entry,
                builder: (context, factor, child) => ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: factor,
                    child: child,
                  ),
                ),
              ),
      );
      if (!dragged) {
        remainingIndex += 1;
      }
    }
    children.add(
      _WeekEventInsertionGap(
        key: ValueKey(
          'week-event-gap-${day.toIso8601String()}-$remainingIndex',
        ),
        active: insertionIndex == remainingIndex,
        extent: draggedExtent,
        animate: !settlingAcceptedDrop,
        child:
            eventDropAccepted &&
                insertionIndex == remainingIndex &&
                draggingEvent != null
            ? Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: IgnorePointer(
                  child: KeyedSubtree(
                    key: ValueKey(
                      'week-event-accepted-preview-${calendarEventOrderKey(draggingEvent!)}',
                    ),
                    child: _WeekEventFlag(
                      event: draggingEvent!,
                      centerTitle: centerEventTitles,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
    return children;
  }
}

class _WeekDayDropTarget extends StatelessWidget {
  const _WeekDayDropTarget({
    required this.date,
    required this.events,
    required this.draggingEvent,
    required this.itemMeasureKeys,
    required this.onEventDropped,
    required this.onEventDropAccepted,
    required this.onDropHoverChanged,
    required this.child,
  });

  final DateTime date;
  final List<CalendarEvent> events;
  final CalendarEvent? draggingEvent;
  final Map<String, GlobalKey> itemMeasureKeys;
  final CalendarEventDropCallback onEventDropped;
  final ValueChanged<CalendarEvent> onEventDropAccepted;
  final void Function(DateTime? date, int? index) onDropHoverChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragTarget<CalendarEventDragPayload>(
      onWillAcceptWithDetails: (details) {
        if (!calendarEventCanMove(details.data.event)) return false;
        onDropHoverChanged(date, _targetIndex(details.offset));
        return true;
      },
      onMove: (details) {
        onDropHoverChanged(date, _targetIndex(details.offset));
      },
      onLeave: (_) => onDropHoverChanged(null, null),
      onAcceptWithDetails: (details) {
        final targetIndex = _targetIndex(details.offset);
        onDropHoverChanged(date, targetIndex);
        onEventDropAccepted(details.data.event);
        unawaited(
          performCalendarEventDrop(
            details.data.event,
            () => onEventDropped(details.data.event, date, targetIndex),
          ),
        );
      },
      builder: (context, candidateData, rejectedData) => child,
    );
  }

  int _targetIndex(Offset globalOffset) {
    final draggedKey = draggingEvent == null
        ? null
        : calendarEventOrderKey(draggingEvent!);
    var index = 0;
    for (final event in events) {
      final eventKey = calendarEventOrderKey(event);
      if (eventKey == draggedKey) continue;
      final renderObject = itemMeasureKeys[_weekEventMeasureKey(event, date)]
          ?.currentContext
          ?.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        final bounds =
            renderObject.localToGlobal(Offset.zero) & renderObject.size;
        if (globalOffset.dy < bounds.center.dy) {
          return index;
        }
      }
      index += 1;
    }
    return index;
  }
}

class _WeekEventInsertionGap extends StatelessWidget {
  const _WeekEventInsertionGap({
    super.key,
    required this.active,
    required this.extent,
    required this.animate,
    this.child,
  });

  final bool active;
  final double extent;
  final bool animate;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final content = active
        ? SizedBox(height: extent, child: child)
        : const SizedBox.shrink();
    if (!animate) {
      return content;
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: content,
    );
  }
}

class _WeekEventFlag extends StatelessWidget {
  const _WeekEventFlag({required this.event, required this.centerTitle});

  final CalendarEvent event;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    final categoryColor = Color(event.colorValue);
    final eventColor = calendarEventAccentColor(
      context,
      categoryColor,
      completed: event.completed,
    );
    final backgroundColor = calendarEventBackgroundColor(
      context,
      categoryColor,
      completed: event.completed,
    );
    final title = context.l10n.eventTitle(event.title, holiday: event.holiday);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              event.allDay
                  ? title
                  : '$title  ${DateFormat('HH:mm').format(event.startAt)}',
              maxLines: 2,
              textAlign: centerTitle ? TextAlign.center : TextAlign.start,
              overflow: TextOverflow.ellipsis,
              style: calendarEventCompletionStyle(
                context,
                TextStyle(
                  color: eventColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                completed: event.completed,
                eventColor: categoryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _setVisibleMonth(
  WidgetRef ref,
  DateTime nextMonth,
  DateTime selectedDate,
) {
  final month = DateTime(nextMonth.year, nextMonth.month);
  final lastDay = DateUtils.getDaysInMonth(month.year, month.month);
  final selectedDay = selectedDate.day > lastDay ? lastDay : selectedDate.day;

  ref.read(visibleMonthProvider.notifier).state = month;
  ref.read(selectedDateProvider.notifier).state = DateTime(
    month.year,
    month.month,
    selectedDay,
  );
}

CalendarRange _monthRangeFor(DateTime month, bool weekStartsOnMonday) {
  final first = DateTime(month.year, month.month);
  final leadingDays = weekStartsOnMonday
      ? first.weekday - 1
      : first.weekday % 7;
  final gridStart = first.subtract(Duration(days: leadingDays));
  return CalendarRange(gridStart, gridStart.add(const Duration(days: 42)));
}

CalendarRange _weekRangeFor(DateTime date, bool weekStartsOnMonday) {
  final day = DateTime(date.year, date.month, date.day);
  final leadingDays = weekStartsOnMonday ? day.weekday - 1 : day.weekday % 7;
  final start = day.subtract(Duration(days: leadingDays));
  return CalendarRange(start, start.add(const Duration(days: 7)));
}

CalendarRange _dayRangeFor(DateTime date) {
  final start = DateTime(date.year, date.month, date.day);
  return CalendarRange(start, start.add(const Duration(days: 1)));
}

List<CalendarEvent> _filterVisibleEvents(
  List<CalendarEvent> events,
  AppSettings settings,
  String searchQuery,
) {
  final hidden = settings.hiddenCategoryIds.toSet();
  final query = searchQuery.trim().toLowerCase();
  final filtered = events.where((event) {
    if (!settings.calendarShowHolidays && event.holiday) {
      return false;
    }
    if (hidden.contains(event.category.id)) {
      return false;
    }
    if (settings.calendarDdayOnly && !event.showDday) {
      return false;
    }
    if (query.isEmpty) {
      return true;
    }
    final searchable = [
      event.title,
      event.memo,
      event.location,
      event.url,
      event.weather,
      event.category.label,
    ].whereType<String>().join(' ').toLowerCase();
    return searchable.contains(query);
  });
  return sortedCalendarEvents(
    filtered,
    priority: settings.calendarEventSortPriority,
    categoryOrder: settings.categories.map((category) => category.id).toList(),
  );
}

List<CalendarEvent> _eventsForDay(List<CalendarEvent> events, DateTime date) {
  final start = DateTime(date.year, date.month, date.day);
  final end = start.add(const Duration(days: 1));
  return events
      .where(
        (event) => event.startAt.isBefore(end) && event.endAt.isAfter(start),
      )
      .toList();
}

List<CalendarEvent> _orderedEventsForDay(
  List<CalendarEvent> events,
  DateTime date, {
  required CalendarEventSortPriority priority,
  required List<String> categoryOrder,
  required Map<String, CalendarManualEventOrder> manualEventOrders,
}) {
  return sortedCalendarEvents(
    _eventsForDay(events, date),
    priority: priority,
    categoryOrder: categoryOrder,
    manualOrder:
        manualEventOrders[calendarDateKey(date)]?.eventKeys ?? const <String>[],
  );
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _isSameCalendarEvent(CalendarEvent first, CalendarEvent second) {
  return calendarEventOrderKey(first) == calendarEventOrderKey(second);
}

bool _isSameCalendarEventOrNull(CalendarEvent? first, CalendarEvent? second) {
  return first != null && second != null && _isSameCalendarEvent(first, second);
}

String _weekEventMeasureKey(CalendarEvent event, DateTime date) {
  return '${calendarEventOrderKey(event)}@${calendarDateKey(date)}';
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}
