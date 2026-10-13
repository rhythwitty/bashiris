"""Tests for formatting, JSON export, and CLI commands."""

import io
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from power_cleaner.cli import main
from power_cleaner.formatters import (
    ColorTheme,
    format_size,
    human_percent,
    render_why_explanation,
    to_json_dict,
)
from power_cleaner.models import (
    AggregateReport,
    BrowserReport,
    BrowserStatus,
    CleanupAction,
    Confidence,
    SafetyLevel,
    StorageItem,
)


class TestFormattersAndCLI(unittest.TestCase):
    def test_format_size(self):
        self.assertEqual(format_size(0), "0 B")
        self.assertEqual(format_size(500), "500 B")
        self.assertEqual(format_size(1024), "1.0 KB")
        self.assertEqual(format_size(1024 * 1024), "1.0 MB")
        self.assertEqual(format_size(1024 * 1024 * 1024 * 2), "2.0 GB")

    def test_human_percent(self):
        self.assertEqual(human_percent(0, 100), "0.0%")
        self.assertEqual(human_percent(50, 100), "50.0%")
        self.assertEqual(human_percent(10, 0), "0.0%")

    def test_color_theme_disabled(self):
        theme = ColorTheme(force_disable=True)
        self.assertFalse(theme.enabled)
        self.assertEqual(theme.safe("text"), "text")
        self.assertEqual(theme.review("text"), "text")

    def test_to_json_dict_structure(self):
        report = BrowserReport(
            name="test_prof",
            path=Path("/fake/test_prof"),
            status=BrowserStatus.INACTIVE,
            total_size=1000,
            safe_size=600,
            review_size=400,
        )
        report.items_by_safety[SafetyLevel.SAFE].append(
            StorageItem(
                relative_path="Default/Cache",
                size=600,
                safety=SafetyLevel.SAFE,
                category="browser_cache",
                description="Cache",
                rationale="Safe",
                cleanup_action=CleanupAction.CLEAR_CONTENTS,
                confidence=Confidence.HIGH,
            )
        )
        aggregate = AggregateReport(
            root=Path("/fake"),
            reports=[report],
        )

        data = to_json_dict(aggregate)
        self.assertEqual(data["browsers"], 1)
        self.assertEqual(data["total_bytes"], 1000)
        self.assertEqual(data["safe_bytes"], 600)
        self.assertEqual(data["review_bytes"], 400)
        self.assertEqual(len(data["profiles"]), 1)
        self.assertEqual(data["profiles"][0]["name"], "test_prof")
        self.assertIn("can_clean_low_risk", data["profiles"][0])
        self.assertEqual(data["profiles"][0]["items"][0]["path"], "Default/Cache")

    def test_cli_json_mode(self):
        fixture_root = Path(__file__).parent / "fixtures" / "chrome_root"
        buf = io.StringIO()
        with patch("sys.stdout", buf):
            main(["--root", str(fixture_root), "--json"])

        output = buf.getvalue()
        # Verify valid JSON
        data = json.loads(output)
        self.assertIn("browsers", data)
        self.assertEqual(data["browsers"], 2)
        self.assertIn("profiles", data)

    def test_cli_dry_run_mode(self):
        fixture_root = Path(__file__).parent / "fixtures" / "chrome_root"
        buf = io.StringIO()
        with patch("sys.stdout", buf):
            main(["--root", str(fixture_root), "--dry-run"])

        output = buf.getvalue()
        self.assertIn("DRY RUN CLEANUP PLAN", output)
        self.assertIn("Dry run complete", output)

    def test_render_why_explanation(self):
        item = StorageItem(
            relative_path="Default/Service Worker",
            size=50000000,
            safety=SafetyLevel.REVIEW,
            category="application_storage",
            description="Service worker data",
            rationale="Service workers contain offline resources.",
            cleanup_action=CleanupAction.NONE,
            confidence=Confidence.HIGH,
        )
        text = render_why_explanation(item)
        self.assertIn("Default/Service Worker", text)
        self.assertIn("REVIEW", text)
        self.assertIn("Suggested action", text)

    def test_cli_dry_run_low_risk(self):
        fixture_root = Path(__file__).parent / "fixtures" / "chrome_root"
        buf = io.StringIO()
        with patch("sys.stdout", buf):
            main(["--root", str(fixture_root), "--dry-run", "--clean-low-risk"])

        output = buf.getvalue()
        self.assertIn("DRY RUN CLEANUP PLAN (LOW-RISK)", output)
        self.assertIn("Dry run complete", output)

    def test_cli_clean_safe_with_yes(self):
        fixture_root = Path(__file__).parent / "fixtures" / "chrome_root"
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_root = Path(tmpdir) / "chrome"
            shutil.copytree(fixture_root, tmp_root)

            buf = io.StringIO()
            with patch("sys.stdout", buf):
                main(["--root", str(tmp_root), "--clean-safe", "--yes"])

            output = buf.getvalue()
            self.assertIn("Confirmation bypassed (--yes)", output)
            self.assertIn("Cleanup Complete", output)

    def test_cli_clean_safe_cancels_on_rejected_prompt(self):
        fixture_root = Path(__file__).parent / "fixtures" / "chrome_root"
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_root = Path(tmpdir) / "chrome"
            shutil.copytree(fixture_root, tmp_root)

            buf = io.StringIO()
            with patch("sys.stdout", buf), patch("builtins.input", return_value="no"):
                main(["--root", str(tmp_root), "--clean-safe"])

            output = buf.getvalue()
            self.assertIn("Cleanup cancelled", output)

    def test_cli_clean_low_risk_with_yes(self):
        fixture_root = Path(__file__).parent / "fixtures" / "chrome_root"
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_root = Path(tmpdir) / "chrome"
            shutil.copytree(fixture_root, tmp_root)
            crx_dir = tmp_root / "browser-a" / "component_crx_cache"
            crx_dir.mkdir(parents=True)
            (crx_dir / "cache.crx").write_bytes(b"DATA" * 100)

            buf = io.StringIO()
            with patch("sys.stdout", buf):
                main(["--root", str(tmp_root), "--clean-low-risk", "--yes"])

            output = buf.getvalue()
            self.assertIn("Confirmation bypassed (--yes)", output)
            self.assertIn("Clean Low-Risk Caches Summary", output)
            self.assertIn("Cleanup Complete", output)

    def test_cli_clean_low_risk_cancels_on_rejected_prompt(self):
        fixture_root = Path(__file__).parent / "fixtures" / "chrome_root"
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_root = Path(tmpdir) / "chrome"
            shutil.copytree(fixture_root, tmp_root)
            crx_dir = tmp_root / "browser-a" / "component_crx_cache"
            crx_dir.mkdir(parents=True)
            (crx_dir / "cache.crx").write_bytes(b"DATA" * 100)

            buf = io.StringIO()
            with patch("sys.stdout", buf), patch("builtins.input", return_value="no"):
                main(["--root", str(tmp_root), "--clean-low-risk"])

            output = buf.getvalue()
            self.assertIn("Clean Low-Risk Caches Summary", output)
            self.assertIn("Cleanup cancelled", output)


if __name__ == "__main__":
    unittest.main()
