from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import time
import base64

HOST = "0.0.0.0"
PORT = 8000

USERNAME = "admin"
PASSWORD = "secret"
BEARER_TOKEN = "abc123-def456-ghi789"

class SimpleHandler(BaseHTTPRequestHandler):
    def _send_json(self, obj, status=200):
        """Helper: send JSON response"""
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(obj).encode("utf-8"))

    def _unauthorized(self):
        """Helper: send 401 response with Basic Auth challenge"""
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="Login Required"')
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"error":"Unauthorized"}')

    def _unauthorized_bearer(self):
        """Helper: send 401 response with Bearer Auth challenge"""
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Bearer realm="API Access"')
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"error":"Bearer token required"}')

    def do_GET(self):
        if self.path == "/hello":
            # simple GET endpoint
            self._send_json({"hello": "world"})
        elif self.path == "/slow":
            # slow GET endpoint (wait 1 second)
            time.sleep(1)
            self._send_json({"status": "slow response"})
        elif self.path == "/bearer":
            # GET endpoint with Bearer Auth
            auth_header = self.headers.get("Authorization")
            if not auth_header or not auth_header.startswith("Bearer "):
                self._unauthorized_bearer()
                return

            token = auth_header.split(" ", 1)[1].strip()
            if token == BEARER_TOKEN:
                self._send_json({"bearer": "success", "token": "valid"})
            else:
                self._unauthorized_bearer()
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'{"error":"Not Found"}')

    def do_POST(self):
        if self.path == "/echo":
            # simple POST endpoint
            self._send_json({"message": "This is a POST response"})
        elif self.path == "/secure":
            # POST endpoint with Basic Auth
            auth_header = self.headers.get("Authorization")
            if not auth_header or not auth_header.startswith("Basic "):
                self._unauthorized()
                return

            try:
                encoded = auth_header.split(" ", 1)[1]
                decoded = base64.b64decode(encoded).decode("utf-8")
                username, password = decoded.split(":", 1)
            except Exception:
                self._unauthorized()
                return

            if username == USERNAME and password == PASSWORD:
                self._send_json({"secure": "success", "user": username})
            else:
                self._unauthorized()
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'{"error":"Not Found"}')


if __name__ == "__main__":
    server = HTTPServer((HOST, PORT), SimpleHandler)
    print(f"Serving on http://{HOST}:{PORT}")
    server.serve_forever()

