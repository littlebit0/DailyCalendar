"""Send the documented anonymous catalog query using its published serializer.

Only encryption of our outgoing request occurs. No response decryption, login,
browser state extraction, token manipulation, or session persistence.
"""
import base64
import json
import secrets
import urllib.request
from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from kumoh_anonymous_bootstrap import bootstrap, UA


def encrypt(value, key):
    # Published PatisUtils.encryptDataForAES, outgoing request only.
    if not value or not key:
        return value
    key_bytes = key.replace('-', '')[:16].encode()
    padder = padding.PKCS7(128).padder()
    data = padder.update(str(value).encode()) + padder.finalize()
    encoder = Cipher(algorithms.AES(key_bytes), modes.CBC(key_bytes)).encryptor()
    return base64.b64encode(encoder.update(data) + encoder.finalize()).decode()


def public_query(opener, referer, initial, service, method, query_parameters):
    transaction = secrets.token_hex(16)
    parameters = dict(query_parameters)
    parameters.update({
        'FRAMEWORK_SERVICE_NAME': service,
        'FRAMEWORK_METHOD_NAME': method,
        'FRAMEWORK_LANGUAGE_GB': 'ko',
        'FRAMEWORK_TRANSACTION_ID': transaction,
        'FRAMEWORKLOG_PROTOCOL': 'JSON',
        'FRAMEWORK_SESSION_USER': initial['gv_sessionUser'],
        'FRAMEWORK_FRAME_GB': '3',
        'FRAMEWORK_FRAME_INFO': initial['gv_gb'],
        'FRAMEWORK_MENU_CD': initial['MENU_CD'],
    })
    encoded = {}
    index = 1
    for key, value in parameters.items():
        if key == 'FRAMEWORK_TRANSACTION_ID':
            encoded['FRAMEWORKLOG_PARAM0'] = [encrypt(key, initial['gv_sessionUser'])]
            encoded['FRAMEWORKLOG_VALUE0'] = [encrypt(value, initial['gv_sessionUser'])]
        else:
            encoded[f'FRAMEWORKLOG_PARAM{index}'] = [encrypt(key, transaction)]
            encoded[f'FRAMEWORKLOG_VALUE{index}'] = [encrypt(value, transaction)]
            index += 1
    # Published Cleopatra JSONRequestBuilder: {param: {name: [values]}}.
    request = urllib.request.Request(
        'https://kit.kumoh.ac.kr/patis/system/serviceController.do',
        data=json.dumps({'param': encoded}).encode(),
        headers={'User-Agent': UA, 'Referer': referer,
                 'Content-Type': 'application/json'},
    )
    with opener.open(request, timeout=40) as response:
        body = response.read().decode('utf-8', errors='replace')
        return response.status, body


def catalog_query():
    opener, referer, initial = bootstrap()
    # Retrieve the normal public department combo to avoid guessing its code.
    _, body = public_query(opener, referer, initial, 'UcCrclmCombo',
                           'DeptSeComboSelect', {
        'SQLMAP_VALUE': '01', 'DEPT_FLAG': '1', 'MENU_CD': initial['MENU_CD'],
        'OGNZ_CLSF_SE': '1', 'ROLE_CD': '', 'YEAR': '2026', 'SHTM': '2',
        'STU_DEPT_CD': '', 'OGNZ_HEAD': 'NONE', 'DEPT_HEAD': 'NONE',
        'MAINAGNT_HEAD': 'ALLSTRING', 'SBJCT_KND_HEAD': 'ALLSTRING',
        'CRCLM_HEAD': 'ALLSTRING', 'DEPT_HEAD_VISIBLE': 'true',
        'MAINAGNT_HEAD_VISIBLE': 'true', 'SBJCT_KND_HEAD_VISIBLE': 'true',
        'CRCLM_HEAD_VISIBLE': 'true',
    })
    choices = json.loads(body).get('ds_out01', [])
    undergraduate = [row for row in choices if row.get('DATA') == '학부']
    if len(undergraduate) != 1:
        raise ValueError('Public undergraduate department choice not confirmed')
    return public_query(opener, referer, initial, 'Ul0307Service', 'selectList01', {
        'YR': '2026', 'SCTM': '2', 'OGNZ_CLSF_SE': '1',
        'DEPT_SE': undergraduate[0]['CODE'], 'MAINAGNT_SE': '',
        'SBJCT_KND_SE': '', 'CRCLM_CD': '', 'CTRT_SSJ_YN': '', 'SBJCT_CD': '',
    })


if __name__ == '__main__':
    status, body = catalog_query()
    # Do not print raw response or any session-related value.
    print(json.dumps({'status': status, 'bytes': len(body),
                      'isJson': body.lstrip().startswith('{'),
                      'containsCatalogDataset': 'ds_out' in body,
                      'containsKnownPublicCourse': 'LA0114' in body}))
