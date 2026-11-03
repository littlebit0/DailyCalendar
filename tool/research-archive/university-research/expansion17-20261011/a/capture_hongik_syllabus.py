import json, pathlib, time

P = pathlib.Path(__file__).parent
URL = 'https://cn.hongik.ac.kr/app/timetable/hak03_syllabus01.jsp?p_yy=2026&p_hakgi=2&p_haksu=001023&p_bunban=1'


class Capture:
    """#219: each Network.getResponseBody gets its own command ID, and its
    answer (body, empty body, base64 or error) is recorded on that one request."""

    def __init__(self, first_command_id=100):
        self.requests = []
        self._next_command_id = first_command_id
        self._pending = {}  # command ID -> request ID

    def handle(self, message, send):
        method = message.get('method')
        if method == 'Network.requestWillBeSent':
            r = message['params']['request']
            self.requests.append({'id': message['params']['requestId'], 'url': r['url'],
                                  'method': r['method'], 'postData': r.get('postData')})
        elif method == 'Network.responseReceived':
            request_id = message['params']['requestId']
            r = message['params']['response']
            command_id = self._next_command_id
            self._next_command_id += 1
            self._pending[command_id] = request_id
            for x in self.requests:
                if x['id'] == request_id:
                    x.update({'status': r['status'], 'mimeType': r['mimeType'], 'responseCall': command_id})
            send({'id': command_id, 'method': 'Network.getResponseBody', 'params': {'requestId': request_id}})
        elif 'id' in message and message['id'] in self._pending:
            request_id = self._pending.pop(message['id'])
            for x in self.requests:
                if x['id'] == request_id and x.get('responseCall') == message['id']:
                    if 'error' in message:
                        x['bodyError'] = message['error']
                    else:
                        x['body'] = message['result'].get('body', '')
                        x['base64'] = message['result'].get('base64Encoded', False)


def main():
    import requests, websocket
    pg = requests.put('http://localhost:64244/json/new?about:blank').json()
    P.joinpath('hongik-syllabus-target.json').write_text(json.dumps({'id': pg['id'], 'url': URL}))
    w = websocket.create_connection(pg['webSocketDebuggerUrl'], origin='http://localhost:64244', timeout=2)
    send = lambda value: w.send(json.dumps(value))
    send({'id': 1, 'method': 'Network.enable'})
    send({'id': 2, 'method': 'Page.navigate', 'params': {'url': URL}})
    capture = Capture()
    end = time.time() + 15
    while time.time() < end:
        try:
            m = json.loads(w.recv())
        except websocket.WebSocketTimeoutException:
            continue
        capture.handle(m, send)
    req = capture.requests
    P.joinpath('hongik-syllabus-network.json').write_text(json.dumps(req, ensure_ascii=False, indent=2))
    print([(r['url'], r.get('status'), len(r.get('body', '')), (r.get('postData') or '')[:150]) for r in req if 'ReportingServer' in r['url']])
    send({'id': 99, 'method': 'Runtime.evaluate', 'params': {'expression': 'document.body.innerText', 'returnByValue': True}})
    while 1:
        try:
            m = json.loads(w.recv())
        except websocket.WebSocketTimeoutException:
            break
        if m.get('id') == 99:
            print(m['result']['result'].get('value', '')[:1000])
            break


if __name__ == '__main__':
    main()
