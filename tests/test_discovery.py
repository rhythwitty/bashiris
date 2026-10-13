"""Tests for browser user-data directory discovery."""

import tempfile
import unittest
from pathlib import Path

from power_cleaner.discovery import discover_browsers, is_chrome_user_data_dir


class TestDiscovery(unittest.TestCase):
    def setUp(self):
        self.fixture_root = Path(__file__).parent / "fixtures" / "chrome_root"

    def test_discover_from_fixture(self):
        browsers = discover_browsers(self.fixture_root)
        names = [b.name for b in browsers]

        # Valid browsers
        self.assertIn("browser-a", names)
        self.assertIn("browser-b", names)

        # Excluded items
        self.assertNotIn("power-cleaner", names)
        self.assertNotIn(".DS_Store", names)

    def test_is_chrome_user_data_dir_validation(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)

            # Empty dir -> False
            self.assertFalse(is_chrome_user_data_dir(tmppath))

            # Only Local State -> False
            (tmppath / "Local State").touch()
            self.assertFalse(is_chrome_user_data_dir(tmppath))

            # Both Local State and Default dir -> True
            (tmppath / "Default").mkdir()
            self.assertTrue(is_chrome_user_data_dir(tmppath))

            # Default is file instead of dir -> False
            (tmppath / "Default").rmdir()
            (tmppath / "Default").touch()
            self.assertFalse(is_chrome_user_data_dir(tmppath))

    def test_ignores_symlinked_browser_directories(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            real_b = tmppath / "real_browser"
            real_b.mkdir()
            (real_b / "Local State").touch()
            (real_b / "Default").mkdir()

            # Create symlink
            link_b = tmppath / "link_browser"
            link_b.symlink_to(real_b)

            browsers = discover_browsers(tmppath)
            names = [b.name for b in browsers]

            self.assertIn("real_browser", names)
            self.assertNotIn("link_browser", names)


if __name__ == "__main__":
    unittest.main()
