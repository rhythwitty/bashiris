"""Formatting and presentation layer with rich ANSI terminal styling and JSON generation."""

from __future__ import annotations

import json
import os
import sys
import threading
import time
from typing import Any

from power_cleaner.models import (
    AggregateReport,
    BrowserReport,
    BrowserStatus,
    SafetyLevel,
    StorageItem,
)
from power_cleaner.rules import SAFETY_DESCRIPTIONS

# ──────────────────────────────────────────────────────────────────────────────
#  Color Theme
# ──────────────────────────────────────────────────────────────────────────────


class ColorTheme:
    """Terminal ANSI colors with automatic TTY and NO_COLOR detection."""

    def __init__(self, force_disable: bool = False) -> None:
        no_color = "NO_COLOR" in os.environ
        is_tty = hasattr(sys.stdout, "isatty") and sys.stdout.isatty()
        self.enabled = not force_disable and is_tty and not no_color

        if self.enabled:
            self.RESET = "\033[0m"
            self.BOLD = "\033[1m"
            self.DIM = "\033[2m"
            self.ITALIC = "\033[3m"

            # Bright variants — more vivid in modern terminals
            self.GREEN = "\033[92m"
            self.YELLOW = "\033[93m"
            self.RED = "\033[91m"
            self.CYAN = "\033[96m"
            self.BLUE = "\033[94m"
            self.MAGENTA = "\033[95m"
            self.WHITE = "\033[97m"
            self.GRAY = "\033[90m"
            self.ORANGE = "\033[38;5;214m"

            # Backgrounds
            self.BG_RED = "\033[48;5;88m"
            self.BG_GREEN = "\033[48;5;22m"
            self.BG_DARK = "\033[48;5;235m"
        else:
            for attr in (
                "RESET",
                "BOLD",
                "DIM",
                "ITALIC",
                "GREEN",
                "YELLOW",
                "RED",
                "CYAN",
                "BLUE",
                "MAGENTA",
                "WHITE",
                "GRAY",
                "ORANGE",
                "BG_RED",
                "BG_GREEN",
                "BG_DARK",
            ):
                setattr(self, attr, "")

    # ── Semantic helpers ───────────────────────────────────────────────────────

    def bold(self, text: str) -> str:
        return f"{self.BOLD}{text}{self.RESET}"

    def dim(self, text: str) -> str:
        return f"{self.DIM}{text}{self.RESET}"

    def muted(self, text: str) -> str:
        return f"{self.GRAY}{text}{self.RESET}"

    def accent(self, text: str) -> str:
        return f"{self.CYAN}{text}{self.RESET}"

    def highlight(self, text: str) -> str:
        return f"{self.BOLD}{self.WHITE}{text}{self.RESET}"

    def safe(self, text: str) -> str:
        return f"{self.GREEN}{text}{self.RESET}"

    def low_risk(self, text: str) -> str:
        return f"{self.CYAN}{text}{self.RESET}"

    def review(self, text: str) -> str:
        return f"{self.YELLOW}{text}{self.RESET}"

    def protected(self, text: str) -> str:
        return f"{self.RED}{text}{self.RESET}"

    def unknown(self, text: str) -> str:
        return f"{self.DIM}{self.GRAY}{text}{self.RESET}"

    def active(self, text: str) -> str:
        return f"{self.BOLD}{self.RED}{text}{self.RESET}"

    def inactive(self, text: str) -> str:
        return f"{self.GREEN}{text}{self.RESET}"

    def status(self, status: BrowserStatus) -> str:
        if status == BrowserStatus.ACTIVE:
            return self.active("● ACTIVE")
        if status == BrowserStatus.INACTIVE:
            return self.inactive("○ inactive")
        return self.review("◌ unknown")

    def safety_label(self, level: SafetyLevel) -> str:
        labels = {
            SafetyLevel.SAFE: self.safe("SAFE"),
            SafetyLevel.LOW_RISK: self.low_risk("LOW-RISK"),
            SafetyLevel.REVIEW: self.review("REVIEW"),
            SafetyLevel.PROTECTED: self.protected("PROTECTED"),
        }
        return labels.get(level, self.unknown("UNKNOWN"))


theme = ColorTheme()


# ──────────────────────────────────────────────────────────────────────────────
#  Spinner (non-blocking, daemon thread)
# ──────────────────────────────────────────────────────────────────────────────


class Spinner:
    """Minimal inline spinner for scan feedback."""

    FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    def __init__(self, message: str = "Scanning") -> None:
        self.message = message
        self._stop_event = threading.Event()
        self._thread: threading.Thread | None = None

    def _spin(self) -> None:
        i = 0
        while not self._stop_event.is_set():
            frame = self.FRAMES[i % len(self.FRAMES)]
            colored = f"{theme.CYAN}{frame}{theme.RESET}" if theme.enabled else frame
            sys.stdout.write(f"\r  {colored}  {self.message}…")
            sys.stdout.flush()
            time.sleep(0.08)
            i += 1

    def start(self) -> None:
        if theme.enabled:
            self._stop_event.clear()
            self._thread = threading.Thread(target=self._spin, daemon=True)
            self._thread.start()
        else:
            print(f"  {self.message}…")

    def stop(self, done_message: str = "") -> None:
        if self._thread:
            self._stop_event.set()
            self._thread.join()
            sys.stdout.write("\r" + " " * (len(self.message) + 12) + "\r")
            sys.stdout.flush()
        if done_message:
            print(done_message)


# ──────────────────────────────────────────────────────────────────────────────
#  Size & Visual Utilities
# ──────────────────────────────────────────────────────────────────────────────


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


def render_mini_bar(part: int, total: int, width: int = 10, color_fn=None) -> str:
    """Render a compact horizontal proportion bar."""
    if total == 0:
        filled = 0
    else:
        filled = round(part / total * width)
    filled = max(0, min(filled, width))
    bar = "█" * filled + "░" * (width - filled)
    return color_fn(bar) if color_fn and theme.enabled else bar


def render_storage_bar(aggregate: AggregateReport, width: int = 30) -> str:
    """Render a stacked segmented storage bar."""
    total = aggregate.total_size
    if total == 0:
        return theme.muted("░" * width) if theme.enabled else "░" * width

    safe_w = round(aggregate.safe_size / total * width)
    low_w = round(aggregate.low_risk_size / total * width)
    rev_w = round(aggregate.review_size / total * width)
    prot_w = round(aggregate.protected_size / total * width)
    unk_w = max(0, width - safe_w - low_w - rev_w - prot_w)

    return (
        theme.safe("█" * safe_w)
        + theme.low_risk("█" * low_w)
        + theme.review("█" * rev_w)
        + theme.protected("█" * prot_w)
        + theme.unknown("░" * unk_w)
    )


def pad_right(text: str, width: int) -> str:
    """Pad string on the right based on visible character count."""
    return text + " " * max(0, width - len(text))


def pad_left(text: str, width: int) -> str:
    """Pad string on the left based on visible character count."""
    return " " * max(0, width - len(text)) + text


def _rule(width: int = 72, char: str = "─", color_fn=None) -> str:
    line = "  " + char * width
    return color_fn(line) if color_fn and theme.enabled else line


def render_breadcrumb(*parts: str) -> str:
    """Render a navigation trail: Home › Browsers › Profile"""
    sep = f"  {theme.muted('›')}  " if theme.enabled else "  ›  "
    colored = []
    for i, p in enumerate(parts):
        if i == len(parts) - 1:
            colored.append(theme.highlight(p) if theme.enabled else p)
        else:
            colored.append(theme.muted(p) if theme.enabled else p)
    return "  " + sep.join(colored)


# ──────────────────────────────────────────────────────────────────────────────
#  Banner
# ──────────────────────────────────────────────────────────────────────────────


def render_banner(version: str = "") -> str:
    """Render the styled app banner as a compact single-line header."""
    ver_str = f" v{version}" if version else ""
    return (
        f"  {theme.accent('⚡')} {theme.bold('ChromePower Cleaner')}{theme.dim(ver_str)}"
        f" {theme.muted('— Storage Analyzer & Cache Cleanup')}"
    )


# ──────────────────────────────────────────────────────────────────────────────
#  Overview
# ──────────────────────────────────────────────────────────────────────────────


def render_overview(aggregate: AggregateReport) -> str:
    """Render the compact, high-density ChromePower overview with precise column alignment."""
    W = 72

    bar = render_storage_bar(aggregate, width=24)
    legend = (
        f"{theme.safe('█')} Safe  "
        f"{theme.low_risk('█')} Low-risk  "
        f"{theme.review('█')} Review  "
        f"{theme.protected('█')} Prot  "
        f"{theme.unknown('░')} Unknown"
    )

    root_str = str(aggregate.root)
    lines = [
        f"  {bar}  {legend}",
        _rule(W, "═", theme.accent if theme.enabled else None),
        f"  {theme.muted(pad_right('Root:', 9))} {theme.dim(root_str) if theme.enabled else root_str}",
        (
            f"  {theme.muted(pad_right('Storage:', 9))} {theme.bold(format_size(aggregate.total_size))} across "
            f"{theme.bold(str(aggregate.browser_count))} browsers  "
            f"({theme.active('● ' + str(aggregate.active_count) + ' active')}  "
            f"{theme.inactive('○ ' + str(aggregate.inactive_count) + ' inactive')}  "
            f"{theme.muted('◌ ' + str(aggregate.unknown_status_count) + ' unknown')})"
        ),
        _rule(W, "─", theme.muted if theme.enabled else None),
    ]

    t = aggregate.total_size
    pct_safe = human_percent(aggregate.safe_size, t)
    s_bar = render_mini_bar(aggregate.safe_size, t, width=8, color_fn=theme.safe)
    l_bar = render_mini_bar(aggregate.low_risk_size, t, width=8, color_fn=theme.low_risk)
    r_bar = render_mini_bar(aggregate.review_size, t, width=8, color_fn=theme.review)

    safe_lbl = theme.muted(pad_right("Safe:", 10))
    safe_val = theme.safe(pad_left(format_size(aggregate.safe_size), 8))
    safe_pct = theme.muted(pad_left(pct_safe, 6))

    low_lbl = theme.muted(pad_right("Low-risk:", 10))
    low_val = theme.low_risk(pad_left(format_size(aggregate.low_risk_size), 8))

    rev_lbl = theme.muted(pad_right("Review:", 10))
    rev_val = theme.review(pad_left(format_size(aggregate.review_size), 8))

    prot_lbl = theme.muted(pad_right("Protected:", 14))
    prot_val = theme.protected(pad_left(format_size(aggregate.protected_size), 9))

    unk_lbl = theme.muted(pad_right("Unknown:", 14))
    unk_val = theme.unknown(pad_left(format_size(aggregate.unknown_size), 9))

    inacc_lbl = theme.muted(pad_right("Inaccessible:", 14))
    inacc_val = pad_left(format_size(aggregate.inaccessible_size), 9)

    blank_pct = " " * 6

    lines.append(
        f"  {safe_lbl} {safe_val}  {s_bar} {safe_pct}   │   {prot_lbl} {prot_val}"
    )
    lines.append(
        f"  {low_lbl} {low_val}  {l_bar} {blank_pct}   │   {unk_lbl} {unk_val}"
    )
    lines.append(
        f"  {rev_lbl} {rev_val}  {r_bar} {blank_pct}   │   {inacc_lbl} {inacc_val}"
    )
    lines.append(_rule(W, "─", theme.muted if theme.enabled else None))

    # Highlights
    hi_parts = []
    if aggregate.largest_browser:
        hi_parts.append(
            f"{theme.muted('Largest browser:')} {theme.highlight(aggregate.largest_browser.name)} {theme.dim('(' + format_size(aggregate.largest_browser.total_size) + ')')}"
        )
    if aggregate.largest_cleanup and aggregate.largest_cleanup.safe_size > 0:
        hi_parts.append(
            f"{theme.muted('Top cleanup opp:')} {theme.highlight(aggregate.largest_cleanup.name)} {theme.safe(format_size(aggregate.largest_cleanup.safe_size) + ' free')}"
        )
    if hi_parts:
        lines.append("  " + "  │  ".join(hi_parts))

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
        lines.append(
            f"  {theme.muted('Largest unknown:')} "
            f"{theme.unknown(largest_unk_browser + ' / ' + largest_unk_path)} "
            f"{theme.dim(format_size(largest_unk_size))}"
        )

    return "\n".join(lines)


# ──────────────────────────────────────────────────────────────────────────────
#  Browser Table
# ──────────────────────────────────────────────────────────────────────────────


def render_browser_table(
    reports: list[BrowserReport],
    sort_by: str = "size",
) -> str:
    """Render the browser profile table with configurable sorting."""
    sorted_reports = list(reports)
    if sort_by == "size":
        sorted_reports.sort(key=lambda r: r.total_size, reverse=True)
    elif sort_by in ("safe", "cleanup"):
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

    W = 84
    lines = [
        "",
        render_breadcrumb("Home", "Browsers"),
        "",
        _rule(W, "═", theme.accent if theme.enabled else None),
        (
            f"  {'#':>2}  "
            f"{theme.bold('Browser'):<25}  "
            f"{theme.bold('Total'):>10}  "
            f"{theme.safe('Safe'):>10}  "
            f"{theme.review('Review'):>10}  "
            f"{theme.unknown('Unknown'):>10}  "
            f"{theme.bold('Status')}"
        ),
        _rule(W, "─", theme.muted if theme.enabled else None),
    ]

    total_size = sum(r.total_size for r in reports)

    for index, r in enumerate(sorted_reports, 1):
        name_str = theme.bold(r.name) if r.status == BrowserStatus.ACTIVE else r.name
        lines.append(
            f"  {theme.muted(str(index)):>2}  "
            f"{name_str:<25}  "
            f"{format_size(r.total_size):>10}  "
            f"{theme.safe(format_size(r.safe_size)):>10}  "
            f"{theme.review(format_size(r.review_size)):>10}  "
            f"{theme.unknown(format_size(r.unknown_size)):>10}  "
            f"{theme.status(r.status)}"
        )

    lines.append(_rule(W, "─", theme.muted if theme.enabled else None))
    lines.append(
        f"  {'':>2}  {theme.muted('Total'):<25}  {theme.bold(format_size(total_size)):>10}"
    )
    lines.append("")
    sort_keys = ["size", "cleanup", "review", "unknown", "name"]
    sort_hint = "  ".join(
        (theme.accent(f"[{k[0]}]") if theme.enabled else f"[{k[0]}]") + f" {k}"
        for k in sort_keys
    )
    lines.append(f"  {theme.muted('Sort:')}  {sort_hint}")
    return "\n".join(lines)


# ──────────────────────────────────────────────────────────────────────────────
#  Browser Details
# ──────────────────────────────────────────────────────────────────────────────


def render_browser_details(report: BrowserReport) -> str:
    """Render comprehensive inspection breakdown for a single browser."""
    W = 76

    lines = [
        "",
        render_breadcrumb("Home", "Browsers", report.name),
    ]

    if report.status == BrowserStatus.ACTIVE:
        badge = f"{theme.active('● ACTIVE')} {theme.dim('— ' + report.status_reason)}"
    elif report.status == BrowserStatus.INACTIVE:
        badge = f"{theme.inactive('○ INACTIVE')} {theme.dim('— safe to clean')}"
    else:
        badge = f"{theme.review('◌ UNKNOWN')} {theme.dim('— ' + report.status_reason)}"

    lines.append(f"  {badge}  │  {theme.dim(str(report.path))}")
    lines.append(_rule(W, "═", theme.accent if theme.enabled else None))

    t = report.total_size
    pct_safe = human_percent(report.safe_size, t)
    s_bar = render_mini_bar(report.safe_size, t, width=8, color_fn=theme.safe)
    l_bar = render_mini_bar(report.low_risk_size, t, width=8, color_fn=theme.low_risk)
    r_bar = render_mini_bar(report.review_size, t, width=8, color_fn=theme.review)

    lines.append(
        f"  {theme.muted('Total: '):<10}{theme.bold(format_size(t)):<10}  │  "
        + (
            f"{theme.safe('✓ READY TO CLEAN')} — {theme.safe(format_size(report.safe_size))} reclaimable"
            if report.can_clean
            else (
                f"{theme.active('⊘ BLOCKED')} — Chrome is active"
                if report.status == BrowserStatus.ACTIVE
                else f"{theme.muted('Nothing safe to clean')}"
            )
        )
    )
    lines.append(_rule(W, "─", theme.muted if theme.enabled else None))

    safe_lbl = theme.muted(pad_right("Safe:", 10))
    safe_val = theme.safe(pad_left(format_size(report.safe_size), 8))
    safe_pct = theme.muted(pad_left(pct_safe, 6))

    low_lbl = theme.muted(pad_right("Low risk:", 10))
    low_val = theme.low_risk(pad_left(format_size(report.low_risk_size), 8))

    rev_lbl = theme.muted(pad_right("Review:", 10))
    rev_val = theme.review(pad_left(format_size(report.review_size), 8))

    prot_lbl = theme.muted(pad_right("Protected:", 14))
    prot_val = theme.protected(pad_left(format_size(report.protected_size), 9))

    unk_lbl = theme.muted(pad_right("Unknown:", 14))
    unk_val = theme.unknown(pad_left(format_size(report.unknown_size), 9))

    inacc_lbl = theme.muted(pad_right("Inaccessible:", 14))
    inacc_val = pad_left(format_size(report.inaccessible_size), 9)

    blank_pct = " " * 6

    lines.append(
        f"  {safe_lbl} {safe_val}  {s_bar} {safe_pct}   │   {prot_lbl} {prot_val}"
    )
    lines.append(
        f"  {low_lbl} {low_val}  {l_bar} {blank_pct}   │   {unk_lbl} {unk_val}"
    )
    lines.append(
        f"  {rev_lbl} {rev_val}  {r_bar} {blank_pct}   │   {inacc_lbl} {inacc_val}"
    )
    lines.append(_rule(W, "─", theme.muted if theme.enabled else None))

    lines.append(f"  {theme.bold('STORAGE BREAKDOWN')}")

    def render_section(title: str, items: list[StorageItem], color_fn) -> None:
        if not items:
            return
        lines.append(f"  {color_fn(title)}:")
        for it in sorted(items, key=lambda x: x.size, reverse=True):
            desc = f"  {theme.dim('— ' + it.description)}" if it.description else ""
            lines.append(f"    {color_fn(format_size(it.size)):>10}  {it.relative_path}{desc}")

    render_section("SAFE TO CLEAN", report.safe_items, theme.safe)
    render_section("LOW RISK", report.low_risk_items, theme.low_risk)
    render_section("REVIEW", report.review_items, theme.review)
    render_section("PROTECTED", report.protected_items, theme.protected)
    render_section("UNKNOWN", report.unknown_items, theme.unknown)

    if report.inaccessible_items:
        render_section("INACCESSIBLE", report.inaccessible_items, theme.review)

    return "\n".join(lines)


# ──────────────────────────────────────────────────────────────────────────────
#  Why Explanation
# ──────────────────────────────────────────────────────────────────────────────


def render_why_explanation(item: StorageItem) -> str:
    """Render detailed explanation of why an item is classified."""
    W = 62
    lines = [
        "",
        render_breadcrumb("Home", "Explain"),
        "",
        _rule(W, "═", theme.accent if theme.enabled else None),
        f"  {theme.bold(item.relative_path)}",
        (
            f"  {theme.muted('Size:')} {format_size(item.size)}"
            f"   {theme.muted('Files:')} {item.file_count}"
            f"   {theme.muted('Category:')} {item.category}"
        ),
        f"  {theme.muted('Classification:')} {theme.safety_label(item.safety)}"
        f"   {theme.muted('Confidence:')} {item.confidence.value}",
        "",
        _rule(W, "─", theme.muted if theme.enabled else None),
        f"  {theme.bold('Why this is classified this way:')}",
        f"  {theme.dim(item.rationale or item.description)}",
        "",
        f"  {theme.bold('Category Overview:')}",
        f"  {theme.dim(SAFETY_DESCRIPTIONS.get(item.safety, 'No category description available.'))}",
        "",
        f"  {theme.bold('Suggested Action:')}",
    ]

    if item.safety == SafetyLevel.SAFE:
        lines.append(
            f"  {theme.safe('✓')}  Safe to clean. Chrome regenerates cache data as needed."
        )
    elif item.safety == SafetyLevel.LOW_RISK:
        lines.append(
            f"  {theme.low_risk('~')}  Can be cleaned if space is critical;"
            " Chrome will redownload component files."
        )
    elif item.safety == SafetyLevel.REVIEW:
        lines.append(
            f"  {theme.review('!')}"
            "  Review before deleting. May affect offline web apps or saved site state."
        )
    elif item.safety == SafetyLevel.PROTECTED:
        lines.append(
            f"  {theme.protected('⊘')}  PROTECTED. Do not delete."
            " Contains essential personal user or browser state."
        )
    else:
        lines.append(
            f"  {theme.unknown('?')}  Unclassified data. Investigate contents before removing."
        )

    lines.append("")
    return "\n".join(lines)


# ──────────────────────────────────────────────────────────────────────────────
#  Cleanup Opportunities
# ──────────────────────────────────────────────────────────────────────────────


def render_largest_cleanup_opportunities(
    reports: list[BrowserReport], top_n: int = 15
) -> str:
    """Render ranked cleanup opportunities showing actual directories responsible."""
    sorted_reports = [r for r in reports if r.safe_size > 0]
    sorted_reports.sort(key=lambda r: r.safe_size, reverse=True)

    W = 80
    lines = [
        "",
        render_breadcrumb("Home", "Cleanup Opportunities"),
        "",
        _rule(W, "═", theme.accent if theme.enabled else None),
        (
            f"  {'#':>2}  "
            f"{theme.bold('Browser'):<25}  "
            f"{theme.bold('Total'):>10}  "
            f"{theme.safe('Safe'):>10}  "
            f"{'%':>5}  "
            f"{'Bar':<10}  "
            f"{theme.bold('Status')}"
        ),
        _rule(W, "─", theme.muted if theme.enabled else None),
    ]

    top_reports = sorted_reports[:top_n]
    total_safe = sum(r.safe_size for r in top_reports)

    for index, r in enumerate(top_reports, 1):
        pct = human_percent(r.safe_size, r.total_size)
        bar = render_mini_bar(r.safe_size, r.total_size, width=10, color_fn=theme.safe)
        lines.append(
            f"  {theme.muted(str(index)):>2}  "
            f"{r.name:<25}  "
            f"{format_size(r.total_size):>10}  "
            f"{theme.safe(format_size(r.safe_size)):>10}  "
            f"{pct:>5}  "
            f"{bar}  "
            f"{theme.status(r.status)}"
        )

    lines.append(_rule(W, "─", theme.muted if theme.enabled else None))
    lines.append(
        f"  {'':>2}  {theme.muted('Total reclaimable'):<25}               "
        f"{theme.safe(format_size(total_safe)):>10}"
    )

    if top_reports:
        lines.extend(
            [
                "",
                f"  {theme.bold('Top Cache Directories:')}",
                _rule(W, "─", theme.muted if theme.enabled else None),
            ]
        )
        for r in top_reports[:5]:
            lines.append(
                f"  {theme.accent('▸')} {theme.bold(r.name)}"
                f"  {theme.dim(format_size(r.safe_size) + ' safe')}"
            )
            for it in sorted(r.safe_items, key=lambda x: x.size, reverse=True)[:3]:
                if it.size > 0:
                    lines.append(
                        f"    {theme.safe(format_size(it.size)):>10}  "
                        f"{theme.dim(it.relative_path)}"
                    )

    return "\n".join(lines)


# ──────────────────────────────────────────────────────────────────────────────
#  Unknown & Review Data
# ──────────────────────────────────────────────────────────────────────────────


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

    W = 84
    lines = [
        "",
        render_breadcrumb("Home", "Unknown Data"),
        "",
        _rule(W, "═", theme.accent if theme.enabled else None),
        (
            f"  {'#':>2}  "
            f"{theme.muted('Browser'):<20}  "
            f"{theme.muted('Relative Path'):<35}  "
            f"{theme.muted('Size'):>10}  "
            f"{theme.muted('Files'):>6}"
        ),
        _rule(W, "─", theme.muted if theme.enabled else None),
    ]

    if not unknown_entries:
        lines.append(
            f"  {theme.safe('✓')}  No unknown data found — all paths are classified!"
        )
    else:
        for index, (b_name, rel_path, size, count) in enumerate(
            unknown_entries[:top_n], 1
        ):
            lines.append(
                f"  {theme.muted(str(index)):>2}  "
                f"{b_name:<20}  "
                f"{theme.unknown(rel_path):<35}  "
                f"{format_size(size):>10}  "
                f"{count:>6}"
            )

    lines.append("")
    return "\n".join(lines)


def render_largest_review_data(reports: list[BrowserReport], top_n: int = 20) -> str:
    """Render list of largest review items across all profiles."""
    review_entries: list[tuple[str, str, int, str]] = []
    for r in reports:
        for it in r.review_items:
            if it.size > 0:
                review_entries.append((r.name, it.relative_path, it.size, it.rationale))

    review_entries.sort(key=lambda x: x[2], reverse=True)

    W = 90
    lines = [
        "",
        render_breadcrumb("Home", "Review Data"),
        "",
        _rule(W, "═", theme.accent if theme.enabled else None),
        (
            f"  {'#':>2}  "
            f"{theme.muted('Browser'):<18}  "
            f"{theme.muted('Path'):<28}  "
            f"{theme.muted('Size'):>10}  "
            f"{theme.muted('Explanation')}"
        ),
        _rule(W, "─", theme.muted if theme.enabled else None),
    ]

    if not review_entries:
        lines.append(f"  {theme.safe('✓')}  No review data found!")
    else:
        for index, (b_name, rel_path, size, rationale) in enumerate(
            review_entries[:top_n], 1
        ):
            short_rat = rationale[:42] + "…" if len(rationale) > 42 else rationale
            lines.append(
                f"  {theme.muted(str(index)):>2}  "
                f"{b_name:<18}  "
                f"{theme.review(rel_path):<28}  "
                f"{format_size(size):>10}  "
                f"{theme.dim(short_rat)}"
            )

    lines.append("")
    return "\n".join(lines)


# ──────────────────────────────────────────────────────────────────────────────
#  JSON Output
# ──────────────────────────────────────────────────────────────────────────────


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
