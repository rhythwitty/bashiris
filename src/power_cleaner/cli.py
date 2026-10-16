"""Interactive command-line interface for ChromePower Cleaner."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from power_cleaner import __version__
from power_cleaner.cleanup import execute_cleanup_plan, prompt_confirmation
from power_cleaner.config import get_chrome_root
from power_cleaner.formatters import (
    Spinner,
    format_size,
    output_json,
    pad_left,
    pad_right,
    render_banner,
    render_browser_details,
    render_browser_table,
    render_largest_cleanup_opportunities,
    render_largest_review_data,
    render_largest_unknown_data,
    render_overview,
    render_why_explanation,
    theme,
)
from power_cleaner.models import (
    AggregateReport,
    BrowserReport,
    BrowserStatus,
    SafetyLevel,
)
from power_cleaner.planner import (
    create_cleanup_plan_for_all,
    create_cleanup_plan_for_browser,
    create_low_risk_cleanup_plan_for_all,
    create_low_risk_cleanup_plan_for_browser,
)
from power_cleaner.scanner import ProfileScanner


def _prompt(label: str = "") -> str:
    """Styled input prompt."""
    arrow = f"{theme.CYAN}❯{theme.RESET}" if theme.enabled else ">"
    try:
        return input(f"  {arrow} {label}").strip()
    except (EOFError, KeyboardInterrupt):
        return ""


def choose_browser_interactive(
    reports: list[BrowserReport],
    current_sort: str = "size",
) -> BrowserReport | None:
    """Display browser table with instant selection, sorting, and navigation."""
    sort_mode = current_sort

    while True:
        print(render_browser_table(reports, sort_by=sort_mode))
        print()
        n = len(reports)
        hint_num = theme.accent(f"[1-{n}]")
        hint_enter = theme.muted("[Enter] back")
        sort_hint = theme.muted("[s]ize [c]leanup [r]eview [u]nknown [n]ame to sort")
        print(f"  {hint_num} inspect browser  │  {sort_hint}  │  {hint_enter}")
        print()
        choice = _prompt()

        if not choice:
            return None

        # Sorting shortcuts
        choice_lower = choice.lower()
        if choice_lower == "s":
            sort_mode = "size"
            continue
        if choice_lower == "c":
            sort_mode = "safe"
            continue
        if choice_lower == "r":
            sort_mode = "review"
            continue
        if choice_lower == "u":
            sort_mode = "unknown"
            continue
        if choice_lower == "n":
            sort_mode = "name"
            continue

        # Check if number entered
        if choice.isdigit():
            idx = int(choice)
            # Find the report at this index in the current sorted order
            sorted_reports = list(reports)
            if sort_mode == "size":
                sorted_reports.sort(key=lambda r: r.total_size, reverse=True)
            elif sort_mode == "safe":
                sorted_reports.sort(key=lambda r: r.safe_size, reverse=True)
            elif sort_mode == "review":
                sorted_reports.sort(key=lambda r: r.review_size, reverse=True)
            elif sort_mode == "unknown":
                sorted_reports.sort(key=lambda r: r.unknown_size, reverse=True)
            elif sort_mode == "name":
                sorted_reports.sort(key=lambda r: r.name.lower())

            if 1 <= idx <= len(sorted_reports):
                return sorted_reports[idx - 1]
            print(
                f"  {theme.review('!')}  Enter a number between 1 and {len(reports)}."
            )
            continue

        # Check if browser name was entered directly
        for r in reports:
            if r.name.lower() == choice_lower:
                return r

        print(f"  {theme.muted('?')}  Unknown command or invalid browser selection.")


def handle_browser_inspection(
    report: BrowserReport,
    scanner: ProfileScanner,
) -> bool:
    """Inspect a browser and present sub-actions (details, why, cleanup).

    Returns True if a cleanup occurred and caller should refresh scan.
    """
    while True:
        print(render_browser_details(report))
        print()

        safe_note = (
            format_size(report.safe_size)
            if report.can_clean
            else ("active" if report.status == BrowserStatus.ACTIVE else "none")
        )
        safe_label = theme.safe("Clean safe") if report.can_clean else "Clean safe"
        safe_str = f"{theme.accent('[2]')} {safe_label} {theme.muted('(' + safe_note + ')')}"

        low_note = (
            format_size(report.low_risk_size)
            if report.can_clean_low_risk
            else ("active" if report.status == BrowserStatus.ACTIVE else "none")
        )
        low_label = (
            theme.low_risk("Clean low-risk")
            if report.can_clean_low_risk
            else "Clean low-risk"
        )
        low_str = f"{theme.accent('[3]')} {low_label} {theme.muted('(' + low_note + ')')}"

        print()
        print(
            f"  {theme.accent('[1]')} Refresh view                   {theme.accent('[4]')} Show review items"
        )
        print(
            f"  {safe_str:<38}  {theme.accent('[5]')} Explain classification (Why?)"
        )
        print(
            f"  {low_str:<38}  {theme.accent('[6]')} Back {theme.muted('[Enter]')}"
        )
        print()

        choice = _prompt()

        if not choice or choice in ("6", "b", "back"):
            return False

        if choice == "1":
            continue

        if choice == "2":
            if not report.can_clean:
                if report.status == BrowserStatus.ACTIVE:
                    print(
                        f"\n  {theme.active('⊘ BLOCKED')} — Chrome is running with profile {theme.bold(report.name)}."
                    )
                elif report.status == BrowserStatus.UNKNOWN:
                    print(
                        f"\n  {theme.review('⊘ BLOCKED')} — Profile {theme.bold(report.name)} activity is unknown."
                    )
                else:
                    print(
                        f"\n  {theme.muted('Nothing safe to clean in this profile.')}"
                    )
                _press_enter()
                continue

            # Confirm cleanup for single profile
            plan = create_cleanup_plan_for_browser(report)
            print(
                f"\n  {theme.bold('Safe cache cleanup for')} {theme.highlight(report.name)}:"
            )
            print()
            for it in sorted(report.safe_items, key=lambda x: x.size, reverse=True):
                if it.size > 0:
                    print(
                        f"    {theme.safe(format_size(it.size)):>12}  {theme.muted(it.relative_path)}"
                    )
            print()
            print(
                f"  {theme.muted('Total reclaimable:')}  {theme.safe(format_size(plan.total_bytes_to_clean))}"
            )

            confirmed = prompt_confirmation(
                '  Type "clean" to confirm, or Enter to cancel: '
            )
            if not confirmed:
                print(f"\n  {theme.muted('Cleanup cancelled.')}")
                continue

            result = execute_cleanup_plan(plan, dry_run=False)
            print(
                f"\n  {theme.safe('✓')} Cleaned {theme.safe(format_size(result.deleted_bytes))}"
            )
            if result.errors:
                print(f"  {theme.review('Warnings')} ({len(result.errors)}):")
                for err in result.errors[:5]:
                    print(f"    {theme.muted(err)}")

            _press_enter()
            return True

        if choice == "3":
            if not report.can_clean_low_risk:
                if report.status == BrowserStatus.ACTIVE:
                    print(
                        f"\n  {theme.active('⊘ BLOCKED')} — Chrome is running with profile {theme.bold(report.name)}."
                    )
                elif report.status == BrowserStatus.UNKNOWN:
                    print(
                        f"\n  {theme.review('⊘ BLOCKED')} — Profile {theme.bold(report.name)} activity is unknown."
                    )
                else:
                    print(
                        f"\n  {theme.muted('Nothing low-risk to clean in this profile.')}"
                    )
                _press_enter()
                continue

            # Confirm low-risk cleanup for single profile
            plan = create_low_risk_cleanup_plan_for_browser(report)
            print()
            print(
                f"  {theme.review('Notice:')} Low-risk items include component downloads, ML models, and"
            )
            print("  safe experiment seeds. Chrome will redownload them when needed.")
            print(
                f"\n  {theme.bold('Low-risk cache cleanup for')} {theme.highlight(report.name)}:"
            )
            print()
            for it in sorted(report.low_risk_items, key=lambda x: x.size, reverse=True):
                if it.size > 0:
                    print(
                        f"    {theme.low_risk(format_size(it.size)):>12}  {theme.muted(it.relative_path)}"
                    )
            print()
            print(
                f"  {theme.muted('Total reclaimable:')}  {theme.safe(format_size(plan.total_bytes_to_clean))}"
            )

            confirmed = prompt_confirmation(
                '  Type "clean" to confirm, or Enter to cancel: '
            )
            if not confirmed:
                print(f"\n  {theme.muted('Cleanup cancelled.')}")
                continue

            result = execute_cleanup_plan(plan, dry_run=False)
            print(
                f"\n  {theme.safe('✓')} Cleaned {theme.safe(format_size(result.deleted_bytes))}"
            )
            if result.errors:
                print(f"  {theme.review('Warnings')} ({len(result.errors)}):")
                for err in result.errors[:5]:
                    print(f"    {theme.muted(err)}")

            _press_enter()
            return True

        if choice == "4":
            print(
                f"\n  {theme.bold('Review items for')} {theme.highlight(report.name)}:"
            )
            if not report.review_items:
                print(f"  {theme.muted('No review items present.')}")
            for it in sorted(report.review_items, key=lambda x: x.size, reverse=True):
                print(
                    f"\n  {theme.review(format_size(it.size)):>12}  {it.relative_path}"
                )
                print(f"  {'':>12}  {theme.muted(it.rationale or it.description)}")
            _press_enter()

        elif choice == "5":
            all_items: list = []
            for level in SafetyLevel:
                all_items.extend(report.items_by_safety.get(level, []))

            if not all_items:
                print(f"\n  {theme.muted('No items to explain.')}")
                continue

            print(f"\n  {theme.bold('Select an item to explain:')}")
            print()
            for i, it in enumerate(all_items, 1):
                print(
                    f"  {theme.muted(str(i)):>2}  {it.relative_path:<35}  "
                    f"{theme.safety_label(it.safety)}"
                )
            print()
            item_choice = _prompt("Item number: ")
            if item_choice.isdigit() and 1 <= int(item_choice) <= len(all_items):
                selected = all_items[int(item_choice) - 1]
                print(render_why_explanation(selected))
            else:
                print(f"  {theme.muted('Invalid item number.')}")
            _press_enter()


def _press_enter(label: str = "Press Enter to continue") -> None:
    """Wait for user to press Enter."""
    arrow = f"{theme.CYAN}↵{theme.RESET}" if theme.enabled else "↵"
    try:
        input(f"\n  {arrow}  {theme.muted(label)}…  ")
    except (EOFError, KeyboardInterrupt):
        pass


def _render_batch_summary_header(plan, title: str) -> None:
    """Print the batch cleanup plan header."""
    W = 60
    print(f"\n  {theme.bold(title)}")
    print(f"  {'═' * W}")
    print(
        f"  {theme.muted('Browsers to clean:')} {theme.bold(str(len(plan.targeted_browsers)))}   │   "
        f"{theme.muted('Storage to reclaim:')} {theme.safe(format_size(plan.total_bytes_to_clean))}"
    )

    sorted_targets = sorted(
        plan.browser_plans, key=lambda p: p.total_bytes, reverse=True
    )
    if sorted_targets:
        print(f"  {theme.muted('Largest opportunities:')}")
        for bp in sorted_targets[:4]:
            bar_w = round(bp.total_bytes / max(t.total_bytes for t in sorted_targets) * 12)
            bar = theme.safe("█" * bar_w) + theme.muted("░" * (12 - bar_w))
            print(f"    {bp.report.name:<22}  {format_size(bp.total_bytes):>10}  {bar}")

    skipped = []
    if plan.skipped_active:
        skipped.append(f"{theme.active('Active (skipped):')} {len(plan.skipped_active)}")
    if plan.skipped_unknown:
        skipped.append(f"{theme.review('Unknown (skipped):')} {len(plan.skipped_unknown)}")
    if skipped:
        print(f"  {'  │  '.join(skipped)}")
    print()


def handle_batch_safe_cleanup(
    aggregate: AggregateReport,
    scanner: ProfileScanner,
    auto_confirm: bool = False,
    interactive: bool = True,
) -> bool:
    """Execute batch cleanup of all safe caches across inactive profiles."""
    plan = create_cleanup_plan_for_all(aggregate)

    if plan.is_empty:
        print(
            f"\n  {theme.muted('No safe caches available to clean across inactive browsers.')}"
        )
        if interactive:
            _press_enter()
        return False

    _render_batch_summary_header(plan, "Clean Safe Caches — Summary")

    if not auto_confirm:
        confirmed = prompt_confirmation('  Type "clean" to confirm batch cleanup: ')
        if not confirmed:
            print(f"\n  {theme.muted('Cleanup cancelled.')}")
            if interactive:
                _press_enter()
            return False
    else:
        print(f"  {theme.muted('Confirmation bypassed (--yes).')}")

    print(f"  {theme.accent('⟳')}  Cleaning safe caches…")
    result = execute_cleanup_plan(plan, dry_run=False)

    W = 30
    print()
    print(f"  {theme.bold('Cleanup Complete')}")
    print(f"  {'─' * W}")
    print(
        f"  {theme.muted('Deleted:')}   {theme.safe(format_size(result.deleted_bytes))}"
    )
    print(f"  {theme.muted('Profiles:')}  {result.cleaned_profiles_count}")
    print(
        f"  {theme.muted('Skipped:')}   "
        f"{result.skipped_active_count} active, "
        f"{result.skipped_unknown_count} unknown"
    )
    if result.errors:
        print(f"  {theme.review('Errors:')}    {len(result.errors)}")
        for err in result.errors[:10]:
            print(f"    {theme.muted(err)}")
    else:
        print(f"  {theme.muted('Errors:')}    {theme.safe('none')}")

    if interactive:
        _press_enter("Press Enter to return to main menu")

    return True


def handle_batch_low_risk_cleanup(
    aggregate: AggregateReport,
    scanner: ProfileScanner,
    auto_confirm: bool = False,
    interactive: bool = True,
) -> bool:
    """Execute batch cleanup of low-risk caches across inactive profiles."""
    plan = create_low_risk_cleanup_plan_for_all(aggregate)

    if plan.is_empty:
        print(
            f"\n  {theme.muted('No low-risk caches available to clean across inactive browsers.')}"
        )
        if interactive:
            _press_enter()
        return False

    print(
        f"\n  {theme.review('Notice:')} Low-risk items include component downloads, ML models, and"
    )
    print(
        "  safe experiment seeds. Chrome will automatically redownload them when needed."
    )
    _render_batch_summary_header(plan, "Clean Low-Risk Caches — Summary")

    if not auto_confirm:
        confirmed = prompt_confirmation(
            '  Type "clean" to confirm batch low-risk cleanup: '
        )
        if not confirmed:
            print(f"\n  {theme.muted('Cleanup cancelled.')}")
            if interactive:
                _press_enter()
            return False
    else:
        print(f"  {theme.muted('Confirmation bypassed (--yes).')}")

    print(f"  {theme.accent('⟳')}  Cleaning low-risk caches…")
    result = execute_cleanup_plan(plan, dry_run=False)

    W = 30
    print()
    print(f"  {theme.bold('Cleanup Complete')}")
    print(f"  {'─' * W}")
    print(
        f"  {theme.muted('Deleted:')}   {theme.safe(format_size(result.deleted_bytes))}"
    )
    print(f"  {theme.muted('Profiles:')}  {result.cleaned_profiles_count}")
    print(
        f"  {theme.muted('Skipped:')}   "
        f"{result.skipped_active_count} active, "
        f"{result.skipped_unknown_count} unknown"
    )
    if result.errors:
        print(f"  {theme.review('Errors:')}    {len(result.errors)}")
        for err in result.errors[:10]:
            print(f"    {theme.muted(err)}")
    else:
        print(f"  {theme.muted('Errors:')}    {theme.safe('none')}")

    if interactive:
        _press_enter("Press Enter to return to main menu")

    return True


def _rescan(
    scanner: ProfileScanner, chrome_root, label: str = "Rescanning"
) -> AggregateReport:
    """Rescan with spinner feedback."""
    spinner = Spinner(f"{label} {chrome_root}")
    spinner.start()
    result = scanner.scan_all(chrome_root, force=True)
    spinner.stop(
        f"  {theme.safe('✓')}  Scan complete — {result.browser_count} browser(s) found"
    )
    return result


def main_menu(root: Path | None = None) -> None:
    """Main interactive terminal loop."""
    scanner = ProfileScanner()
    chrome_root = get_chrome_root(root)

    print(render_banner(__version__))
    print()
    spinner = Spinner(f"Scanning {chrome_root}")
    spinner.start()
    aggregate = scanner.scan_all(chrome_root)
    spinner.stop(
        f"  {theme.safe('✓')}  Found {theme.bold(str(aggregate.browser_count))} browser(s)"
    )

    def _col(num: str, label_styled: str, label_plain: str, shortcut: str = "") -> str:
        sc = f" {theme.muted('(' + shortcut + ')')}" if shortcut else ""
        n_str = theme.accent(f"[{num}]")
        raw_len = len(f"[{num}] {label_plain}" + (f" ({shortcut})" if shortcut else ""))
        pad = " " * max(1, 33 - raw_len)
        return f"{n_str} {label_styled}{sc}{pad}"

    while True:
        print(render_overview(aggregate))
        print(f"  {theme.bold('Actions:')}")
        print(
            f"  {_col('1', 'Overview', 'Overview', 'o')}{_col('6', 'Largest cleanup opportunities', 'Largest cleanup opportunities')}"
        )
        print(
            f"  {_col('2', 'Browsers', 'Browsers', 'b')}{_col('7', 'Largest unknown data', 'Largest unknown data')}"
        )
        print(
            f"  {_col('3', 'Inspect browser', 'Inspect browser')}{_col('8', 'Largest review data', 'Largest review data')}"
        )
        safe_lbl = theme.safe("Clean safe caches") if aggregate.safe_size > 0 else "Clean safe caches"
        print(
            f"  {_col('4', safe_lbl, 'Clean safe caches')}{_col('9', 'Refresh scan', 'Refresh scan', 'r')}"
        )
        low_lbl = theme.low_risk("Clean low-risk caches") if aggregate.low_risk_size > 0 else "Clean low-risk caches"
        print(
            f"  {_col('5', low_lbl, 'Clean low-risk caches')}{_col('10', 'Quit', 'Quit', 'q')}"
        )
        print()

        try:
            choice = _prompt()
        except (EOFError, KeyboardInterrupt):
            choice = "q"

        choice = choice.lower()

        if not choice or choice in ("1", "o", "overview"):
            continue

        elif choice in ("2", "b", "browsers"):
            selected = choose_browser_interactive(aggregate.reports)
            if selected:
                changed = handle_browser_inspection(selected, scanner)
                if changed:
                    aggregate = _rescan(scanner, chrome_root)

        elif choice in ("3", "inspect"):
            selected = choose_browser_interactive(aggregate.reports)
            if selected:
                changed = handle_browser_inspection(selected, scanner)
                if changed:
                    aggregate = _rescan(scanner, chrome_root)

        elif choice in ("4", "clean", "clean-safe"):
            changed = handle_batch_safe_cleanup(aggregate, scanner)
            if changed:
                aggregate = _rescan(scanner, chrome_root)

        elif choice in ("5", "clean-low-risk", "low-risk"):
            changed = handle_batch_low_risk_cleanup(aggregate, scanner)
            if changed:
                aggregate = _rescan(scanner, chrome_root)

        elif choice == "6":
            print(render_largest_cleanup_opportunities(aggregate.reports))
            _press_enter()

        elif choice == "7":
            print(render_largest_unknown_data(aggregate.reports))
            _press_enter()

        elif choice == "8":
            print(render_largest_review_data(aggregate.reports))
            _press_enter()

        elif choice in ("9", "r", "refresh"):
            aggregate = _rescan(scanner, chrome_root)

        elif choice in ("10", "q", "quit", "exit"):
            print(f"\n  {theme.muted('Bye.')}")
            break

        else:
            print(
                f"  {theme.muted('?')}  Unknown command — try [1-10], [o], [b], [r], [q]."
            )


def main(argv: list[str] | None = None) -> None:
    """CLI entry point with flag parsing and dispatch."""
    parser = argparse.ArgumentParser(
        prog="power-cleaner",
        description="Safe ChromePower storage analysis and cache cleanup tool.",
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=None,
        help="Optional ChromePower cache root path (defaults to auto-detected root)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output full analysis as structured JSON to stdout and exit",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Perform a complete scan and show cleanup actions without deleting anything",
    )
    parser.add_argument(
        "--clean-safe",
        action="store_true",
        help="Run batch safe cleanup across all inactive profiles",
    )
    parser.add_argument(
        "--clean-low-risk",
        action="store_true",
        help="Run batch low-risk cache cleanup across all inactive profiles",
    )
    parser.add_argument(
        "-y",
        "--yes",
        "--no-confirm",
        dest="yes",
        action="store_true",
        help="Bypass interactive confirmation prompts (for automated/non-interactive execution)",
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"chrome-power-cleaner {__version__}",
    )

    args = parser.parse_args(argv)
    chrome_root = get_chrome_root(args.root)

    scanner = ProfileScanner()

    # JSON mode
    if args.json:
        aggregate = scanner.scan_all(chrome_root)
        output_json(aggregate)
        return

    # Dry-run mode
    if args.dry_run:
        spinner = Spinner(f"Dry-run scan on {chrome_root}")
        spinner.start()
        aggregate = scanner.scan_all(chrome_root)
        spinner.stop()

        if args.clean_low_risk and args.clean_safe:
            safety_levels = (SafetyLevel.SAFE, SafetyLevel.LOW_RISK)
            dry_title = "DRY RUN CLEANUP PLAN (SAFE + LOW-RISK)"
        elif args.clean_low_risk:
            safety_levels = (SafetyLevel.LOW_RISK,)
            dry_title = "DRY RUN CLEANUP PLAN (LOW-RISK)"
        else:
            safety_levels = (SafetyLevel.SAFE,)
            dry_title = "DRY RUN CLEANUP PLAN"

        plan = create_cleanup_plan_for_all(aggregate, safety_levels=safety_levels)
        print(render_overview(aggregate))
        print(f"\n  {theme.bold(dry_title)}")
        print(f"  {'═' * 72}")
        t_label = theme.muted(pad_right("Targeted inactive profiles:", 28))
        s_label = theme.muted(pad_right("Skipped active profiles:", 28))
        r_label = theme.muted(pad_right("Total cache reclaimable:", 25))
        u_label = theme.muted(pad_right("Skipped unknown profiles:", 25))
        r_val = theme.safe(pad_left(format_size(plan.total_bytes_to_clean), 9))
        u_val = pad_left(str(len(plan.skipped_unknown)), 9)
        print(f"  {t_label} {len(plan.targeted_browsers):>2}   │   {r_label} {r_val}")
        print(f"  {s_label} {len(plan.skipped_active):>2}   │   {u_label} {u_val}")
        result = execute_cleanup_plan(plan, dry_run=True)
        print(
            f"  {theme.safe('✓')} Dry run complete — would delete "
            f"{theme.safe(format_size(result.deleted_bytes))} across "
            f"{result.cleaned_profiles_count} profile(s)."
        )
        return

    # Direct batch clean flags
    if args.clean_safe or args.clean_low_risk:
        spinner = Spinner(f"Scanning {chrome_root}")
        spinner.start()
        aggregate = scanner.scan_all(chrome_root)
        spinner.stop()
        if args.clean_safe:
            handle_batch_safe_cleanup(
                aggregate, scanner, auto_confirm=args.yes, interactive=False
            )
            if args.clean_low_risk:
                spinner2 = Spinner("Rescanning")
                spinner2.start()
                aggregate = scanner.scan_all(chrome_root, force=True)
                spinner2.stop()
        if args.clean_low_risk:
            handle_batch_low_risk_cleanup(
                aggregate, scanner, auto_confirm=args.yes, interactive=False
            )
        return

    # Interactive menu by default
    try:
        main_menu(args.root)
    except KeyboardInterrupt:
        print(f"\n\n  {theme.muted('Bye.')}")
        sys.exit(0)


if __name__ == "__main__":
    main()
