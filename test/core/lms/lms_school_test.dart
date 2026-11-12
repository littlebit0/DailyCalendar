import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/lms/lms_controller.dart';
import 'package:daily/core/lms/lms_credentials_store.dart';
import 'package:daily/core/lms/lms_learning_report_client.dart';
import 'package:daily/core/lms/lms_school.dart';
import 'package:daily/core/lms/lms_web_session.dart';
import 'package:flutter_test/flutter_test.dart';

const _universities = {
  'smu': 'institution:academyinfo:0000117',
  'jnu': 'institution:academyinfo:0000023',
  'changwon': 'institution:academyinfo:0000028',
  'jnue': 'institution:academyinfo:0000258',
  'kyonggi': 'institution:academyinfo:0000056',
  'mokpo': 'institution:academyinfo:0000011',
  'gachon': 'institution:academyinfo:0000063',
};

const _hosts = {
  'smu': 'ecampus.smu.ac.kr',
  'jnu': 'sel.jnu.ac.kr',
  'changwon': 'ecampus.changwon.ac.kr',
  'jnue': 'lms.jnue.kr',
  'kyonggi': 'lms.kyonggi.ac.kr',
  'mokpo': 'lms.mokpo.ac.kr',
  'gachon': 'cyber.gachon.ac.kr',
};

Map<String, dynamic> _localForm(String host, {String? action}) => {
  'method': 'post',
  'action': action ?? 'https://$host/login/index.php',
  'children': {
    'input[name="username"]': {'name': 'username'},
    'input[name="password"]': {'name': 'password', 'type': 'password'},
    'input[name="rememberusername"]': {
      'name': 'rememberusername',
      'type': 'checkbox',
    },
  },
};

/// Null when Node.js is unavailable; the caller then skips, never passes.
Future<Map<String, dynamic>?> _run(
  LmsSchool school,
  Map<String, dynamic> page, {
  String stage = 'entry',
}) async {
  final Process process;
  try {
    process = await Process.start('node', [
      'test/core/lms/login_script_harness.js',
    ]);
  } on ProcessException {
    return null;
  }
  process.stdin.write(
    jsonEncode({
      'script': LmsWebSession.automaticLoginScript,
      'args': {
        ...school.scriptArguments,
        'stage': stage,
        'username': 'fixture-id',
        'password': 'fixture-password',
      },
      'page': page,
    }),
  );
  await process.stdin.close();
  final output = await process.stdout.transform(utf8.decoder).join();
  final errors = await process.stderr.transform(utf8.decoder).join();
  expect(await process.exitCode, 0, reason: errors);
  return jsonDecode(output) as Map<String, dynamic>;
}

void main() {
  test('the school list decides which profiles have LMS support', () {
    expect(LmsSchool.all.map((s) => s.id).toSet(), _universities.keys.toSet());
    for (final entry in _universities.entries) {
      final profile = AcademicProfile(
        universityId: entry.value,
        universityName: entry.key,
        schoolKind: 'fourYear',
      );
      expect(profile.timetableUniversity, entry.key);
      expect(LmsController.supportsSchool(entry.key), isTrue);
      final school = LmsSchool.of(entry.key)!;
      expect(school.baseUrl, Uri.parse('https://${_hosts[entry.key]}/'));
      expect(LmsSchool.byHost(school.host), same(school));
      expect(school.host.endsWith('.${school.domain}'), isTrue);
    }
    // Only Sangmyung enters through a school SSO form.
    expect(
      LmsSchool.all.where((s) => s.sso != null).map((s) => s.id),
      ['smu'],
    );
    expect(LmsSchool.of('smu')!.sso!.host, 'smsso.smu.ac.kr');
    expect(LmsWebSession.automaticLoginScript, isNot(contains('smu.ac.kr')));
  });

  test('schools outside the list are blocked at every entry point', () async {
    for (final school in ['cue', 'hansung', 'scnu', '', null]) {
      expect(LmsController.supportsSchool(school), isFalse);
    }
    expect(
      () => LmsWebSession(ownerId: 'student@example.com', schoolId: 'cue'),
      throwsA(isA<LmsWebSessionException>()),
    );
    expect(
      () => LmsCredentialsStore().save(
        'student@example.com',
        'cue',
        const LmsLocalCredentials('fixture-id', 'fixture-password'),
      ),
      throwsArgumentError,
    );
    expect(
      await LmsLearningReportClient(
        createClient: () => fail('an unlisted host must not be requested'),
      ).read(
        Uri.parse(
          'https://lms.cue.ac.kr/report/ubcompletion/user_progress.php?id=1',
        ),
        const [
          {'name': 'MoodleSession', 'value': 'fixture'},
        ],
      ),
      {'status': 'invalid'},
    );
  });

  test('login navigation stays inside each school\'s own domain', () {
    for (final school in LmsSchool.all) {
      final policy = LmsWebRequestPolicy(school.baseUrl);
      expect(policy.allowsLoginNavigation(school.baseUrl), isTrue);
      expect(
        policy.allowsLoginNavigation(Uri.parse('https://sso.${school.domain}/')),
        isTrue,
      );
      expect(
        policy.allowsLoginNavigation(Uri.parse('http://${school.host}/')),
        isFalse,
      );
      expect(
        policy.allowsLoginNavigation(Uri.parse('https://${school.host}:8443/')),
        isFalse,
      );
      expect(
        policy.allowsLoginNavigation(
          Uri.parse('https://${school.domain}.attacker.test/'),
        ),
        isFalse,
      );
      for (final other in LmsSchool.all.where((o) => o != school)) {
        expect(policy.allowsLoginNavigation(other.baseUrl), isFalse);
        expect(policy.allowsRead(other.baseUrl), isFalse);
      }
    }
    expect(
      LmsWebRequestPolicy(
        Uri.parse('https://lms.cue.ac.kr/'),
      ).allowsLoginNavigation(Uri.parse('https://lms.cue.ac.kr/')),
      isFalse,
    );
  });

  test('Apple cookie bridges accept exactly the listed LMS hosts', () {
    for (final path in [
      'ios/Runner/AppDelegate.swift',
      'macos/Runner/MainFlutterWindow.swift',
    ]) {
      final source = File(path).readAsStringSync();
      final declared = RegExp(
        r'private static let hosts: Set<String> = \[(.*?)\]',
        dotAll: true,
      ).firstMatch(source)!.group(1)!;
      expect(
        RegExp(r'"([^"]+)"').allMatches(declared).map((m) => m.group(1)).toSet(),
        LmsSchool.all.map((s) => s.host).toSet(),
        reason: path,
      );
    }
  });

  group('automatic login script', () {
    test('submits each school\'s configured local form exactly once', () async {
      for (final school in LmsSchool.all) {
        // Mobile theme: every school serves form.form-login.
        final mobile = await _run(school, {
          'hostname': school.host,
          'selectors': {
            'input[type="password"]': {'type': 'password'},
            'form.form-login': _localForm(school.host),
          },
        });
        if (mobile == null) return markTestSkipped('Node.js is unavailable');
        expect(mobile['result'], {'state': 'credentialsSubmitted'});
        expect(mobile['calls'], ['submit:form.form-login']);
        final fields = mobile['fields'] as Map<String, dynamic>;
        expect(
          fields['form.form-login input[name="username"]']['value'],
          'fixture-id',
        );
        expect(
          fields['form.form-login input[name="password"]']['value'],
          'fixture-password',
        );
        expect(
          fields['form.form-login input[name="rememberusername"]']['checked'],
          isFalse,
        );

        // Desktop theme of Kyonggi, Mokpo and Gachon: form.loginform.
        final desktop = await _run(school, {
          'hostname': school.host,
          'selectors': {
            'input[type="password"]': {'type': 'password'},
            'form.loginform': _localForm(school.host),
          },
        });
        final accepts = const {'kyonggi', 'mokpo', 'gachon'}.contains(school.id);
        expect(
          desktop!['result'],
          accepts ? {'state': 'credentialsSubmitted'} : {'state': 'blocked'},
          reason: school.id,
        );
        expect(desktop['calls'], accepts ? ['submit:form.loginform'] : isEmpty);
      }
    });

    test('only Sangmyung takes the SSO entry and SSO form', () async {
      final smu = LmsSchool.of('smu')!;
      final ssoEntry = {
        'input[type="password"]': {'type': 'password'},
        'form.form-login': _localForm(smu.host),
        'form.form-sso-login': {
          'method': 'post',
          'action': 'https://${smu.host}/exsignon/sso/sso_idp_login.php',
        },
      };
      final entry = await _run(smu, {
        'hostname': smu.host,
        'selectors': ssoEntry,
      });
      if (entry == null) return markTestSkipped('Node.js is unavailable');
      expect(entry['result'], {'state': 'entrySubmitted'});
      expect(entry['calls'], ['submit:form.form-sso-login']);

      Map<String, dynamic> ssoPage(String host) => {
        'hostname': host,
        'functions': ['doLogin'],
        'selectors': {
          'form#loginFrm': {
            'method': 'post',
            'action': 'https://$host/Login.do',
            'children': {
              '#user_id': {'id': 'user_id'},
              '#user_password': {'id': 'user_password', 'type': 'password'},
            },
          },
          '#saveIdIpt': {'type': 'checkbox'},
        },
      };
      final sso = await _run(smu, ssoPage('smsso.smu.ac.kr'), stage: 'sso');
      expect(sso!['result'], {'state': 'credentialsSubmitted'});
      expect(sso['calls'], ['call:doLogin']);
      expect(sso['fields']['#saveIdIpt']['checked'], isFalse);
      expect(sso['fields']['form#loginFrm #user_id']['value'], 'fixture-id');

      // A school without SSO never submits an SSO entry form or fills a
      // same-shaped SSO page, even on its own school's SSO host.
      final gachon = LmsSchool.of('gachon')!;
      final ignored = await _run(gachon, {
        'hostname': gachon.host,
        'selectors': {
          ...ssoEntry,
          'form.form-login': _localForm(gachon.host),
        },
      });
      expect(ignored!['calls'], ['submit:form.form-login']);
      final foreign = await _run(
        gachon,
        ssoPage('sso.gachon.ac.kr'),
        stage: 'sso',
      );
      expect(foreign!['result'], {'state': 'blocked'});
      expect(foreign['calls'], isEmpty);
      // Another school's LMS host is not this school's page.
      final crossed = await _run(smu, {
        'hostname': gachon.host,
        'selectors': {'form.form-login': _localForm(gachon.host)},
      });
      expect(crossed!['result'], {'state': 'blocked'});
    });

    test('a form that differs from the configuration is not submitted', () async {
      final school = LmsSchool.of('kyonggi')!;
      final variants = <String, Map<String, dynamic>>{
        'other origin': _localForm(
          school.host,
          action: 'https://attacker.test/login/index.php',
        ),
        'other path': _localForm(
          school.host,
          action: 'https://${school.host}/login/other.php',
        ),
        'GET': {..._localForm(school.host), 'method': 'get'},
        'no password field': {
          'action': 'https://${school.host}/login/index.php',
          'children': {
            'input[name="username"]': {'name': 'username'},
          },
        },
      };
      for (final entry in variants.entries) {
        final result = await _run(school, {
          'hostname': school.host,
          'selectors': {
            'input[type="password"]': {'type': 'password'},
            'form.loginform': entry.value,
          },
        });
        if (result == null) return markTestSkipped('Node.js is unavailable');
        expect(result['result'], {'state': 'blocked'}, reason: entry.key);
        expect(result['calls'], isEmpty, reason: entry.key);
      }
      final insecure = await _run(school, {
        'hostname': school.host,
        'protocol': 'http:',
        'selectors': {'form.loginform': _localForm(school.host)},
      });
      expect(insecure!['result'], {'state': 'blocked'});
      final captcha = _localForm(school.host);
      (captcha['children'] as Map)['#captcha'] = {'id': 'captcha_code'};
      final challenged = await _run(school, {
        'hostname': school.host,
        'selectors': {
          'input[type="password"]': {'type': 'password'},
          'form.loginform': captcha,
        },
      });
      expect(challenged!['result'], {
        'state': 'blocked',
        'failure': 'additionalAuthentication',
      });
      expect(challenged['calls'], isEmpty);
    });

    test('school failure phrases end as fixed failures for every school', () async {
      const phrases = {
        '계정이 잠금 처리되었습니다.': LmsLoginFailure.accountLocked,
        '로그인 시도 횟수를 초과했습니다.': LmsLoginFailure.accountLocked,
        '비밀번호가 만료되었습니다.': LmsLoginFailure.passwordExpired,
        '아이디 또는 비밀번호가 일치하지 않습니다.': LmsLoginFailure.credentialsRejected,
        'Invalid username or password': LmsLoginFailure.credentialsRejected,
        '보안문자를 입력해 주세요.': LmsLoginFailure.additionalAuthentication,
        '인증번호를 입력해 주세요.': LmsLoginFailure.additionalAuthentication,
      };
      for (final school in LmsSchool.all) {
        for (final entry in phrases.entries) {
          final result = await _run(school, {
            'hostname': school.host,
            'errors': [entry.key],
            'selectors': {
              'input[type="password"]': {'type': 'password'},
              'form.form-login': _localForm(school.host),
            },
          });
          if (result == null) return markTestSkipped('Node.js is unavailable');
          expect(result['result']['state'], 'blocked', reason: entry.key);
          expect(
            LmsLoginFailure.fromSchoolCode(result['result']['failure']),
            entry.value,
            reason: '${school.id}: ${entry.key}',
          );
          expect(result['calls'], isEmpty);
        }
      }
    });
  });
}
