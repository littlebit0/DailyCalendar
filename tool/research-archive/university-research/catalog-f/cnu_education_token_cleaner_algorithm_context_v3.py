"""Remove private/contact/access values while preserving neighboring education."""
import html
import re

COUNTS = {}
# Actual HTML markup only: course titles and teaching instructions may use
# literal angle brackets, which must remain educational text.
HTML_TAGS = frozenset(('a abbr address area article aside audio b base bdi bdo blockquote body br button canvas caption cite code col colgroup data datalist dd del details dfn dialog div dl dt em embed fieldset figcaption figure footer form h1 h2 h3 h4 h5 h6 head header hgroup hr html i iframe img input ins kbd label legend li link main map mark menu meta meter nav noscript object ol optgroup option output p picture pre progress q rp rt ruby s samp script search section select slot small source span strong style sub summary sup table tbody td template textarea tfoot th thead time title tr track u ul var video wbr font center strike').split())

def educational_html_text(value):
    def markup(match):
        tag = re.match(r'</?\s*([A-Za-z][A-Za-z0-9]*)\b', match.group())
        if tag and tag.group(1).lower() in HTML_TAGS:
            return ' '
        return match.group()
    value = re.sub(r'<(?:br\s*/?|/p|/div|/li)>', '\n', value, flags=re.I)
    value = re.sub(r'<!--[\s\S]*?-->', ' ', value)
    return html.unescape(re.sub(r'<[^>]*>', markup, value))

def replace(pattern, replacement, value, label, flags=0):
    value, count = re.subn(pattern, replacement, value, flags=flags)
    COUNTS[label] = COUNTS.get(label, 0) + count
    return value

def clean(value):
    if not isinstance(value, str):
        return value
    value = educational_html_text(value)
    value = replace(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}', '[contact removed]', value, 'email')
    value = replace(r'(?<!\d)(?:\+82[- ]?)?0\d{1,2}[- .]\d{3,4}[- .]\d{4}(?!\d)', '[contact removed]', value, 'phone')
    value = replace(r'(?<!\d)\d{3}\s+\d{4}\s+\d{4}(?!\d)', '[access_removed]', value, 'meetingValue')
    value = replace(r'https?://[^\s<>]+|www\.[^\s<>]+', '[link removed]', value, 'url', re.I)
    value = replace(r'(^[^\n]*(?:zoom|화상|회의|meeting|담당교수)[^\n]*?\[link removed\])(?:[ \t]+\d{4}){2}(?!\d)', r'\1 [access removed]', value, 'urlAdjacentAccessSuffix', re.I|re.M)
    value = replace(r'(?<!\d)\d{3}[- ]\d{4}(?!\d)', '[contact removed]', value, 'shortPhone')
    labels = r'회의\s*(?:ID|아이디|암호|비밀번호)|meeting\s*(?:id|passcode|password)|(?:접속|입장)\s*(?:코드|암호|비밀번호)|담당\s*교수\s*(?:ID|아이디)|암호(?!\s*(?:알고리즘|/복호|프로그래밍|기반|작성|및|방식|라이브러리))|비밀번호|password|passcode'
    value = replace(r'((?:'+labels+r')(?:\s*[:：=]\s*|\s+))[^\s,;]+', r'\1[access removed]', value, 'labelledAccess', re.I)
    if re.search(r'(?:개인|자택|본인)\s*주소\s*[:：]', value):
        raise ValueError('private-address value boundary ambiguous; no field persisted')
    value = replace(r'((?:계좌\s*번호|주민등록번호)\s*[:：]\s*)[\d -]+', r'\1[private number removed]', value, 'privateNumber')
    value = value.replace('[access_removed]', '[access removed]')
    lines = []
    for line in value.splitlines():
        if '호적등재오류' in line and '개명' in line:
            if re.search(r'수업|휴강|보강|교시|시간표|현장|실습|시험|종강|개강|요일|온라인|원격|대면|비대면|녹화|[0-9]{1,2}[:：][0-9]{2}|(?:교|공|자|인|생|글로벌|산학연)[0-9]{2,4}[A-Z]?', line):
                raise ValueError('biography and education share a line; no field persisted')
            # Previously reviewed exact noninstructional biography line, no lesson context.
            COUNTS['previouslyReviewedNoninstructionalBiography'] = COUNTS.get('previouslyReviewedNoninstructionalBiography', 0) + 1
            continue
        lines.append(line)
    return '\n'.join(lines).strip()

if __name__ == '__main__':
    assert clean('휴강 9월 24일 연락 sample@example.org 보강 12월 10일') == '휴강 9월 24일 연락 [contact removed] 보강 12월 10일'
    assert clean('교수 042-123-4567 수업 목14:00~15:00 교301') == '교수 [contact removed] 수업 목14:00~15:00 교301'
    assert clean('회의 ID: 123456789 수업은 실시간이며 화10시 시작') == '회의 ID: [access removed] 수업은 실시간이며 화10시 시작'
    assert clean('비밀번호: abc123 보강은 12월 10일') == '비밀번호: [access removed] 보강은 12월 10일'
    assert clean('회의 ID 123456789 수업 화10시') == '회의 ID [access removed] 수업 화10시'
    assert clean('회의 123 4567 8901 보강12월10일') == '회의 [access removed] 보강12월10일'
    assert clean('zoom 주소: https://example.org/123 4567 8901 수업 화10시') == 'zoom 주소: [link removed] 수업 화10시'
    assert clean('zoom 주소: [link removed] 4567 8901 수업 화10시') == 'zoom 주소: [link removed] [access removed] 수업 화10시'
    assert clean('<p><일본어연습> 이수 또는 동등 실력</p>') == '<일본어연습> 이수 또는 동등 실력'
    assert clean('<수업없음 9월24일> 보강 12월10일') == '<수업없음 9월24일> 보강 12월10일'
    assert clean('<span>수업</span><br><별도 강의실 교301>') == '수업 \n<별도 강의실 교301>'
    assert clean('&lt;일본어연습&gt; 이수') == '<일본어연습> 이수'
    print('12 token-only and literal-angle education-preservation checks passed')

assert clean("대칭키 암호 알고리즘인 AES와 암호 알고리즘, 암호/복호 기능") == "대칭키 암호 알고리즘인 AES와 암호 알고리즘, 암호/복호 기능"

assert clean("암호 프로그래밍 암호 기반 암호 작성 암호 및 AES 암호 방식 암호 라이브러리") == "암호 프로그래밍 암호 기반 암호 작성 암호 및 AES 암호 방식 암호 라이브러리"
assert clean("회의 암호: secret 교육 암호 방식") == "회의 암호: [access removed] 교육 암호 방식"
