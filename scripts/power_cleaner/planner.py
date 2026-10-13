"""Cleanup planning and validation logic."""

from __future__ import annotations

from dataclasses import dataclass, field

from power_cleaner.models import (
    AggregateReport,
    BrowserReport,
    BrowserStatus,
    SafetyLevel,
    StorageItem,
)

VALID_CLEANUP_LEVELS: frozenset[SafetyLevel] = frozenset(
    {SafetyLevel.SAFE, SafetyLevel.LOW_RISK}
)


@dataclass
class BrowserCleanupPlan:
    """Planned cleanup actions for an individual inactive browser profile."""

    report: BrowserReport
    items_to_clean: list[StorageItem]
    total_bytes: int
    allowed_safety_levels: tuple[SafetyLevel, ...] = (SafetyLevel.SAFE,)

    def __post_init__(self) -> None:
        # Enforce safety constraints
        if self.report.status != BrowserStatus.INACTIVE:
            raise ValueError(
                f"Cannot plan cleanup for {self.report.name}: status is {self.report.status}"
            )
        for lvl in self.allowed_safety_levels:
            if lvl not in VALID_CLEANUP_LEVELS:
                raise ValueError(
                    f"Safety level {lvl} is not eligible for cleanup (allowed: {sorted(lvl.value for lvl in VALID_CLEANUP_LEVELS)})"
                )
        for item in self.items_to_clean:
            if item.safety not in self.allowed_safety_levels:
                raise ValueError(
                    f"Refusing to clean item {item.relative_path} ({item.safety}) not in allowed levels {self.allowed_safety_levels}"
                )


@dataclass
class CleanupPlan:
    """Complete plan for cache cleanup across one or more profiles."""

    targeted_browsers: list[BrowserReport] = field(default_factory=list)
    skipped_active: list[BrowserReport] = field(default_factory=list)
    skipped_unknown: list[BrowserReport] = field(default_factory=list)
    skipped_clean: list[BrowserReport] = field(default_factory=list)
    browser_plans: list[BrowserCleanupPlan] = field(default_factory=list)
    safety_levels: tuple[SafetyLevel, ...] = (SafetyLevel.SAFE,)

    @property
    def total_bytes_to_clean(self) -> int:
        return sum(bp.total_bytes for bp in self.browser_plans)

    @property
    def is_empty(self) -> bool:
        return len(self.browser_plans) == 0


def create_cleanup_plan_for_all(
    aggregate: AggregateReport,
    safety_levels: tuple[SafetyLevel, ...] = (SafetyLevel.SAFE,),
) -> CleanupPlan:
    """Generate a cleanup plan for all inactive profiles in the aggregate report."""
    plan = CleanupPlan(safety_levels=safety_levels)

    for report in aggregate.reports:
        if report.status == BrowserStatus.ACTIVE:
            plan.skipped_active.append(report)
            continue

        if report.status == BrowserStatus.UNKNOWN:
            plan.skipped_unknown.append(report)
            continue

        # Browser is INACTIVE
        items_to_clean: list[StorageItem] = []
        for level in safety_levels:
            items_to_clean.extend(
                it for it in report.items_by_safety.get(level, []) if it.size > 0
            )

        if not items_to_clean:
            plan.skipped_clean.append(report)
            continue

        b_plan = BrowserCleanupPlan(
            report=report,
            items_to_clean=items_to_clean,
            total_bytes=sum(it.size for it in items_to_clean),
            allowed_safety_levels=safety_levels,
        )
        plan.targeted_browsers.append(report)
        plan.browser_plans.append(b_plan)

    return plan


def create_cleanup_plan_for_browser(
    report: BrowserReport,
    safety_levels: tuple[SafetyLevel, ...] = (SafetyLevel.SAFE,),
) -> CleanupPlan:
    """Generate a cleanup plan for a single browser profile."""
    plan = CleanupPlan(safety_levels=safety_levels)

    if report.status == BrowserStatus.ACTIVE:
        plan.skipped_active.append(report)
        return plan

    if report.status == BrowserStatus.UNKNOWN:
        plan.skipped_unknown.append(report)
        return plan

    items_to_clean: list[StorageItem] = []
    for level in safety_levels:
        items_to_clean.extend(
            it for it in report.items_by_safety.get(level, []) if it.size > 0
        )

    if not items_to_clean:
        plan.skipped_clean.append(report)
        return plan

    b_plan = BrowserCleanupPlan(
        report=report,
        items_to_clean=items_to_clean,
        total_bytes=sum(it.size for it in items_to_clean),
        allowed_safety_levels=safety_levels,
    )
    plan.targeted_browsers.append(report)
    plan.browser_plans.append(b_plan)
    return plan


def create_low_risk_cleanup_plan_for_all(aggregate: AggregateReport) -> CleanupPlan:
    """Generate a low-risk cache cleanup plan for all inactive profiles."""
    return create_cleanup_plan_for_all(aggregate, safety_levels=(SafetyLevel.LOW_RISK,))


def create_low_risk_cleanup_plan_for_browser(report: BrowserReport) -> CleanupPlan:
    """Generate a low-risk cache cleanup plan for a single browser profile."""
    return create_cleanup_plan_for_browser(
        report, safety_levels=(SafetyLevel.LOW_RISK,)
    )
