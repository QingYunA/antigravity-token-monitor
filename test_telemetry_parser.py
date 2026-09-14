import unittest
from telemetry_parser import (
    parse_protobuf_varint,
    extract_step_telemetry,
    calculate_step_cost,
    PRICING_TABLE,
    TelemetryParser
)

class TestTelemetryParser(unittest.TestCase):
    def test_parse_protobuf_varint(self):
        # 1-byte varint: 1 -> 1
        val, consumed = parse_protobuf_varint(b"\x01", 0)
        self.assertEqual(val, 1)
        self.assertEqual(consumed, 1)

        # 2-byte varint: 300 -> 0xAC 0x02
        val, consumed = parse_protobuf_varint(b"\xac\x02", 0)
        self.assertEqual(val, 300)
        self.assertEqual(consumed, 2)

    def test_extract_step_telemetry(self):
        # Construct synthetic protobuf with:
        # field 1 (bytes) -> field 4 (bytes) -> field 2 (prompt=1000), field 3 (total_output=300), field 5 (cached=5000), field 9 (thinking=100), field 10 (content=200)
        # and field 19 (model name) = "gemini-3.8-flash"
        
        # Helper to encode varint
        def enc_varint(val):
            res = bytearray()
            while True:
                b = val & 0x7F
                val >>= 7
                if val:
                    res.append(b | 0x80)
                else:
                    res.append(b)
                    break
            return bytes(res)

        def enc_field(field_num, wire_type, data):
            tag = (field_num << 3) | wire_type
            if wire_type == 0:
                return enc_varint(tag) + enc_varint(data)
            elif wire_type == 2:
                return enc_varint(tag) + enc_varint(len(data)) + data
            raise ValueError()

        # field_4 sub-fields
        f4_content = (
            enc_field(2, 0, 1000) +   # prompt tokens
            enc_field(3, 0, 300) +    # total output
            enc_field(5, 0, 5000) +   # cached tokens
            enc_field(9, 0, 100) +    # thinking
            enc_field(10, 0, 200)     # content
        )

        # field 1 payload
        f1_content = enc_field(4, 2, f4_content) + enc_field(19, 2, b"gemini-3.8-flash")
        raw_proto = enc_field(1, 2, f1_content)

        metrics = extract_step_telemetry(raw_proto)
        self.assertIsNotNone(metrics)
        self.assertEqual(metrics["prompt_tokens"], 1000)
        self.assertEqual(metrics["cached_tokens"], 5000)
        self.assertEqual(metrics["output_tokens"], 300)
        self.assertEqual(metrics["thinking_tokens"], 100)
        self.assertEqual(metrics["content_tokens"], 200)
        self.assertEqual(metrics["total_tokens"], 1000 + 5000 + 300)
        self.assertEqual(metrics["model"], "gemini-3.8-flash")

    def test_calculate_step_cost(self):
        metrics = {
            "model": "gemini-3.8-flash",
            "prompt_tokens": 10000,
            "cached_tokens": 50000,
            "output_tokens": 2000,
            "thinking_tokens": 500,
            "content_tokens": 1500
        }
        # Gemini 3.8 / 3.7 Flash pricing:
        # prompt: $0.10 / 1M = 0.0000001
        # cached: $0.025 / 1M = 0.000000025
        # output: $0.40 / 1M = 0.0000004
        costs = calculate_step_cost(metrics)
        self.assertIn("usd", costs)
        self.assertIn("cny", costs)
        expected_usd = (10000 * 0.10 + 50000 * 0.025 + 2000 * 0.40) / 1000000.0
        self.assertAlmostEqual(costs["usd"], expected_usd, places=6)
        self.assertGreater(costs["cny"], costs["usd"] * 7.0)

if __name__ == "__main__":
    unittest.main()
