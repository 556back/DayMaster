"""Serve the compiled local app with explicit web module MIME types."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

class AppHandler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".js": "application/javascript",
        ".mjs": "application/javascript",
        ".wasm": "application/wasm",
        ".json": "application/json",
        ".svg": "image/svg+xml",
        ".otf": "font/otf",
        ".ttf": "font/ttf",
    }

    def send_head(self):
        # A local rebuild must not reuse an earlier module MIME type.
        if "If-Modified-Since" in self.headers:
            del self.headers["If-Modified-Since"]
        return super().send_head()

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=5173)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent / "build" / "web"
    if not (root / "index.html").exists():
        parser.error("Build the web app first: flutter build web --no-web-resources-cdn")
    handler = partial(AppHandler, directory=str(root))
    print(f"DayMaster preview: http://127.0.0.1:{args.port}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", args.port), handler).serve_forever()
