# GitHub 리뷰를 Claude Actions에 전달

게시된 리뷰를 기준으로 Claude Code Action을 실행한다. 기존 Claude 데스크톱 세션에 메시지를 넣는 기능은 아니다. 전달 첫 문장은 항상 `PR #{실제 번호}에 리뷰 댓글을 작성했습니다.`이다.

## 활성화

1. 이 변경의 PR을 검토한 뒤 사용자가 기본 브랜치에 머지한다. 에이전트는 머지하지 않는다.
2. 사용자가 `claude setup-token`으로 준비한 토큰을 저장소 Actions 시크릿 `CLAUDE_CODE_OAUTH_TOKEN`에 등록한다. 로컬 로그인은 Actions 인증을 대신하지 않는다.
3. 저장소 Actions 변수 `REVIEW_RELAY_SINCE`를 활성화할 UTC 시각(`YYYY-MM-DDTHH:MM:SSZ`)으로 설정한다. 이 시각 이전 리뷰는 실행하지 않는다. 미설정은 명시적 실패다.
4. Actions 정책에서 워크플로 및 `anthropics/claude-code-action`, `actions/checkout`, `actions/upload-artifact` 실행을 허용해야 한다.
5. 실제 지적사항이 있는 리뷰가 게시된 뒤 `Claude 리뷰 전달` 실행, `claude-review-relay/{리뷰 ID}` check run, `relay-receipt.json`을 확인한다. 파일 반영이나 시크릿 이름 존재만으로 전달 완료로 보지 않는다.

Claude가 PR에 새 커밋을 푸시하면 기존 `platform-builds.yml`을 명시적으로 dispatch한다. `GITHUB_TOKEN`으로 푸시한 변경이 일반 push 이벤트 CI를 시작하지 않는 조건을 처리하기 위해 Actions 쓰기 권한을 사용한다. dispatch 접수와 CI 통과는 구분하며 영수증에도 통과로 쓰지 않는다.

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

## 2026-10-23 후속 복구

실제 `pull_request_review` 수집 실행 39936415961과 `workflow_run` 전달 실행 39936436175(시도 1)는 PR #670 / 리뷰 5626757465를 선택했다. 그러나 Claude 실행에는 도구 권한 거부 3건이 있었고, 기존 완료 판정은 이를 놓쳤다. 이 실행의 녹색 상태는 수신·수정 완료 증거가 아니다.

새 실행기는 구조화 응답의 저장소·PR·리뷰·대상 커밋·알림 문장과 리뷰 조회 확인을 대조한다. 실행 성공, 권한 거부 0건, 구조화 완료 응답이 모두 있어야 완료 영수증(schema 2)을 만든다. 이전 형식의 성공 기록도 확인되지 않은 실행으로 취급하며, 해당 리뷰 ID와 결과 불명확 확인을 명시해야 재시도한다. 기본 브랜치 반영 전에는 해당 후보 브랜치의 workflow_dispatch로 별도 검증할 수 있으나 이것은 실제 리뷰 이벤트 연결 검증을 대체하지 않는다.

전달 실행기는 workflow_sha로 고정한다. PR별 동시 실행을 직렬화하고, 예약 이후 실패·취소·중단은 자동 재전송하지 않는다. GitHub 기록과 외부 Claude 실행 사이의 원자적 트랜잭션은 없으므로 정확히 한 번 실행을 보장하지 않는다. 모델의 구조화 확인은 수신 근거이며 수정 내용의 정확성이나 전체 CI 통과를 보장하지 않는다. 도구 제한과 프롬프트의 자동 머지 금지는 별도 GitHub 브랜치 보호를 대체하지 않는다.


후속 실제 실행: 후보 커밋 `0a79eb4faf43b4af5c6ab083b24447a6e8720c4e`의 workflow_dispatch 39939320519(시도 1)는 PR #670 / 리뷰 5626757465의 정확한 대상 정보와 `PR #670에 리뷰 댓글을 작성했습니다.`를 Claude 구조화 응답에서 대조해 `received: true`를 기록했다. 그러나 권한 거부 3건으로 후속 상태는 uncertain, check 120367087762 및 작업 결과는 failure다. Claude 세션은 `02a310d3-c1cd-4f75-978c-c024287f3f17`이다. 대상 PR에는 후속 커밋 b3d4988e05906e88ba6c485ebeab329b6ceb7fcc와 답글 issuecomment-6362883393이 생겼다. 이것은 수정 내용의 정확성이나 전체 CI 통과를 확인한 결과가 아니다.

수신 영수증이 있는 리뷰는 후속 작업이 실패했어도 재전달하지 않는다. 후속 작업 문제는 이미 받은 알림의 중복 전송으로 해결하지 않는다. 수신 자체가 확인되지 않은 실패·중단·기존 형식의 성공 기록만 명시적 재시도 대상으로 남는다. 후속 단계에서 권한 거부가 있으면 전체 실행을 완료로 기록하지 않는다. 다음 실행부터 시크릿이나 원문 인수 대신 거부 도구명·알려진 실행 프로그램명·인수 키·인수 해시만 영수증에 남긴다. 이번 실행은 이전 후보 코드여서 거부된 도구의 상세는 보존되지 않았으며 그 3건의 구체적 원인은 미확인이다.


## 남은 수용 검증 — 2026-10-23

실행 39941070919 / 시도 1 / workflow_dispatch / 후보 9d6d2533의 읽기 진단은 success였다. Claude 세션 ff732c62-8ce1-4f3c-8edc-44ca65745116, received=true, permission_denials_count=0, state=completed. PR #670의 실제 게시 리뷰 5626757465와 원래 커밋 841ff63deb4e31498bb13002bdb6607727d0fcfa를 사용했다.

실행 39941381611 / 시도 1 / workflow_dispatch / 후보 98dfc3bb의 격리된 수정·검증 재현도 success였다. Claude 세션 bdcfd981-5fef-4494-820d-90266b981988, received=true, permission_denials_count=0, state=completed. GitHub 토큰은 contents:read, pull-requests:read이고 실제 PR에 커밋·푸시·댓글·머지를 요청하지 않는다. runner만 원래 리뷰 커밋으로 detached checkout한다. 진단 실행기와 원래 대상 문맥은 checkout 전에 RUNNER_TEMP에 보존한다. 재현은 새 리뷰 게시 이벤트나 실제 PR 수정 완료 검증을 대체하지 않는다.

두 진단 모두 실제 기존 리뷰를 사용했으며 시험용 거짓 리뷰를 게시하지 않았다. 기존 39939320519 실행의 raw 실행 파일은 runner 임시 경로에만 남고 업로드되지 않았다. 현재 남은 artifact는 context/receipt뿐이며 기본 Action 로그는 도구 거부 횟수만 출력한다. 따라서 과거 3건의 개별 명령·인과관계는 복원할 수 없으며, 새 재현에서 거부가 없었다는 사실을 그 원인의 확정으로 표현하지 않는다.

diagnostic_only=true는 scan/deliver를 생략하며 전달 원장을 생성하거나 수정하지 않는다. probe_pr/probe_review에는 실제 게시된 대상만 받는다. diagnostic_replay=false는 조회 진단, true는 runner 안에서만 원래 리뷰의 수정·검증 재현이다. 두 모드 모두 원격 쓰기 권한이 없다. 공개 로그를 전부 노출하는 show_full_output는 사용하지 않는다.

21개 로컬 테스트와 후보 98dfc3bb의 Actions 전달 로직 검증 39941388269가 통과했다. 최신 기본 브랜치의 실제 리뷰 이벤트까지 검증하려면 사용자 검토·머지가 필요하다. 자동 머지는 하지 않는다.
