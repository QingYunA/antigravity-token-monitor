import os
import re
import ssl
import json
import subprocess
import urllib.request
import datetime
from typing import Optional, Dict, Any

class LanguageServerClient:
    def __init__(self):
        self._cached_conn: Optional[Dict[str, Any]] = None
        self._ssl_ctx = ssl._create_unverified_context()

    def discover_process(self) -> Optional[Dict[str, Any]]:
        """Scans local processes to find Antigravity language_server, extracting PID, CSRF Token, and listening port."""
        try:
            # 1. Look for language_server in ps
            ps_proc = subprocess.run(
                ["ps", "-A", "-o", "pid,command"],
                capture_output=True,
                check=True
            )
            ps_stdout = ps_proc.stdout.decode("utf-8", errors="replace")

            pid = None
            csrf_token = None
            for line in ps_stdout.splitlines():
                if "language_server" in line and "--csrf_token" in line:
                    match_pid = re.match(r"^\s*(\d+)\s+", line)
                    match_token = re.search(r"--csrf_token\s+([a-f0-9\-]+)", line)
                    if match_pid and match_token:
                        pid = int(match_pid.group(1))
                        csrf_token = match_token.group(1)
                        break

            if not pid or not csrf_token:
                return None

            # 2. Check if main.log has the exact port
            log_path = os.path.expanduser("~/Library/Logs/Antigravity/main.log")
            hinted_ports = []
            if os.path.exists(log_path):
                try:
                    with open(log_path, "r", encoding="utf-8", errors="ignore") as lf:
                        lines = lf.readlines()[-50:]
                        for line in reversed(lines):
                            m_url = re.search(r"https?://127\.0\.0\.1:(\d+)", line)
                            if m_url:
                                hinted_ports.append(int(m_url.group(1)))
                except Exception:
                    pass

            # 3. Find listening ports via lsof
            lsof_proc = subprocess.run(
                ["lsof", "-nP", "-iTCP", "-sTCP:LISTEN", "-p", str(pid)],
                capture_output=True,
                check=True
            )
            lsof_stdout = lsof_proc.stdout.decode("utf-8", errors="replace")

            ports = list(hinted_ports)
            for line in lsof_stdout.splitlines():
                m = re.search(r"127\.0\.0\.1:(\d+)", line)
                if m:
                    pt = int(m.group(1))
                    if pt not in ports:
                        ports.append(pt)

            if not ports:
                return None

            # Test available ports to see which one answers Connect-RPC with genuine quota
            active_port = None
            for p in ports:
                data = self._post_rpc(
                    f"https://127.0.0.1:{p}/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary",
                    csrf_token,
                    timeout=1.0
                )
                if data and ("groups" in data.get("response", {}) or "response" in data):
                    active_port = p
                    break

            if active_port:
                conn_info = {
                    "pid": pid,
                    "csrf_token": csrf_token,
                    "port": active_port
                }
                self._cached_conn = conn_info
                return conn_info

            return None
        except Exception:
            return None

    def _post_rpc(self, url: str, csrf_token: str, timeout: float = 2.0) -> Optional[Dict[str, Any]]:
        """Unified Connect-RPC POST helper with CSRF authentication and SSL handling."""
        try:
            req = urllib.request.Request(
                url,
                data=b"{}",
                headers={
                    "X-Codeium-Csrf-Token": csrf_token,
                    "Content-Type": "application/json"
                },
                method="POST"
            )
            with urllib.request.urlopen(req, context=self._ssl_ctx, timeout=timeout) as resp:
                if resp.status == 200:
                    return json.loads(resp.read().decode("utf-8"))
        except Exception:
            pass
        return None

    def get_connection(self) -> Optional[Dict[str, Any]]:
        if self._cached_conn:
            # Check if PID is still alive
            try:
                os_pid = self._cached_conn["pid"]
                subprocess.run(["kill", "-0", str(os_pid)], check=True, capture_output=True)
                return self._cached_conn
            except Exception:
                self._cached_conn = None

        return self.discover_process()

    def get_quota(self) -> Dict[str, Any]:
        """Fetches live quota summary and user status from local Language Server."""
        conn = self.get_connection()
        if not conn:
            return {
                "status": "offline",
                "message": "Antigravity Language Server not detected or not running",
                "last_checked": datetime.datetime.now().isoformat()
            }

        port = conn["port"]
        csrf_token = conn["csrf_token"]

        result = {
            "status": "ok",
            "port": port,
            "pid": conn["pid"],
            "groups": [],
            "user_tier": "Google AI Pro",
            "last_checked": datetime.datetime.now().isoformat()
        }

        # 1. Call RetrieveUserQuotaSummary
        quota_data = self._post_rpc(
            f"https://127.0.0.1:{port}/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary",
            csrf_token,
            timeout=2.0
        )
        if quota_data:
            result["groups"] = quota_data.get("response", {}).get("groups", [])
        else:
            result["quota_error"] = "Failed to query RetrieveUserQuotaSummary"

        # 2. Call GetUserStatus for User Tier
        status_data = self._post_rpc(
            f"https://127.0.0.1:{port}/exa.language_server_pb.LanguageServerService/GetUserStatus",
            csrf_token,
            timeout=2.0
        )
        if status_data:
            tier_info = status_data.get("userTier", {})
            result["user_tier"] = tier_info.get("name", "Google AI Pro")

        return result
