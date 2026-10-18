#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Use a synthetic command, never Flatpak or the network, to test result handling."""
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
COMMIT = "a" * 64


class MeasurementTests(unittest.TestCase):
    def measure(self, mode, configuration="http3"):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            command = root / "synthetic-command"
            command.write_text("#!/usr/bin/env python3\n" + f"""
import os, sys
if sys.argv[1] == 'info':
    print({'b' * 64 if mode == 'wrong-commit' else COMMIT!r})
    raise SystemExit(0)
if {mode!r} == 'failed':
    raise SystemExit(7)
if {mode!r} == 'environment':
    assert os.environ.get('OSTREE_TURBO_HTTP3') is None
    assert os.environ.get('OSTREE_DEBUG_HTTP') == '1'
    print('> GET /repo/objects/aa/example.filez HTTP/2', file=sys.stderr)
    print('< HTTP/2 200', file=sys.stderr)
else:
    assert os.environ.get('OSTREE_TURBO_HTTP3') == '1'
    print('> GET /repo/objects/aa/example.filez HTTP/3', file=sys.stderr)
    print('< HTTP/3 200', file=sys.stderr)
""")
            command.chmod(0o700)
            env = {**os.environ, "OSTREE_TURBO_HTTP3": "1", "PYTHONDONTWRITEBYTECODE": "1"}
            result = subprocess.run([sys.executable, "-B", str(ROOT / "scripts/measure.py"),
                                     "--state", str(root), "--configuration", configuration,
                                     "--commit", COMMIT, "--ref", "runtime/example/x86_64/stable", "--",
                                     str(command), "install"], env=env, capture_output=True, text=True)
            record = json.loads((root / "result.json").read_text())
            return result.returncode, record

    def test_success_is_recorded(self):
        status, record = self.measure("success")
        self.assertEqual(status, 0)
        self.assertTrue(record["valid"])
        self.assertGreaterEqual(record["elapsed_seconds"], 0)

    def test_failed_command_is_not_a_fast_success(self):
        status, record = self.measure("failed")
        self.assertEqual(status, 1)
        self.assertEqual(record["exit_code"], 7)
        self.assertFalse(record["valid"])

    def test_wrong_commit_is_rejected(self):
        status, record = self.measure("wrong-commit")
        self.assertEqual(status, 1)
        self.assertIn("commit", record["invalid_reason"])

    def test_control_unsets_inherited_opt_in(self):
        status, record = self.measure("environment", "http2")
        self.assertEqual(status, 0)
        self.assertTrue(record["valid"])


if __name__ == "__main__":
    unittest.main()
