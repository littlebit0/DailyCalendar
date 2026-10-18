import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class BugReportEnvironment {
  const BugReportEnvironment({
    required this.version,
    required this.buildNumber,
    required this.platform,
    required this.osVersion,
  });

  final String version;
  final String buildNumber;
  final String platform;
  final String osVersion;

  Map<String, String> toJson() => {
    'version': version,
    'buildNumber': buildNumber,
    'platform': platform,
    'osVersion': osVersion,
  };
}

class BugReportDraft {
  const BugReportDraft({
    required this.title,
    required this.description,
    required this.reproductionSteps,
    required this.expectedBehavior,
    required this.actualBehavior,
  });

  final String title;
  final String description;
  final String reproductionSteps;
  final String expectedBehavior;
  final String actualBehavior;

  Map<String, String> toJson() => {
    'title': title.trim(),
    'description': description.trim(),
    'reproductionSteps': reproductionSteps.trim(),
    'expectedBehavior': expectedBehavior.trim(),
    'actualBehavior': actualBehavior.trim(),
  };
}

/// Room kept for the environment block and the JSON wrapper when checking
/// whether report text can still be sent. The real body is checked again
/// before sending.
const bugReportEnvironmentAllowanceBytes = 4 * 1024;

/// Whether [draft], encoded the way it is sent, fits the receiver's request
/// limit. Counts UTF-8 bytes of the JSON, so a character made of many code
/// points (such as a family emoji) costs what it really costs, unlike the
/// text field's own character-based `maxLength`.
bool bugReportDraftFits(BugReportDraft draft) {
  final bytes = utf8.encode(jsonEncode({'report': draft.toJson()})).length;
  return bytes + bugReportEnvironmentAllowanceBytes <= bugReportMaxRequestBytes;
}

class BugReportSubmission {
  const BugReportSubmission({
    required this.issueNumber,
    required this.issueUrl,
  });

  final int issueNumber;
  final Uri issueUrl;
}

class BugReportException implements Exception {
  const BugReportException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// What the receiver accepts for one request (UTF-8 bytes of the JSON body).
const bugReportMaxRequestBytes = 64 * 1024;

class BugReportService {
  BugReportService({http.Client? httpClient, Uri? endpoint})
    : _httpClient = httpClient ?? http.Client(),
      _ownsHttpClient = httpClient == null,
      _endpoint = endpoint ?? _configuredEndpoint;

  static final Uri _configuredEndpoint = Uri.parse(
    const String.fromEnvironment(
      'DAILY_BUG_REPORT_ENDPOINT',
      defaultValue: 'https://littlebit.tail6514a4.ts.net/v1/bug-reports',
    ),
  );

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Uri _endpoint;

  /// One request ID per logical report, so a retry after a lost answer cannot
  /// create a second issue. Cleared on success; a different report gets a new ID.
  final Map<String, String> _requestIds = {};

  String _requestIdFor(BugReportDraft draft, BugReportEnvironment environment) {
    final fingerprint = sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'report': draft.toJson(),
              'environment': environment.toJson(),
            }),
          ),
        )
        .toString();
    if (_requestIds.length >= 8 && !_requestIds.containsKey(fingerprint)) {
      _requestIds.remove(_requestIds.keys.first);
    }
    return _requestIds.putIfAbsent(fingerprint, () => const Uuid().v4());
  }

  Future<BugReportSubmission> submit({
    required BugReportDraft draft,
    required BugReportEnvironment environment,
    required Map<String, String> googleAuthorizationHeaders,
  }) async {
    final authorization =
        googleAuthorizationHeaders['Authorization'] ??
        googleAuthorizationHeaders['authorization'];
    if (authorization == null || !authorization.startsWith('Bearer ')) {
      throw const BugReportException(
        'google_auth_required',
        'Google 로그인 정보를 확인할 수 없습니다.',
      );
    }

    final requestBody = jsonEncode({
      'report': draft.toJson(),
      'environment': environment.toJson(),
    });
    // Too large for the receiver: say so before sending; the text is kept.
    if (utf8.encode(requestBody).length > bugReportMaxRequestBytes) {
      throw const BugReportException(
        'invalid_size',
        '제보 내용이 너무 깁니다. 내용을 줄여 다시 시도해 주세요.',
      );
    }
    final requestId = _requestIdFor(draft, environment);
    late final http.Response response;
    try {
      response = await _httpClient
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': authorization,
              // A header, so an older receiver that validates the body keys still accepts it.
              'Idempotency-Key': requestId,
            },
            body: requestBody,
          )
          // Covers the receiver's Google check and GitHub create/lookup budgets.
          .timeout(const Duration(seconds: 40));
    } on Object {
      throw const BugReportException('network', '버그 제보 서버에 연결할 수 없습니다.');
    }

    Map<String, Object?> body = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) body = Map<String, Object?>.from(decoded);
    } on FormatException {
      // The status code below still produces a stable user-facing error.
    }
    if (response.statusCode != 201) {
      final code = body['error']?.toString() ?? 'submission_failed';
      throw BugReportException(code, _messageFor(code));
    }
    final issueNumber = body['issueNumber'];
    final issueUrl = Uri.tryParse(body['issueUrl']?.toString() ?? '');
    if (issueNumber is! int || issueUrl == null || issueUrl.scheme != 'https') {
      throw const BugReportException(
        'invalid_response',
        '버그 제보 결과를 확인할 수 없습니다.',
      );
    }
    _requestIds.removeWhere((_, id) => id == requestId);
    return BugReportSubmission(issueNumber: issueNumber, issueUrl: issueUrl);
  }

  void dispose() {
    if (_ownsHttpClient) _httpClient.close();
  }

  static String _messageFor(String code) => switch (code) {
    'google_auth_required' ||
    'invalid_google_token' => 'Google 로그인 상태를 확인한 뒤 다시 시도해 주세요.',
    'rate_limited' => '버그 제보 요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.',
    'invalid_report' => '버그 제보 내용을 다시 확인해 주세요.',
    'invalid_size' => '제보 내용이 너무 깁니다. 내용을 줄여 다시 시도해 주세요.',
    'github_unavailable' => 'GitHub 이슈를 생성하지 못했습니다. 잠시 후 다시 시도해 주세요.',
    _ => '버그 제보를 등록하지 못했습니다. 잠시 후 다시 시도해 주세요.',
  };
}
