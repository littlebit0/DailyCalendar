# Chonnam public undergraduate timetable

Checked 2026-09-26. The official [registration entry page](https://sugang.jnu.ac.kr/)
links directly to the public [undergraduate timetable](https://hakstd.jnu.ac.kr/web/Suup/TimeTable/Suup030_C.aspx).
The catalog import uses only this unauthenticated search page. It neither logs
in nor enters the registration system or changes any enrollment.

`tool/timetable/import_jnu.py` selects the requested year/semester, then follows
the form's normal college/department and general-education/admission-year/area
filters. Requests run serially with at least 350 ms between requests. HTML
responses are cached under the supplied work directory for offline, reproducible
extraction. A missing table, changed column shape, pagination, conflicting
subject data or an unknown campus fails the import rather than silently emitting
an incomplete or inferred dataset. A run is bounded to 1,200 request attempts,
three attempts per response, a 30-second request timeout and an 8 MiB response
limit. Cached records include their year/semester and cannot be relabeled for
another term. The requested term, both-campus selection and undergraduate
college/admission-year selectors are checked explicitly.

The 2026-2 snapshot visits 266 major and 309 general-education search groups,
including all published undergraduate admission cohorts through 2026 (the
graduate-program selector is excluded). The resulting 20,215 source rows merge
into 3,862 unique campus/course/section identities:

| Campus | Source rows | Courses | Parsed meetings | Unrecognized notation | Official empty time |
| --- | ---: | ---: | ---: | ---: | ---: |
| Gwangju | 16,871 | 3,166 | 3,072 | 93 | 1 |
| Yeosu | 3,344 | 696 | 662 | 34 | 0 |

These are all undergraduate results returned by those public filters, not a
claim to cover graduate courses or courses absent from the public source.

The table's own campus column selects `gwangju` or `yeosu`. Course IDs retain the
university, campus, academic year, semester, subject code and section. Official
classification and remarks remain per search department/area, including cross-
campus enrollment eligibility and the published target group. Professor, room,
credit and section fields are not inferred from course names. Source-provided
language/remote-class annotations appear in remarks rather than in course names.
Original `sourceSchedule` and `sourceClassroom` remain available even where
meetings cannot safely be parsed. A repeated multi-line room name is collapsed
only when every period repeats exactly the same room-name pattern.

The [official 2026-2 registration notice](https://engedu.jnu.ac.kr/bbs/engedu/2411/1050036/artclView.do)
publishes 50-minute Monday/Wednesday/Friday and 75-minute Tuesday/Thursday
modules. The importer preserves those real ends. Daily's existing display
rounding separately extends the block to the next half-hour boundary.

The [official Physics department 2026 freshman handbook](https://physics.jnu.ac.kr/bbs/physics/2140/828207/download.do),
page 5, additionally defines Saturday periods 0–15 as 50-minute modules. The
actual page was rendered and visually checked; its Saturday table supports all
204 Saturday courses in this snapshot.

The 2026-2 notice and its original HWP attachment disagree with the handbook and
the [official English Education module table](https://engedu.jnu.ac.kr/bbs/engedu/2295/946734/artclView.do)
on Monday/Wednesday/Friday period 13 and Tuesday/Thursday period 9. For example,
the new notice duplicates the 22:00 slot at both period 13 and 14, and labels
a 15-minute slot as a 75-minute class. Only these conflicting period numbers
remain unresolved: unambiguous late periods 14/15 and Tuesday/Thursday 10 are
supported. There are 121 courses containing conflicting periods and six other
unrecognized source notations (including `****` and an ambiguous room mapping).
A course with such notation remains searchable with its original fields, marked
`unrecognized` and without fabricated meetings. An empty official schedule is
marked `unscheduled`. Automatic addition is available only when meetings have
been parsed. The UI directs other courses to manual entry after checking the
source. Disconnected periods and different rooms are not merged. No verified
Sunday module was found; any future Sunday notation remains unrecognized.

The public source does not state a publication date. The dataset's displayed
reference date (`publishedDate` for legacy schema compatibility) is the
retrieval date, also recorded explicitly as `retrievedAt`.

Rebuild with network access:

```sh
python3 tool/timetable/import_jnu.py --fetch \
  --cache work/university-expansion/jnu-2026-2 \
  --year 2026 --semester 2 --checked-at 2026-09-26
```

Omit `--fetch` to rebuild exclusively from the cached official responses. Cache
HTML contains public ASP.NET form state and is not committed. The small test
fixture contains only the public electrical-engineering course table.
