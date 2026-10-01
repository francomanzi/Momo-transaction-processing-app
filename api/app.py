

import base64
import json
import os
import re
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dsa.parse_xml import parse_xml, JSON_PATH

HOST = os.getenv('API_HOST', '127.0.0.1')
PORT = int(os.getenv('API_PORT', '8000'))
API_USER = os.getenv('API_USER', 'admin')
API_PASS = os.getenv('API_PASS', 'Maureen123!')

TRANSACTIONS = []
NEXT_ID = 1


def load_data():
    """Load transactions from the parsed JSON file, or parse the XML."""
    global TRANSACTIONS, NEXT_ID
    if os.path.exists(JSON_PATH):
        with open(JSON_PATH, encoding='utf-8') as handle:
            TRANSACTIONS = json.load(handle)
    else:
        TRANSACTIONS = parse_xml()
    if TRANSACTIONS:
        NEXT_ID = max(record['id'] for record in TRANSACTIONS) + 1


def parse_path(path):
    """Split /transactions or /transactions/{id}; return (is_match, id)."""
    match = re.fullmatch(r'/transactions(?:/(\d+))?/?', path)
    if not match:
        return False, None
    id_value = match.group(1)
    return True, int(id_value) if id_value else None


class ApiHandler(BaseHTTPRequestHandler):
    server_version = 'MoMoAPI/1.0'

    def send_json(self, status, payload):
        body = json.dumps(payload).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def is_authorized(self):
        header = self.headers.get('Authorization', '')
        if not header.startswith('Basic '):
            return False
        try:
            decoded = base64.b64decode(header[6:]).decode('utf-8')
            username, _, password = decoded.partition(':')
        except Exception:
            return False
        return username == API_USER and password == API_PASS

    def require_auth(self):
        """Send 401 if credentials are missing or wrong. Return True if OK."""
        if not self.is_authorized():
            self.send_response(401)
            self.send_header('WWW-Authenticate', 'Basic realm="momo_api"')
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', '0')
            self.end_headers()
            return False
        return True

    def not_found(self, message):
        self.send_json(404, {'error': message})

    def bad_request(self, message):
        self.send_json(400, {'error': message})

    def read_body(self):
        """Read and decode the JSON body; return dict or None if invalid."""
        try:
            length = int(self.headers.get('Content-Length', '0'))
        except ValueError:
            return None
        if length <= 0:
            return None
        try:
            data = json.loads(self.rfile.read(length).decode('utf-8'))
        except Exception:
            return None
        return data if isinstance(data, dict) else None

    # ------------------------- handlers -------------------------

    def do_GET(self):
        if not self.require_auth():
            return
        matches, record_id = parse_path(self.path)
        if not matches:
            self.send_json(404, {'error': 'Not found'})
            return
        if record_id is None:
            self.send_json(200, TRANSACTIONS)
            return
        for record in TRANSACTIONS:
            if record['id'] == record_id:
                self.send_json(200, record)
                return
        self.not_found(f'transaction {record_id} not found')

    def do_POST(self):
        if not self.require_auth():
            return
        matches, _ = parse_path(self.path)
        if not matches:
            self.send_json(404, {'error': 'Not found'})
            return
        global NEXT_ID
        data = self.read_body()
        if data is None:
            self.bad_request('body must be a valid JSON object')
            return
        data['id'] = NEXT_ID
        NEXT_ID += 1
        TRANSACTIONS.append(data)
        self.send_json(201, data)

    def do_PUT(self):
        if not self.require_auth():
            return
        matches, record_id = parse_path(self.path)
        if not matches or record_id is None:
            self.send_json(404, {'error': 'Not found'})
            return
        data = self.read_body()
        if data is None:
            self.bad_request('body must be a valid JSON object')
            return
        for record in TRANSACTIONS:
            if record['id'] == record_id:
                record.update(data)
                record['id'] = record_id
                self.send_json(200, record)
                return
        self.not_found(f'transaction {record_id} not found')

    def do_DELETE(self):
        if not self.require_auth():
            return
        matches, record_id = parse_path(self.path)
        if not matches or record_id is None:
            self.send_json(404, {'error': 'Not found'})
            return
        for index, record in enumerate(TRANSACTIONS):
            if record['id'] == record_id:
                removed = TRANSACTIONS.pop(index)
                self.send_json(200, removed)
                return
        self.not_found(f'transaction {record_id} not found')

    def log_message(self, format, *args):
        pass


def main():
    load_data()
    server = ThreadingHTTPServer((HOST, PORT), ApiHandler)
    print(f'MoMo API running on http://{HOST}:{PORT}  (user: {API_USER})')
    print(f'Loaded {len(TRANSACTIONS)} transactions')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nShutting down.')
        server.shutdown()


if __name__ == '__main__':
    main()