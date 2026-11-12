/// The school's own single-sign-on step that follows the LMS entry form.
class LmsSchoolSso {
  const LmsSchoolSso({
    required this.host,
    required this.entryForm,
    required this.entryPath,
    required this.form,
    required this.path,
    required this.userField,
    required this.passwordField,
    required this.loginFunction,
    required this.rememberField,
  });
  final String host;
  final String entryForm;
  final String entryPath;
  final String form;
  final String path;
  final String userField;
  final String passwordField;
  final String loginFunction;
  final String rememberField;
}

/// One row per supported school. Every school-specific host, form and SSO value
/// lives here; removing a row turns that school's LMS support off everywhere
/// in Dart. The Apple cookie bridges keep the same host list (see
/// `DailyLmsCookieStore.hosts`), verified by test.
class LmsSchool {
  const LmsSchool({
    required this.id,
    required this.host,
    required this.domain,
    this.loginForm = 'form.form-login',
    this.sso,
  });

  /// The academic profile's `timetableUniversity` value.
  final String id;
  final String host;

  /// Manual login may visit this domain and its subdomains (HTTPS 443 only).
  final String domain;

  /// The LMS's own `POST /login/index.php` form. Some desktop themes name it
  /// `form.loginform` while the mobile theme keeps `form.form-login`.
  final String loginForm;
  final LmsSchoolSso? sso;

  Uri get baseUrl => Uri.https(host, '/');
  String get origin => baseUrl.origin;

  /// Flat, secret-free arguments for the automatic login script.
  Map<String, String> get scriptArguments => {
    'lmsHost': host,
    'loginForm': loginForm,
    'ssoHost': sso?.host ?? '',
    'ssoEntryForm': sso?.entryForm ?? '',
    'ssoEntryPath': sso?.entryPath ?? '',
    'ssoForm': sso?.form ?? '',
    'ssoPath': sso?.path ?? '',
    'ssoUser': sso?.userField ?? '',
    'ssoPassword': sso?.passwordField ?? '',
    'ssoFunction': sso?.loginFunction ?? '',
    'ssoRemember': sso?.rememberField ?? '',
  };

  static const _bothThemes = 'form.form-login, form.loginform';

  static const all = <LmsSchool>[
    LmsSchool(
      id: 'smu',
      host: 'ecampus.smu.ac.kr',
      domain: 'smu.ac.kr',
      sso: LmsSchoolSso(
        host: 'smsso.smu.ac.kr',
        entryForm: 'form.form-sso-login',
        entryPath: '/exsignon/sso/sso_idp_login.php',
        form: 'form#loginFrm',
        path: '/Login.do',
        userField: '#user_id',
        passwordField: '#user_password',
        loginFunction: 'doLogin',
        rememberField: '#saveIdIpt',
      ),
    ),
    LmsSchool(id: 'jnu', host: 'sel.jnu.ac.kr', domain: 'jnu.ac.kr'),
    LmsSchool(
      id: 'changwon',
      host: 'ecampus.changwon.ac.kr',
      domain: 'changwon.ac.kr',
    ),
    LmsSchool(id: 'jnue', host: 'lms.jnue.kr', domain: 'jnue.kr'),
    LmsSchool(
      id: 'kyonggi',
      host: 'lms.kyonggi.ac.kr',
      domain: 'kyonggi.ac.kr',
      loginForm: _bothThemes,
    ),
    LmsSchool(
      id: 'mokpo',
      host: 'lms.mokpo.ac.kr',
      domain: 'mokpo.ac.kr',
      loginForm: _bothThemes,
    ),
    // Gachon posted a notice on 2026-11-06 against entering school accounts
    // into outside services. Delete this row to withdraw Gachon support.
    LmsSchool(
      id: 'gachon',
      host: 'cyber.gachon.ac.kr',
      domain: 'gachon.ac.kr',
      loginForm: _bothThemes,
    ),
  ];

  static LmsSchool? of(String? id) {
    for (final school in all) {
      if (school.id == id) return school;
    }
    return null;
  }

  static LmsSchool? byHost(String host) {
    for (final school in all) {
      if (school.host == host) return school;
    }
    return null;
  }
}
