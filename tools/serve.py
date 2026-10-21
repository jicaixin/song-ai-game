#!/usr/bin/env python3
"""Serve the HTML5 build. wasm and pck need explicit types on some Pythons."""

import http.server
import os
import socketserver
from pathlib import Path

PORT = int(os.environ.get("PORT", "8734"))
ROOT = Path(__file__).resolve().parents[1] / "build" / "web"


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = http.server.SimpleHTTPRequestHandler.extensions_map | {
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
    }

    def end_headers(self) -> None:
        # No COOP/COEP. The nothreads build must run without SharedArrayBuffer.
        super().end_headers()


def main() -> None:
    os.chdir(ROOT)
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", PORT), Handler) as httpd:
        print(f"serving {ROOT} at http://127.0.0.1:{PORT}", flush=True)
        httpd.serve_forever()


if __name__ == "__main__":
    main()
