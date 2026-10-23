"""읽기 전용 실제 리뷰 진단. 전달 원장/PR 댓글/브랜치를 변경하지 않는다."""
import json
import os
from pathlib import Path
import sys
import claude_review_relay as relay


def prepare():
    pr = int(os.environ['PROBE_PR'])
    review_id = int(os.environ['PROBE_REVIEW'])
    if pr <= 0 or review_id <= 0:
        raise ValueError('양의 PR/리뷰 번호 필요')
    review = relay.api(f'pulls/{pr}/reviews/{review_id}')
    if review['id'] != review_id or not review.get('submitted_at'):
        raise ValueError('게시된 실제 리뷰가 아님')
    context = {'repository': os.environ['GITHUB_REPOSITORY'], 'pr_number': pr,
               'review_id': review_id, 'commit': review['commit_id'],
               'notification': f'PR #{pr}에 리뷰 댓글을 작성했습니다.'}
    Path('relay-context.json').write_text(json.dumps(context, ensure_ascii=False))


def finish():
    context = json.loads(Path('relay-context.json').read_text())
    records = json.loads(Path(os.environ['CLAUDE_EXECUTION_FILE']).read_text())
    if not isinstance(records, list):
        records = [records]
    acknowledgment = json.loads(os.environ.get('CLAUDE_STRUCTURED_OUTPUT', '{}'))
    result = relay.evaluate_execution(os.environ.get('CLAUDE_OUTCOME'), records, acknowledgment, context)
    result['mode'] = 'read_only_diagnostic_not_delivery'
    Path('relay-probe.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
    if result['state'] != 'completed':
        raise RuntimeError('읽기 전용 진단 미통과. 영수증의 권한 거부를 확인하세요.')


if __name__ == '__main__':
    {'prepare': prepare, 'finish': finish}[sys.argv[1]]()
