"""Tests for cleanup execution engine, dry-run, and filesystem safety."""

import tempfile
import unittest
from pathlib import Path

from power_cleaner.cleanup import execute_cleanup_plan, prompt_confirmation
from power_cleaner.models import (
    BrowserReport,
    BrowserStatus,
    CleanupAction,
    SafetyLevel,
    StorageItem,
)
from power_cleaner.planner import BrowserCleanupPlan, CleanupPlan


class TestCleanup(unittest.TestCase):
    def test_dry_run_modifies_no_files(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            profile = Path(tmpdir) / "profile"
            cache_dir = profile / "Default" / "Cache"
            cache_dir.mkdir(parents=True)
            cache_file = cache_dir / "data_0"
            cache_file.write_bytes(b"CACHE" * 100)

            report = BrowserReport(
                name="profile",
                path=profile,
                status=BrowserStatus.INACTIVE,
                safe_size=500,
            )
            item = StorageItem(
                relative_path="Default/Cache",
                size=500,
                safety=SafetyLevel.SAFE,
                category="cache",
                description="Cache",
                rationale="Safe",
                cleanup_action=CleanupAction.CLEAR_CONTENTS,
            )

            plan = CleanupPlan(
                targeted_browsers=[report],
                browser_plans=[
                    BrowserCleanupPlan(
                        report=report,
                        items_to_clean=[item],
                        total_bytes=500,
                    )
                ],
            )

            result = execute_cleanup_plan(plan, dry_run=True)
            self.assertTrue(result.dry_run)
            self.assertEqual(result.deleted_bytes, 500)
            self.assertEqual(result.cleaned_profiles_count, 1)

            # File must still exist!
            self.assertTrue(cache_file.exists())

    def test_clear_contents_preserves_directory(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            profile = Path(tmpdir) / "profile"
            cache_dir = profile / "Default" / "Cache"
            cache_dir.mkdir(parents=True)
            cache_file = cache_dir / "data_0"
            cache_file.write_bytes(b"CACHE" * 100)

            cookies = profile / "Default" / "Cookies"
            cookies.write_bytes(b"SECRET_COOKIE")

            report = BrowserReport(
                name="profile",
                path=profile,
                status=BrowserStatus.INACTIVE,
                safe_size=500,
            )
            item = StorageItem(
                relative_path="Default/Cache",
                size=500,
                safety=SafetyLevel.SAFE,
                category="cache",
                description="Cache",
                rationale="Safe",
                cleanup_action=CleanupAction.CLEAR_CONTENTS,
            )

            plan = CleanupPlan(
                targeted_browsers=[report],
                browser_plans=[
                    BrowserCleanupPlan(
                        report=report,
                        items_to_clean=[item],
                        total_bytes=500,
                    )
                ],
            )

            result = execute_cleanup_plan(plan, dry_run=False)
            self.assertFalse(result.dry_run)
            self.assertEqual(result.cleaned_profiles_count, 1)

            # The Cache directory itself must still exist!
            self.assertTrue(cache_dir.exists())
            # But its content must be gone!
            self.assertFalse(cache_file.exists())
            # Protected data (Cookies) must be untouched!
            self.assertTrue(cookies.exists())

    def test_path_traversal_guard(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            profile = Path(tmpdir) / "profile"
            profile.mkdir()

            outside_file = Path(tmpdir) / "outside.txt"
            outside_file.write_text("critical outside data")

            report = BrowserReport(
                name="profile",
                path=profile,
                status=BrowserStatus.INACTIVE,
                safe_size=10,
            )
            malicious_item = StorageItem(
                relative_path="../outside.txt",
                size=10,
                safety=SafetyLevel.SAFE,
                category="cache",
                description="Malicious",
                rationale="Traversing",
                cleanup_action=CleanupAction.DELETE_PATH,
            )

            plan = CleanupPlan(
                targeted_browsers=[report],
                browser_plans=[
                    BrowserCleanupPlan(
                        report=report,
                        items_to_clean=[malicious_item],
                        total_bytes=10,
                    )
                ],
            )

            result = execute_cleanup_plan(plan, dry_run=False)
            # Must be caught by safety guard
            self.assertTrue(outside_file.exists())
            self.assertTrue(any("escapes profile" in err for err in result.errors))

    def test_clear_contents_counts_nested_subdirectories_size(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            profile = Path(tmpdir) / "profile"
            cache_dir = profile / "Default" / "Cache"
            sub_dir = cache_dir / "js"
            sub_dir.mkdir(parents=True)
            nested_file = sub_dir / "chunk_0.bin"
            nested_file.write_bytes(b"B" * 2000)

            top_file = cache_dir / "index"
            top_file.write_bytes(b"A" * 500)

            report = BrowserReport(
                name="profile",
                path=profile,
                status=BrowserStatus.INACTIVE,
                safe_size=2500,
            )
            item = StorageItem(
                relative_path="Default/Cache",
                size=2500,
                safety=SafetyLevel.SAFE,
                category="cache",
                description="Cache",
                rationale="Safe",
                cleanup_action=CleanupAction.CLEAR_CONTENTS,
            )

            plan = CleanupPlan(
                targeted_browsers=[report],
                browser_plans=[
                    BrowserCleanupPlan(
                        report=report,
                        items_to_clean=[item],
                        total_bytes=2500,
                    )
                ],
            )

            result = execute_cleanup_plan(plan, dry_run=False)
            self.assertEqual(result.deleted_bytes, 2500)
            self.assertEqual(result.cleaned_profiles_count, 1)
            self.assertTrue(cache_dir.exists())
            self.assertFalse(sub_dir.exists())
            self.assertFalse(top_file.exists())

    def test_delete_path_directory_counts_full_size(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            profile = Path(tmpdir) / "profile"
            profile.mkdir()
            spare_file = profile / "BrowserMetrics-spare.pma"
            spare_file.write_bytes(b"M" * 4000)

            report = BrowserReport(
                name="profile",
                path=profile,
                status=BrowserStatus.INACTIVE,
                safe_size=4000,
            )
            item = StorageItem(
                relative_path="BrowserMetrics-spare.pma",
                size=4000,
                safety=SafetyLevel.SAFE,
                category="telemetry",
                description="Spare metrics",
                rationale="Safe",
                cleanup_action=CleanupAction.DELETE_PATH,
            )

            plan = CleanupPlan(
                targeted_browsers=[report],
                browser_plans=[
                    BrowserCleanupPlan(
                        report=report,
                        items_to_clean=[item],
                        total_bytes=4000,
                    )
                ],
            )

            result = execute_cleanup_plan(plan, dry_run=False)
            self.assertEqual(result.deleted_bytes, 4000)
            self.assertEqual(result.cleaned_profiles_count, 1)
            self.assertFalse(spare_file.exists())

    def test_low_risk_cleanup_execution(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            profile = Path(tmpdir) / "profile"
            profile.mkdir()
            crx_cache = profile / "component_crx_cache"
            crx_cache.mkdir()
            sub_file = crx_cache / "cached.crx"
            sub_file.write_bytes(b"CRX" * 100)

            manifest_file = profile / "OptimizationGuideModelsManifest"
            manifest_file.write_bytes(b"MANIFEST" * 50)

            report = BrowserReport(
                name="profile",
                path=profile,
                status=BrowserStatus.INACTIVE,
                low_risk_size=700,
            )
            item1 = StorageItem(
                relative_path="component_crx_cache",
                size=300,
                safety=SafetyLevel.LOW_RISK,
                category="component_cache",
                description="CRX cache",
                rationale="Low risk",
                cleanup_action=CleanupAction.CLEAR_CONTENTS,
            )
            item2 = StorageItem(
                relative_path="OptimizationGuideModelsManifest",
                size=400,
                safety=SafetyLevel.LOW_RISK,
                category="component_cache",
                description="Manifest",
                rationale="Low risk",
                cleanup_action=CleanupAction.DELETE_PATH,
            )

            plan = CleanupPlan(
                targeted_browsers=[report],
                browser_plans=[
                    BrowserCleanupPlan(
                        report=report,
                        items_to_clean=[item1, item2],
                        total_bytes=700,
                        allowed_safety_levels=(SafetyLevel.LOW_RISK,),
                    )
                ],
                safety_levels=(SafetyLevel.LOW_RISK,),
            )

            result = execute_cleanup_plan(plan, dry_run=False)
            self.assertEqual(result.deleted_bytes, 700)
            self.assertEqual(result.cleaned_profiles_count, 1)
            # Directory preserved, content cleared
            self.assertTrue(crx_cache.exists())
            self.assertFalse(sub_file.exists())
            # File deleted
            self.assertFalse(manifest_file.exists())

    def test_cleanup_guard_rejects_disallowed_levels(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            profile = Path(tmpdir) / "profile"
            profile.mkdir()
            cookies = profile / "Default" / "Cookies"
            cookies.parent.mkdir(parents=True)
            cookies.write_text("COOKIE")

            report = BrowserReport(
                name="profile",
                path=profile,
                status=BrowserStatus.INACTIVE,
                safe_size=10,
            )
            safe_item = StorageItem(
                relative_path="Default/Cache",
                size=10,
                safety=SafetyLevel.SAFE,
                category="cache",
                description="Cache",
                rationale="Safe",
                cleanup_action=CleanupAction.CLEAR_CONTENTS,
            )
            # Plan only allows SAFE
            b_plan = BrowserCleanupPlan(
                report=report,
                items_to_clean=[safe_item],
                total_bytes=10,
                allowed_safety_levels=(SafetyLevel.SAFE,),
            )
            # Maliciously sneak in a PROTECTED item into items_to_clean
            protected_item = StorageItem(
                relative_path="Default/Cookies",
                size=6,
                safety=SafetyLevel.PROTECTED,
                category="auth",
                description="Cookies",
                rationale="Protected",
                cleanup_action=CleanupAction.DELETE_PATH,
            )
            b_plan.items_to_clean.append(protected_item)

            plan = CleanupPlan(
                targeted_browsers=[report],
                browser_plans=[b_plan],
            )

            result = execute_cleanup_plan(plan, dry_run=False)
            self.assertTrue(cookies.exists())
            self.assertTrue(
                any("not permitted for cleanup" in err for err in result.errors)
            )

    def test_prompt_confirmation(self):
        from unittest.mock import patch

        with patch("builtins.input", return_value="clean"):
            self.assertTrue(prompt_confirmation())
        with patch("builtins.input", return_value="CLEAN"):
            self.assertTrue(prompt_confirmation())
        with patch("builtins.input", return_value="no"):
            self.assertFalse(prompt_confirmation())
        with patch("builtins.input", return_value=""):
            self.assertFalse(prompt_confirmation())


if __name__ == "__main__":
    unittest.main()
