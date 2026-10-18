#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
import importlib.util
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("staging", ROOT / "scripts/promote-stage.py")
staging = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(staging)


class StagingTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temporary.name).resolve()
        self.stage = self.root / "stage"
        self.prefix = self.root / "prefix"
        self.logical = self.stage / str(self.prefix).lstrip("/")
        self.logical.mkdir(parents=True)
        (self.logical / "example.txt").write_text("test data, not a binary\n")

    def tearDown(self):
        self.temporary.cleanup()

    def test_valid_install_and_relative_symlink(self):
        (self.logical / "alias.txt").symlink_to("example.txt")
        staging.promote(self.stage, self.prefix)
        self.assertEqual((self.prefix / "example.txt").read_text(), "test data, not a binary\n")
        self.assertTrue((self.prefix / "alias.txt").is_symlink())

    def test_reject_system_destination(self):
        extra = self.stage / "usr/share/example.txt"
        extra.parent.mkdir(parents=True)
        extra.write_text("must not be installed")
        with self.assertRaises(ValueError):
            staging.promote(self.stage, self.prefix)
        self.assertFalse(self.prefix.exists())

    def test_reject_existing_prefix(self):
        self.prefix.mkdir()
        sentinel = self.prefix / "sentinel"
        sentinel.write_text("keep")
        with self.assertRaises(ValueError):
            staging.promote(self.stage, self.prefix)
        self.assertEqual(sentinel.read_text(), "keep")

    def test_reject_absolute_escaping_symlink(self):
        (self.logical / "escape").symlink_to("/usr/lib")
        with self.assertRaises(ValueError):
            staging.promote(self.stage, self.prefix)

    def test_reject_relative_escaping_symlink(self):
        (self.logical / "escape").symlink_to("../../outside")
        with self.assertRaises(ValueError):
            staging.promote(self.stage, self.prefix)


if __name__ == "__main__":
    unittest.main()
