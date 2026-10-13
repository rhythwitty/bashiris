"""Formatting and presentation layer with ANSI terminal styling and JSON generation."""

from __future__ import annotations

import json
import os
import sys
from typing import Any

from power_cleaner.models import (
    AggregateReport,
    BrowserReport,
    BrowserStatus,
    SafetyLevel,
    StorageItem,
)
from power_cleaner.rules import SAFETY_DESCRIPTIONS


class ColorTheme:
    """Terminal ANSI colors with automatic TTY and NO_COLOR detection."""

    def __init__(self, force_disable: bool = False) -> None:
        # Detect whether colors should be enabled
        no_color = "NO_COLOR" in os.environ
        is_tty = hasattr(sys.stdout, "isatty") and sys.stdout.isatty()
        self.enabled = not force_disable and is_tty and not no_color

        if self.enabled:
            self.RESET = "\033[0m"
            self.BOLD = "\033[1m"
            self.DIM = "\033[2m"
            self.GREEN = "\033[32m"
            self.YELLOW = "\033[33m"
            self.RED = "\033[31m"
            self.CYAN = "\033[36m"
            self.BLUE = "\033[34m"
            self.MAGENTA = "\033[35m"
        else:
            self.RESET = ""
            self.BOLD = ""
            self.DIM = ""
            self.GREEN = ""
            self.YELLOW = ""
            self.RED = ""
            self.CYAN = ""
            self.BLUE = ""
            self.MAGENTA = ""

    def bold(self, text: str) -> str:
        return f"{self.BOLD}{text}{self.RESET}"

    def safe(self, text: str) -> str:
        return f"{self.GREEN}{text}{self.RESET}"

    def low_risk(self, text: str) -> str:
        return f"{self.CYAN}{text}{self.RESET}"

    def review(self, text: str) -> str:
        return f"{self.YELLOW}{text}{self.RESET}"

    def protected(self, text: str) -> str:
        return f"{self.RED}{text}{self.RESET}"

    def unknown(self, text: str) -> str:
        return f"{self.DIM}{text}{self.RESET}"

    def active(self, text: str) -> str:
        return f"{self.RED}{self.BOLD}{text}{self.RESET}"

    def inactive(self, text: str) -> str:
        return f"{self.GREEN}{text}{self.RESET}"

    def status(self, status: BrowserStatus) -> str:
        if status == BrowserStatus.ACTIVE:
            return self.active("ACTIVE")
        if status == BrowserStatus.INACTIVE:
            return self.inactive("inactive")
        return self.review("UNKNOWN")


theme = ColorTheme()


def format_size(size: int) -> str:
    """Format bytes into a clean human-readable string."""
    units = ["B", "KB", "MB", "GB", "TB"]
    value = float(size)
    for unit in units:
        if value < 1024:
            if unit == "B":
                return f"{int(value)} B"
            return f"{value:.1f} {unit}"
        value /= 1024
    return f"{value:.1f} PB"


def human_percent(part: int, total: int) -> str:
    """Return formatted percentage string."""
    if total == 0:
        return "0.0%"
    return f"{part / total * 100:.1f}%"


def render_overview(aggregate: AggregateReport) -> str:
    """Render the high-level ChromePower overview."""
    lines = [
        "",
        theme.bold("ChromePower Cleaner"),
        "═" * 55,
        f"Root:              {aggregate.root}",
        "",
        f"Browsers:          {theme.bold(str(aggregate.browser_count))}",
        f"Total storage:     {theme.bold(format_size(aggregate.total_size))}",
        "",
        theme.bold("Potential cleanup:"),
        f"  Safe:            {theme.safe(format_size(aggregate.safe_size))}",
        f"  Low-risk:        {theme.low_risk(format_size(aggregate.low_risk_size))}",
        f"  Review:          {theme.review(format_size(aggregate.review_size))}",
        "",
        f"Protected:         {theme.protected(format_size(aggregate.protected_size))}",
        f"Unknown:           {theme.unknown(format_size(aggregate.unknown_size))}",
        f"Inaccessible:      {format_size(aggregate.inaccessible_size)}",
        "",
    ]

    if aggregate.total_size > 0:
        safe_pct = human_percent(aggregate.safe_size, aggregate.total_size)
        lines.append(f"Safe cleanup:      {theme.safe(safe_pct)}")
        lines.append("")

    if aggregate.largest_browser:
        lines.append("Largest browser:")
        lines.append(
            f"    {aggregate.largest_browser.name} — {format_size(aggregate.largest_browser.total_size)}"
        )
        lines.append("")

    if aggregate.largest_cleanup and aggregate.largest_cleanup.safe_size > 0:
        lines.append("Largest cleanup opportunity:")
        lines.append(
            f"    {aggregate.largest_cleanup.name} — {theme.safe(format_size(aggregate.largest_cleanup.safe_size))}"
        )
        lines.append("")

    # Find largest unknown item across profiles
    largest_unk_browser = ""
    largest_unk_path = ""
    largest_unk_size = 0
    for r in aggregate.reports:
        for it in r.unknown_items:
            if it.size > largest_unk_size:
                largest_unk_size = it.size
                largest_unk_browser = r.name
                largest_unk_path = it.relative_path

    if largest_unk_size > 0:
        lines.append("Largest unknown data:")
        lines.append(
            f"    {largest_unk_browser} / {largest_unk_path} — {format_size(largest_unk_size)}"
        )
        lines.append("")

    lines.append("Browser activity status:")
    lines.append(f"  Active:          {theme.active(str(aggregate.active_count))}")
    lines.append(f"  Inactive:        {theme.inactive(str(aggregate.inactive_count))}")
    lines.append(f"  Unknown status:  {str(aggregate.unknown_status_count)}")

    return "\n".join(lines)


def render_browser_table(
    reports: list[BrowserReport],
    sort_by: str = "size",
) -> str:
    """Render the browser profile table with configurable sorting."""
    sorted_reports = list(reports)
    if sort_by == "size":
        sorted_reports.sort(key=lambda r: r.total_size, reverse=True)
    elif sort_by == "safe" or sort_by == "cleanup":
        sorted_reports.sort(key=lambda r: r.safe_size, reverse=True)
    elif sort_by == "review":
        sorted_reports.sort(key=lambda r: r.review_size, reverse=True)
    elif sort_by == "unknown":
        sorted_reports.sort(key=lambda r: r.unknown_size, reverse=True)
    elif sort_by == "name":
        sorted_reports.sort(key=lambda r: r.name.lower())
    elif sort_by == "status":
        sorted_reports.sort(
            key=lambda r: (r.status != BrowserStatus.ACTIVE, r.name.lower())
        )

    lines = [
        "",
        theme.bold(f"ChromePower Browsers (Sorted by {sort_by})"),
        f"{'#':>3}  {'Browser':<25} {'Total':>10} {'Safe':>10} {'Review':>10} {'Unknown':>10}  {'Status'}",
        "─" * 82,
    ]

    for index, r in enumerate(sorted_reports, 1):
        status_str = theme.status(r.status)
        lines.append(
            f"{index:>3}  "
            f"{r.name:<25} "
            f"{format_size(r.total_size):>10} "
            f"{format_size(r.safe_size):>10} "
            f"{format_size(r.review_size):>10} "
            f"{format_size(r.unknown_size):>10}  "
            f"{status_str}"
        )

    return "\n".join(lines)


def render_browser_details(report: BrowserReport) -> str:
    """Render comprehensive inspection breakdown for a single browser."""
    lines = [
        "",
        theme.bold(f"Browser: {report.name}"),
        f"Path:    {report.path}",
    ]

    if report.status == BrowserStatus.ACTIVE:
        lines.append(
            f"Status:  {theme.active('ACTIVE — cleanup disabled')} ({report.status_reason})"
        )
    elif report.status == BrowserStatus.INACTIVE:
        lines.append(f"Status:  {theme.inactive('INACTIVE')}")
    else:
        lines.append(
            f"Status:  {theme.review('UNKNOWN — cleanup disabled')} ({report.status_reason})"
        )

    lines.extend(
        [
            "",
            f"Total:         {format_size(report.total_size)}",
            f"Safe:          {theme.safe(format_size(report.safe_size))}",
            f"Low risk:      {theme.low_risk(format_size(report.low_risk_size))}",
            f"Review:        {theme.review(format_size(report.review_size))}",
            f"Protected:     {theme.protected(format_size(report.protected_size))}",
            f"Unknown:       {theme.unknown(format_size(report.unknown_size))}",
            f"Inaccessible:  {format_size(report.inaccessible_size)} ({report.inaccessible_count} errors)",
            "",
            theme.bold("STORAGE BREAKDOWN"),
            "═" * 45,
        ]
    )

    def render_section(title: str, items: list[StorageItem], color_fn) -> None:
        lines.append(f"\n{color_fn(title)}")
        lines.append("─" * len(title))
        if not items:
            lines.append("  (None)")
            return
        for it in items:
            lines.append(f"  {format_size(it.size):>10}  {it.relative_path}")
            if it.description:
                lines.append(f"              {theme.DIM}{it.description}{theme.RESET}")

    render_section("SAFE TO CLEAN", report.safe_items, theme.safe)
    render_section("LOW RISK", report.low_risk_items, theme.low_risk)
    render_section("REVIEW", report.review_items, theme.review)
    render_section("PROTECTED", report.protected_items, theme.protected)
    render_section("UNKNOWN", report.unknown_items, theme.unknown)

    if report.inaccessible_items:
        render_section("INACCESSIBLE", report.inaccessible_items, theme.review)

    lines.extend(
        [
            "",
            theme.bold("CLEANUP SUMMARY"),
            "─" * 25,
            f"Potentially reclaimable: {theme.safe(format_size(report.safe_size))}",
        ]
    )

    if report.status == BrowserStatus.ACTIVE:
        lines.append(
            f"Cleanup:                 {theme.active('BLOCKED — Chrome is active')}"
        )
    elif report.status == BrowserStatus.UNKNOWN:
        lines.append(
            f"Cleanup:                 {theme.review('BLOCKED — activity status unknown')}"
        )
    elif report.safe_size == 0:
        lines.append("Cleanup:                 Nothing safe to clean")
    else:
        lines.append(f"Cleanup:                 {theme.safe('READY TO CLEAN')}")

    return "\n".join(lines)


def render_why_explanation(item: StorageItem) -> str:
    """Render detailed explanation of why an item is classified and what action is advised."""
    lines = [
        "",
        theme.bold(f"Path: {item.relative_path}"),
        f"Size: {format_size(item.size)} ({item.file_count} files)",
        f"Category: {item.category}",
        f"Classification: {item.safety.value} (Confidence: {item.confidence.value})",
        "",
        theme.bold("Why:"),
        f"  {item.rationale or item.description}",
        "",
        theme.bold("Category Overview:"),
        f"  {SAFETY_DESCRIPTIONS.get(item.safety, 'No category description available.')}",
        "",
        theme.bold("Suggested action:"),
    ]

    if item.safety == SafetyLevel.SAFE:
        lines.append("  Safe to clean. Chrome will regenerate cache data as needed.")
    elif item.safety == SafetyLevel.LOW_RISK:
        lines.append(
            "  Can be cleaned if space is critical; Chrome will redownload component files."
        )
    elif item.safety == SafetyLevel.REVIEW:
        lines.append(
            "  Review before deleting. May affect offline web apps or saved site state."
        )
    elif item.safety == SafetyLevel.PROTECTED:
        lines.append(
            "  PROTECTED. Do not delete. Contains essential personal user or browser state."
        )
    else:
        lines.append("  Unclassified data. Investigate contents before removing.")

    return "\n".join(lines)


def render_largest_cleanup_opportunities(
    reports: list[BrowserReport], top_n: int = 15
) -> str:
    """Render ranked cleanup opportunities showing actual directories responsible."""
    sorted_reports = [r for r in reports if r.safe_size > 0]
    sorted_reports.sort(key=lambda r: r.safe_size, reverse=True)

    lines = [
        "",
        theme.bold("Largest Cleanup Opportunities"),
        f"{'#':>2} {'Browser':<25} {'Total':>10} {'Safe':>10} {'% Reclaimable':>14}  {'Status'}",
        "─" * 72,
    ]

    top_reports = sorted_reports[:top_n]
    for index, r in enumerate(top_reports, 1):
        pct = human_percent(r.safe_size, r.total_size)
        lines.append(
            f"{index:>2} "
            f"{r.name:<25} "
            f"{format_size(r.total_size):>10} "
            f"{theme.safe(format_size(r.safe_size)):>10} "
            f"{pct:>14}  "
            f"{theme.status(r.status)}"
        )

    # Show directories responsible for top 5
    if top_reports:
        lines.extend(
            [
                "",
                theme.bold("Responsible Cache Directories (Top Browsers):"),
                "─" * 50,
            ]
        )
        for r in top_reports[:5]:
            lines.append(f"\n{theme.bold(r.name)} (Safe: {format_size(r.safe_size)}):")
            for it in r.safe_items[:4]:
                if it.size > 0:
                    lines.append(
                        f"    {it.relative_path:<32} {format_size(it.size):>10}"
                    )

    return "\n".join(lines)


def render_largest_unknown_data(reports: list[BrowserReport], top_n: int = 20) -> str:
    """Render list of largest unknown paths across all profiles."""
    unknown_entries: list[tuple[str, str, int, int]] = []
    for r in reports:
        for it in r.unknown_items:
            if it.size > 0:
                unknown_entries.append(
                    (r.name, it.relative_path, it.size, it.file_count)
                )

    unknown_entries.sort(key=lambda x: x[2], reverse=True)

    lines = [
        "",
        theme.bold("Largest Unknown Data (Opportunities for Rule Additions)"),
        f"{'#':>2} {'Browser':<20} {'Relative Path':<35} {'Size':>10} {'Files':>8}",
        "─" * 80,
    ]

    if not unknown_entries:
        lines.append("  (No unknown data found across any profiles!)")
        return "\n".join(lines)

    for index, (b_name, rel_path, size, count) in enumerate(unknown_entries[:top_n], 1):
        lines.append(
            f"{index:>2} {b_name:<20} {rel_path:<35} {format_size(size):>10} {count:>8}"
        )

    return "\n".join(lines)


def render_largest_review_data(reports: list[BrowserReport], top_n: int = 20) -> str:
    """Render list of largest review items across all profiles."""
    review_entries: list[tuple[str, str, int, str]] = []
    for r in reports:
        for it in r.review_items:
            if it.size > 0:
                review_entries.append((r.name, it.relative_path, it.size, it.rationale))

    review_entries.sort(key=lambda x: x[2], reverse=True)

    lines = [
        "",
        theme.bold("Largest Review Data (Persistent Web / App Storage)"),
        f"{'#':>2} {'Browser':<18} {'Path':<28} {'Size':>10}  {'Explanation'}",
        "─" * 85,
    ]

    if not review_entries:
        lines.append("  (No review data found!)")
        return "\n".join(lines)

    for index, (b_name, rel_path, size, rationale) in enumerate(
        review_entries[:top_n], 1
    ):
        short_rat = rationale[:40] + "..." if len(rationale) > 40 else rationale
        lines.append(
            f"{index:>2} "
            f"{b_name:<18} "
            f"{rel_path:<28} "
            f"{format_size(size):>10}  "
            f"{short_rat}"
        )

    return "\n".join(lines)


def to_json_dict(aggregate: AggregateReport) -> dict[str, Any]:
    """Convert aggregate report into structured JSON suitable for scripts."""
    profiles_data = []
    for r in aggregate.reports:
        items_data = []
        for level in SafetyLevel:
            for it in r.items_by_safety.get(level, []):
                items_data.append(
                    {
                        "path": it.relative_path,
                        "size_bytes": it.size,
                        "file_count": it.file_count,
                        "safety": it.safety.value,
                        "category": it.category,
                        "description": it.description,
                        "rationale": it.rationale,
                        "confidence": it.confidence.value,
                    }
                )

        profiles_data.append(
            {
                "name": r.name,
                "path": str(r.path),
                "status": r.status.value,
                "status_reason": r.status_reason,
                "active_pid": r.active_pid,
                "can_clean": r.can_clean,
                "can_clean_low_risk": r.can_clean_low_risk,
                "total_bytes": r.total_size,
                "safe_bytes": r.safe_size,
                "low_risk_bytes": r.low_risk_size,
                "review_bytes": r.review_size,
                "protected_bytes": r.protected_size,
                "unknown_bytes": r.unknown_size,
                "inaccessible_bytes": r.inaccessible_size,
                "inaccessible_count": r.inaccessible_count,
                "is_accounting_exact": r.is_accounting_exact,
                "items": items_data,
            }
        )

    return {
        "root": str(aggregate.root),
        "browsers": aggregate.browser_count,
        "active_browsers": aggregate.active_count,
        "inactive_browsers": aggregate.inactive_count,
        "unknown_status_browsers": aggregate.unknown_status_count,
        "total_bytes": aggregate.total_size,
        "safe_bytes": aggregate.safe_size,
        "low_risk_bytes": aggregate.low_risk_size,
        "review_bytes": aggregate.review_size,
        "protected_bytes": aggregate.protected_size,
        "unknown_bytes": aggregate.unknown_size,
        "inaccessible_bytes": aggregate.inaccessible_size,
        "profiles": profiles_data,
    }


def output_json(aggregate: AggregateReport) -> None:
    """Print pure JSON to stdout."""
    data = to_json_dict(aggregate)
    json.dump(data, sys.stdout, indent=2)
    sys.stdout.write("\n")
    sys.stdout.flush()
