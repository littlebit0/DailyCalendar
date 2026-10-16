#!/usr/bin/env python3
"""Local, read-only Drive AppData reader with a separate OAuth session."""
import argparse
import contextlib
from concurrent.futures import ThreadPoolExecutor, wait, FIRST_COMPLETED
import base64
from datetime import datetime, timedelta
import hashlib
import html
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
from pathlib import Path
import re
import secrets
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from zoneinfo import ZoneInfo

from keychain_store import session as keychain_session, KeychainError, KeychainPermissionError

ROOT = Path(__file__).resolve().parent
LEGACY_RUNTIME = Path.home() / 'Documents/Codex/DailyCalendar/work/dot-awareness-runtime'
RUNTIME = Path(os.environ['DAILY_DOT_RUNTIME']) if os.environ.get('DAILY_DOT_RUNTIME') else (
    LEGACY_RUNTIME if LEGACY_RUNTIME.exists() else Path.home() / 'Library/Application Support/DailyCalendarDot')
APP_SCOPE = 'https://www.googleapis.com/auth/drive.appdata'
TOKEN_URL = 'https://oauth2.googleapis.com/token'
USER_URL = 'https://openidconnect.googleapis.com/v1/userinfo'
FILES_URL = 'https://www.googleapis.com/drive/v3/files'
CONFIG_PATHS = [
    Path.home() / 'Library/Application Support/Daily/google_desktop_oauth.json',
    Path.home() / 'Library/Application Support/com.littlebit0.daily/google_desktop_oauth.json',
]


class ReaderError(Exception):
    pass


class ReaderBusy(ReaderError):
    pass


class KeychainApprovalRequired(ReaderError):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def request_json(url, token=None, form=None):
    # Credentials are sent only to these fixed Google endpoints. Drive is GET only.
    is_file = re.fullmatch(re.escape(FILES_URL) + r'/[A-Za-z0-9_-]+', url.split('?')[0])
    if url.split('?')[0] not in (TOKEN_URL, USER_URL, FILES_URL) and not is_file:
        raise ReaderError('허용되지 않은 API 주소입니다.')
    if form is not None and url != TOKEN_URL:
        raise ReaderError('Drive 쓰기 요청은 지원하지 않습니다.')
    headers = {'Accept': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    body = None
    if form is not None:
        body = urllib.parse.urlencode(form).encode()
        headers['Content-Type'] = 'application/x-www-form-urlencoded'
    req = urllib.request.Request(url, data=body, headers=headers)
    try:
        with urllib.request.build_opener(NoRedirect).open(req, timeout=30) as response:
            raw = response.read(32 * 1024 * 1024 + 1)
        if len(raw) > 32 * 1024 * 1024:
            raise ReaderError('단일 응답이 읽기 한도를 초과했습니다. 전체 조회로 처리하지 않습니다.')
        result = json.loads(raw)
        if not isinstance(result, dict):
            raise ReaderError('API 응답 형식이 올바르지 않습니다.')
        return result
    except urllib.error.HTTPError as error:
        # Never expose response bodies, credentials or authorization codes.
        raise ReaderError(f'Google 요청 실패(HTTP {error.code}). 권한·연결을 확인하세요.') from None
    except (urllib.error.URLError, TimeoutError, OSError, ValueError):
        raise ReaderError('Google 연결 또는 JSON 응답 확인에 실패했습니다.') from None


def config():
    override = os.environ.get('GOOGLE_DESKTOP_OAUTH_CONFIG')
    candidates = [Path(override)] if override else CONFIG_PATHS
    for path in candidates:
        if path.is_file():
            try:
                data = json.loads(path.read_text())
                value = data.get('installed', data)
                client_id, secret = value['client_id'], value['client_secret']
                if not isinstance(client_id, str) or not client_id.endswith('.apps.googleusercontent.com'):
                    raise ValueError()
                if not isinstance(secret, str) or not secret:
                    raise ValueError()
                return {'client_id': client_id, 'client_secret': secret}
            except (KeyError, TypeError, ValueError, OSError):
                raise ReaderError('DailyCalendar 데스크톱 OAuth 설정을 확인할 수 없습니다.') from None
    raise ReaderError('DailyCalendar 데스크톱 OAuth 설정 파일이 필요합니다.')


def keychain(action, value=None, interactive=False):
    try:
        return keychain_session(action, value, interactive=interactive)
    except KeychainPermissionError:
        raise KeychainApprovalRequired("macOS 키체인 접근 승인이 필요합니다. Google 연결에서 확인하세요.") from None
    except (KeychainError, OSError):
        raise ReaderError('Dot 전용 키체인에 접근하지 못했습니다. macOS 접근 승인을 확인하세요. 기존 세션은 삭제하지 않았습니다.') from None


def identity(token):
    value = request_json(USER_URL, token=token)
    if not value.get('sub') or not value.get('email') or value.get('email_verified') is not True:
        raise ReaderError('Google 계정 신원을 확인하지 못했습니다.')
    return {key: value[key] for key in ('sub', 'email')}


def validated_token(response, previous=None):
    if not isinstance(response.get('access_token'), str) or not response['access_token']:
        raise ReaderError('Google 인증 토큰 응답이 올바르지 않습니다.')
    if response.get('token_type', '').lower() != 'bearer':
        raise ReaderError('지원하지 않는 인증 토큰입니다.')
    if 'scope' in response and APP_SCOPE not in response['scope'].split():
        raise ReaderError('DailyCalendar AppData 접근 권한이 부여되지 않았습니다.')
    refresh = response.get('refresh_token') or (previous or {}).get('refresh_token')
    if not refresh:
        raise ReaderError('지속 연결 권한이 없습니다. 다시 연결해야 합니다.')
    try:
        expires = int(response['expires_in'])
        if expires <= 0:
            raise ValueError()
    except (KeyError, ValueError, TypeError):
        raise ReaderError('토큰 유효기간을 확인하지 못했습니다.') from None
    return {'access_token': response['access_token'], 'refresh_token': refresh,
            'expires_at': time.time() + expires}


def access(interactive=False):
    credentials = config()
    saved = keychain('read', interactive=interactive)
    if not saved:
        raise ReaderError('Dot 전용 Google 연결이 없습니다. connect를 먼저 실행하세요.')
    if saved.get('client_id') != credentials['client_id'] or not saved.get('sub'):
        raise ReaderError('연결된 OAuth 앱이 다릅니다. 새 연결을 확인해야 합니다.')
    try:
        refresh_needed = float(saved['expires_at']) <= time.time() + 60
        if not saved.get('access_token') or not saved.get('refresh_token'):
            raise ValueError()
    except (KeyError, ValueError, TypeError):
        raise ReaderError('저장된 인증 정보가 불완전합니다. 다시 연결하세요.') from None
    if refresh_needed:
        response = request_json(TOKEN_URL, form={**credentials,
            'grant_type': 'refresh_token', 'refresh_token': saved['refresh_token']})
        tokens = validated_token(response, saved)
        user = identity(tokens['access_token'])
        if user['sub'] != saved['sub']:
            raise ReaderError('갱신된 Google 계정이 달라 조회를 중단했습니다.')
        saved = {**saved, **tokens, **user}
        keychain('write', saved, interactive=interactive)
    else:
        user = identity(saved['access_token'])
        if user['sub'] != saved['sub']:
            raise ReaderError('Google 계정이 달라 조회를 중단했습니다.')
    return saved


def callback_result(query, expected_state):
    fields = urllib.parse.parse_qs(query)
    states = fields.get('state', [])
    if len(states) != 1 or not secrets.compare_digest(states[0], expected_state):
        return None
    if fields.get('error'):
        raise ReaderError('Google 연결이 취소되거나 거절되었습니다.')
    codes = fields.get('code', [])
    if len(codes) != 1 or not codes[0]:
        raise ReaderError('Google 연결 응답에 인증 코드가 없습니다.')
    return codes[0]


def connect(timeout):
    credentials = config()
    # Ensure the secure store exists before requesting consent.
    print(json.dumps({'status': 'waiting_for_keychain'}), flush=True)
    existing = keychain('read', interactive=True)
    if existing:
        user = access(interactive=True)
        print(json.dumps({'status': 'connected', 'email': user['email']}, ensure_ascii=False), flush=True)
        return
    state = secrets.token_urlsafe(32)
    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b'=').decode()
    result = {}
    landing = '/connect/' + secrets.token_urlsafe(24)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_GET(self):
            parsed = urllib.parse.urlsplit(self.path)
            status = 200
            if parsed.path == landing:
                body = ('<h1>DailyCalendar → Dot 연결</h1>'
                        '<p>DailyCalendar에서 사용하는 Google 계정을 선택하세요.</p>'
                        '<p>Google의 AppData 권한은 읽기·쓰기가 묶여 있으나 이 도구는 조회만 수행합니다.</p>'
                        '<p>기존 앱 로그인은 변경하지 않습니다.</p>'
                        '<a href="' + html.escape(auth_url, quote=True) + '">Google 계정 연결</a>')
            elif parsed.path == '/callback':
                try:
                    code = callback_result(parsed.query, state)
                    if code:
                        result['code'] = code
                        body = '<p>Google 응답을 받았습니다. 계정과 Drive 접근 검증 결과는 작업 화면에서 확인하세요.</p>'
                    else:
                        status, body = 400, '<p>유효하지 않은 연결 요청입니다.</p>'
                except ReaderError as error:
                    result['error'] = error
                    body = '<p>연결이 완료되지 않았습니다. 작업 화면을 확인하세요.</p>'
            else:
                status, body = 404, '<p>페이지가 없습니다.</p>'
            payload = ('<!doctype html><meta charset="utf-8">' + body).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(payload)))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Referrer-Policy', 'no-referrer')
            self.send_header('X-Frame-Options', 'DENY')
            self.end_headers()
            self.wfile.write(payload)

    with HTTPServer(('127.0.0.1', 0), Handler) as server:
        server.timeout = 1
        base = f'http://127.0.0.1:{server.server_port}'
        redirect = base + '/callback'
        auth_url = 'https://accounts.google.com/o/oauth2/v2/auth?' + urllib.parse.urlencode({
            'client_id': credentials['client_id'], 'redirect_uri': redirect,
            'response_type': 'code', 'scope': 'openid email ' + APP_SCOPE,
            'access_type': 'offline', 'prompt': 'select_account consent',
            'code_challenge': challenge, 'code_challenge_method': 'S256', 'state': state})
        print(json.dumps({'status': 'waiting_for_user', 'url': base + landing,
                          'expires_in_seconds': timeout}), flush=True)
        deadline = time.monotonic() + timeout
        while not result and time.monotonic() < deadline:
            server.handle_request()
    if not result:
        raise ReaderError('연결 대기 시간이 끝났습니다. connect를 다시 실행하세요.')
    if 'error' in result:
        raise result['error']
    response = request_json(TOKEN_URL, form={**credentials,
        'grant_type': 'authorization_code', 'code': result['code'],
        'redirect_uri': redirect, 'code_verifier': verifier})
    tokens = validated_token(response)
    user = identity(tokens['access_token'])
    if existing and existing.get('sub') != user['sub']:
        raise ReaderError('기존 Dot 연결과 다른 계정입니다. 기존 연결은 보존했습니다. 계정 변경을 별도로 요청하세요.')
    # Probe the actual appData space before replacing the dedicated session.
    listing = list_files(tokens['access_token'])
    saved = {**tokens, **user, 'client_id': credentials['client_id']}
    keychain('write', saved, interactive=True)
    print(json.dumps({'status': 'connected', 'email': user['email'],
                      'daily_file_count': len(listing)}, ensure_ascii=False), flush=True)


def list_files(token, deadline=None):
    files, pages, page = {}, set(), None
    while True:
        if deadline is not None and time.monotonic() >= deadline:
            raise ReaderError('일정 조회 제한 시간을 초과했습니다. 다시 시도해 주세요.')
        args = {'spaces': 'appDataFolder', 'pageSize': '1000',
                'q': "trashed = false and (name contains 'daily-sync-v2-event-' or name = 'daily-sync-v2-settings.json' or name = 'daily-sync-v2-timetable.json')",
                'fields': 'nextPageToken,incompleteSearch,files(id,name,mimeType,modifiedTime,version)'}
        if page:
            args['pageToken'] = page
        data = request_json(FILES_URL + '?' + urllib.parse.urlencode(args), token=token)
        if data.get('incompleteSearch'):
            raise ReaderError('Drive가 부분 검색을 반환했습니다. 전체 조회를 중단합니다.')
        if not isinstance(data.get('files'), list):
            raise ReaderError('Drive 파일 목록이 누락되었습니다.')
        for item in data['files']:
            if not isinstance(item, dict) or not re.fullmatch(r'[A-Za-z0-9_-]+', item.get('id', '')):
                raise ReaderError('Drive 파일 식별자가 올바르지 않습니다.')
            name = item.get('name', '')
            if not (re.fullmatch(r'daily-sync-v2-event-.+\.json', name) or name in
                    ('daily-sync-v2-settings.json', 'daily-sync-v2-timetable.json')):
                continue
            if not item.get('version') or not item.get('modifiedTime'):
                raise ReaderError('Drive 파일 버전 정보가 누락되었습니다.')
            if item['id'] in files and files[item['id']] != item:
                raise ReaderError('페이지를 읽는 동안 Drive 파일이 변경되었습니다. 다시 조회하세요.')
            files[item['id']] = item
        page = data.get('nextPageToken')
        if not page:
            return sorted(files.values(), key=lambda item: item['id'])
        if not isinstance(page, str) or page in pages:
            raise ReaderError('Drive 페이지 순환을 감지했습니다. 전체 조회로 처리하지 않습니다.')
        pages.add(page)


def snapshot(token, progress=None):
    deadline = time.monotonic() + 120
    def report(phase, completed=0, total=0):
        if time.monotonic() >= deadline:
            raise ReaderError('일정 조회 제한 시간을 초과했습니다. 다시 시도해 주세요.')
        if progress:
            progress(phase, completed, total)
    def download(meta):
        return {'file': meta, 'payload': request_json(
            FILES_URL + '/' + meta['id'] + '?alt=media', token=token)}
    # Keep the stable before/after listing and all-or-nothing publication.
    for _ in range(2):
        report('listing')
        before = list_files(token, deadline=deadline)
        documents = [None] * len(before)
        report('downloading', 0, len(before))
        with ThreadPoolExecutor(max_workers=6) as pool:
            pending = {}
            source = iter(enumerate(before))
            completed = 0
            def enqueue():
                item = next(source, None)
                if item is not None:
                    index, meta = item
                    pending[pool.submit(download, meta)] = index
            for _ in range(6):
                enqueue()
            try:
                while pending:
                    ready, _ = wait(pending, timeout=1, return_when=FIRST_COMPLETED)
                    report('downloading', completed, len(before))
                    for future in ready:
                        documents[pending.pop(future)] = future.result()
                        completed += 1
                        report('downloading', completed, len(before))
                        enqueue()
            finally:
                for future in pending:
                    future.cancel()
        report('verifying', completed, len(before))
        if before == list_files(token, deadline=deadline):
            report('verified', completed, len(before))
            return documents
    raise ReaderError('조회 중 Drive 데이터가 계속 변경되어 완전한 자료를 확보하지 못했습니다. 다시 조회하세요.')


def private_write(path, value):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if path.parent.is_symlink() or path.is_symlink():
        raise ReaderError('개인 자료 경로에 심볼릭 링크를 사용할 수 없습니다.')
    os.chmod(path.parent, 0o700)
    fd, temporary = tempfile.mkstemp(prefix='.snapshot-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def read_schedule(include_past, emit=True, progress=None):
    user = access()
    now = datetime.now(ZoneInfo('Asia/Seoul'))
    documents = snapshot(user['access_token'], progress=progress)
    path = RUNTIME / 'private/drive-snapshot.json'
    value = {'source': 'Google Drive appDataFolder', 'email': user['email'],
             'acquired_at': datetime.now(ZoneInfo('Asia/Seoul')).isoformat(),
             'timezone': 'Asia/Seoul', 'reference_date': now.date().isoformat(),
             'interest_start_date': (now.date() - timedelta(days=7 if include_past else 0)).isoformat(),
             'future_end': None, 'acquisition_complete': True,
             'semantic_interpretation_complete': False,
             'note': '원본 전체 수집 자료. 스킬의 삭제·계정·반복·관심 날짜 해석 후에만 일정 조회 완료로 보고하세요.',
             'documents': documents}
    private_write(path, value)
    summary = {'status': 'acquired', 'email': user['email'], 'file_count': len(documents),
               'snapshot': str(path), 'semantic_interpretation_complete': False}
    if emit:
        print(json.dumps(summary, ensure_ascii=False))
    return summary


@contextlib.contextmanager
def session_lock():
    # Avoid concurrent connect/refresh overwriting the dedicated session.
    import fcntl
    directory = RUNTIME / 'private'
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    if directory.is_symlink():
        raise ReaderError('개인 자료 경로가 올바르지 않습니다.')
    os.chmod(directory, 0o700)
    lock_fd = os.open(directory / 'reader.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(lock_fd, 'w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ReaderBusy('다른 연결/조회 작업이 진행 중입니다.') from None
        yield


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    login = sub.add_parser('connect')
    login.add_argument('--timeout', type=int, default=600, choices=range(30, 1801), metavar='30..1800')
    sub.add_parser('status')
    read = sub.add_parser('read')
    read.add_argument('--include-past', action='store_true')
    args = parser.parse_args()
    try:
        with session_lock():
            if args.command == 'connect':
                connect(args.timeout)
            elif args.command == 'read':
                read_schedule(args.include_past)
            else:
                user = access()
                print(json.dumps({'status': 'connected', 'email': user['email']}, ensure_ascii=False))
    except (ReaderError, OSError) as error:
        message = str(error) if isinstance(error, ReaderError) else '로컬 파일/프로세스 접근에 실패했습니다.'
        print(json.dumps({'status': 'error', 'code': 'busy' if isinstance(error, ReaderBusy) else 'keychain_access' if isinstance(error, KeychainApprovalRequired) else 'connection_failed', 'message': message}, ensure_ascii=False), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
