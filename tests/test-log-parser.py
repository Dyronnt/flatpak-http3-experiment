#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
import importlib.util
import json
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("summary", ROOT / "scripts/summarize-results.py")
summary = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(summary)


class EvidenceTests(unittest.TestCase):
    def fixture(self, name):
        return summary.protocol_evidence((ROOT / "tests/fixtures" / name).read_text())

    def test_http2_is_not_http3(self):
        self.assertFalse(self.fixture("http2.txt")["http3_response_observed"])

    def test_alt_svc_is_not_proof(self):
        result = self.fixture("alt-svc-only.txt")
        self.assertFalse(result["http3_response_observed"])
        self.assertFalse(result["http3_payload_request_observed"])

    def test_mixed_protocols(self):
        result = self.fixture("http3-mixed.txt")
        self.assertEqual(result["responses"], {"HTTP/2 200": 1, "HTTP/3 200": 2})
        self.assertTrue(result["http3_success_response_observed"])
        self.assertEqual(result["payload_requests"], {"3": 2})

    def test_cached_metadata_is_not_payload(self):
        result = summary.protocol_evidence("> GET /repo/summary HTTP/3\n< HTTP/3 304\n")
        self.assertFalse(result["http3_success_response_observed"])
        self.assertFalse(result["http3_payload_request_observed"])

    def test_failed_http3_is_not_success(self):
        result = summary.protocol_evidence("> GET /repo/objects/aa/object.filez HTTP/3\n< HTTP/3 503\n")
        self.assertTrue(result["http3_response_observed"])
        self.assertFalse(result["http3_success_response_observed"])

    def test_ignore_body_text_and_announcements(self):
        result = summary.protocol_evidence("HTTP/3 200\n* using HTTP/3\n< alt-svc: h3=\":443\"\n")
        self.assertEqual(result["responses"], {})

    def test_only_valid_samples_are_summarized(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            for i, (valid, seconds) in enumerate([(True, 2.0), (True, 4.0), (False, 0.1)]):
                run = root / str(i)
                run.mkdir()
                (run / "result.json").write_text(json.dumps({"valid": valid, "configuration": "http3", "elapsed_seconds": seconds}))
            result = summary.summarize_runs(root)
            self.assertEqual(result["configurations"]["http3"]["n"], 2)
            self.assertEqual(result["configurations"]["http3"]["median_seconds"], 3.0)
            self.assertEqual(len(result["invalid_runs"]), 1)


if __name__ == "__main__":
    unittest.main()
