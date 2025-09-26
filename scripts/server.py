from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import time
import base64

HOST = "0.0.0.0"
PORT = 8000

USERNAME = "admin"
PASSWORD = "secret"
BEARER_TOKEN = "abc123-def456-ghi789"
API_KEY = "secret-api-key-123"

# OAuth Configuration
OAUTH_CLIENT_ID = "test_client_id"
OAUTH_CLIENT_SECRET = "test_client_secret"
OAUTH_COGNITO_CLIENT_ID = "cognito_client_123"
OAUTH_COGNITO_CLIENT_SECRET = "cognito_secret_456"
OAUTH_AUTH0_CLIENT_ID = "auth0_client_789"
OAUTH_AUTH0_CLIENT_SECRET = "auth0_secret_abc"
OAUTH_APIGEE_CLIENT_ID = "apigee_client_def"
OAUTH_APIGEE_CLIENT_SECRET = "apigee_secret_ghi"

class SimpleHandler(BaseHTTPRequestHandler):
    def _log_headers(self):
        """Helper: log incoming request headers"""
        print(f"Headers for {self.command} {self.path}:")
        for header, value in self.headers.items():
            print(f"  {header}: {value}")
        print()

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

    def _unauthorized_apikey(self):
        """Helper: send 401 response for API key authentication"""
        self.send_response(401)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"error":"Invalid API key"}')

    def _validate_basic_auth(self, expected_client_id, expected_client_secret):
        """Helper: validate OAuth Basic Auth credentials"""
        auth_header = self.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Basic "):
            return False

        try:
            encoded = auth_header.split(" ", 1)[1]
            decoded = base64.b64decode(encoded).decode("utf-8")
            client_id, client_secret = decoded.split(":", 1)
            return client_id == expected_client_id and client_secret == expected_client_secret
        except Exception:
            return False

    def _oauth_error(self, error, description=""):
        """Helper: send OAuth error response"""
        response = {"error": error}
        if description:
            response["error_description"] = description
        self._send_json(response, 400)

    def _oauth_success(self, token_suffix=""):
        """Helper: send OAuth success response"""
        self._send_json({
            "access_token": f"oauth_token_{token_suffix}_{int(time.time())}",
            "token_type": "Bearer",
            "expires_in": 3600,
            "scope": "read:users write:orders"
        })

    def do_GET(self):
        self._log_headers()
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
        elif self.path == "/apikey":
            # GET endpoint with API Key Auth (supports both Authorization header and X-API-Key)
            auth_header = self.headers.get("Authorization")
            api_key_header = self.headers.get("X-API-Key")

            api_key = None

            # Check Authorization header first
            if auth_header and auth_header.startswith("ApiKey "):
                api_key = auth_header.split(" ", 1)[1].strip()
            # Fall back to X-API-Key header
            elif api_key_header:
                api_key = api_key_header.strip()

            if not api_key:
                self._unauthorized_apikey()
                return

            if api_key == API_KEY:
                self._send_json({"apikey": "success", "key": "valid"})
            else:
                self._unauthorized_apikey()
        elif self.path == "/oauth-test":
            # GET endpoint to test OAuth tokens
            auth_header = self.headers.get("Authorization")
            if not auth_header or not auth_header.startswith("Bearer "):
                self._unauthorized_bearer()
                return

            token = auth_header.split(" ", 1)[1].strip()
            if token.startswith("oauth_token_"):
                # Extract provider from token (oauth_token_generic_123456)
                parts = token.split("_")
                provider = parts[2] if len(parts) >= 3 else "unknown"
                self._send_json({
                    "oauth_test": "success",
                    "token_valid": True,
                    "provider": provider,
                    "token_prefix": token[:20] + "..."
                })
            else:
                self._unauthorized_bearer()
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'{"error":"Not Found"}')

    def do_POST(self):
        self._log_headers()
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
        elif self.path == "/oauth/token":
            # Generic OAuth token endpoint (Basic Auth + form data)
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length).decode('utf-8')

            if "grant_type=client_credentials" not in body:
                self._oauth_error("unsupported_grant_type", "Only client_credentials supported")
                return

            if self._validate_basic_auth(OAUTH_CLIENT_ID, OAUTH_CLIENT_SECRET):
                self._oauth_success("generic")
            else:
                self._oauth_error("invalid_client", "Invalid client credentials")
        elif self.path == "/oauth2/token":
            # AWS Cognito style (Basic Auth + form data)
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length).decode('utf-8')

            if "grant_type=client_credentials" not in body:
                self._oauth_error("unsupported_grant_type")
                return

            if self._validate_basic_auth(OAUTH_COGNITO_CLIENT_ID, OAUTH_COGNITO_CLIENT_SECRET):
                self._oauth_success("cognito")
            else:
                self._oauth_error("invalid_client")
        elif self.path == "/oauth/token/auth0":
            # Auth0 style (JSON body)
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length).decode('utf-8')

            try:
                data = json.loads(body)
                if data.get("grant_type") != "client_credentials":
                    self._oauth_error("unsupported_grant_type")
                    return

                if (data.get("client_id") == OAUTH_AUTH0_CLIENT_ID and
                    data.get("client_secret") == OAUTH_AUTH0_CLIENT_SECRET):
                    self._oauth_success("auth0")
                else:
                    self._oauth_error("invalid_client")
            except json.JSONDecodeError:
                self._oauth_error("invalid_request", "Invalid JSON body")
        elif self.path == "/oauth/v2/accesstoken":
            # Apigee style (form data in body)
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length).decode('utf-8')

            # Parse form data
            params = {}
            for param in body.split('&'):
                if '=' in param:
                    key, value = param.split('=', 1)
                    params[key] = value

            if params.get("grant_type") != "client_credentials":
                self._oauth_error("unsupported_grant_type")
                return

            if (params.get("client_id") == OAUTH_APIGEE_CLIENT_ID and
                params.get("client_secret") == OAUTH_APIGEE_CLIENT_SECRET):
                self._oauth_success("apigee")
            else:
                self._oauth_error("invalid_client")
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'{"error":"Not Found"}')


if __name__ == "__main__":
    server = HTTPServer((HOST, PORT), SimpleHandler)
    print(f"Serving on http://{HOST}:{PORT}")
    server.serve_forever()

