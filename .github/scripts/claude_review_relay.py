"""게시된 Codex 리뷰만 Claude에 전달하는 기본 브랜치 실행기."""
import datetime
import json
import os
from pathlib import Path
import re
import hashlib
import shlex
import sys
import time
import urllib.error
import urllib.request

BOT = 'chatgpt-codex-connector[bot]'
HUMAN = 'littlebit0'
MARKER = '<!-- codex-review-relay:v1 -->'
FINDING = re.compile(r'\[P[0-3](?:\]| Badge\])')
CHECK_PREFIX = 'claude-review-relay/'


def api(path, method='GET', body=None):
    """읽기만 제한적으로 재시도. 쓰기 응답 유실은 자동 재전송하지 않는다."""
    url = 'https://api.github.com/repos/' + os.environ['GITHUB_REPOSITORY'] + '/' + path
    for attempt in range(3):
        request = urllib.request.Request(url, method=method, data=None if body is None else json.dumps(body).encode(),
            headers={'Authorization': 'Bearer ' + os.environ['GH_TOKEN'], 'Accept': 'application/vnd.github+json',
                     'X-GitHub-Api-Version': '2022-11-28', 'Content-Type': 'application/json'})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return {} if response.status == 204 else json.load(response)
        except urllib.error.HTTPError as exc:
            if method == 'GET' and exc.code in (429, 500, 502, 503, 504) and attempt < 2:
                time.sleep(2 ** attempt)
                continue
            raise RuntimeError(f'GitHub {method} 실패: HTTP {exc.code}; 성공으로 처리하지 않음') from None
        except (urllib.error.URLError, TimeoutError):
            if method == 'GET' and attempt < 2:
                time.sleep(2 ** attempt)
                continue
            raise RuntimeError('GitHub 응답 미확인; 쓰기는 재전송하지 않음') from None


def pages(path, key=None):
    result = []
    separator = '&' if '?' in path else '?'
    for page in range(1, 101):
        response = api(f'{path}{separator}per_page=100&page={page}')
        batch = response[key] if key else response
        result.extend(batch)
        if len(batch) < 100:
            return result
    raise RuntimeError('페이지 조회 한도 초과: 일부 결과를 전체로 취급하지 않음')


def eligible(review, comments, since):
    if review.get('state') not in ('COMMENTED', 'CHANGES_REQUESTED') or not review.get('submitted_at'):
        return False
    if review['submitted_at'] < since:
        return False
    actor = review['user']['login']
    if actor == HUMAN:
        if review['user'].get('type') != 'User' or MARKER not in (review.get('body') or ''):
            return False
    elif actor == BOT:
        if review['user'].get('type') != 'Bot':
            return False
    else:
        return False
    bodies = [review.get('body') or ''] + [c.get('body') or '' for c in comments
        if c.get('pull_request_review_id') == review['id'] and c['user']['login'] == actor]
    return any(FINDING.search(body) for body in bodies)


def latest_check(checks, review_id):
    matches = [c for c in checks if c.get('name') == CHECK_PREFIX + str(review_id)
               and c.get('app', {}).get('slug') == 'github-actions']
    return max(matches, key=lambda c: c['id']) if matches else None


def verified_receipt(check):
    try:
        receipt = json.loads(check.get('output', {}).get('summary', '{}'))
        # Delivery acknowledgment prevents duplicate work even if follow-up tools failed.
        return receipt.get('schema') == 2 and receipt.get('received') is True
    except (ValueError, TypeError):
        return False


def retry_allowed(check, review_id):
    if check is None:
        return True
    if verified_receipt(check):
        return False
    return os.environ.get('RETRY_REVIEW_ID') == str(review_id) and os.environ.get('ACKNOWLEDGE_UNCERTAIN') == 'true'


def cutoff():
    value = os.environ.get('REVIEW_RELAY_SINCE', '')
    if not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z', value):
        raise RuntimeError('REVIEW_RELAY_SINCE를 활성화 시각(UTC)으로 설정해야 함')
    datetime.datetime.strptime(value, '%Y-%m-%dT%H:%M:%SZ')
    return value


def scan():
    since = cutoff()
    selected = []
    for pr in pages('pulls?state=open&sort=created&direction=asc'):
        # Forks require a separate trusted write/approval design; report rather than run secrets there.
        reviews = pages(f"pulls/{pr['number']}/reviews")
        if not any(r.get('submitted_at') and r['submitted_at'] >= since for r in reviews):
            continue
        comments = pages(f"pulls/{pr['number']}/comments")
        candidates = [r for r in reviews if eligible(r, comments, since)]
        if not candidates:
            continue
        if pr['head']['repo']['full_name'] != os.environ['GITHUB_REPOSITORY']:
            raise RuntimeError(f"외부 fork PR #{pr['number']}: 권한 검토 필요, 자동 실행하지 않음")
        checks = []
        for commit in sorted({r['commit_id'] for r in candidates}):
            checks.extend(pages(f"commits/{commit}/check-runs?filter=all", 'check_runs'))
        unresolved = [r for r in candidates if latest_check(checks, r['id'])
                      and not verified_receipt(latest_check(checks, r['id']))]
        if any(not retry_allowed(latest_check(checks, r['id']), r['id']) for r in unresolved):
            print(f"PR #{pr['number']}: 이전 커밋을 포함한 불명확한 실행이 있어 보류", file=sys.stderr)
            continue
        for review in sorted(candidates, key=lambda r: r['id']):
            if review['commit_id'] != pr['head']['sha']:
                continue  # 새 커밋에는 새 리뷰가 필요하다.
            previous = latest_check(checks, review['id'])
            if os.environ.get('RETRY_REVIEW_ID') and os.environ['RETRY_REVIEW_ID'] != str(review['id']):
                continue
            if previous and verified_receipt(previous):
                continue
            if not retry_allowed(previous, review['id']):
                print(f"PR #{pr['number']} 리뷰 {review['id']}: 실행 결과 미확인/실패, 명시적 재시도 필요", file=sys.stderr)
                break  # 불명확한 실행이 있는 PR의 후속 실행도 중지한다.
            selected.append({'pr': pr['number'], 'review': review['id']})
            break  # PR별 한 건씩; 남은 리뷰는 다음 스캔에서 처리.
    if len(selected) > 256:
        raise RuntimeError('행렬 한도 초과: 큐 처리 설계 확장 필요')
    output('matrix', {'include': selected})
    output('has_work', bool(selected))


def output(name, value):
    encoded = json.dumps(value, ensure_ascii=False, separators=(',', ':')) if not isinstance(value, str) else value
    if '\n' in encoded or '\r' in encoded:
        raise RuntimeError('여러 줄 출력 거부')
    with open(os.environ['GITHUB_OUTPUT'], 'a') as stream:
        stream.write(name + '=' + encoded + '\n')


def claim(pr_number, review_id):
    pr = api(f'pulls/{pr_number}')
    review = api(f'pulls/{pr_number}/reviews/{review_id}')
    comments = pages(f'pulls/{pr_number}/reviews/{review_id}/comments')
    valid = (pr['state'] == 'open' and pr['head']['repo']['full_name'] == os.environ['GITHUB_REPOSITORY']
             and review['id'] == review_id and review['commit_id'] == pr['head']['sha']
             and eligible(review, comments, cutoff()))
    if not valid:
        output('execute', False)
        return
    checks = pages(f"commits/{pr['head']['sha']}/check-runs?filter=all", 'check_runs')
    # Recheck after entering the PR concurrency group; scan may predate another attempt.
    previous_reviews = pages(f'pulls/{pr_number}/reviews')
    for commit in sorted({r['commit_id'] for r in previous_reviews if r.get('commit_id')} - {pr['head']['sha']}):
        checks.extend(pages(f'commits/{commit}/check-runs?filter=all', 'check_runs'))
    for previous_id in {r['id'] for r in previous_reviews}:
        previous = latest_check(checks, previous_id)
        if previous and not verified_receipt(previous) and not retry_allowed(previous, previous_id):
            output('execute', False)
            return
    if not retry_allowed(latest_check(checks, review_id), review_id):
        output('execute', False)
        return
    context = {'repository': os.environ['GITHUB_REPOSITORY'], 'pr_number': pr_number,
               'review_id': review_id, 'review_url': review['html_url'], 'commit': review['commit_id'],
               'reviewer': review['user']['login'], 'notification': f'PR #{pr_number}에 리뷰 댓글을 작성했습니다.'}
    # No external body/comment is interpolated into shell, workflow code or instructions.
    Path('relay-context.json').write_text(json.dumps(context, ensure_ascii=False, indent=2))
    if os.environ.get('RELAY_CONTEXT_PATH'):
        Path(os.environ['RELAY_CONTEXT_PATH']).write_text(json.dumps(context, ensure_ascii=False, indent=2))
    check = api('check-runs', 'POST', {'name': CHECK_PREFIX + str(review_id), 'head_sha': review['commit_id'],
        'status': 'in_progress', 'external_id': f"{os.environ['GITHUB_RUN_ID']}:{os.environ['GITHUB_RUN_ATTEMPT']}",
        'details_url': run_url(), 'output': {'title': 'Claude 전달 시작 전 예약',
        'summary': '성공 영수증 전까지 결과 미확인. 중단 시 자동 재전송하지 않습니다.'}})
    output('check_id', str(check['id']))
    output('execute', True)
    output('notification', context['notification'])


def run_url():
    return f"https://github.com/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}/attempts/{os.environ['GITHUB_RUN_ATTEMPT']}"


def denial_summary(result):
    summaries = []
    for item in result.get('permission_denials', []):
        if not isinstance(item, dict):
            continue
        inputs = item.get('tool_input', {})
        program = None
        if isinstance(inputs, dict) and isinstance(inputs.get('command'), str):
            try:
                words = shlex.split(inputs['command'])
                candidate = Path(words[0]).name if words else None
                if candidate in {'git', 'gh', 'python3', 'bash', 'sh', 'cd', 'ls', 'pwd', 'cat', 'sed', 'rg', 'find', 'flutter', 'dart'}:
                    program = candidate
            except ValueError:
                pass
        summaries.append({'tool': item.get('tool_name'), 'program': program,
                          'input_keys': sorted(inputs) if isinstance(inputs, dict) else [],
                          'input_sha256': hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()})
    return summaries


def evaluate_execution(outcome, records, acknowledgment, context):
    results = [r for r in records if isinstance(r, dict) and r.get('type') == 'result']
    result = results[-1] if results else {}
    denials = result.get('permission_denials_count')
    if denials is None and isinstance(result.get('permission_denials'), list):
        denials = len(result['permission_denials'])
    identity = ('repository', 'pr_number', 'review_id', 'commit', 'notification')
    received = isinstance(acknowledgment, dict) and all(
        acknowledgment.get(key) == context[key] for key in identity)
    received = received and acknowledgment.get('review_read') is True
    success = (outcome == 'success' and result.get('subtype') == 'success'
               and result.get('is_error') is False and denials == 0 and received
               and acknowledgment.get('status') == 'completed')
    return {'schema': 2, 'received': bool(received), 'permission_denials_count': denials,
            'denied_tools': denial_summary(result),
            'acknowledgment_status': acknowledgment.get('status') if isinstance(acknowledgment, dict) else None,
            'state': 'completed' if success else 'uncertain',
            'session_id': result.get('session_id'), 'target': {key: context[key] for key in identity}}


def finish(check_id):
    outcome = os.environ.get('CLAUDE_OUTCOME', 'unknown')
    execution = os.environ.get('CLAUDE_EXECUTION_FILE', '')
    context = json.loads(Path(os.environ.get('RELAY_CONTEXT_PATH', 'relay-context.json')).read_text())
    records = []
    if execution and Path(execution).is_file():
        try:
            text = Path(execution).read_text()
            try:
                parsed = json.loads(text)
                records = parsed if isinstance(parsed, list) else [parsed]
            except json.JSONDecodeError:
                records = [json.loads(line) for line in text.splitlines() if line.strip()]
        except (OSError, ValueError):
            records = []
    try:
        acknowledgment = json.loads(os.environ.get('CLAUDE_STRUCTURED_OUTPUT', '{}'))
    except ValueError:
        acknowledgment = {}
    receipt = evaluate_execution(outcome, records, acknowledgment, context)
    receipt.update({'run_url': run_url(), 'check_id': check_id, 'action_outcome': outcome,
                    'ci': 'not_dispatched', 'exactly_once_guaranteed': False})
    # Preserve received/execution evidence even when later CI or GitHub writes fail.
    Path('relay-receipt.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2))
    if receipt['state'] == 'completed':
        pr = api(f"pulls/{int(context['pr_number'])}")
        if pr['state'] == 'open' and pr['head']['sha'] != context['commit']:
            if pr['head']['repo']['full_name'] != os.environ['GITHUB_REPOSITORY'] or pr['head']['ref'] == pr['base']['ref']:
                raise RuntimeError('후속 CI 대상 저장소/브랜치 불일치')
            api('actions/workflows/platform-builds.yml/dispatches', 'POST', {'ref': pr['head']['ref']})
            receipt['ci'] = 'dispatch_accepted_not_verified'
        else:
            receipt['ci'] = 'no_open_head_change'
    Path('relay-receipt.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2))
    api(f'check-runs/{check_id}', 'PATCH', {'status': 'completed',
        'conclusion': 'success' if receipt['state'] == 'completed' else 'failure',
        'output': {'title': 'Claude 수신 및 후속 결과 대조' if receipt['state'] == 'completed' else 'Claude 권한/수신/결과 미확인',
                   'summary': json.dumps(receipt, ensure_ascii=False)}})
    if receipt['state'] != 'completed':
        raise RuntimeError('Claude의 대상 리뷰 수신·후속 결과를 확인하지 못함. 영수증과 로그 확인 후 명시적으로 재시도하세요.')


if __name__ == '__main__':
    action = sys.argv[1]
    if action == 'scan': scan()
    elif action == 'claim': claim(int(os.environ['PR_NUMBER']), int(os.environ['REVIEW_ID']))
    elif action == 'finish': finish(int(os.environ['CHECK_ID']))
    else: raise SystemExit('지원하지 않는 동작')
