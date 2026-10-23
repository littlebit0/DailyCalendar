# GitHub 리뷰를 Claude Actions에 전달

게시된 리뷰를 기준으로 Claude Code Action을 실행한다. 기존 Claude 데스크톱 세션에 메시지를 넣는 기능은 아니다. 전달 첫 문장은 항상 `PR #{실제 번호}에 리뷰 댓글을 작성했습니다.`이다.

## 활성화

1. 이 변경의 PR을 검토한 뒤 사용자가 기본 브랜치에 머지한다. 에이전트는 머지하지 않는다.
2. 사용자가 `claude setup-token`으로 준비한 토큰을 저장소 Actions 시크릿 `CLAUDE_CODE_OAUTH_TOKEN`에 등록한다. 로컬 로그인은 Actions 인증을 대신하지 않는다.
3. 저장소 Actions 변수 `REVIEW_RELAY_SINCE`를 활성화할 UTC 시각(`YYYY-MM-DDTHH:MM:SSZ`)으로 설정한다. 이 시각 이전 리뷰는 실행하지 않는다. 미설정은 명시적 실패다.
4. Actions 정책에서 워크플로 및 `anthropics/claude-code-action`, `actions/checkout`, `actions/upload-artifact` 실행을 허용해야 한다.
5. 실제 지적사항이 있는 리뷰가 게시된 뒤 `Claude 리뷰 전달` 실행, `claude-review-relay/{리뷰 ID}` check run, `relay-receipt.json`을 확인한다. 파일 반영이나 시크릿 이름 존재만으로 전달 완료로 보지 않는다.

GitHub 인증에는 명시적인 `github_token` 입력을 사용한다. Claude GitHub App 설치 여부를 가정하지 않는다. 작업 토큰에는 내용·PR 수정과 check run 기록 권한이 있다. 기본 브랜치 보호 규칙도 유지해야 한다. Claude에게 자동 머지를 지시하는 코드나 단계는 없으며, 프롬프트 및 도구 제한에도 금지한다. 이는 악의적인 프롬프트에 대한 OS 수준 격리나 모든 우회 명령 차단 보장이 아니다.

## 어떤 리뷰를 전달하는가

- `chatgpt-codex-connector[bot]`의 제출된 지적 리뷰.
- `littlebit0`의 리뷰 본문에 `<!-- codex-review-relay:v1 -->` 표식이 있고, 리뷰 본문 또는 그 리뷰에 속한 동일 작성자의 인라인 댓글에 `[P0]`–`[P3]` 또는 Codex 우선순위 배지가 있는 경우.
- 위 표식은 littlebit0가 Codex 지적사항 전달용 리뷰임을 명시하는 규약이다. 모든 일반 댓글을 Codex 리뷰로 추정하지 않는다. 자동화는 과거 리뷰에 표식을 추가하지 않는다.
- `PENDING`, `DISMISSED`, `APPROVED`, 지적 없는 리뷰, 현재 head와 다른 커밋의 리뷰, 닫힌 PR은 실행하지 않는다. 새 head에는 새 리뷰가 필요하다.
- Claude나 Actions 봇의 댓글은 입력 대상이 아니므로 응답으로 재실행되지 않는다.
- 외부 fork의 대상 리뷰는 권한 검토가 필요하다는 오류를 남긴다. fork에 시크릿을 노출하지 않으며, 외부 fork 후속 수정은 이 구현에서 지원하지 않는다.

## 중복·실패·복구

수신 워크플로는 코드 체크아웃과 시크릿 없이 제출 이벤트만 받는다. `workflow_run` 및 예약 실행은 기본 브랜치의 실행기로 GitHub에서 리뷰·댓글·커밋을 다시 조회한다. 이벤트에 딸린 외부 본문을 셸이나 워크플로 코드로 실행하지 않는다.

리뷰 ID별 check run을 원장으로 사용하고 PR별 concurrency를 적용한다. 여러 인라인 댓글, 재전달, 워크플로 재실행은 같은 성공 원장을 확인하고 생략한다. 실행 중 PR 하나에는 한 작업만 허용한다. GitHub가 대기 실행을 대체하거나 이벤트를 놓쳐도 10분 주기 스캔이 남은 대상 리뷰를 다시 찾는다. GitHub 예약 실행 지연·중단은 가능하므로 10분 내 실행을 보장하지 않는다.

읽기 요청의 일시적 네트워크/서버 실패만 최대 3회 재시도한다. 인증/권한 오류는 실패한다. 예약 쓰기 응답이 유실되면 Claude를 시작하지 않는다. Claude 시작 후 실패·중단·영수증 누락은 결과 미확인으로 남기고 자동 재실행하지 않는다. 정상 취소 처리 단계조차 실행되지 못하면 check run이 `in_progress`로 남아 재실행을 막는다.

재시도할 때 해당 PR의 변경과 기존 실행 로그를 먼저 확인한 뒤 `workflow_dispatch`에 `retry_review_id`를 지정하고 `acknowledge_uncertain=true`로 실행한다. 성공 처리된 리뷰는 재시도하지 않는다. API의 관측 지연, 외부 원장 변경, 중단 시점 때문에 **정확히 한 번 실행을 보장하지 않는다**.

성공 영수증은 Action 성공과 Claude 결과 파일의 성공 레코드를 함께 요구한다. 이는 Claude 실행 종료 확인이며 수정 내용의 정확성·모든 테스트 통과·사용자 수용을 대신하지 않는다. PR 수정 후 새로운 리뷰가 있어야 다시 실행한다.

## 로컬 검증

```sh
python3 -m unittest discover -s .github/scripts -p 'test_claude_review_relay.py' -v
```

공식 근거: [Claude GitHub Actions](https://code.claude.com/docs/en/github-actions), [Claude CLI](https://code.claude.com/docs/en/cli-reference), [고정 액션 정의](https://github.com/anthropics/claude-code-action/blob/ae68417a745a5df4b2124873632bd73a2255e6f6/action.yml).
