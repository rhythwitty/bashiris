"""Data models for ChromePower storage analysis and cleanup."""

from __future__ import annotations

import sys
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path

if sys.version_info >= (3, 11):
    from enum import StrEnum
else:
    class StrEnum(str, Enum):
        def __str__(self) -> str:
            return str(self.value)


class SafetyLevel(StrEnum):
    SAFE = "SAFE"
    LOW_RISK = "LOW_RISK"
    REVIEW = "REVIEW"
    PROTECTED = "PROTECTED"
    UNKNOWN = "UNKNOWN"
    INACCESSIBLE = "INACCESSIBLE"


class Confidence(StrEnum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"


class CleanupAction(StrEnum):
    CLEAR_CONTENTS = "clear_contents"
    DELETE_PATH = "delete_path"
    NONE = "none"


class BrowserStatus(StrEnum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    UNKNOWN = "UNKNOWN"


@dataclass(frozen=True)
class Rule:
    """A data-driven classification rule for a Chrome path."""

    path: str
    category: str
    safety: SafetyLevel
    description: str
    rationale: str
    cleanup_action: CleanupAction = CleanupAction.CLEAR_CONTENTS
    # Reserved for a future opt-in/opt-out filtering feature.
    # Currently not consulted by RuleRegistry.match_path() or the planner.
    enabled_by_default: bool = True
    confidence: Confidence = Confidence.HIGH

    @property
    def normalized_path(self) -> str:
        return self.path.replace("\\", "/").strip("/")


@dataclass
class StorageItem:
    """An aggregated storage item classified under a specific rule or category."""

    relative_path: str
    size: int
    safety: SafetyLevel
    category: str
    description: str
    rationale: str
    cleanup_action: CleanupAction = CleanupAction.NONE
    confidence: Confidence = Confidence.HIGH
    file_count: int = 1
    path: Path | None = None


@dataclass
class BrowserReport:
    """Detailed storage and status report for an individual Chrome browser profile."""

    name: str
    path: Path

    status: BrowserStatus = BrowserStatus.UNKNOWN
    status_reason: str = ""
    active_pid: int | None = None

    total_size: int = 0
    safe_size: int = 0
    low_risk_size: int = 0
    review_size: int = 0
    protected_size: int = 0
    unknown_size: int = 0
    inaccessible_size: int = 0
    inaccessible_count: int = 0

    items_by_safety: dict[SafetyLevel, list[StorageItem]] = field(
        default_factory=lambda: {level: [] for level in SafetyLevel}
    )

    @property
    def can_clean(self) -> bool:
        """Only inactive profiles with safe bytes can be cleaned."""
        return self.status == BrowserStatus.INACTIVE and self.safe_size > 0

    @property
    def can_clean_low_risk(self) -> bool:
        """Only inactive profiles with low-risk bytes can be cleaned."""
        return self.status == BrowserStatus.INACTIVE and self.low_risk_size > 0

    @property
    def calculated_sum(self) -> int:
        return (
            self.safe_size
            + self.low_risk_size
            + self.review_size
            + self.protected_size
            + self.unknown_size
            + self.inaccessible_size
        )

    @property
    def is_accounting_exact(self) -> bool:
        return self.total_size == self.calculated_sum

    @property
    def safe_items(self) -> list[StorageItem]:
        return self.items_by_safety.get(SafetyLevel.SAFE, [])

    @property
    def low_risk_items(self) -> list[StorageItem]:
        return self.items_by_safety.get(SafetyLevel.LOW_RISK, [])

    @property
    def review_items(self) -> list[StorageItem]:
        return self.items_by_safety.get(SafetyLevel.REVIEW, [])

    @property
    def protected_items(self) -> list[StorageItem]:
        return self.items_by_safety.get(SafetyLevel.PROTECTED, [])

    @property
    def unknown_items(self) -> list[StorageItem]:
        return self.items_by_safety.get(SafetyLevel.UNKNOWN, [])

    @property
    def inaccessible_items(self) -> list[StorageItem]:
        return self.items_by_safety.get(SafetyLevel.INACCESSIBLE, [])


@dataclass
class AggregateReport:
    """Summary of all discovered Chrome profiles across the ChromePower root."""

    root: Path
    reports: list[BrowserReport]

    @property
    def browser_count(self) -> int:
        return len(self.reports)

    @property
    def active_count(self) -> int:
        return sum(1 for r in self.reports if r.status == BrowserStatus.ACTIVE)

    @property
    def inactive_count(self) -> int:
        return sum(1 for r in self.reports if r.status == BrowserStatus.INACTIVE)

    @property
    def unknown_status_count(self) -> int:
        return sum(1 for r in self.reports if r.status == BrowserStatus.UNKNOWN)

    @property
    def total_size(self) -> int:
        return sum(r.total_size for r in self.reports)

    @property
    def safe_size(self) -> int:
        return sum(r.safe_size for r in self.reports)

    @property
    def low_risk_size(self) -> int:
        return sum(r.low_risk_size for r in self.reports)

    @property
    def review_size(self) -> int:
        return sum(r.review_size for r in self.reports)

    @property
    def protected_size(self) -> int:
        return sum(r.protected_size for r in self.reports)

    @property
    def unknown_size(self) -> int:
        return sum(r.unknown_size for r in self.reports)

    @property
    def inaccessible_size(self) -> int:
        return sum(r.inaccessible_size for r in self.reports)

    @property
    def largest_browser(self) -> BrowserReport | None:
        if not self.reports:
            return None
        return max(self.reports, key=lambda r: r.total_size)

    @property
    def largest_cleanup(self) -> BrowserReport | None:
        if not self.reports:
            return None
        return max(self.reports, key=lambda r: r.safe_size)

    @property
    def largest_unknown(self) -> BrowserReport | None:
        """Browser with the most unclassified data — useful for rule authoring."""
        if not self.reports:
            return None
        return max(self.reports, key=lambda r: r.unknown_size)
