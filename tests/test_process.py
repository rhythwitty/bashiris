"""Tests for active Chrome process detection and stale lock handling."""

import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from power_cleaner.models import BrowserStatus
from power_cleaner.process import inspect_browser_activity


class TestProcess(unittest.TestCase):
    def test_active_process_detection(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            profile = Path(tmpdir) / "profile1"
            profile.mkdir()

            mock_processes = [
                (
                    12345,
                    f"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --user-data-dir={profile}",
                ),
                (99999, "bash"),
            ]

            status, reason, pid = inspect_browser_activity(
                profile, processes=mock_processes
            )
            self.assertEqual(status, BrowserStatus.ACTIVE)
            self.assertEqual(pid, 12345)
            self.assertIn("running with this profile", reason)

    def test_inactive_process_detection(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            profile = Path(tmpdir) / "profile1"
            profile.mkdir()

            mock_processes = [
                (
                    54321,
                    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --user-data-dir=/some/other/profile",
                ),
            ]

            status, reason, pid = inspect_browser_activity(
                profile, processes=mock_processes
            )
            self.assertEqual(status, BrowserStatus.INACTIVE)
            self.assertIsNone(pid)

    def test_stale_singleton_lock_not_treated_as_active(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            profile = Path(tmpdir) / "profile_crashed"
            profile.mkdir()

            # Create a stale SingletonLock symlink to a nonexistent PID (e.g. 99999999)
            lock = profile / "SingletonLock"
            lock.symlink_to("testhost-99999999")

            # Mock processes without this profile
            mock_processes = [(100, "launchd")]

            # Even though lock exists, dead PID means INACTIVE, never ACTIVE
            status, reason, pid = inspect_browser_activity(
                profile, processes=mock_processes
            )
            self.assertEqual(status, BrowserStatus.INACTIVE)

    def test_inconclusive_processes_returns_unknown(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            profile = Path(tmpdir) / "profile1"
            profile.mkdir()

            # Mock get_system_processes returning None (failure)
            with patch(
                "power_cleaner.process._get_system_processes", return_value=None
            ):
                status, reason, pid = inspect_browser_activity(profile, processes=None)
                self.assertEqual(status, BrowserStatus.UNKNOWN)
                self.assertIn("Could not inspect system processes", reason)

    def test_active_singleton_lock_detection(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            profile = Path(tmpdir) / "profile_active"
            profile.mkdir()

            # Create SingletonLock symlink to an alive PID (e.g. current PID)
            current_pid = os.getpid()
            lock = profile / "SingletonLock"
            lock.symlink_to(f"testhost-{current_pid}")

            with patch(
                "power_cleaner.process._get_command_for_pid",
                return_value="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            ):
                status, reason, pid = inspect_browser_activity(profile, processes=[])
                self.assertEqual(status, BrowserStatus.ACTIVE)
                self.assertEqual(pid, current_pid)
                self.assertIn("holds SingletonLock", reason)

    def test_extract_user_data_dir_quotes_and_spaces(self):
        from power_cleaner.process import _extract_user_data_dir

        cmd_quoted = '/Applications/Chrome.app/Contents/MacOS/Google Chrome --user-data-dir="/Users/test/My Profiles/Profile 1" --flag'
        self.assertEqual(
            _extract_user_data_dir(cmd_quoted), "/Users/test/My Profiles/Profile 1"
        )

        cmd_single = "/Applications/Chrome.app/Contents/MacOS/Google Chrome --user-data-dir='/Users/test/My Profiles/Profile 1'"
        self.assertEqual(
            _extract_user_data_dir(cmd_single), "/Users/test/My Profiles/Profile 1"
        )

        cmd_bare = "/Applications/Chrome.app/Contents/MacOS/Google Chrome --user-data-dir=/Users/test/chrome-profile"
        self.assertEqual(_extract_user_data_dir(cmd_bare), "/Users/test/chrome-profile")


if __name__ == "__main__":
    unittest.main()
