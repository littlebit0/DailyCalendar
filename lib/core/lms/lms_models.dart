import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Browser response location is retained so relative LMS links resolve safely.
class LmsHtmlPage {
  const LmsHtmlPage({required this.url, required this.html});

  final Uri url;
  final String html;
}

String normalizeLmsOwner(String owner) => owner.trim().toLowerCase();

/// Source data only. Fetch timestamps and credentials belong to the connection,
/// and a server submission status never changes Daily's personal completion.
class LmsEventMetadata {
  LmsEventMetadata({
    this.provider = 'coursemos',
    required this.schoolId,
    required String ownerId,
    required this.lmsUserId,
    required this.courseId,
    required this.courseTitle,
    required this.activityType,
    required this.activityId,
    required this.sourceUrl,
    DateTime? openAt,
    DateTime? dueAt,
    this.submissionStatus,
    this.progressPercent,
  }) : ownerId = normalizeLmsOwner(ownerId),
       openAt = openAt?.toUtc(),
       dueAt = dueAt?.toUtc() {
    if ([
      provider,
      schoolId,
      this.ownerId,
      lmsUserId,
      courseId,
      activityId,
    ].any((value) => value.trim().isEmpty)) {
      throw const FormatException('Missing LMS source identity');
    }
    if (!const {
      'assignment',
      'quiz',
      'lecture',
      'calendar',
    }.contains(activityType)) {
      throw const FormatException('Invalid LMS activity type');
    }
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Invalid LMS source URL');
    }
    if (progressPercent != null &&
        (!progressPercent!.isFinite ||
            progressPercent! < 0 ||
            progressPercent! > 100)) {
      throw const FormatException('Invalid LMS progress');
    }
  }

  final String provider;
  final String schoolId;
  final String ownerId;
  final String lmsUserId;
  final String courseId;
  final String courseTitle;
  final String activityType;
  final String activityId;
  final String sourceUrl;
  final DateTime? openAt;
  final DateTime? dueAt;
  final String? submissionStatus;
  final double? progressPercent;

  bool belongsToOwner(String? owner) =>
      owner != null && normalizeLmsOwner(owner) == ownerId;

  Map<String, Object?> toJson() => {
    'provider': provider,
    'schoolId': schoolId,
    'ownerId': ownerId,
    'lmsUserId': lmsUserId,
    'courseId': courseId,
    'courseTitle': courseTitle,
    'activityType': activityType,
    'activityId': activityId,
    'sourceUrl': sourceUrl,
    'openAt': openAt?.toIso8601String(),
    'dueAt': dueAt?.toIso8601String(),
    'submissionStatus': submissionStatus,
    'progressPercent': progressPercent,
  };

  factory LmsEventMetadata.fromJson(Map<String, Object?> json) {
    String string(String key) {
      final value = json[key];
      if (value is! String) throw FormatException('Invalid LMS $key');
      return value;
    }

    DateTime? date(String key) {
      final value = json[key];
      if (value == null) return null;
      final parsed = value is String ? DateTime.tryParse(value) : null;
      if (parsed == null) throw FormatException('Invalid LMS $key');
      return parsed.toUtc();
    }

    final progress = json['progressPercent'];
    final status = json['submissionStatus'];
    if (progress != null && progress is! num ||
        status != null && status is! String) {
      throw const FormatException('Invalid LMS activity state');
    }
    return LmsEventMetadata(
      provider: string('provider'),
      schoolId: string('schoolId'),
      ownerId: string('ownerId'),
      lmsUserId: string('lmsUserId'),
      courseId: string('courseId'),
      courseTitle: string('courseTitle'),
      activityType: string('activityType'),
      activityId: string('activityId'),
      sourceUrl: string('sourceUrl'),
      openAt: date('openAt'),
      dueAt: date('dueAt'),
      submissionStatus: status as String?,
      progressPercent: (progress as num?)?.toDouble(),
    );
  }

  LmsEventMetadata copyWith({
    String? provider,
    String? schoolId,
    String? ownerId,
    String? lmsUserId,
    String? courseId,
    String? courseTitle,
    String? activityType,
    String? activityId,
    String? sourceUrl,
    DateTime? openAt,
    DateTime? dueAt,
    String? submissionStatus,
    double? progressPercent,
    bool clearOpenAt = false,
    bool clearDueAt = false,
    bool clearSubmissionStatus = false,
    bool clearProgressPercent = false,
  }) => LmsEventMetadata(
    provider: provider ?? this.provider,
    schoolId: schoolId ?? this.schoolId,
    ownerId: ownerId ?? this.ownerId,
    lmsUserId: lmsUserId ?? this.lmsUserId,
    courseId: courseId ?? this.courseId,
    courseTitle: courseTitle ?? this.courseTitle,
    activityType: activityType ?? this.activityType,
    activityId: activityId ?? this.activityId,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    openAt: clearOpenAt ? null : openAt ?? this.openAt,
    dueAt: clearDueAt ? null : dueAt ?? this.dueAt,
    submissionStatus: clearSubmissionStatus
        ? null
        : submissionStatus ?? this.submissionStatus,
    progressPercent: clearProgressPercent
        ? null
        : progressPercent ?? this.progressPercent,
  );

  String get fingerprint =>
      sha256.convert(utf8.encode(jsonEncode(toJson()))).toString();

  @override
  bool operator ==(Object other) =>
      other is LmsEventMetadata && fingerprint == other.fingerprint;

  @override
  int get hashCode => fingerprint.hashCode;
}
