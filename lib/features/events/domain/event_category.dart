class EventCategory {
  const EventCategory({
    required this.id,
    required this.label,
    required this.colorValue,
    this.locked = false,
    this.keywords = const [],
  });

  final String id;
  final String label;
  final int colorValue;
  final bool locked;
  final List<String> keywords;

  String get name => id;

  static const basic = EventCategory(
    id: 'basic',
    label: '기본',
    colorValue: 0xff2563eb,
    keywords: ['일정', '약속', '회의', '미팅', '업무', '개인', '병원', '이동', '여행', '마감'],
  );

  static const holiday = EventCategory(
    id: 'holiday',
    label: '공휴일',
    colorValue: 0xffef4444,
    locked: true,
  );

  static const values = <EventCategory>[basic, holiday];

  // Backward-compatible aliases for old saved data and tests. They are no
  // longer shown as default categories.
  static const other = basic;
  static const health = basic;
  static const work = basic;
  static const appointment = basic;
  static const family = basic;
  static const personal = basic;
  static const travel = basic;
  static const deadline = basic;

  EventCategory copyWith({
    String? id,
    String? label,
    int? colorValue,
    bool? locked,
    List<String>? keywords,
  }) {
    return EventCategory(
      id: id ?? this.id,
      label: label ?? this.label,
      colorValue: colorValue ?? this.colorValue,
      locked: locked ?? this.locked,
      keywords: keywords ?? this.keywords,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'label': label,
      'colorValue': colorValue,
      'locked': locked,
    };
  }

  static EventCategory fromJson(Map<String, Object?> json) {
    final id = json['id'] as String? ?? '';
    if (id == holiday.id) {
      return holiday.copyWith(
        colorValue: json['colorValue'] as int? ?? holiday.colorValue,
        locked: true,
      );
    }
    if (id == basic.id) {
      return basic.copyWith(
        label: json['label'] as String? ?? basic.label,
        colorValue: json['colorValue'] as int? ?? basic.colorValue,
        locked: json['locked'] as bool? ?? basic.locked,
      );
    }
    final label = (json['label'] as String? ?? '분류').trim();
    return EventCategory(
      id: id.isEmpty ? _customId(label) : id,
      label: label.isEmpty ? '분류' : label,
      colorValue: json['colorValue'] as int? ?? basic.colorValue,
      locked: json['locked'] as bool? ?? false,
    );
  }

  static EventCategory fromName(String? name) {
    return fromStored(name);
  }

  static EventCategory fromStored(String? value, {int? colorValue}) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return basic;
    }
    if (normalized == holiday.id || normalized == holiday.label) {
      return holiday.copyWith(colorValue: colorValue ?? holiday.colorValue);
    }
    if (normalized == basic.id || normalized == basic.label) {
      return basic;
    }

    // Old default categories and old enum names collapse into the new default.
    const legacyBasicNames = {
      'other',
      'health',
      'work',
      'appointment',
      'family',
      'personal',
      'travel',
      'deadline',
    };
    if (legacyBasicNames.contains(normalized)) {
      return basic;
    }

    final looksLikeGeneratedId = normalized.startsWith('custom_');
    return EventCategory(
      id: looksLikeGeneratedId ? normalized : _customId(normalized),
      label: looksLikeGeneratedId ? '분류' : normalized,
      colorValue: colorValue ?? basic.colorValue,
    );
  }

  static EventCategory classify(String input) {
    final normalized = input.toLowerCase();
    if (basic.keywords.any(normalized.contains)) {
      return basic;
    }
    return basic;
  }

  /// [existing] holds the other categories already saved. When the hashed id
  /// is held by a category with a different name, a numbered suffix is added
  /// so that category is not silently replaced. A same-name category keeps
  /// sharing its id, and ids already saved are never regenerated.
  static EventCategory custom({
    required String label,
    required int colorValue,
    Iterable<EventCategory> existing = const [],
  }) {
    final name = label.trim().toLowerCase();
    final baseId = _customId(label);
    // Reuse a same-name category anywhere in this hash's id chain first, so a
    // freed lower slot does not split one name across two ids.
    final sameName = existing.where(
      (category) =>
          (category.id == baseId || category.id.startsWith('${baseId}_')) &&
          category.label.trim().toLowerCase() == name,
    );
    if (sameName.isNotEmpty) {
      return EventCategory(
        id: sameName.first.id,
        label: label.trim(),
        colorValue: colorValue,
      );
    }
    var id = baseId;
    for (var suffix = 2; existing.any((c) => c.id == id); suffix++) {
      id = '${baseId}_$suffix';
    }
    return EventCategory(id: id, label: label.trim(), colorValue: colorValue);
  }

  static String _customId(String value) {
    final normalized = value.trim().toLowerCase();
    final code = normalized.codeUnits.fold<int>(
      17,
      (hash, code) => (hash * 31 + code) & 0x7fffffff,
    );
    return 'custom_$code';
  }

  @override
  bool operator ==(Object other) {
    return other is EventCategory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
