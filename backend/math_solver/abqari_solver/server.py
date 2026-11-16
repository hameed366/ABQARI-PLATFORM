"""A tiny HTTP service that lets the app reach the engine on the same device.

Run inside the app by the embedded Python runtime. It is not a network
service: it binds to the loopback interface only, and every request must
carry the secret token the app generated for this launch, so other apps on
the phone cannot use it. Problems are never logged.

    ABQARI_PORT=… ABQARI_TOKEN=… python main.py

GET  /health  → {"ready": true, "engine_version": "…"}
POST /solve   {"text": "…", "task"?: "…", "variable"?: "…"} → the engine result
"""
from __future__ import annotations

import hmac
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from .version import ENGINE_VERSION

MAX_BODY = 8192
TOKEN_HEADER = "X-Abqari-Token"


def make_server(token: str, port: int = 0, host: str = "127.0.0.1") -> ThreadingHTTPServer:
    if len(token) < 32:
        raise ValueError("the token must be at least 32 characters")
    if host not in ("127.0.0.1", "::1", "localhost"):
        raise ValueError("the engine service only listens on the loopback interface")

    class Handler(BaseHTTPRequestHandler):
        server_version = "abqari-engine"
        sys_version = ""

        def log_message(self, *args) -> None:  # never log problems or tokens
            return

        def _authorised(self) -> bool:
            supplied = self.headers.get(TOKEN_HEADER, "")
            return hmac.compare_digest(supplied.encode(), token.encode())

        def _reply(self, status: int, payload: dict) -> None:
            data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self) -> None:  # noqa: N802 (http.server naming)
            if not self._authorised():
                self._reply(403, {"error": "forbidden"})
            elif self.path == "/health":
                self._reply(200, {"ready": True, "engine_version": ENGINE_VERSION})
            else:
                self._reply(404, {"error": "not_found"})

        def do_POST(self) -> None:  # noqa: N802
            if not self._authorised():
                self._reply(403, {"error": "forbidden"})
                return
            if self.path != "/solve":
                self._reply(404, {"error": "not_found"})
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
            except ValueError:
                length = -1
            if length < 0 or length > MAX_BODY:
                self._reply(413, {"error": "too_large"})
                return
            try:
                body = json.loads(self.rfile.read(length).decode("utf-8"))
                text = body["text"]
                if not isinstance(text, str):
                    raise TypeError
            except (ValueError, KeyError, TypeError, UnicodeDecodeError):
                self._reply(400, {"error": "bad_request"})
                return
            from .engine import solve  # imported on first use; SymPy is slow to load

            try:
                result = solve(text, task=body.get("task"), variable=body.get("variable"))
            except Exception as error:  # a bug must surface as an answer, not a hang
                self._reply(500, {"error": "internal_error", "detail": type(error).__name__})
                return
            self._reply(200, result)

    return ThreadingHTTPServer((host, port), Handler)


def warm_up() -> None:
    """Load SymPy and solve once, so the first real problem is fast."""
    from .engine import solve

    solve("x^2 - 1 = 0")


def main() -> None:
    server = make_server(os.environ["ABQARI_TOKEN"], int(os.environ["ABQARI_PORT"]))
    warm_up()
    server.serve_forever()
