"""Tests for scanner, exact storage accounting, and symlink protection."""

import tempfile
import unittest
from pathlib import Path

from power_cleaner.scanner import ProfileScanner


class TestScanner(unittest.TestCase):
    def setUp(self):
        self.fixture_root = Path(__file__).parent / "fixtures" / "chrome_root"
        self.scanner = ProfileScanner()

    def test_fixture_scan_exact_accounting(self):
        browser_a = self.fixture_root / "browser-a"
        report_a = self.scanner.scan_browser(browser_a)

        # Exact accounting must hold: total == sum of parts
        self.assertTrue(report_a.is_accounting_exact)
        self.assertEqual(
            report_a.total_size,
            (
                report_a.safe_size
                + report_a.low_risk_size
                + report_a.review_size
                + report_a.protected_size
                + report_a.unknown_size
                + report_a.inaccessible_size
            ),
        )

        # browser-a has Default/Cache and Default/Code Cache as SAFE
        self.assertGreater(report_a.safe_size, 0)
        safe_paths = [it.relative_path for it in report_a.safe_items]
        self.assertIn("Default/Cache", safe_paths)
        self.assertIn("Default/Code Cache", safe_paths)

        # browser-a has Default/IndexedDB as REVIEW
        self.assertGreater(report_a.review_size, 0)
        review_paths = [it.relative_path for it in report_a.review_items]
        self.assertIn("Default/IndexedDB", review_paths)

        # browser-a has Local State, Cookies, History as PROTECTED
        self.assertGreater(report_a.protected_size, 0)
        protected_paths = [it.relative_path for it in report_a.protected_items]
        self.assertIn("Local State", protected_paths)
        self.assertIn("Default/Cookies", protected_paths)
        self.assertIn("Default/History", protected_paths)

    def test_unknown_data_accounting(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            profile = Path(tmpdir) / "test_prof"
            profile.mkdir()
            (profile / "Local State").write_text("state")
            (profile / "Default").mkdir()

            # Create known safe cache
            (profile / "Default" / "Cache").mkdir()
            (profile / "Default" / "Cache" / "f1").write_bytes(b"A" * 100)

            # Create unknown folder with unknown data
            (profile / "Default" / "BrandNewStore").mkdir()
            (profile / "Default" / "BrandNewStore" / "part1").write_bytes(b"B" * 200)
            (profile / "Default" / "BrandNewStore" / "part2").write_bytes(b"B" * 300)

            report = self.scanner.scan_browser(profile)

            self.assertTrue(report.is_accounting_exact)
            self.assertEqual(report.safe_size, 100)
            self.assertEqual(report.unknown_size, 500)

            # Check that unknown data is grouped under Default/BrandNewStore
            unknown_items = report.unknown_items
            self.assertEqual(len(unknown_items), 1)
            self.assertEqual(unknown_items[0].relative_path, "Default/BrandNewStore")
            self.assertEqual(unknown_items[0].size, 500)
            self.assertEqual(unknown_items[0].file_count, 2)

    def test_symlink_safety_not_followed(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            outside = Path(tmpdir) / "outside_dir"
            outside.mkdir()
            (outside / "large_file").write_bytes(b"X" * 10000)

            profile = Path(tmpdir) / "test_prof"
            profile.mkdir()
            (profile / "Local State").write_text("state")
            (profile / "Default").mkdir()

            # Symlink outside directory into profile
            symlink_dir = profile / "Default" / "symlinked_folder"
            symlink_dir.symlink_to(outside)

            # Symlink outside file into profile
            symlink_file = profile / "Default" / "symlinked_file"
            symlink_file.symlink_to(outside / "large_file")

            report = self.scanner.scan_browser(profile)

            # Symlink targets must not be traversed or counted in storage
            self.assertTrue(report.is_accounting_exact)
            self.assertLess(report.total_size, 10000)


if __name__ == "__main__":
    unittest.main()
