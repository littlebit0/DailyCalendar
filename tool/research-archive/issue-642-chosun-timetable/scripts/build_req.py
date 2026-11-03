# 조선대 공개 개설강좌 화면(a.chosun.ac.kr) 클라이언트가 만드는 요청 본문을 그대로 재현한다.
import json, subprocess, sys, base64, secrets
def enc(data, key):
    k = key.replace('-', '')[:16].encode().hex()
    out = subprocess.run(['openssl', 'enc', '-aes-128-cbc', '-K', k, '-iv', k, '-base64', '-A'],
                         input=str(data).encode(), capture_output=True, check=True).stdout.decode()
    return out
session_user, service, method, menu_cd, params_json = sys.argv[1:6]
params = json.loads(params_json)
txid = str(secrets.randbits(32)) + str(secrets.randbits(32))
params.update({
    'FRAMEWORK_SERVICE_NAME': service, 'FRAMEWORK_METHOD_NAME': method,
    'FRAMEWORK_LANGUAGE_GB': 'ko', 'FRAMEWORK_TRANSACTION_ID': txid,
    'FRAMEWORKLOG_PROTOCOL': 'JSON', 'FRAMEWORK_SESSION_USER': session_user,
    'FRAMEWORK_FRAME_GB': '3', 'FRAMEWORK_FRAME_INFO': 'outlink', 'FRAMEWORK_MENU_CD': menu_cd,
})
p = {}
for no, (key, value) in enumerate(params.items(), start=1):
    value = '' if value is None else str(value)
    if key == 'FRAMEWORK_TRANSACTION_ID':
        p['FRAMEWORKLOG_PARAM0'] = [enc(key, session_user)]
        p['FRAMEWORKLOG_VALUE0'] = [enc(value, session_user)]
    else:
        if value in ('undefined', 'null'):
            value = ''
        p[f'FRAMEWORKLOG_PARAM{no}'] = [enc(key, txid)]
        p[f'FRAMEWORKLOG_VALUE{no}'] = [enc(value, txid) if value else value]
print(json.dumps({'param': p}))
