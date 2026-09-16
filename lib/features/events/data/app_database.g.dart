// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $EventRecordsTable extends EventRecords
    with TableInfo<$EventRecordsTable, EventRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weatherMeta = const VerificationMeta(
    'weather',
  );
  @override
  late final GeneratedColumn<String> weather = GeneratedColumn<String>(
    'weather',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startAtMeta = const VerificationMeta(
    'startAt',
  );
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
    'start_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<DateTime> endAt = GeneratedColumn<DateTime>(
    'end_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _allDayMeta = const VerificationMeta('allDay');
  @override
  late final GeneratedColumn<bool> allDay = GeneratedColumn<bool>(
    'all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("all_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('basic'),
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reminderMinutesBeforeMeta =
      const VerificationMeta('reminderMinutesBefore');
  @override
  late final GeneratedColumn<int> reminderMinutesBefore = GeneratedColumn<int>(
    'reminder_minutes_before',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderMinutesBeforeListMeta =
      const VerificationMeta('reminderMinutesBeforeList');
  @override
  late final GeneratedColumn<String> reminderMinutesBeforeList =
      GeneratedColumn<String>(
        'reminder_minutes_before_list',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _recurrenceFrequencyMeta =
      const VerificationMeta('recurrenceFrequency');
  @override
  late final GeneratedColumn<String> recurrenceFrequency =
      GeneratedColumn<String>(
        'recurrence_frequency',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('none'),
      );
  static const VerificationMeta _recurrenceIntervalMeta =
      const VerificationMeta('recurrenceInterval');
  @override
  late final GeneratedColumn<int> recurrenceInterval = GeneratedColumn<int>(
    'recurrence_interval',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _recurrenceUntilMeta = const VerificationMeta(
    'recurrenceUntil',
  );
  @override
  late final GeneratedColumn<DateTime> recurrenceUntil =
      GeneratedColumn<DateTime>(
        'recurrence_until',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _recurrenceCountMeta = const VerificationMeta(
    'recurrenceCount',
  );
  @override
  late final GeneratedColumn<int> recurrenceCount = GeneratedColumn<int>(
    'recurrence_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceExcludedDatesMeta =
      const VerificationMeta('recurrenceExcludedDates');
  @override
  late final GeneratedColumn<String> recurrenceExcludedDates =
      GeneratedColumn<String>(
        'recurrence_excluded_dates',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncTimestampDetailsMeta =
      const VerificationMeta('syncTimestampDetails');
  @override
  late final GeneratedColumn<String> syncTimestampDetails =
      GeneratedColumn<String>(
        'sync_timestamp_details',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _showDdayMeta = const VerificationMeta(
    'showDday',
  );
  @override
  late final GeneratedColumn<bool> showDday = GeneratedColumn<bool>(
    'show_dday',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_dday" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _alarmEnabledMeta = const VerificationMeta(
    'alarmEnabled',
  );
  @override
  late final GeneratedColumn<bool> alarmEnabled = GeneratedColumn<bool>(
    'alarm_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("alarm_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _allDayAlarmMinutesMeta =
      const VerificationMeta('allDayAlarmMinutes');
  @override
  late final GeneratedColumn<int> allDayAlarmMinutes = GeneratedColumn<int>(
    'all_day_alarm_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(9 * 60),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    memo,
    location,
    url,
    weather,
    startAt,
    endAt,
    allDay,
    category,
    colorValue,
    reminderMinutesBefore,
    reminderMinutesBeforeList,
    recurrenceFrequency,
    recurrenceInterval,
    recurrenceUntil,
    recurrenceCount,
    recurrenceExcludedDates,
    createdAt,
    updatedAt,
    deletedAt,
    syncTimestampDetails,
    deviceId,
    syncStatus,
    showDday,
    completed,
    alarmEnabled,
    allDayAlarmMinutes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'event_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('weather')) {
      context.handle(
        _weatherMeta,
        weather.isAcceptableOrUnknown(data['weather']!, _weatherMeta),
      );
    }
    if (data.containsKey('start_at')) {
      context.handle(
        _startAtMeta,
        startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startAtMeta);
    }
    if (data.containsKey('end_at')) {
      context.handle(
        _endAtMeta,
        endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endAtMeta);
    }
    if (data.containsKey('all_day')) {
      context.handle(
        _allDayMeta,
        allDay.isAcceptableOrUnknown(data['all_day']!, _allDayMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('reminder_minutes_before')) {
      context.handle(
        _reminderMinutesBeforeMeta,
        reminderMinutesBefore.isAcceptableOrUnknown(
          data['reminder_minutes_before']!,
          _reminderMinutesBeforeMeta,
        ),
      );
    }
    if (data.containsKey('reminder_minutes_before_list')) {
      context.handle(
        _reminderMinutesBeforeListMeta,
        reminderMinutesBeforeList.isAcceptableOrUnknown(
          data['reminder_minutes_before_list']!,
          _reminderMinutesBeforeListMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_frequency')) {
      context.handle(
        _recurrenceFrequencyMeta,
        recurrenceFrequency.isAcceptableOrUnknown(
          data['recurrence_frequency']!,
          _recurrenceFrequencyMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_interval')) {
      context.handle(
        _recurrenceIntervalMeta,
        recurrenceInterval.isAcceptableOrUnknown(
          data['recurrence_interval']!,
          _recurrenceIntervalMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_until')) {
      context.handle(
        _recurrenceUntilMeta,
        recurrenceUntil.isAcceptableOrUnknown(
          data['recurrence_until']!,
          _recurrenceUntilMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_count')) {
      context.handle(
        _recurrenceCountMeta,
        recurrenceCount.isAcceptableOrUnknown(
          data['recurrence_count']!,
          _recurrenceCountMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_excluded_dates')) {
      context.handle(
        _recurrenceExcludedDatesMeta,
        recurrenceExcludedDates.isAcceptableOrUnknown(
          data['recurrence_excluded_dates']!,
          _recurrenceExcludedDatesMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('sync_timestamp_details')) {
      context.handle(
        _syncTimestampDetailsMeta,
        syncTimestampDetails.isAcceptableOrUnknown(
          data['sync_timestamp_details']!,
          _syncTimestampDetailsMeta,
        ),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('show_dday')) {
      context.handle(
        _showDdayMeta,
        showDday.isAcceptableOrUnknown(data['show_dday']!, _showDdayMeta),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('alarm_enabled')) {
      context.handle(
        _alarmEnabledMeta,
        alarmEnabled.isAcceptableOrUnknown(
          data['alarm_enabled']!,
          _alarmEnabledMeta,
        ),
      );
    }
    if (data.containsKey('all_day_alarm_minutes')) {
      context.handle(
        _allDayAlarmMinutesMeta,
        allDayAlarmMinutes.isAcceptableOrUnknown(
          data['all_day_alarm_minutes']!,
          _allDayAlarmMinutesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
      weather: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weather'],
      ),
      startAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_at'],
      )!,
      endAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_at'],
      )!,
      allDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}all_day'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      reminderMinutesBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minutes_before'],
      ),
      reminderMinutesBeforeList: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_minutes_before_list'],
      )!,
      recurrenceFrequency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_frequency'],
      )!,
      recurrenceInterval: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recurrence_interval'],
      )!,
      recurrenceUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recurrence_until'],
      ),
      recurrenceCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recurrence_count'],
      ),
      recurrenceExcludedDates: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_excluded_dates'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      syncTimestampDetails: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_timestamp_details'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      showDday: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_dday'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      alarmEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}alarm_enabled'],
      )!,
      allDayAlarmMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}all_day_alarm_minutes'],
      )!,
    );
  }

  @override
  $EventRecordsTable createAlias(String alias) {
    return $EventRecordsTable(attachedDatabase, alias);
  }
}

class EventRecord extends DataClass implements Insertable<EventRecord> {
  final String id;
  final String title;
  final String? memo;
  final String? location;
  final String? url;
  final String? weather;
  final DateTime startAt;
  final DateTime endAt;
  final bool allDay;
  final String category;
  final int colorValue;
  final int? reminderMinutesBefore;
  final String reminderMinutesBeforeList;
  final String recurrenceFrequency;
  final int recurrenceInterval;
  final DateTime? recurrenceUntil;
  final int? recurrenceCount;
  final String recurrenceExcludedDates;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? syncTimestampDetails;
  final String deviceId;
  final String syncStatus;
  final bool showDday;
  final bool completed;
  final bool alarmEnabled;
  final int allDayAlarmMinutes;
  const EventRecord({
    required this.id,
    required this.title,
    this.memo,
    this.location,
    this.url,
    this.weather,
    required this.startAt,
    required this.endAt,
    required this.allDay,
    required this.category,
    required this.colorValue,
    this.reminderMinutesBefore,
    required this.reminderMinutesBeforeList,
    required this.recurrenceFrequency,
    required this.recurrenceInterval,
    this.recurrenceUntil,
    this.recurrenceCount,
    required this.recurrenceExcludedDates,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncTimestampDetails,
    required this.deviceId,
    required this.syncStatus,
    required this.showDday,
    required this.completed,
    required this.alarmEnabled,
    required this.allDayAlarmMinutes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || memo != null) {
      map['memo'] = Variable<String>(memo);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    if (!nullToAbsent || weather != null) {
      map['weather'] = Variable<String>(weather);
    }
    map['start_at'] = Variable<DateTime>(startAt);
    map['end_at'] = Variable<DateTime>(endAt);
    map['all_day'] = Variable<bool>(allDay);
    map['category'] = Variable<String>(category);
    map['color_value'] = Variable<int>(colorValue);
    if (!nullToAbsent || reminderMinutesBefore != null) {
      map['reminder_minutes_before'] = Variable<int>(reminderMinutesBefore);
    }
    map['reminder_minutes_before_list'] = Variable<String>(
      reminderMinutesBeforeList,
    );
    map['recurrence_frequency'] = Variable<String>(recurrenceFrequency);
    map['recurrence_interval'] = Variable<int>(recurrenceInterval);
    if (!nullToAbsent || recurrenceUntil != null) {
      map['recurrence_until'] = Variable<DateTime>(recurrenceUntil);
    }
    if (!nullToAbsent || recurrenceCount != null) {
      map['recurrence_count'] = Variable<int>(recurrenceCount);
    }
    map['recurrence_excluded_dates'] = Variable<String>(
      recurrenceExcludedDates,
    );
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || syncTimestampDetails != null) {
      map['sync_timestamp_details'] = Variable<String>(syncTimestampDetails);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['sync_status'] = Variable<String>(syncStatus);
    map['show_dday'] = Variable<bool>(showDday);
    map['completed'] = Variable<bool>(completed);
    map['alarm_enabled'] = Variable<bool>(alarmEnabled);
    map['all_day_alarm_minutes'] = Variable<int>(allDayAlarmMinutes);
    return map;
  }

  EventRecordsCompanion toCompanion(bool nullToAbsent) {
    return EventRecordsCompanion(
      id: Value(id),
      title: Value(title),
      memo: memo == null && nullToAbsent ? const Value.absent() : Value(memo),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      weather: weather == null && nullToAbsent
          ? const Value.absent()
          : Value(weather),
      startAt: Value(startAt),
      endAt: Value(endAt),
      allDay: Value(allDay),
      category: Value(category),
      colorValue: Value(colorValue),
      reminderMinutesBefore: reminderMinutesBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderMinutesBefore),
      reminderMinutesBeforeList: Value(reminderMinutesBeforeList),
      recurrenceFrequency: Value(recurrenceFrequency),
      recurrenceInterval: Value(recurrenceInterval),
      recurrenceUntil: recurrenceUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceUntil),
      recurrenceCount: recurrenceCount == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceCount),
      recurrenceExcludedDates: Value(recurrenceExcludedDates),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      syncTimestampDetails: syncTimestampDetails == null && nullToAbsent
          ? const Value.absent()
          : Value(syncTimestampDetails),
      deviceId: Value(deviceId),
      syncStatus: Value(syncStatus),
      showDday: Value(showDday),
      completed: Value(completed),
      alarmEnabled: Value(alarmEnabled),
      allDayAlarmMinutes: Value(allDayAlarmMinutes),
    );
  }

  factory EventRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventRecord(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      memo: serializer.fromJson<String?>(json['memo']),
      location: serializer.fromJson<String?>(json['location']),
      url: serializer.fromJson<String?>(json['url']),
      weather: serializer.fromJson<String?>(json['weather']),
      startAt: serializer.fromJson<DateTime>(json['startAt']),
      endAt: serializer.fromJson<DateTime>(json['endAt']),
      allDay: serializer.fromJson<bool>(json['allDay']),
      category: serializer.fromJson<String>(json['category']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      reminderMinutesBefore: serializer.fromJson<int?>(
        json['reminderMinutesBefore'],
      ),
      reminderMinutesBeforeList: serializer.fromJson<String>(
        json['reminderMinutesBeforeList'],
      ),
      recurrenceFrequency: serializer.fromJson<String>(
        json['recurrenceFrequency'],
      ),
      recurrenceInterval: serializer.fromJson<int>(json['recurrenceInterval']),
      recurrenceUntil: serializer.fromJson<DateTime?>(json['recurrenceUntil']),
      recurrenceCount: serializer.fromJson<int?>(json['recurrenceCount']),
      recurrenceExcludedDates: serializer.fromJson<String>(
        json['recurrenceExcludedDates'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      syncTimestampDetails: serializer.fromJson<String?>(
        json['syncTimestampDetails'],
      ),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      showDday: serializer.fromJson<bool>(json['showDday']),
      completed: serializer.fromJson<bool>(json['completed']),
      alarmEnabled: serializer.fromJson<bool>(json['alarmEnabled']),
      allDayAlarmMinutes: serializer.fromJson<int>(json['allDayAlarmMinutes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'memo': serializer.toJson<String?>(memo),
      'location': serializer.toJson<String?>(location),
      'url': serializer.toJson<String?>(url),
      'weather': serializer.toJson<String?>(weather),
      'startAt': serializer.toJson<DateTime>(startAt),
      'endAt': serializer.toJson<DateTime>(endAt),
      'allDay': serializer.toJson<bool>(allDay),
      'category': serializer.toJson<String>(category),
      'colorValue': serializer.toJson<int>(colorValue),
      'reminderMinutesBefore': serializer.toJson<int?>(reminderMinutesBefore),
      'reminderMinutesBeforeList': serializer.toJson<String>(
        reminderMinutesBeforeList,
      ),
      'recurrenceFrequency': serializer.toJson<String>(recurrenceFrequency),
      'recurrenceInterval': serializer.toJson<int>(recurrenceInterval),
      'recurrenceUntil': serializer.toJson<DateTime?>(recurrenceUntil),
      'recurrenceCount': serializer.toJson<int?>(recurrenceCount),
      'recurrenceExcludedDates': serializer.toJson<String>(
        recurrenceExcludedDates,
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'syncTimestampDetails': serializer.toJson<String?>(syncTimestampDetails),
      'deviceId': serializer.toJson<String>(deviceId),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'showDday': serializer.toJson<bool>(showDday),
      'completed': serializer.toJson<bool>(completed),
      'alarmEnabled': serializer.toJson<bool>(alarmEnabled),
      'allDayAlarmMinutes': serializer.toJson<int>(allDayAlarmMinutes),
    };
  }

  EventRecord copyWith({
    String? id,
    String? title,
    Value<String?> memo = const Value.absent(),
    Value<String?> location = const Value.absent(),
    Value<String?> url = const Value.absent(),
    Value<String?> weather = const Value.absent(),
    DateTime? startAt,
    DateTime? endAt,
    bool? allDay,
    String? category,
    int? colorValue,
    Value<int?> reminderMinutesBefore = const Value.absent(),
    String? reminderMinutesBeforeList,
    String? recurrenceFrequency,
    int? recurrenceInterval,
    Value<DateTime?> recurrenceUntil = const Value.absent(),
    Value<int?> recurrenceCount = const Value.absent(),
    String? recurrenceExcludedDates,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<String?> syncTimestampDetails = const Value.absent(),
    String? deviceId,
    String? syncStatus,
    bool? showDday,
    bool? completed,
    bool? alarmEnabled,
    int? allDayAlarmMinutes,
  }) => EventRecord(
    id: id ?? this.id,
    title: title ?? this.title,
    memo: memo.present ? memo.value : this.memo,
    location: location.present ? location.value : this.location,
    url: url.present ? url.value : this.url,
    weather: weather.present ? weather.value : this.weather,
    startAt: startAt ?? this.startAt,
    endAt: endAt ?? this.endAt,
    allDay: allDay ?? this.allDay,
    category: category ?? this.category,
    colorValue: colorValue ?? this.colorValue,
    reminderMinutesBefore: reminderMinutesBefore.present
        ? reminderMinutesBefore.value
        : this.reminderMinutesBefore,
    reminderMinutesBeforeList:
        reminderMinutesBeforeList ?? this.reminderMinutesBeforeList,
    recurrenceFrequency: recurrenceFrequency ?? this.recurrenceFrequency,
    recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
    recurrenceUntil: recurrenceUntil.present
        ? recurrenceUntil.value
        : this.recurrenceUntil,
    recurrenceCount: recurrenceCount.present
        ? recurrenceCount.value
        : this.recurrenceCount,
    recurrenceExcludedDates:
        recurrenceExcludedDates ?? this.recurrenceExcludedDates,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    syncTimestampDetails: syncTimestampDetails.present
        ? syncTimestampDetails.value
        : this.syncTimestampDetails,
    deviceId: deviceId ?? this.deviceId,
    syncStatus: syncStatus ?? this.syncStatus,
    showDday: showDday ?? this.showDday,
    completed: completed ?? this.completed,
    alarmEnabled: alarmEnabled ?? this.alarmEnabled,
    allDayAlarmMinutes: allDayAlarmMinutes ?? this.allDayAlarmMinutes,
  );
  EventRecord copyWithCompanion(EventRecordsCompanion data) {
    return EventRecord(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      memo: data.memo.present ? data.memo.value : this.memo,
      location: data.location.present ? data.location.value : this.location,
      url: data.url.present ? data.url.value : this.url,
      weather: data.weather.present ? data.weather.value : this.weather,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      allDay: data.allDay.present ? data.allDay.value : this.allDay,
      category: data.category.present ? data.category.value : this.category,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      reminderMinutesBefore: data.reminderMinutesBefore.present
          ? data.reminderMinutesBefore.value
          : this.reminderMinutesBefore,
      reminderMinutesBeforeList: data.reminderMinutesBeforeList.present
          ? data.reminderMinutesBeforeList.value
          : this.reminderMinutesBeforeList,
      recurrenceFrequency: data.recurrenceFrequency.present
          ? data.recurrenceFrequency.value
          : this.recurrenceFrequency,
      recurrenceInterval: data.recurrenceInterval.present
          ? data.recurrenceInterval.value
          : this.recurrenceInterval,
      recurrenceUntil: data.recurrenceUntil.present
          ? data.recurrenceUntil.value
          : this.recurrenceUntil,
      recurrenceCount: data.recurrenceCount.present
          ? data.recurrenceCount.value
          : this.recurrenceCount,
      recurrenceExcludedDates: data.recurrenceExcludedDates.present
          ? data.recurrenceExcludedDates.value
          : this.recurrenceExcludedDates,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      syncTimestampDetails: data.syncTimestampDetails.present
          ? data.syncTimestampDetails.value
          : this.syncTimestampDetails,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      showDday: data.showDday.present ? data.showDday.value : this.showDday,
      completed: data.completed.present ? data.completed.value : this.completed,
      alarmEnabled: data.alarmEnabled.present
          ? data.alarmEnabled.value
          : this.alarmEnabled,
      allDayAlarmMinutes: data.allDayAlarmMinutes.present
          ? data.allDayAlarmMinutes.value
          : this.allDayAlarmMinutes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventRecord(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('memo: $memo, ')
          ..write('location: $location, ')
          ..write('url: $url, ')
          ..write('weather: $weather, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('allDay: $allDay, ')
          ..write('category: $category, ')
          ..write('colorValue: $colorValue, ')
          ..write('reminderMinutesBefore: $reminderMinutesBefore, ')
          ..write('reminderMinutesBeforeList: $reminderMinutesBeforeList, ')
          ..write('recurrenceFrequency: $recurrenceFrequency, ')
          ..write('recurrenceInterval: $recurrenceInterval, ')
          ..write('recurrenceUntil: $recurrenceUntil, ')
          ..write('recurrenceCount: $recurrenceCount, ')
          ..write('recurrenceExcludedDates: $recurrenceExcludedDates, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncTimestampDetails: $syncTimestampDetails, ')
          ..write('deviceId: $deviceId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('showDday: $showDday, ')
          ..write('completed: $completed, ')
          ..write('alarmEnabled: $alarmEnabled, ')
          ..write('allDayAlarmMinutes: $allDayAlarmMinutes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    memo,
    location,
    url,
    weather,
    startAt,
    endAt,
    allDay,
    category,
    colorValue,
    reminderMinutesBefore,
    reminderMinutesBeforeList,
    recurrenceFrequency,
    recurrenceInterval,
    recurrenceUntil,
    recurrenceCount,
    recurrenceExcludedDates,
    createdAt,
    updatedAt,
    deletedAt,
    syncTimestampDetails,
    deviceId,
    syncStatus,
    showDday,
    completed,
    alarmEnabled,
    allDayAlarmMinutes,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventRecord &&
          other.id == this.id &&
          other.title == this.title &&
          other.memo == this.memo &&
          other.location == this.location &&
          other.url == this.url &&
          other.weather == this.weather &&
          other.startAt == this.startAt &&
          other.endAt == this.endAt &&
          other.allDay == this.allDay &&
          other.category == this.category &&
          other.colorValue == this.colorValue &&
          other.reminderMinutesBefore == this.reminderMinutesBefore &&
          other.reminderMinutesBeforeList == this.reminderMinutesBeforeList &&
          other.recurrenceFrequency == this.recurrenceFrequency &&
          other.recurrenceInterval == this.recurrenceInterval &&
          other.recurrenceUntil == this.recurrenceUntil &&
          other.recurrenceCount == this.recurrenceCount &&
          other.recurrenceExcludedDates == this.recurrenceExcludedDates &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.syncTimestampDetails == this.syncTimestampDetails &&
          other.deviceId == this.deviceId &&
          other.syncStatus == this.syncStatus &&
          other.showDday == this.showDday &&
          other.completed == this.completed &&
          other.alarmEnabled == this.alarmEnabled &&
          other.allDayAlarmMinutes == this.allDayAlarmMinutes);
}

class EventRecordsCompanion extends UpdateCompanion<EventRecord> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> memo;
  final Value<String?> location;
  final Value<String?> url;
  final Value<String?> weather;
  final Value<DateTime> startAt;
  final Value<DateTime> endAt;
  final Value<bool> allDay;
  final Value<String> category;
  final Value<int> colorValue;
  final Value<int?> reminderMinutesBefore;
  final Value<String> reminderMinutesBeforeList;
  final Value<String> recurrenceFrequency;
  final Value<int> recurrenceInterval;
  final Value<DateTime?> recurrenceUntil;
  final Value<int?> recurrenceCount;
  final Value<String> recurrenceExcludedDates;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> syncTimestampDetails;
  final Value<String> deviceId;
  final Value<String> syncStatus;
  final Value<bool> showDday;
  final Value<bool> completed;
  final Value<bool> alarmEnabled;
  final Value<int> allDayAlarmMinutes;
  final Value<int> rowid;
  const EventRecordsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.memo = const Value.absent(),
    this.location = const Value.absent(),
    this.url = const Value.absent(),
    this.weather = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.allDay = const Value.absent(),
    this.category = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.reminderMinutesBefore = const Value.absent(),
    this.reminderMinutesBeforeList = const Value.absent(),
    this.recurrenceFrequency = const Value.absent(),
    this.recurrenceInterval = const Value.absent(),
    this.recurrenceUntil = const Value.absent(),
    this.recurrenceCount = const Value.absent(),
    this.recurrenceExcludedDates = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.syncTimestampDetails = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.showDday = const Value.absent(),
    this.completed = const Value.absent(),
    this.alarmEnabled = const Value.absent(),
    this.allDayAlarmMinutes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventRecordsCompanion.insert({
    required String id,
    required String title,
    this.memo = const Value.absent(),
    this.location = const Value.absent(),
    this.url = const Value.absent(),
    this.weather = const Value.absent(),
    required DateTime startAt,
    required DateTime endAt,
    this.allDay = const Value.absent(),
    this.category = const Value.absent(),
    required int colorValue,
    this.reminderMinutesBefore = const Value.absent(),
    this.reminderMinutesBeforeList = const Value.absent(),
    this.recurrenceFrequency = const Value.absent(),
    this.recurrenceInterval = const Value.absent(),
    this.recurrenceUntil = const Value.absent(),
    this.recurrenceCount = const Value.absent(),
    this.recurrenceExcludedDates = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.syncTimestampDetails = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.showDday = const Value.absent(),
    this.completed = const Value.absent(),
    this.alarmEnabled = const Value.absent(),
    this.allDayAlarmMinutes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       startAt = Value(startAt),
       endAt = Value(endAt),
       colorValue = Value(colorValue),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<EventRecord> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? memo,
    Expression<String>? location,
    Expression<String>? url,
    Expression<String>? weather,
    Expression<DateTime>? startAt,
    Expression<DateTime>? endAt,
    Expression<bool>? allDay,
    Expression<String>? category,
    Expression<int>? colorValue,
    Expression<int>? reminderMinutesBefore,
    Expression<String>? reminderMinutesBeforeList,
    Expression<String>? recurrenceFrequency,
    Expression<int>? recurrenceInterval,
    Expression<DateTime>? recurrenceUntil,
    Expression<int>? recurrenceCount,
    Expression<String>? recurrenceExcludedDates,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? syncTimestampDetails,
    Expression<String>? deviceId,
    Expression<String>? syncStatus,
    Expression<bool>? showDday,
    Expression<bool>? completed,
    Expression<bool>? alarmEnabled,
    Expression<int>? allDayAlarmMinutes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (memo != null) 'memo': memo,
      if (location != null) 'location': location,
      if (url != null) 'url': url,
      if (weather != null) 'weather': weather,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (allDay != null) 'all_day': allDay,
      if (category != null) 'category': category,
      if (colorValue != null) 'color_value': colorValue,
      if (reminderMinutesBefore != null)
        'reminder_minutes_before': reminderMinutesBefore,
      if (reminderMinutesBeforeList != null)
        'reminder_minutes_before_list': reminderMinutesBeforeList,
      if (recurrenceFrequency != null)
        'recurrence_frequency': recurrenceFrequency,
      if (recurrenceInterval != null) 'recurrence_interval': recurrenceInterval,
      if (recurrenceUntil != null) 'recurrence_until': recurrenceUntil,
      if (recurrenceCount != null) 'recurrence_count': recurrenceCount,
      if (recurrenceExcludedDates != null)
        'recurrence_excluded_dates': recurrenceExcludedDates,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (syncTimestampDetails != null)
        'sync_timestamp_details': syncTimestampDetails,
      if (deviceId != null) 'device_id': deviceId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (showDday != null) 'show_dday': showDday,
      if (completed != null) 'completed': completed,
      if (alarmEnabled != null) 'alarm_enabled': alarmEnabled,
      if (allDayAlarmMinutes != null)
        'all_day_alarm_minutes': allDayAlarmMinutes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? memo,
    Value<String?>? location,
    Value<String?>? url,
    Value<String?>? weather,
    Value<DateTime>? startAt,
    Value<DateTime>? endAt,
    Value<bool>? allDay,
    Value<String>? category,
    Value<int>? colorValue,
    Value<int?>? reminderMinutesBefore,
    Value<String>? reminderMinutesBeforeList,
    Value<String>? recurrenceFrequency,
    Value<int>? recurrenceInterval,
    Value<DateTime?>? recurrenceUntil,
    Value<int?>? recurrenceCount,
    Value<String>? recurrenceExcludedDates,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String?>? syncTimestampDetails,
    Value<String>? deviceId,
    Value<String>? syncStatus,
    Value<bool>? showDday,
    Value<bool>? completed,
    Value<bool>? alarmEnabled,
    Value<int>? allDayAlarmMinutes,
    Value<int>? rowid,
  }) {
    return EventRecordsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      memo: memo ?? this.memo,
      location: location ?? this.location,
      url: url ?? this.url,
      weather: weather ?? this.weather,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      allDay: allDay ?? this.allDay,
      category: category ?? this.category,
      colorValue: colorValue ?? this.colorValue,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      reminderMinutesBeforeList:
          reminderMinutesBeforeList ?? this.reminderMinutesBeforeList,
      recurrenceFrequency: recurrenceFrequency ?? this.recurrenceFrequency,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceUntil: recurrenceUntil ?? this.recurrenceUntil,
      recurrenceCount: recurrenceCount ?? this.recurrenceCount,
      recurrenceExcludedDates:
          recurrenceExcludedDates ?? this.recurrenceExcludedDates,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncTimestampDetails: syncTimestampDetails ?? this.syncTimestampDetails,
      deviceId: deviceId ?? this.deviceId,
      syncStatus: syncStatus ?? this.syncStatus,
      showDday: showDday ?? this.showDday,
      completed: completed ?? this.completed,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      allDayAlarmMinutes: allDayAlarmMinutes ?? this.allDayAlarmMinutes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (weather.present) {
      map['weather'] = Variable<String>(weather.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<DateTime>(endAt.value);
    }
    if (allDay.present) {
      map['all_day'] = Variable<bool>(allDay.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (reminderMinutesBefore.present) {
      map['reminder_minutes_before'] = Variable<int>(
        reminderMinutesBefore.value,
      );
    }
    if (reminderMinutesBeforeList.present) {
      map['reminder_minutes_before_list'] = Variable<String>(
        reminderMinutesBeforeList.value,
      );
    }
    if (recurrenceFrequency.present) {
      map['recurrence_frequency'] = Variable<String>(recurrenceFrequency.value);
    }
    if (recurrenceInterval.present) {
      map['recurrence_interval'] = Variable<int>(recurrenceInterval.value);
    }
    if (recurrenceUntil.present) {
      map['recurrence_until'] = Variable<DateTime>(recurrenceUntil.value);
    }
    if (recurrenceCount.present) {
      map['recurrence_count'] = Variable<int>(recurrenceCount.value);
    }
    if (recurrenceExcludedDates.present) {
      map['recurrence_excluded_dates'] = Variable<String>(
        recurrenceExcludedDates.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (syncTimestampDetails.present) {
      map['sync_timestamp_details'] = Variable<String>(
        syncTimestampDetails.value,
      );
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (showDday.present) {
      map['show_dday'] = Variable<bool>(showDday.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (alarmEnabled.present) {
      map['alarm_enabled'] = Variable<bool>(alarmEnabled.value);
    }
    if (allDayAlarmMinutes.present) {
      map['all_day_alarm_minutes'] = Variable<int>(allDayAlarmMinutes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventRecordsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('memo: $memo, ')
          ..write('location: $location, ')
          ..write('url: $url, ')
          ..write('weather: $weather, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('allDay: $allDay, ')
          ..write('category: $category, ')
          ..write('colorValue: $colorValue, ')
          ..write('reminderMinutesBefore: $reminderMinutesBefore, ')
          ..write('reminderMinutesBeforeList: $reminderMinutesBeforeList, ')
          ..write('recurrenceFrequency: $recurrenceFrequency, ')
          ..write('recurrenceInterval: $recurrenceInterval, ')
          ..write('recurrenceUntil: $recurrenceUntil, ')
          ..write('recurrenceCount: $recurrenceCount, ')
          ..write('recurrenceExcludedDates: $recurrenceExcludedDates, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('syncTimestampDetails: $syncTimestampDetails, ')
          ..write('deviceId: $deviceId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('showDday: $showDday, ')
          ..write('completed: $completed, ')
          ..write('alarmEnabled: $alarmEnabled, ')
          ..write('allDayAlarmMinutes: $allDayAlarmMinutes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EventRecordsTable eventRecords = $EventRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [eventRecords];
}

typedef $$EventRecordsTableCreateCompanionBuilder =
    EventRecordsCompanion Function({
      required String id,
      required String title,
      Value<String?> memo,
      Value<String?> location,
      Value<String?> url,
      Value<String?> weather,
      required DateTime startAt,
      required DateTime endAt,
      Value<bool> allDay,
      Value<String> category,
      required int colorValue,
      Value<int?> reminderMinutesBefore,
      Value<String> reminderMinutesBeforeList,
      Value<String> recurrenceFrequency,
      Value<int> recurrenceInterval,
      Value<DateTime?> recurrenceUntil,
      Value<int?> recurrenceCount,
      Value<String> recurrenceExcludedDates,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<String?> syncTimestampDetails,
      Value<String> deviceId,
      Value<String> syncStatus,
      Value<bool> showDday,
      Value<bool> completed,
      Value<bool> alarmEnabled,
      Value<int> allDayAlarmMinutes,
      Value<int> rowid,
    });
typedef $$EventRecordsTableUpdateCompanionBuilder =
    EventRecordsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> memo,
      Value<String?> location,
      Value<String?> url,
      Value<String?> weather,
      Value<DateTime> startAt,
      Value<DateTime> endAt,
      Value<bool> allDay,
      Value<String> category,
      Value<int> colorValue,
      Value<int?> reminderMinutesBefore,
      Value<String> reminderMinutesBeforeList,
      Value<String> recurrenceFrequency,
      Value<int> recurrenceInterval,
      Value<DateTime?> recurrenceUntil,
      Value<int?> recurrenceCount,
      Value<String> recurrenceExcludedDates,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String?> syncTimestampDetails,
      Value<String> deviceId,
      Value<String> syncStatus,
      Value<bool> showDday,
      Value<bool> completed,
      Value<bool> alarmEnabled,
      Value<int> allDayAlarmMinutes,
      Value<int> rowid,
    });

class $$EventRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $EventRecordsTable> {
  $$EventRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weather => $composableBuilder(
    column: $table.weather,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinutesBefore => $composableBuilder(
    column: $table.reminderMinutesBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderMinutesBeforeList => $composableBuilder(
    column: $table.reminderMinutesBeforeList,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceFrequency => $composableBuilder(
    column: $table.recurrenceFrequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recurrenceInterval => $composableBuilder(
    column: $table.recurrenceInterval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recurrenceUntil => $composableBuilder(
    column: $table.recurrenceUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recurrenceCount => $composableBuilder(
    column: $table.recurrenceCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceExcludedDates => $composableBuilder(
    column: $table.recurrenceExcludedDates,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncTimestampDetails => $composableBuilder(
    column: $table.syncTimestampDetails,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showDday => $composableBuilder(
    column: $table.showDday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get alarmEnabled => $composableBuilder(
    column: $table.alarmEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get allDayAlarmMinutes => $composableBuilder(
    column: $table.allDayAlarmMinutes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $EventRecordsTable> {
  $$EventRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weather => $composableBuilder(
    column: $table.weather,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinutesBefore => $composableBuilder(
    column: $table.reminderMinutesBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderMinutesBeforeList => $composableBuilder(
    column: $table.reminderMinutesBeforeList,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceFrequency => $composableBuilder(
    column: $table.recurrenceFrequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recurrenceInterval => $composableBuilder(
    column: $table.recurrenceInterval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recurrenceUntil => $composableBuilder(
    column: $table.recurrenceUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recurrenceCount => $composableBuilder(
    column: $table.recurrenceCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceExcludedDates => $composableBuilder(
    column: $table.recurrenceExcludedDates,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncTimestampDetails => $composableBuilder(
    column: $table.syncTimestampDetails,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showDday => $composableBuilder(
    column: $table.showDday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get alarmEnabled => $composableBuilder(
    column: $table.alarmEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get allDayAlarmMinutes => $composableBuilder(
    column: $table.allDayAlarmMinutes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventRecordsTable> {
  $$EventRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get weather =>
      $composableBuilder(column: $table.weather, builder: (column) => column);

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<bool> get allDay =>
      $composableBuilder(column: $table.allDay, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderMinutesBefore => $composableBuilder(
    column: $table.reminderMinutesBefore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reminderMinutesBeforeList => $composableBuilder(
    column: $table.reminderMinutesBeforeList,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceFrequency => $composableBuilder(
    column: $table.recurrenceFrequency,
    builder: (column) => column,
  );

  GeneratedColumn<int> get recurrenceInterval => $composableBuilder(
    column: $table.recurrenceInterval,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get recurrenceUntil => $composableBuilder(
    column: $table.recurrenceUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get recurrenceCount => $composableBuilder(
    column: $table.recurrenceCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceExcludedDates => $composableBuilder(
    column: $table.recurrenceExcludedDates,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get syncTimestampDetails => $composableBuilder(
    column: $table.syncTimestampDetails,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showDday =>
      $composableBuilder(column: $table.showDday, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<bool> get alarmEnabled => $composableBuilder(
    column: $table.alarmEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get allDayAlarmMinutes => $composableBuilder(
    column: $table.allDayAlarmMinutes,
    builder: (column) => column,
  );
}

class $$EventRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventRecordsTable,
          EventRecord,
          $$EventRecordsTableFilterComposer,
          $$EventRecordsTableOrderingComposer,
          $$EventRecordsTableAnnotationComposer,
          $$EventRecordsTableCreateCompanionBuilder,
          $$EventRecordsTableUpdateCompanionBuilder,
          (
            EventRecord,
            BaseReferences<_$AppDatabase, $EventRecordsTable, EventRecord>,
          ),
          EventRecord,
          PrefetchHooks Function()
        > {
  $$EventRecordsTableTableManager(_$AppDatabase db, $EventRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> memo = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> weather = const Value.absent(),
                Value<DateTime> startAt = const Value.absent(),
                Value<DateTime> endAt = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<int?> reminderMinutesBefore = const Value.absent(),
                Value<String> reminderMinutesBeforeList = const Value.absent(),
                Value<String> recurrenceFrequency = const Value.absent(),
                Value<int> recurrenceInterval = const Value.absent(),
                Value<DateTime?> recurrenceUntil = const Value.absent(),
                Value<int?> recurrenceCount = const Value.absent(),
                Value<String> recurrenceExcludedDates = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> syncTimestampDetails = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<bool> showDday = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<bool> alarmEnabled = const Value.absent(),
                Value<int> allDayAlarmMinutes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventRecordsCompanion(
                id: id,
                title: title,
                memo: memo,
                location: location,
                url: url,
                weather: weather,
                startAt: startAt,
                endAt: endAt,
                allDay: allDay,
                category: category,
                colorValue: colorValue,
                reminderMinutesBefore: reminderMinutesBefore,
                reminderMinutesBeforeList: reminderMinutesBeforeList,
                recurrenceFrequency: recurrenceFrequency,
                recurrenceInterval: recurrenceInterval,
                recurrenceUntil: recurrenceUntil,
                recurrenceCount: recurrenceCount,
                recurrenceExcludedDates: recurrenceExcludedDates,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                syncTimestampDetails: syncTimestampDetails,
                deviceId: deviceId,
                syncStatus: syncStatus,
                showDday: showDday,
                completed: completed,
                alarmEnabled: alarmEnabled,
                allDayAlarmMinutes: allDayAlarmMinutes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> memo = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> weather = const Value.absent(),
                required DateTime startAt,
                required DateTime endAt,
                Value<bool> allDay = const Value.absent(),
                Value<String> category = const Value.absent(),
                required int colorValue,
                Value<int?> reminderMinutesBefore = const Value.absent(),
                Value<String> reminderMinutesBeforeList = const Value.absent(),
                Value<String> recurrenceFrequency = const Value.absent(),
                Value<int> recurrenceInterval = const Value.absent(),
                Value<DateTime?> recurrenceUntil = const Value.absent(),
                Value<int?> recurrenceCount = const Value.absent(),
                Value<String> recurrenceExcludedDates = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> syncTimestampDetails = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<bool> showDday = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<bool> alarmEnabled = const Value.absent(),
                Value<int> allDayAlarmMinutes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventRecordsCompanion.insert(
                id: id,
                title: title,
                memo: memo,
                location: location,
                url: url,
                weather: weather,
                startAt: startAt,
                endAt: endAt,
                allDay: allDay,
                category: category,
                colorValue: colorValue,
                reminderMinutesBefore: reminderMinutesBefore,
                reminderMinutesBeforeList: reminderMinutesBeforeList,
                recurrenceFrequency: recurrenceFrequency,
                recurrenceInterval: recurrenceInterval,
                recurrenceUntil: recurrenceUntil,
                recurrenceCount: recurrenceCount,
                recurrenceExcludedDates: recurrenceExcludedDates,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                syncTimestampDetails: syncTimestampDetails,
                deviceId: deviceId,
                syncStatus: syncStatus,
                showDday: showDday,
                completed: completed,
                alarmEnabled: alarmEnabled,
                allDayAlarmMinutes: allDayAlarmMinutes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventRecordsTable,
      EventRecord,
      $$EventRecordsTableFilterComposer,
      $$EventRecordsTableOrderingComposer,
      $$EventRecordsTableAnnotationComposer,
      $$EventRecordsTableCreateCompanionBuilder,
      $$EventRecordsTableUpdateCompanionBuilder,
      (
        EventRecord,
        BaseReferences<_$AppDatabase, $EventRecordsTable, EventRecord>,
      ),
      EventRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EventRecordsTableTableManager get eventRecords =>
      $$EventRecordsTableTableManager(_db, _db.eventRecords);
}
