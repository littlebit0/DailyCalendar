#!/bin/sh
# 조선대 개설교과목조회 공개 화면(비로그인)을 브라우저와 같은 순서로 curl로 받는다.
# robots.txt(a.chosun.ac.kr: Disallow: /) 차단 경로를 사용자 결정(2026-10-23)에 따라 직접 조회. 요청 간격 1초 이상.
set -e
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36 DailyCalendar/1.0 (+https://github.com/littlebit0/DailyCalendar)'
OUT=${1:?출력 폴더}; J=$OUT/cj; S=$(dirname "$0")
curl -s -A "$UA" -c $J -b $J -L -o $OUT/gaeseol.html https://a.chosun.ac.kr/S/sugang/gaeseol; sleep 1
KEY=$(sed -n 's/.*name="MENU_KEY" value="\([^"]*\)".*/\1/p' $OUT/gaeseol.html)
curl -s -A "$UA" -c $J -b $J -d "method=checkURL&MENU_KEY=$KEY" -o $OUT/step2.html https://a.chosun.ac.kr/patis/common/OutLinkController.do; sleep 1
SU=$(sed -n 's/.*"gv_sessionUser":"\([^"]*\)".*/\1/p' $OUT/step2.html)
post() { python3 -I $S/build_req.py "$SU" hl_0308000_service $1 8021602000 "$2" > $OUT/req.json
  curl -s -A "$UA" -c $J -b $J -H 'Content-Type: application/json' --data-binary @$OUT/req.json -o $3 \
    "https://a.chosun.ac.kr/haksa/patis/system/serviceController.do?SN=hl_0308000_service&MN=$1"; sleep 1; }
post selectInitData '{}' $OUT/init.json
post selectList '{"YEAR":"2026","HAKGI_GB":"21","CORS_GB":"1","DAEHAK_CD":"","HAKGWA_CD":"","GANGUI_GB":"","GYOGWA_GB":"","ISU_GB":"","TEAM_TEACHING_YN":"0","GWAMOK_CD":"","JUYA_GB":"","PYEGANG_YN":"2","GYOSU_NO":"","HAKSAENG_CHK":"","MENU_CD":"8021602000","USER_ID":"","USER_ID_GB":""}' $OUT/list.tsv
rm -f $J $OUT/req.json
# list.tsv에는 담당교수 연락처 열(HP_NO, EMAIL)이 있다. 저장 전에 빼고 원본은 지운다.
