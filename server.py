import os
import json
import time
import queue
import threading
from http.server import HTTPServer, SimpleHTTPRequestHandler
from socketserver import ThreadingMixIn
from urllib.parse import urlparse
from typing import Set, Tuple

from telemetry_parser import TelemetryParser
from ls_client import LanguageServerClient

STATIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")
APP_VERSION = "1.2.0"

def get_update_info() -> dict:
    return {
        "current_version": APP_VERSION,
        "latest_version": APP_VERSION,
        "has_update": False,
        "release_name": f"v{APP_VERSION} 稳定版",
        "release_notes": "1. 支持中英文 (i18n) 双语无缝即时切换\n2. 全新设计的极简几何悬浮引力核矢量图标\n3. 支持今天、近 7 天、最近 30 天与全部用量聚合对比\n4. 完善版本检查与平滑升级机制",
        "release_notes_en": "1. Full bilingual (Chinese / English) i18n support\n2. High-end Antigravity Quantum Core vector icon\n3. Time range aggregation for Today, 7D, 30D, and All Time\n4. Built-in version check and seamless update mechanism",
        "download_url": "https://github.com/QingYunA/antigravity-token-monitor",
        "update_command": f"cd '{os.path.dirname(os.path.abspath(__file__))}' && ./update.sh",
        "checked_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }

class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True

class SSEBroadcaster:
    def __init__(self, watch_dir: str = "~/.gemini/antigravity/conversations"):
        self.watch_dir = os.path.expanduser(watch_dir)
        self.clients: Set[queue.Queue] = set()
        self.lock = threading.Lock()
        self._last_snapshot = {}
        self._running = True

    def register(self) -> queue.Queue:
        q = queue.Queue(maxsize=10)
        with self.lock:
            self.clients.add(q)
        return q

    def unregister(self, q: queue.Queue):
        with self.lock:
            if q in self.clients:
                self.clients.remove(q)

    def broadcast(self, data: str):
        with self.lock:
            for q in list(self.clients):
                try:
                    q.put_nowait(data)
                except queue.Full:
                    pass

    def start_watcher(self):
        thread = threading.Thread(target=self._watch_loop, daemon=True)
        thread.start()

    def _watch_loop(self):
        while self._running:
            try:
                if os.path.exists(self.watch_dir):
                    current_snap = {}
                    for fname in os.listdir(self.watch_dir):
                        if fname.endswith(".db"):
                            p = os.path.join(self.watch_dir, fname)
                            try:
                                current_snap[fname] = os.path.getmtime(p)
                            except OSError:
                                pass

                    if self._last_snapshot and current_snap != self._last_snapshot:
                        self.broadcast(json.dumps({"type": "db_updated", "timestamp": time.time()}))
                    self._last_snapshot = current_snap
            except Exception:
                pass
            time.sleep(1.0)

broadcaster = SSEBroadcaster()
broadcaster.start_watcher()
telemetry_parser = TelemetryParser()
ls_client = LanguageServerClient()

class MonitorHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=STATIC_DIR, **kwargs)

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path == "/" or path == "/index.html":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            index_path = os.path.join(STATIC_DIR, "index.html")
            with open(index_path, "rb") as f:
                self.wfile.write(f.read())
            return

        elif path == "/api/summary":
            self._handle_json(telemetry_parser.get_all_metrics())
            return

        elif path == "/api/conversations":
            metrics = telemetry_parser.get_all_metrics()
            self._handle_json({"conversations": metrics.get("conversations", [])})
            return

        elif path == "/api/quota":
            self._handle_json(ls_client.get_quota())
            return

        elif path == "/api/stats":
            metrics = telemetry_parser.get_all_metrics()
            combined = {
                "status": "ok",
                "timestamp": time.time(),
                "quota": ls_client.get_quota(),
                "summary": metrics.get("summary", {}),
                "today": metrics.get("today", {}),
                "last_7d": metrics.get("last_7d", {}),
                "last_30d": metrics.get("last_30d", {}),
                "models": metrics.get("models", {}),
            }
            self._handle_json(combined)
            return

        elif path == "/api/version":
            self._handle_json({"version": APP_VERSION, "name": "Antigravity Token Monitor", "status": "stable"})
            return

        elif path == "/api/check_update":
            self._handle_json(get_update_info())
            return

        elif path.startswith("/api/conversation/"):
            cid = path.replace("/api/conversation/", "").strip()
            data = telemetry_parser.parse_single_conversation(cid)
            if data:
                self._handle_json(data)
            else:
                self.send_error(404, "Conversation Not Found")
            return

        elif path == "/api/events":
            self._handle_sse()
            return

        else:
            # Fallback to static files
            super().do_GET()

    def _handle_json(self, data: dict):
        body = json.dumps(data).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _handle_sse(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

        # Send initial connected message
        self.wfile.write(b"data: {\"status\": \"connected\"}\n\n")
        self.wfile.flush()

        client_queue = broadcaster.register()
        try:
            while True:
                try:
                    msg = client_queue.get(timeout=15.0)
                    self.wfile.write(f"data: {msg}\n\n".encode("utf-8"))
                    self.wfile.flush()
                except queue.Empty:
                    # Heartbeat comment to keep alive
                    self.wfile.write(b": heartbeat\n\n")
                    self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass
        finally:
            broadcaster.unregister(client_queue)

    def log_message(self, format, *args):
        # Suppress noisy access logs in console
        pass

def create_server(host: str = "127.0.0.1", port: int = 8765) -> Tuple[HTTPServer, int]:
    server = ThreadingHTTPServer((host, port), MonitorHandler)
    actual_port = server.server_address[1]
    return server, actual_port

if __name__ == "__main__":
    server, port = create_server(port=8765)
    print(f"🚀 Antigravity Token Monitor running at http://127.0.0.1:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server...")
        server.server_close()
