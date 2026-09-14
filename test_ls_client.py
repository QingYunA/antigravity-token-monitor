import unittest
from ls_client import LanguageServerClient

class TestLanguageServerClient(unittest.TestCase):
    def test_client_detection(self):
        client = LanguageServerClient()
        # On this mac environment where Antigravity is running, discovery should succeed
        conn_info = client.discover_process()
        if conn_info:
            self.assertIn("pid", conn_info)
            self.assertIn("csrf_token", conn_info)
            self.assertIn("port", conn_info)
            self.assertGreater(conn_info["port"], 0)

    def test_get_quota_summary(self):
        client = LanguageServerClient()
        quota = client.get_quota()
        # If LS is running, quota will have "groups" or "status"
        self.assertIsNotNone(quota)
        self.assertIn("status", quota)
        if quota["status"] == "ok":
            self.assertIn("groups", quota)
            self.assertIn("user_tier", quota)

if __name__ == "__main__":
    unittest.main()
