import unittest
import threading
import urllib.request
import json
import time
from server import create_server

class TestServer(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.httpd, cls.port = create_server(port=0) # ephemeral port
        cls.thread = threading.Thread(target=cls.httpd.serve_forever, daemon=True)
        cls.thread.start()
        time.sleep(0.1)

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()
        cls.httpd.server_close()

    def test_api_summary(self):
        url = f"http://127.0.0.1:{self.port}/api/summary"
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=15.0) as resp:
            self.assertEqual(resp.status, 200)
            data = json.loads(resp.read().decode("utf-8"))
            self.assertIn("summary", data)
            self.assertIn("today", data)
            self.assertIn("last_7d", data)
            self.assertIn("last_30d", data)
            self.assertIn("models", data)

    def test_api_quota(self):
        url = f"http://127.0.0.1:{self.port}/api/quota"
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=15.0) as resp:
            self.assertEqual(resp.status, 200)
            data = json.loads(resp.read().decode("utf-8"))
            self.assertIn("status", data)

    def test_api_stats(self):
        url = f"http://127.0.0.1:{self.port}/api/stats"
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=15.0) as resp:
            self.assertEqual(resp.status, 200)
            data = json.loads(resp.read().decode("utf-8"))
            self.assertIn("quota", data)
            self.assertIn("summary", data)
            self.assertIn("today", data)
            self.assertIn("last_7d", data)
            self.assertIn("last_30d", data)

    def test_api_version(self):
        url = f"http://127.0.0.1:{self.port}/api/version"
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=15.0) as resp:
            self.assertEqual(resp.status, 200)
            data = json.loads(resp.read().decode("utf-8"))
            self.assertIn("version", data)
            self.assertEqual(data["version"], "1.2.0")

    def test_api_check_update(self):
        url = f"http://127.0.0.1:{self.port}/api/check_update"
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=15.0) as resp:
            self.assertEqual(resp.status, 200)
            data = json.loads(resp.read().decode("utf-8"))
            self.assertIn("current_version", data)
            self.assertIn("latest_version", data)
            self.assertIn("has_update", data)
            self.assertIn("release_notes", data)
            self.assertIn("update_command", data)

    def test_static_index(self):
        url = f"http://127.0.0.1:{self.port}/"
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=15.0) as resp:
            self.assertEqual(resp.status, 200)
            content = resp.read().decode("utf-8")
            self.assertIn("Antigravity Token", content)

if __name__ == "__main__":
    unittest.main()
