# Nationwide undergraduate school directory

`assets/academic/universities.json` retains a bundled, sourced directory and
legacy profile identities. The current picker offers **183 four-year
institutions only**, with no degree-kind tabs. Junior colleges, cyber
universities, LH토지주택대학교, and the military/theology exclusions below are
not offered. Existing saved profiles and their Drive records are preserved.
Selection eligibility is separate from automatic academic/calendar integration
support, which follows the saved university profile.

Snapshot checked: **2026-09-26**. Main disclosure year: **2026**.

## Sources and coverage

| Source | Public source rows checked | Included campus rows |
| --- | ---: | ---: |
| [한국대학교육협의회 대학알리미, 2026 공시대상대학](https://m.academyinfo.go.kr/intro/intro0350/intro.do) | 456 | 412 |
| [교육부·한국직업능력연구원 커리어넷, 학교정보](https://m.career.go.kr/cnet/web/base/school/schoolUniversityList.mdo) | 472 | 11 |
| Public undergraduate military/police institutions excluded from disclosure | 6 | 6 |
| Total | | **429** |

The university disclosure list supplies all 251 university-group and 161
junior-college-group campus rows. Its 44 graduate-only institutions are excluded
from this undergraduate picker. General, education, industrial, cyber,
broadcasting, technical, special and polytechnic schools are retained under their
source's degree grouping, without inferring the grouping from a school-name
suffix. The source's narrower classification remains in `sourceKind`.

Disclosure does not cover all degree-granting facilities. The public CareerNet
list supplements the omitted in-house, lifelong-education major and remote-degree
categories: LH토지주택대학교, SPC식품과학대학, 국제예술대학교,
백석예술대학교, 삼성전자공과대학교, 세계사이버대학, 영남사이버대학교,
정화예술대학교 (two campuses), and 포스코기술대학 (two campuses).
Ordinary university rows from CareerNet are not unioned indiscriminately: some
still carry institutions' names from before a 2026 merger, whereas the primary
2026 disclosure source includes the successor schools.

The six additional undergraduate schools are 육군사관학교, 해군사관학교,
공군사관학교, 국군간호사관학교, 육군3사관학교, and 경찰대학. Their omission
from disclosure is explicitly documented by the
[official disclosure scope](https://m.academyinfo.go.kr/intro/intro0330/intro.do).
The [2026 인천광역시교육청 진로진학 길라잡이](https://www.ice.go.kr/upload/ice/na/bbs_2090/2026/02/1cdf8137ad36d6e27cc8ef3a0e977004.pdf)
also covers special-law university admissions. Their school/region pairs are
listed in the [government's regional-university classification guidance](https://www.law.go.kr/LSW/admRulInfoP.do?admRulSeq=2100000266868&chrClsCd=010201).
They appear in the bachelor-degree group (`fourYear`); this is not a promise that
every transfer or work-based course requires four additional years. In
particular, 육군3사관학교 offers transfer entry.

The two picker groups contain **260 four-year/bachelor-group campus rows** and
**169 two/three-year/junior-college-group campus rows**. Counts are campus rows,
not a claim that Korea has 429 independent universities. Graduate-only schools,
non-degree training facilities, historical closed schools not in the current
source, and foreign-university branches are outside this domestic undergraduate
directory's source scope. The snapshot is bundled, not a live query.

## Identity and campus handling

- Main IDs use the source's stable school ID: `academyinfo:{schl_id}`. Campus rows
  remain stable campus identities, even when they share an institution. They are
  not separate school choices in the picker.
- Sangmyung Seoul is `academyinfo:0000117`, integration `smu/seoul`; Sangmyung
  Cheonan is `academyinfo:0002959`, integration `smu/cheonan`. The source's generic
  `본교` / `제2캠퍼스` descriptions are retained in `sourceCampus`; their user-facing
  campus names are 서울캠퍼스 / 천안캠퍼스, consistent with the existing sourced
  Sangmyung catalogue. A name match cannot enable an integration.
- The CareerNet public mobile list exposes names, campus names, grouping, regions
  and public websites, but no numeric school identifier. The eleven initial IDs
  use `careernet:` plus the first 16 hex characters of SHA-256 of the original
  `name|campus`. **Preserve the committed ID across renames; do not recompute it
  from an updated name.** No official numeric ID is invented.
- The six special institutions use committed stable `special:` identifiers
  (`kma`, `kna`, `kafa`, `afna`, `kaay`, `knpu`). These are Daily IDs, not government
  school codes.
- Original `name`, `sourceSchoolId`, source and degree grouping remain unchanged.
  Where a published campus name or more useful locality replaces a generic
  label, `sourceCampus` / `sourceRegion` retain the original disclosure text. A
  saved profile retains its selected names for readability after a directory
  update; integration support is always determined from a validated stable ID.
- Schema 2 adds an explicit `institutionId`, `institutionName` and `campusOrder`
  to every row. Institution IDs use `institution:` plus a committed representative
  campus ID. Preserve these IDs across later naming/order changes. A profile may
  store this institution ID together with the existing campus ID; the directory
  continues to resolve legacy campus IDs without rewriting cloud records.
- `UniversityDirectory.byId` / `search` still return campus rows. New
  `institutions`, `institutionById`, `institutionForCampus` and
  `searchInstitutions` expose one school with its campus list. Search considers
  institution/campus/region and reviewed aliases (including 고려대 안암), using
  the same full-text and Hangul-initial rules.

## Collection and renewal

All requests below read public pages; no account or API credential is involved.
This is a release-time snapshot, so clients do not poll these websites.

1. Open the disclosure page and select the intended disclosure year. Its public
   list request is `POST https://m.academyinfo.go.kr/intro/intro0350/selectSchlListAll.do`
   with `svy_yr=2026`, `pageindex=1`, empty `pbnf_area_cd`, and empty `searchVal`.
   Fetch all `paginationInfo.totalPageCount` pages (46 in this snapshot, 10 rows
   per page), verify the final count equals `totalRecordCount` (456), and assert
   every `schl_id` is unique. Include `schl_div_nm` 대학 / 전문대학, excluding only
   대학원대학. Do not guess the meaning of internal status codes to filter rows.
2. The page's official download is `POST https://academyinfo.go.kr/intro/intro0350/FileDown.do`
   with the same form. The 2026 workbook contains 359 undergraduate institution
   rows, using grouped institutions rather than separate campus rows. Comparison
   with the public list covers every institution: the eight 한국폴리텍 groups are
   expanded to their campus rows, and 영산대학교 appears as 양산 / 해운대 rows.
3. Fetch the CareerNet public page with `pageIndex=1&mPageSize=30`, then all 16
   pages. Verify 472 parsed rows match the page's displayed total. Supplement
   only the stated omitted source categories. Check name changes and mergers
   against the current disclosure list before adding any other row.
4. Recheck the six special institutions' official scope and names. Preserve
   existing IDs for unchanged schools; explicitly migrate identity if a merger
   replaces a school.
5. Update `checkedAt`, `dataYear`, source totals and counts; review changed rows.
   Keep source URLs in the asset and this document. Update the corpus expectations
   in `test/core/academic/university_directory_test.dart` after verifying changes.

The source [public-data use policy](https://m.academyinfo.go.kr/footer/footer1560/footer.do)
permits use of university public data, including commercial reuse. Only factual
school-directory data is bundled; source site designs, logos, descriptions and
images are not copied.

Local acquisition evidence is under `work/university-directory/` (ignored work
files, not required at runtime). SHA-256 of the verified input files:

| File | SHA-256 |
| --- | --- |
| `academy-2026.json` | `7e70c0d14a6af1cbf9f440560a34fe22164d765a65e20c15efa100c235bacce6` |
| Official downloaded workbook | `89a1f550b57d0608d9a502eca5c428d2032dd0d5c18e46bb492001a684bc58bd` |
| `career-all.json` | `5925f4e68e5efa4384f5c155dfe5978ce7956ce2203fecaec783499472c54ff5` |

## Verification

`university_directory_test.dart` verifies the bundled row counts and unique IDs,
both source-based degree groups, broad regional/institution coverage, campus
selection, full-text/initial/mixed Hangul search, Latin case-insensitive search,
stable integration identity, and rejection of duplicate/truncated/invalid data.
The loader never substitutes a small fallback list after a data error.

## Institution grouping review (2026-09-25)

The **same 429 campus records** now form **369 school choices**: 226 in the
bachelor group and 143 in the junior-college group. There are 37 groups with
multiple existing campus records. These are picker group counts, not a new claim
about legally independent universities. In particular, a university's separately
disclosed branch can appear beneath the same school choice. No campus row,
source school ID, or integration identity was removed or replaced.

Grouping is an explicit reviewed ID mapping in the asset's `institutionGroups`.
The app never strips parentheses or merges names by similarity. Each mapping
includes its exact campus IDs and source URLs. Its member order is explicit,
with the disclosed main/first campus first. Unrelated Catholic universities and
ICT폴리텍대학 are separate; the eight independently disclosed 한국폴리텍 colleges
retain their separate institution groups, with their existing campus records
underneath each college.

The 2026 대학알리미 download and campus list were compared for all 18 repeated
AcademyInfo names: 가톨릭, 강원, 건양, 경기, 경동, 경인교육, 단국, 명지, 상명,
신한, 안양, 예원예술, 을지, 인제, 인천가톨릭, 전남, 중앙 and 홍익. The two
repeated CareerNet names are 정화예술대학교 and 포스코기술대학. The source's
본교/제2캠퍼스/제3캠퍼스 labels are kept where a more specific name has not been
verified; we do not guess names or invent additional campus identities.

All parenthesized school names in the current corpus were reviewed. The following
primary sources confirm their university/campus relationships, together with the
disclosure records.

| Institution | Existing records presented as campuses | Additional primary source |
| --- | --- | --- |
| 가야대학교 | 김해, 고령 | [University portal footer](https://kplus.kaya.ac.kr/) |
| 건국대학교 | 서울, GLOCAL(글로컬) | [GLOCAL university site](https://www.kku.ac.kr/index.do) |
| 고려대학교 | 서울, 세종 | [Official campus composition](https://www.korea.ac.kr/ko/351/subview.do) |
| 국립목포대학교 | 본교(도림), 담양 | [University history and campus addresses](https://www.mokpo.ac.kr/www/1397/subview.do) |
| 국립창원대학교 | 창원, 거창, 남해 | [University campus guide](https://www.changwon.ac.kr/eduhub/main.do) |
| 동국대학교 | 서울, WISE | [University WISE organization](https://www.dongguk.edu/page/513) |
| 연세대학교 | 본교, 미래 | [University campus site map](https://www.yonsei.ac.kr/sc/209/subview.do) |
| 영산대학교 | 해운대, 양산 | [University campus introduction](https://www3.ysu.ac.kr/kor/Main.do) |
| 한양대학교 | 서울, ERICA | [University ERICA introduction](https://site.hanyang.ac.kr/web/family/erica) |
| 한국폴리텍 I–VII 대학 / 특성화대학 | Existing 32 campus rows in eight college groups | [Official nationwide campus structure](https://www.kopo.ac.kr/intro.do) |

The three requested examples are explicit:

- **상명대학교** `institution:academyinfo:0000117`: 서울캠퍼스
  `academyinfo:0000117` and 천안캠퍼스 `academyinfo:0002959`. Names and localities
  follow the [official campus map](https://map.smu.ac.kr/kor/index.do) and
  [admissions contact addresses](https://admission.smu.ac.kr/apply/program.html).
- **전남대학교** `institution:academyinfo:0000023`: 광주캠퍼스
  `academyinfo:0000023` and 여수캠퍼스 `academyinfo:0000024`. The university's
  [official footer and contact information](https://english.jnu.ac.kr/english/18859/subview.do)
  confirm the campus names and locations. `region` displays 광주 / 여수 so the
  source's common administrative label 전남광주 does not obscure the difference.
- **고려대학교** `institution:academyinfo:0000069`: 서울캠퍼스
  `academyinfo:0000069` and 세종캠퍼스 `academyinfo:0000070`. The official campus
  name is 서울캠퍼스; 안암 and 안암캠퍼스 are search aliases, supported by the
  [university's campus guide](https://frecon.korea.ac.kr/temp_g/info/map.do).

The [operator's report](https://newsroom.posco.com/kr/포스코기술대학-2018학년도-전문학사-40명-배출/)
also identifies 포스코기술대학's 포항/광양 campus names; their existing CareerNet
IDs and regional records determine which of its two records receives each label.

This revision groups the existing source snapshot. It is **not** an exhaustive
new inventory of every physical campus nationwide: some disclosure records
represent more than one physical site, and adding absent campus identities needs
a separate sourced directory renewal. The client must not interpret a one-row
institution as a claim that the university has only one physical campus.

The directory tests verify all 429 IDs survive grouping exactly once, the 369
counts, all 37 source-manifest memberships, the three requested examples,
parenthesized branches, distinct similarly named institutions, explicit campus
order, legacy row lookup, and group/campus/initial search. Malformed membership
metadata and inconsistent institution name/kind are rejected.

## Selection scope and campus presentation (2026-09-26)

The source corpus still contains all **429 stable campus IDs / 369 institutions**.
The latest selection scope is **183 eligible four-year institutions**, with
the degree-kind selector removed. Junior-college and cyber entries remain in
the source corpus for lookup of existing profiles, but cannot be selected.
LH토지주택대학교 is additionally excluded by explicit product scope.
The 22 retained cyber entries
come from the source's `사이버대학(대학)`, `사이버대학(전문대학)`,
`원격대학(대학)` and `원격대학(전문)` categories; their prior degree grouping is
retained as `sourceDegreeKind`. 방송통신대학 remains in its original category.

Four-year eligibility uses the retained source kind; individual exclusions are
explicit data, not a runtime name-substring filter.
Five military academies (육군사관학교, 해군사관학교, 공군사관학교,
국군간호사관학교, 육군3사관학교) and these 18 theology/clergy-training institutions
are excluded from new choices: 감리교신학대학교, 광주가톨릭대학교,
대전가톨릭대학교, 대전신학대학교, 부산장신대학교, 서울신학대학교,
서울장신대학교, 수원가톨릭대학교, 순복음총회신학교, 아신대학교,
영남신학대학교, 영산선학대학교, 장로회신학대학교, 중앙승가대학교,
총신대학교, 한국침례신학대학교, 한일장신대학교, 호남신학대학교.
The source records and existing saved profiles are not deleted or rewritten.
Police University and religious-affiliated comprehensive universities remain;
religious affiliation or one theology department alone is not an exclusion.
The scope is recorded in the asset's `selectionPolicy`. Examples confirming
specialized scope include [ACTS educational purpose](https://acts.ac.kr/design/contents10.asp?code=2010),
[Daejeon Catholic admissions](https://www.dcatholic.ac.kr/univ/s2/college.php),
[Suwon Catholic introduction](https://www.suwoncatholic.ac.kr/),
[Gwangju Catholic admissions](https://admission.gjc.ac.kr/inc/2025univplan.pdf), and
[Youngsan University of Seon Studies](https://www.youngsan.ac.kr/).

Integrated schools are registered at institution level, without a required home
campus. Selecting Sangmyung, Chonnam, or Dankook therefore stores the institution
ID and leaves campus/campusId unset. Their names are primary; official campus
names appear as secondary text (서울 / 천안, 광주 / 여수, 죽전 / 천안).
The five explicitly reviewed branch groups — Korea, Yonsei, Konkuk, Dongguk,
and Hanyang — retain campus selection and a saved campus ID. This is the product's
reviewed selection policy, not a legal reclassification of other universities.
Sources include [Yonsei's current main/branch structure](https://www.yonsei.ac.kr/wj/1483/subview.do),
[Konkuk's regulations](https://rule.konkuk.ac.kr/lmxsrv/law/lawFullContent.do?SEQ=401&SEQ_HISTORY=3403),
[Dongguk WISE organization](https://www.dongguk.edu/page/513), and
[Hanyang's campus map](https://hanyang.ac.kr/web/www/map_erica), alongside the
existing official Korea University campus source above.

`campusNames` contains reviewed official names for display and search. It can
include multiple physical campuses represented by one disclosure row (e.g.
Yonsei's main school includes Sinchon and International campuses). No synthetic
campus IDs are created. Generic source labels such as 본교 or 제2캠퍼스 are kept
in the source rows but are not presented as official physical campus names.
A region is never used to manufacture a campus name. `campusSummary` strips the
repeated 캠퍼스 suffix for concise secondary text.

Additional official-name review:

| Institution | Official display names | Source |
| --- | --- | --- |
| 가천대학교 | 글로벌 / 메디컬 | [Official campus directions](https://www.gachon.ac.kr/buying/2625/subview.do) |
| 가톨릭대학교 | 성심교정 / 성의교정 / 성신교정 | [Official campus portal](https://m.songsin.catholic.ac.kr/ko/index.do) |
| 강원대학교 | 춘천 / 삼척 / 도계 / 강릉 / 원주 | [Admissions](https://admission.kangwon.ac.kr/admission/main.do), [2026 graduate admissions](https://graduate.kangwon.ac.kr/graduate/notice/on-campus.do?articleNo=559205&mode=view) |
| 건양대학교 | 글로컬 / 메디컬 | [2026 official site](https://www.konyang.ac.kr/kor.do) |
| 경기대학교 | 수원 / 서울 | [Admissions footer](https://enter.kyonggi.ac.kr/cms/FR_CON/index.do?MENU_ID=80) |
| 경동대학교 | 글로벌 / 메디컬 / 메트로폴 | [Official sitemap](https://www.kduniv.ac.kr/kor/CMS/SiteMap/SiteMapLayer.do) |
| 경인교육대학교 | 인천 / 경기 | [Official LMS](https://lms.ginue.ac.kr/?epTicket=LOG) |
| 경희대학교 | 서울 / 국제 / 광릉 | [Official campus map](https://www.khu.ac.kr/kor/user/mapManager/view.do?menuNo=200357) |
| 단국대학교 | 죽전 / 천안 | [Official campus map](https://dankook.ac.kr/campusmap) |
| 명지대학교 | 자연 / 인문 | [Official department/contact page](https://www.mju.ac.kr/mjukr/192/subview.do) |
| 성균관대학교 | 인문사회과학 / 자연과학 | [Official student campus map](https://student.skku.edu/student/in_cen.do) |
| 신한대학교 | 의정부 / 동두천 | [Official campus page](https://www.shinhan.ac.kr/kr/231/subview.do) |
| 안양대학교 | 안양 / 강화 | [Official campus guide](https://www.anyang.ac.kr/main/introduction/anyang-campus-map.do) |
| 예원예술대학교 | 전북희망 / 경기드림 | [Official footer](https://www.yewon.ac.kr/) |
| 을지대학교 | 대전 / 성남 / 의정부 | [Official course guide](https://www.eulji.ac.kr/webshr/univ/download/2021Guide.pdf) |
| 인제대학교 | 김해 / 부산 | [Official safety guide](https://safety.inje.ac.kr/safety/management/aed.do) |
| 인천가톨릭대학교 | 강화 / 송도국제 | [Official campus portal](https://shin.iccu.ac.kr/) |
| 중앙대학교 | 서울 / 다빈치 | [Official campus map](https://www.cau.ac.kr/cms/FR_CON/index.do?CAMPUS_MAP=2&MENU_ID=610) |
| 홍익대학교 | 서울 / 세종 | [Official site](https://www.hongik.ac.kr/kr/index.do) |
| 한국외국어대학교 | 서울 / 글로벌 | [Official campus facts](https://hufs.ac.kr/hufs/11142/subview.do) |
| 연세대학교 | 신촌 / 국제 / 미래 | [2026 school structure](https://www.yonsei.ac.kr/wj/1483/subview.do) |

Existing names verified in the September 25 review remain. This is still not an
exhaustive physical-campus inventory beyond the sourced records; missing names
are not replaced by a city, invented generic label, or unverified campus.

The September 26 follow-up fills the verified names above for Gachon, Kyung Hee,
Sungkyunkwan and HUFS, each represented by one disclosure row. Their original
IDs and integrated selection behavior remain; `campusNameSourceUrls` records
each official source. Both university-and-campus text and initial-consonant
search now find these institutions without creating extra campus identities.
