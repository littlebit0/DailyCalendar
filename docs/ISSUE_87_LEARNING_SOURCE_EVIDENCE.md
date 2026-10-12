# Issue 87: LMS completion and learning evidence

Updated 2026-09-29. This note separates verified source semantics from unverified school
responses. It does not claim that Moodle's standard service is enabled on SMU.

## Assignment completion

- The existing anonymized SMU index fixtures have an explicit submission column
  with `미제출`. The adjacent grade column is independent.
- On 2026-09-28, the user completed login in the current Mac test app. Root's
  read-only accessibility inspection of the calendar observed two source-state
  labels with exact text `제출 완료`, alongside a last-check time of 23:35. The
  parser accepts that exact current source-derived state as submitted. No quiz
  or assignment detail page was opened for this check; it was not a fabricated
  positive fixture or a grade-based inference.
- The authorized 2026-09-29 app-owned assignment-index collection confirmed
  the exact `제출 완료` label for four rows, independently of grades. The
  collection retained only allowlisted status counts, not names or grades.
- SMU's published learner manual, printed page 38, identifies the submitted
  assignment's submission state as `채점 필요`, separately from grading status.
  Printed page 37 also shows `제출 안 함` as an unsubmitted state. These samples
  are in the assignment detail UI; observing them in the current index
  response remains a separate runtime check.
- Moodle documents `Submitted for grading` and `Draft (not submitted)` as
  different states. A teacher can return a submission to draft. A nonempty grade
  is not used as submission evidence.
- The parser maps these explicit states to a nullable source-completion value.
  An unfamiliar label stays unknown, rather than becoming incomplete or being
  interpreted by a substring match for `제출`.

Sources:

- [SMU learner manual](https://ecampus.smu.ac.kr/pluginfile.php/21/mod_ubboard/attachment/588657/e-Campus%20%ED%95%99%EC%8A%B5%EC%9E%90%20%EC%82%AC%EC%9A%A9%EC%84%A4%EB%AA%85%EC%84%9C.pdf?forcedownload=1)
- [Moodle assignment settings](https://docs.moodle.org/405/en/Assignment_settings)
- [Moodle assignment usage](https://docs.moodle.org/400/en/Using_Assignment)

## Daily completion mapping

The approved [issue 87](https://github.com/littlebit0/DailyCalendar/issues/87)
explicitly makes LMS the source of truth. A fresh, known source completion value
now sets Daily's ordinary completion flag in the repository transaction, including
true-to-false transitions. Unknown source state preserves the latest personal
value. Category-only imports and stale editor drafts do not reapply cached source
completion. Daily completion never submits an assignment or changes school state.
Completing an imported event also cancels its existing reminders and alarms.

This implements mapping for verified source values; it does not establish a safe
quiz attempt feed or a complete learning-content import. Those evidence gaps
below remain separate.

## Quiz completion: verified gap

The current SMU quiz index fixture contains title, due date, and grade. It does
not expose the attempt state. Moodle 3.11's matching index implementation hides
grades according to review options. Therefore neither a blank grade nor a
displayed score is used to infer the current attempt state.

Automatically fetching `mod/quiz/view.php` is unsafe for this read-only feature:
the official source invokes `quiz_view` (view-completion recording), and may
invoke `handle_if_time_expired` on an unfinished attempt. This route can change
school state merely by being opened.

`mod_quiz_get_user_attempts` is a standard read service, but its declaration in
Moodle 3.11 does not enable ordinary AJAX access. A normal browser cookie session
alone does not establish that the service can be called. SMU's available service,
authorization flow, and current payload have not been verified. No token was
created, exported, or inferred for this research.

Generic activity-completion marks are also insufficient without the configured
criterion: Moodle supports manual, view-based, grade-based, passing-grade, and
submitted-attempt rules. The issue asks for actual submission/attempt completion.
SMU's learner manual (printed page 41, visually checked) explicitly identifies
`종료됨` and `제출됨` as submitted quiz states, but displays them on the attempt
detail page. It does not establish a safe index/report route exposing them.

Sources:

- [Quiz index implementation](https://raw.githubusercontent.com/moodle/moodle/MOODLE_311_STABLE/mod/quiz/index.php)
- [Quiz detail implementation](https://raw.githubusercontent.com/moodle/moodle/MOODLE_311_STABLE/mod/quiz/view.php)
- [Quiz service declarations](https://raw.githubusercontent.com/moodle/moodle/MOODLE_311_STABLE/mod/quiz/db/services.php)
- [AJAX dispatch](https://raw.githubusercontent.com/moodle/moodle/MOODLE_311_STABLE/lib/ajax/service.php)
- [AJAX service authorization](https://raw.githubusercontent.com/moodle/moodle/MOODLE_311_STABLE/lib/externallib.php)
- [Activity completion settings](https://docs.moodle.org/311/en/Activity_completion_settings)

### Alternate cookie-session reads checked on 2026-09-29

Two alternatives were traced through the official `MOODLE_311_STABLE` source.
Neither supplies sufficient evidence of an actual submitted quiz attempt. No
school AJAX request, token provisioning, or session export was performed.

1. **Course-module HTML via `core_course_get_module`.** This function is declared
   `type: read` with `ajax: true`; it validates course access and renders the
   module's course-page HTML. The ordinary AJAX dispatcher requires the existing
   login and its session CSRF key. This is a possible authenticated read route,
   but its completion badges are not an attempt-state feed.
   [Declaration, lines 503–510](https://github.com/moodle/moodle/blob/MOODLE_311_STABLE/lib/db/services.php#L503-L510),
   [implementation, lines 3646–3682](https://github.com/moodle/moodle/blob/MOODLE_311_STABLE/course/externallib.php#L3646-L3682),
   [AJAX checks, lines 221–235](https://github.com/moodle/moodle/blob/MOODLE_311_STABLE/lib/externallib.php#L221-L235).
   Detailed automatic conditions depend on course display settings. The quiz's
   minimum-attempt condition counts `quiz_get_user_attempts(..., 'finished', true)`;
   despite that argument's name, the helper includes both `FINISHED` and
   `ABANDONED`. Thus even a satisfied minimum of one is not proof of submission.
   Teacher overrides can also replace the displayed per-condition status.
   [Display gate, lines 945–963](https://github.com/moodle/moodle/blob/MOODLE_311_STABLE/course/renderer.php#L945-L963),
   [minimum-attempt rule, lines 98–107](https://github.com/moodle/moodle/blob/MOODLE_311_STABLE/mod/quiz/classes/completion/custom_completion.php#L98-L107),
   [attempt filtering, lines 588–606](https://github.com/moodle/moodle/blob/MOODLE_311_STABLE/mod/quiz/lib.php#L588-L606),
   [override handling, lines 98–139](https://github.com/moodle/moodle/blob/MOODLE_311_STABLE/completion/classes/cm_completion_details.php#L98-L139).

2. **Calendar action-event AJAX.** The calendar action-event reads permit AJAX,
   but the quiz callback suppresses an action for several distinct reasons:
   insufficient capability, general activity completion, a closed quiz,
   nonparticipation, or an attempt returned by that same `finished` helper.
   An absent action therefore cannot distinguish submission from expiration,
   abandonment, or another exclusion. The response does not expose which branch
   caused the absence.
   [Read declarations, lines 216–245](https://github.com/moodle/moodle/blob/MOODLE_311_STABLE/lib/db/services.php#L216-L245),
   [quiz action callback, lines 2016–2081](https://github.com/moodle/moodle/blob/MOODLE_311_STABLE/mod/quiz/lib.php#L2016-L2081).

These routes are not added to collection or used to infer completion. An actual
attempt-state source still needs independent verification; an unknown state
remains unknown. This conclusion concerns these inspected alternatives and does
not assert that every school-specific read endpoint is unavailable.

## Video and e-learning reports

The authorized 2026-09-29 collection used the running app's authenticated
`LmsWebSession.fetchHtml` only for the dashboard, own-course
`report/ubcompletion/user_progress.php`, and assignment indexes. It did not
extract cookies, change accounts, visit players or activity detail pages, click
controls, or execute report JavaScript. Only sanitized structures were saved.
Nine course reports were collected twice, with 400 ms spacing and session and
product-sync guards before and after each request.

The report's exact columns are `주` (or `주제`), `강의자료`,
`출석인정요구시간`, `총학습시간`, and `진도율`, with whitespace normalized.
Week cells use row spans. Of the 23 named learning rows, 14 expose a single
`.track_detail` button with `data-modname`, `data-modid`, `data-sterm`,
`data-eterm`, and `data-progresstime`. The confirmed modules are `vod` (11)
and `econtents` (3). Their periods are ten-digit Unix seconds. For example,
`1790521200`–`1791125940` is 2026-09-28 00:00 through 2026-10-04 23:59
in Korea, or 2026-09-27 15:00 through 2026-10-04 14:59 UTC.

The learned-time cell contains a `상세보기 (n)` label that is stripped before
parsing. Durations appear as minute:second or hour:minute:second. A required-time
literal `0` is also present, but cannot produce a learning deadline. A blank
learned-time cell remains unknown, never zero. `data-progresstime` was `1` in all
14 markers and is **not** the duration. One confirmed e-learning row reports
required `18:00`, learned `18:23`, and progress `91.92%`; the issue's requested
required-time comparison therefore cannot be replaced by a 100% progress test.

The core parser now converts only verified `vod`/`econtents` rows with a valid
increasing period, positive required time, nonnegative known learned time, and
an opaque source identity. It returns `lecture` activities for compatibility
with existing Daily metadata, IDs `report:vod:<modid>` or
`report:econtents:<modid>`, UTC dates, the two durations, and source completion
from learned time >= required time. It uses the verified **report URL**, because
`modid` has not been established as the course-module ID required by a player
URL. It never constructs or fetches a player link.

The second collection inspected every row-owned element's tag and attribute
names, plus only narrow typed attributes. The nine unstudied named rows have no
source ID, learning period, activity anchor, or JavaScript handler anywhere in
the row. Their total-time cell is blank and their progress is `-`; two have
required time `0`. Ordinary empty-week rows instead contain a numeric week and
four empty cells. The parser ignores that confirmed empty-week shape while
retaining seven named rows with missing learning data as unresolved. The two
rows whose required time is explicitly `0` are separately excluded as
nonattendance/reference material; they do not produce a deadline or a
missing-data warning. A blank required-time cell remains unresolved. Two additional course responses
have the report wrapper but no expected progress table; they remain unsupported
responses, not proof that the course has no learning activities.

The first Python sanitizer exposed an HTML normalization issue: malformed
omitted-close `<tr>` elements can become nested with BeautifulSoup's
`html.parser`, so descendant selection accidentally included a following row's
marker. The second collection restricts every marker to its nearest owning row.
Dart's `package:html` uses HTML5 normalization; a regression fixture preserves
the observed omitted close tag and verifies separate identities and durations.
No title matching, row-position identity, or selection of the first of multiple
markers is used.

`CoursemosLearningIndex.activities` is an explicitly partial list of confirmed
rows. `coverageComplete` remains false when any named row is unresolved; even a
complete single table is not evidence that an absent activity was deleted.
**Core-parser conversion is not evidence of complete production import.** The
unlearned rows and missing report tables still need a verified nonmutating
source before the overall video/e-learning requirement can be called complete.

The final authorized collection ran the actual Dart parser against each fresh
report response through an anonymous stdin pipe. Raw HTML was neither written
nor printed; the subprocess returned only allowlisted counts and safe error
codes. Seven reports parsed successfully, producing 14 confirmed activities
(13 required-time-complete and one incomplete), initially with nine unresolved
named rows. The subsequent zero-requirement correction separates those nine
into seven unresolved rows and two explicitly excluded reference rows. Two
reports correctly returned `learning_table_missing`. This validates
HTML5 row normalization and actual-source conversion, not product import.
The focused assignment and learning parser suite also passed all 25 tests.

The missing-table investigation found a profile-information table whose static
headers include `이름` and `휴대전화` (no cell values collected), plus two
`progress_detail` tables inside `user_progress_modal` and
`user_progress_detail_modal`. These are detail-modal structures, not an
alternate attendance listing. Remaining unknown heading text was deliberately
masked; its content is not needed to establish the modal ancestry. No modal was
opened. This rules out using those three tables as learning activities, but does
not establish an authoritative empty-learning marker. No further school requests
were performed for this investigation.

The saved public report script reads `.progressreport .track_detail` metadata
and attaches POST detail handlers. It also contains attendance-recognition write
handlers. Neither handler is a collection route, and no detail button is clicked.

SMU documentation distinguishes the progress report for ordinary classes from
the online attendance report for remote classes. It also distinguishes the
actual attendance period from the academic week's dates. The requested Daily
deadline must come from the activity's actual learning period, not the week
heading. Required-time completion is a Daily mapping requested in issue 87;
it is not proof that every school attendance rule has been fulfilled.

Sources:

- [Prior authorized response evidence](ISSUE_65_COSMOS_FEASIBILITY.md)
- Local evidence: `work/issue65-cosmos/{authenticated-read-verification.json,progress-shape.json,public-progress-module.js}`.
- Original collection selectors: `work/issue65-cosmos/read-only-sample.cjs`.
- [SMU learner manual](https://ecampus.smu.ac.kr/pluginfile.php/24/mod_ubboard/attachment/588655/e-Campus%20%ED%95%99%EC%8A%B5%EC%9E%90%20%EC%82%AC%EC%9A%A9%EC%84%A4%EB%AA%85%EC%84%9C.pdf)
- [SMU remote-class learner manual](https://ecampus.smu.ac.kr/pluginfile.php/24/mod_ubboard/attachment/250059/e-Campus_%EC%9B%90%EA%B2%A9%EC%88%98%EC%97%85%20%ED%95%99%EC%8A%B5%EC%9E%90%20%EB%A7%A4%EB%89%B4%EC%96%BC.pdf)
- [SMU attendance-period settings](https://ecampus.smu.ac.kr/local/ubion/manual/contents/manual_f/2.CourseManagement.pdf)

## Remaining source collection

### Approved partial import verified in the app on 2026-09-29

The user approved importing confirmed learning rows with a coverage notice.
The updated Mac test app's first authenticated sync added14 learning events to
the existing14 assignments/quizzes, with no deletion or duplicate. Dynamic
coverage reported14 learning activities,7 unresolved named rows,2 zero-requirement
items excluded as nonattendance material, and2 unavailable course reports.
The UI displays the unresolved and unavailable counts and the event's learned
and required durations. Unknown learning rows are retained for later discovery;
their absence never deletes an existing lecture event.

A read-only repository audit found28 current-scope rows:17 known completed,
8 known incomplete,3 unknown. Every known source completion matched Daily and
there were no duplicate event or source IDs. Evidence:
`work/issues-87-88/mac-completion-learning-36937.json` and the live sync report.
This proves this Mac import, not an actual cross-device school-login/Drive test.
Full Flutter1067 passed with one existing skip; analyze clean. Quiz actual
submitted-attempt collection and the7 unresolved learning rows remain open.

The current sanitized evidence is local and excluded from commits:
`work/issues-87-88/learning-shapes-20260929.json`,
`work/issues-87-88/learning-structure-20260929-v2.json`, and
`work/issues-87-88/learning-parser-live-20260929.json`. They retain pseudonymous
course/title/source IDs, dates, durations, status counts, and structural
attributes; raw HTML, cookies, tokens, names, student IDs, grades, IP addresses,
and contact details were not saved. The collector is
`work/issues-87-88/collect_learning_shapes.py`.

Diagnostic collection is now stopped. The user subsequently approved importing
confirmed learning rows with a notice for the remaining gaps. Production sync
now fetches each course's learning report sequentially after its assignment and
quiz indexes, using the existing 400 ms request spacing. Its result reports the
current confirmed-learning, unresolved-named-row, and failed-report-course counts;
the observed counts are evidence values, not constants in the product.
`excludedLearningActivities` separately counts known zero requirements and does
not contribute to the incomplete-coverage notice.

A learning report's nonauthentication failure leaves the valid assignment/quiz
and other confirmed learning results usable. Authentication failure, login HTML,
Google-owner change, or school-principal/generation change aborts the staged
snapshot before any event is written. Deadline events carry the verified period,
required and learned durations, and source completion through the existing event
transaction. Category changes apply to cached lectures as well. Only complete
assignment/quiz indexes may establish deletion; a lecture missing from even a
fully parsed learning report is never pruned.

Focused sync, parser, and persistence tests passed 55 cases, including partial
coverage recovery, multiple-course report failure, source completion transitions,
category movement, and account changes after an earlier course has been fetched.
The subsequent zero-requirement correction passed 49 targeted sync/parser
tests, including a course containing only zero-requirement references. Targeted
analysis found no issues. This is implementation/test evidence;
installation and live production-import verification remain separate checks.

A future new source must be independently verified as nonmutating and allowed by
the active app's request policy. Unknown quiz/learning evidence must not be
filled using scores, title matching, invented metadata, a modal POST, or playback.
