import 'package:flutter/widgets.dart' show StringCharacters;

/// A dateless reminder ("잊모기"). It is never projected into calendar events.
class ImogiItem {
  const ImogiItem({
    required this.id,
    required this.title,
    this.note,
    this.important = false,
    required this.createdAt,
    this.completedAt,
  });

  static const maxTitleLength = 200;
  static const maxNoteLength = 2000;

  final String id;
  final String title;
  final String? note;
  final bool important;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get completed => completedAt != null;

  bool get isValid =>
      id.isNotEmpty &&
      title.trim().isNotEmpty &&
      title == title.trim() &&
      title.characters.length <= maxTitleLength &&
      (note == null ||
          (note!.trim().isNotEmpty &&
              note!.characters.length <= maxNoteLength));

  ImogiItem copyWith({
    String? title,
    String? note,
    bool clearNote = false,
    bool? important,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) => ImogiItem(
    id: id,
    title: title ?? this.title,
    note: clearNote ? null : note ?? this.note,
    important: important ?? this.important,
    createdAt: createdAt,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'important': important,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'completedAt': completedAt?.toUtc().toIso8601String(),
  };

  factory ImogiItem.fromJson(Map<String, dynamic> json) {
    DateTime? date(Object? raw) {
      if (raw == null) return null;
      final parsed = raw is String ? DateTime.tryParse(raw) : null;
      if (parsed == null || !parsed.isUtc) {
        throw const FormatException('Invalid imogi date');
      }
      return parsed;
    }

    final item = ImogiItem(
      id: json['id'] as String,
      title: json['title'] as String,
      note: json['note'] as String?,
      important: json['important'] as bool,
      createdAt: date(json['createdAt'])!,
      completedAt: date(json['completedAt']),
    );
    if (!item.isValid) throw const FormatException('Invalid imogi item');
    return item;
  }
}

/// Open items first by importance, then newest first; completed newest first.
int compareImogiItems(ImogiItem a, ImogiItem b) {
  if (a.completed != b.completed) return a.completed ? 1 : -1;
  if (a.completed) {
    final done = b.completedAt!.compareTo(a.completedAt!);
    if (done != 0) return done;
  } else if (a.important != b.important) {
    return a.important ? -1 : 1;
  }
  final created = b.createdAt.compareTo(a.createdAt);
  return created != 0 ? created : a.id.compareTo(b.id);
}

/// The tab badge text: hidden at zero and capped at `99+`.
String? imogiBadgeLabel(int openCount) => openCount <= 0
    ? null
    : openCount > 99
    ? '99+'
    : '$openCount';
