import unittest
import threading
import urllib.request
import json
import time
from server import create_server

class TestApiStats(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.httpd, cls.port = create_server(port=0)
        cls.thread = threading.Thread(target=cls.httpd.serve_forever, daemon=True)
        cls.thread.start()
        time.sleep(0.1)

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()
        cls.httpd.server_close()

    def test_api_stats_payload_format(self):
        url = f"http://127.0.0.1:{self.port}/api/stats"
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=15.0) as resp:
            self.assertEqual(resp.status, 200)
            data = json.loads(resp.read().decode("utf-8"))
            self.assertEqual(data.get("status"), "ok")
            self.assertIn("timestamp", data)
            self.assertIn("quota", data)
            self.assertIn("summary", data)
            
            # Verify summary keys
            summary = data["summary"]
            self.assertIn("total_tokens", summary)
            self.assertIn("prompt_tokens", summary)
            self.assertIn("cached_tokens", summary)
            self.assertIn("output_tokens", summary)
            self.assertIn("cost_usd", summary)
            self.assertIn("saved_usd", summary)

if __name__ == "__main__":
    unittest.main()
