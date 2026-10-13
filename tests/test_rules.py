"""Tests for rule model, registry, and path classification matching."""

import unittest

from power_cleaner.models import CleanupAction, Confidence, Rule, SafetyLevel
from power_cleaner.rules import DEFAULT_RULES, RuleRegistry


class TestRules(unittest.TestCase):
    def setUp(self):
        self.registry = RuleRegistry()

    def test_safe_rules_have_high_confidence(self):
        for rule in DEFAULT_RULES:
            if rule.safety == SafetyLevel.SAFE:
                self.assertEqual(
                    rule.confidence,
                    Confidence.HIGH,
                    f"Rule {rule.path} is marked SAFE but lacks HIGH confidence",
                )

    def test_exact_path_match(self):
        rule = self.registry.match_path("Default/Cache")
        self.assertIsNotNone(rule)
        self.assertEqual(rule.path, "Default/Cache")
        self.assertEqual(rule.safety, SafetyLevel.SAFE)
        self.assertEqual(rule.cleanup_action, CleanupAction.CLEAR_CONTENTS)

    def test_directory_prefix_match(self):
        # A file nested inside Default/Cache should match Default/Cache
        rule = self.registry.match_path("Default/Cache/data_0")
        self.assertIsNotNone(rule)
        self.assertEqual(rule.path, "Default/Cache")
        self.assertEqual(rule.safety, SafetyLevel.SAFE)

    def test_longest_prefix_match_precedence(self):
        custom_registry = RuleRegistry(
            rules=[
                Rule(
                    path="Default",
                    category="general",
                    safety=SafetyLevel.PROTECTED,
                    description="General profile",
                    rationale="Base directory",
                ),
                Rule(
                    path="Default/Cache",
                    category="browser_cache",
                    safety=SafetyLevel.SAFE,
                    description="Cache directory",
                    rationale="Safe cache",
                ),
            ]
        )
        # Should match the more specific rule Default/Cache, not Default
        rule = custom_registry.match_path("Default/Cache/index")
        self.assertIsNotNone(rule)
        self.assertEqual(rule.path, "Default/Cache")
        self.assertEqual(rule.safety, SafetyLevel.SAFE)

        # File directly under Default matches Default
        rule_base = custom_registry.match_path("Default/custom_file")
        self.assertIsNotNone(rule_base)
        self.assertEqual(rule_base.path, "Default")

    def test_sqlite_sidecar_matching(self):
        # Default/History is PROTECTED; History-wal and History-journal must match
        rule_wal = self.registry.match_path("Default/History-wal")
        self.assertIsNotNone(rule_wal)
        self.assertEqual(rule_wal.path, "Default/History")
        self.assertEqual(rule_wal.safety, SafetyLevel.PROTECTED)

        rule_journal = self.registry.match_path("Default/History-journal")
        self.assertIsNotNone(rule_journal)
        self.assertEqual(rule_journal.path, "Default/History")
        self.assertEqual(rule_journal.safety, SafetyLevel.PROTECTED)

    def test_unclassified_path_returns_none(self):
        rule = self.registry.match_path("Default/UnknownFolder/mystery.bin")
        self.assertIsNone(rule)

    def test_newly_added_rules(self):
        # LOW_RISK items
        rule = self.registry.match_path("VariationsSafeSeedV2")
        self.assertIsNotNone(rule)
        self.assertEqual(rule.safety, SafetyLevel.LOW_RISK)

        rule = self.registry.match_path("first_party_sets.db")
        self.assertIsNotNone(rule)
        self.assertEqual(rule.safety, SafetyLevel.LOW_RISK)

        # REVIEW items
        rule = self.registry.match_path("Default/Network Action Predictor")
        self.assertIsNotNone(rule)
        self.assertEqual(rule.safety, SafetyLevel.REVIEW)

        # PROTECTED items
        rule = self.registry.match_path("Default/Affiliation Database")
        self.assertIsNotNone(rule)
        self.assertEqual(rule.safety, SafetyLevel.PROTECTED)

        rule = self.registry.match_path("Default/Accounts")
        self.assertIsNotNone(rule)
        self.assertEqual(rule.safety, SafetyLevel.PROTECTED)


if __name__ == "__main__":
    unittest.main()
