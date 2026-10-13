"""Tests for cleanup plan generation and validation guards."""

import unittest
from pathlib import Path

from power_cleaner.models import (
    AggregateReport,
    BrowserReport,
    BrowserStatus,
    SafetyLevel,
    StorageItem,
)
from power_cleaner.planner import (
    BrowserCleanupPlan,
    create_cleanup_plan_for_all,
    create_cleanup_plan_for_browser,
    create_low_risk_cleanup_plan_for_all,
    create_low_risk_cleanup_plan_for_browser,
)


class TestPlanner(unittest.TestCase):
    def setUp(self):
        self.fake_path = Path("/fake/chrome/user1")

    def test_plan_skips_active_and_unknown_profiles(self):
        active_report = BrowserReport(
            name="active_prof",
            path=self.fake_path,
            status=BrowserStatus.ACTIVE,
            safe_size=5000,
        )
        active_report.items_by_safety[SafetyLevel.SAFE].append(
            StorageItem(
                relative_path="Default/Cache",
                size=5000,
                safety=SafetyLevel.SAFE,
                category="cache",
                description="Cache",
                rationale="Safe",
            )
        )

        unknown_report = BrowserReport(
            name="unknown_prof",
            path=self.fake_path,
            status=BrowserStatus.UNKNOWN,
            safe_size=3000,
        )

        inactive_report = BrowserReport(
            name="inactive_prof",
            path=self.fake_path,
            status=BrowserStatus.INACTIVE,
            safe_size=8000,
        )
        inactive_report.items_by_safety[SafetyLevel.SAFE].append(
            StorageItem(
                relative_path="Default/Cache",
                size=8000,
                safety=SafetyLevel.SAFE,
                category="cache",
                description="Cache",
                rationale="Safe",
            )
        )

        aggregate = AggregateReport(
            root=Path("/fake/chrome"),
            reports=[active_report, unknown_report, inactive_report],
        )

        plan = create_cleanup_plan_for_all(aggregate)

        # Only the inactive profile should be targeted
        self.assertEqual(len(plan.targeted_browsers), 1)
        self.assertEqual(plan.targeted_browsers[0].name, "inactive_prof")
        self.assertEqual(plan.total_bytes_to_clean, 8000)

        # Active and unknown must be skipped
        self.assertEqual(len(plan.skipped_active), 1)
        self.assertEqual(plan.skipped_active[0].name, "active_prof")
        self.assertEqual(len(plan.skipped_unknown), 1)
        self.assertEqual(plan.skipped_unknown[0].name, "unknown_prof")

    def test_plan_for_active_single_browser_returns_empty_plan(self):
        report = BrowserReport(
            name="active_single",
            path=self.fake_path,
            status=BrowserStatus.ACTIVE,
            safe_size=5000,
        )
        plan = create_cleanup_plan_for_browser(report)
        self.assertTrue(plan.is_empty)
        self.assertEqual(len(plan.skipped_active), 1)

    def test_browser_cleanup_plan_refuses_non_safe_items(self):
        inactive_report = BrowserReport(
            name="inactive_prof",
            path=self.fake_path,
            status=BrowserStatus.INACTIVE,
            safe_size=5000,
        )
        dangerous_item = StorageItem(
            relative_path="Default/Cookies",
            size=5000,
            safety=SafetyLevel.PROTECTED,
            category="auth",
            description="Cookies",
            rationale="Protected",
        )
        with self.assertRaises(ValueError):
            BrowserCleanupPlan(
                report=inactive_report,
                items_to_clean=[dangerous_item],
                total_bytes=5000,
            )

    def test_low_risk_cleanup_planning(self):
        active_report = BrowserReport(
            name="active_prof",
            path=self.fake_path,
            status=BrowserStatus.ACTIVE,
            low_risk_size=1000,
        )
        active_report.items_by_safety[SafetyLevel.LOW_RISK].append(
            StorageItem(
                relative_path="component_crx_cache",
                size=1000,
                safety=SafetyLevel.LOW_RISK,
                category="component_cache",
                description="Components",
                rationale="Low risk",
            )
        )

        inactive_report = BrowserReport(
            name="inactive_prof",
            path=self.fake_path,
            status=BrowserStatus.INACTIVE,
            low_risk_size=4000,
        )
        inactive_report.items_by_safety[SafetyLevel.LOW_RISK].append(
            StorageItem(
                relative_path="component_crx_cache",
                size=4000,
                safety=SafetyLevel.LOW_RISK,
                category="component_cache",
                description="Components",
                rationale="Low risk",
            )
        )

        aggregate = AggregateReport(
            root=Path("/fake/chrome"),
            reports=[active_report, inactive_report],
        )

        plan = create_low_risk_cleanup_plan_for_all(aggregate)
        self.assertEqual(len(plan.targeted_browsers), 1)
        self.assertEqual(plan.targeted_browsers[0].name, "inactive_prof")
        self.assertEqual(plan.total_bytes_to_clean, 4000)
        self.assertEqual(len(plan.skipped_active), 1)

        single_plan = create_low_risk_cleanup_plan_for_browser(inactive_report)
        self.assertEqual(len(single_plan.targeted_browsers), 1)
        self.assertEqual(single_plan.total_bytes_to_clean, 4000)

    def test_browser_cleanup_plan_disallows_unsafe_levels(self):
        inactive_report = BrowserReport(
            name="inactive_prof",
            path=self.fake_path,
            status=BrowserStatus.INACTIVE,
            review_size=2000,
        )
        review_item = StorageItem(
            relative_path="Default/Service Worker",
            size=2000,
            safety=SafetyLevel.REVIEW,
            category="application_storage",
            description="Service Worker",
            rationale="Review",
        )
        # Attempting to allow REVIEW must fail
        with self.assertRaises(ValueError):
            BrowserCleanupPlan(
                report=inactive_report,
                items_to_clean=[review_item],
                total_bytes=2000,
                allowed_safety_levels=(SafetyLevel.REVIEW,),
            )


if __name__ == "__main__":
    unittest.main()
