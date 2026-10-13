"""Single-pass filesystem scanner with exact storage accounting."""

from __future__ import annotations

import logging
import os
from pathlib import Path

logger = logging.getLogger(__name__)

from power_cleaner.config import get_chrome_root
from power_cleaner.discovery import discover_browsers
from power_cleaner.models import (
    AggregateReport,
    BrowserReport,
    CleanupAction,
    Confidence,
    SafetyLevel,
    StorageItem,
)
from power_cleaner.process import get_system_processes, inspect_browser_activity
from power_cleaner.rules import RuleRegistry


class ProfileScanner:
    """High-performance profile scanner ensuring 100% exact storage accounting."""

    def __init__(self, registry: RuleRegistry | None = None) -> None:
        self.registry = registry or RuleRegistry()
        self._cache: dict[Path, BrowserReport] = {}

    def clear_cache(self) -> None:
        self._cache.clear()

    def scan_browser(
        self,
        browser_path: Path,
        force: bool = False,
        processes: list[tuple[int, str]] | None = None,
    ) -> BrowserReport:
        """Scan a single browser profile directory with exact single-pass accounting."""
        resolved_path = browser_path.resolve()
        if not force and resolved_path in self._cache:
            return self._cache[resolved_path]

        report = BrowserReport(
            name=browser_path.name,
            path=browser_path,
        )

        # 1. Activity inspection
        status, reason, pid = inspect_browser_activity(
            browser_path, processes=processes
        )
        report.status = status
        report.status_reason = reason
        report.active_pid = pid

        # Aggregation containers
        classified_aggregates: dict[str, dict] = {}
        unknown_aggregates: dict[str, dict] = {}
        inaccessible_items: list[StorageItem] = []

        total_bytes = 0
        safe_bytes = 0
        low_risk_bytes = 0
        review_bytes = 0
        protected_bytes = 0
        unknown_bytes = 0
        inaccessible_bytes = 0
        inaccessible_count = 0

        def on_walk_error(err: OSError) -> None:
            nonlocal inaccessible_bytes, inaccessible_count
            inaccessible_count += 1
            rel_err = str(err.filename) if err.filename else "unknown"
            try:
                rel_err = Path(rel_err).relative_to(browser_path).as_posix()
            except (ValueError, TypeError):
                pass
            inaccessible_items.append(
                StorageItem(
                    relative_path=rel_err,
                    size=0,
                    safety=SafetyLevel.INACCESSIBLE,
                    category="inaccessible",
                    description=f"Permission error or access failure: {err.strerror}",
                    rationale="Cannot inspect directory contents safely.",
                    cleanup_action=CleanupAction.NONE,
                    confidence=Confidence.HIGH,
                )
            )

        # 2. Single-pass filesystem traversal
        try:
            for root, dirs, files in os.walk(
                browser_path, followlinks=False, onerror=on_walk_error
            ):
                root_path = Path(root)

                # Never follow symlinked directories
                dirs[:] = [d for d in dirs if not (root_path / d).is_symlink()]

                for filename in files:
                    file_path = root_path / filename

                    # Ignore symlinks
                    if file_path.is_symlink():
                        continue

                    try:
                        stat = file_path.stat()
                        size = stat.st_size
                    except (PermissionError, FileNotFoundError, OSError) as exc:
                        inaccessible_count += 1
                        try:
                            rel = file_path.relative_to(browser_path).as_posix()
                        except ValueError:
                            rel = file_path.name
                        inaccessible_items.append(
                            StorageItem(
                                relative_path=rel,
                                size=0,
                                safety=SafetyLevel.INACCESSIBLE,
                                category="inaccessible",
                                description=f"Inaccessible file: {exc}",
                                rationale="File could not be inspected safely.",
                                cleanup_action=CleanupAction.NONE,
                                confidence=Confidence.HIGH,
                            )
                        )
                        continue

                    total_bytes += size

                    # Determine relative path from browser root
                    try:
                        rel_path = file_path.relative_to(browser_path).as_posix()
                    except ValueError:
                        rel_path = filename

                    rule = self.registry.match_path(rel_path)

                    if rule is not None:
                        # Classified by a known rule
                        rule_key = rule.normalized_path
                        if rule_key not in classified_aggregates:
                            classified_aggregates[rule_key] = {
                                "rule": rule,
                                "size": 0,
                                "count": 0,
                            }
                        classified_aggregates[rule_key]["size"] += size
                        classified_aggregates[rule_key]["count"] += 1

                        if rule.safety == SafetyLevel.SAFE:
                            safe_bytes += size
                        elif rule.safety == SafetyLevel.LOW_RISK:
                            low_risk_bytes += size
                        elif rule.safety == SafetyLevel.REVIEW:
                            review_bytes += size
                        elif rule.safety == SafetyLevel.PROTECTED:
                            protected_bytes += size
                        elif rule.safety == SafetyLevel.UNKNOWN:
                            unknown_bytes += size
                    else:
                        # Unclassified / UNKNOWN file
                        unknown_bytes += size

                        # Group unknown files by their container
                        parts = rel_path.split("/")
                        if parts[0] == "Default" and len(parts) > 1:
                            group_key = f"Default/{parts[1]}"
                        elif len(parts) > 1:
                            group_key = parts[0]
                        else:
                            group_key = parts[0]

                        if group_key not in unknown_aggregates:
                            unknown_aggregates[group_key] = {
                                "size": 0,
                                "count": 0,
                            }
                        unknown_aggregates[group_key]["size"] += size
                        unknown_aggregates[group_key]["count"] += 1

        except (PermissionError, OSError) as exc:
            on_walk_error(exc)

        # 3. Populate report totals
        # inaccessible_bytes stays 0 because we cannot stat the files;
        # inaccessible_size in the report mirrors this (0 B per item is correct
        # and the accounting invariant still holds).  The count is what matters
        # for the display.
        report.total_size = total_bytes
        report.safe_size = safe_bytes
        report.low_risk_size = low_risk_bytes
        report.review_size = review_bytes
        report.protected_size = protected_bytes
        report.unknown_size = unknown_bytes
        report.inaccessible_size = sum(item.size for item in inaccessible_items)
        report.inaccessible_count = inaccessible_count

        # 4. Construct items by safety
        # Classified items
        for rule_key, data in classified_aggregates.items():
            rule = data["rule"]
            item = StorageItem(
                relative_path=rule.path,
                size=data["size"],
                safety=rule.safety,
                category=rule.category,
                description=rule.description,
                rationale=rule.rationale,
                cleanup_action=rule.cleanup_action,
                confidence=rule.confidence,
                file_count=data["count"],
                path=browser_path / rule.normalized_path,
            )
            report.items_by_safety[rule.safety].append(item)

        # Unknown items
        for group_key, data in unknown_aggregates.items():
            item = StorageItem(
                relative_path=group_key,
                size=data["size"],
                safety=SafetyLevel.UNKNOWN,
                category="unknown",
                description="Unclassified Chrome profile data",
                rationale="Not recognized by current cleanup rules; review to determine purpose.",
                cleanup_action=CleanupAction.NONE,
                confidence=Confidence.LOW,
                file_count=data["count"],
                path=browser_path / group_key,
            )
            report.items_by_safety[SafetyLevel.UNKNOWN].append(item)

        # Inaccessible items
        report.items_by_safety[SafetyLevel.INACCESSIBLE].extend(inaccessible_items)

        # Sort all item lists by size descending
        for level in SafetyLevel:
            report.items_by_safety[level].sort(key=lambda it: it.size, reverse=True)

        # Exact accounting check
        if not report.is_accounting_exact:
            logger.warning(
                "Accounting mismatch for %s: total=%d vs sum=%d (diff=%d)",
                browser_path.name,
                report.total_size,
                report.calculated_sum,
                report.total_size - report.calculated_sum,
            )

        self._cache[resolved_path] = report
        return report

    def scan_all(
        self,
        root: Path | None = None,
        force: bool = False,
    ) -> AggregateReport:
        """Scan all discovered profiles under the ChromePower root."""
        browsers = discover_browsers(root)

        # Fetch process list ONCE for the entire batch
        processes = get_system_processes()

        reports: list[BrowserReport] = []
        for browser in browsers:
            reports.append(self.scan_browser(browser, force=force, processes=processes))

        search_root = root or (
            Path(browsers[0].parent) if browsers else get_chrome_root()
        )
        return AggregateReport(root=search_root, reports=reports)
