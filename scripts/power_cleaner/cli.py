"""Interactive command-line interface for ChromePower Cleaner."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from power_cleaner import __version__
from power_cleaner.cleanup import execute_cleanup_plan, prompt_confirmation
from power_cleaner.config import get_chrome_root
from power_cleaner.formatters import (
    format_size,
    output_json,
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


def choose_browser_interactive(
    reports: list[BrowserReport],
    current_sort: str = "size",
) -> BrowserReport | None:
    """Display browser table with instant selection, sorting, and navigation."""
    sort_mode = current_sort

    while True:
        print(render_browser_table(reports, sort_by=sort_mode))
        print()
        print(
            "Commands: [1-"
            + str(len(reports))
            + "] inspect  |  [s]ize [c]leanup [r]eview [u]nknown [n]ame sort  |  [Enter] back"
        )
        try:
            choice = input("❯ ").strip()
        except (EOFError, KeyboardInterrupt):
            return None

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
            print(f"Please enter a number between 1 and {len(reports)}.")
            continue

        # Check if browser name was entered directly
        for r in reports:
            if r.name.lower() == choice_lower:
                return r

        print("Unknown command or invalid browser selection.")


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
        print("Actions:")
        print("  1. Show details (refresh view)")

        if report.can_clean:
            print(f"  2. Clean safe caches ({format_size(report.safe_size)})")
        elif report.status == BrowserStatus.ACTIVE:
            print(
                f"  2. Clean safe caches {theme.active('[DISABLED: Browser is ACTIVE]')}"
            )
        elif report.status == BrowserStatus.UNKNOWN:
            print(
                f"  2. Clean safe caches {theme.review('[DISABLED: Status is UNKNOWN]')}"
            )
        else:
            print("  2. Clean safe caches [No safe caches to clean]")

        if report.can_clean_low_risk:
            print(f"  3. Clean low-risk caches ({format_size(report.low_risk_size)})")
        elif report.status == BrowserStatus.ACTIVE:
            print(
                f"  3. Clean low-risk caches {theme.active('[DISABLED: Browser is ACTIVE]')}"
            )
        elif report.status == BrowserStatus.UNKNOWN:
            print(
                f"  3. Clean low-risk caches {theme.review('[DISABLED: Status is UNKNOWN]')}"
            )
        else:
            print("  3. Clean low-risk caches [No low-risk caches to clean]")

        print("  4. Show review items with explanations")
        print("  5. Explain classification for an item (Why?)")
        print("  6. Back to browser list (Enter)")
        print()

        try:
            choice = input("❯ ").strip()
        except (EOFError, KeyboardInterrupt):
            return False

        if not choice or choice in ("6", "b", "back"):
            return False

        if choice == "1":
            continue

        if choice == "2":
            if not report.can_clean:
                if report.status == BrowserStatus.ACTIVE:
                    print(
                        f"\n⚠️  {theme.active('BLOCKED')}: Chrome is running with profile {report.name}."
                    )
                elif report.status == BrowserStatus.UNKNOWN:
                    print(
                        f"\n⚠️  {theme.review('BLOCKED')}: Profile {report.name} activity is unknown."
                    )
                else:
                    print("\nNothing safe to clean in this profile.")
                try:
                    input("\nPress Enter to continue...")
                except (EOFError, KeyboardInterrupt):
                    pass
                continue

            # Confirm cleanup for single profile
            plan = create_cleanup_plan_for_browser(report)
            print(f"\nYou are about to clean safe caches in {report.name}:")
            for it in report.safe_items:
                if it.size > 0:
                    print(f"  {format_size(it.size):>10}  {it.relative_path}")
            print(
                f"\nTotal reclaimable: {theme.safe(format_size(plan.total_bytes_to_clean))}"
            )

            confirmed = prompt_confirmation('Type "clean" to confirm: ')
            if not confirmed:
                print("\nCleanup cancelled.")
                continue

            result = execute_cleanup_plan(plan, dry_run=False)
            print(f"\n✓ Cleaned {theme.safe(format_size(result.deleted_bytes))}")
            if result.errors:
                print(f"Warnings/errors ({len(result.errors)}):")
                for err in result.errors[:5]:
                    print(f"  {err}")

            try:
                input("\nPress Enter to continue...")
            except (EOFError, KeyboardInterrupt):
                pass
            return True

        if choice == "3":
            if not report.can_clean_low_risk:
                if report.status == BrowserStatus.ACTIVE:
                    print(
                        f"\n⚠️  {theme.active('BLOCKED')}: Chrome is running with profile {report.name}."
                    )
                elif report.status == BrowserStatus.UNKNOWN:
                    print(
                        f"\n⚠️  {theme.review('BLOCKED')}: Profile {report.name} activity is unknown."
                    )
                else:
                    print("\nNothing low-risk to clean in this profile.")
                try:
                    input("\nPress Enter to continue...")
                except (EOFError, KeyboardInterrupt):
                    pass
                continue

            # Confirm low-risk cleanup for single profile
            plan = create_low_risk_cleanup_plan_for_browser(report)
            print(
                f"\n⚠️  {theme.review('Notice')}: Low-risk items include component downloads, ML models, and"
            )
            print("   safe experiment seeds. Chrome will redownload them when needed.")
            print(f"\nYou are about to clean low-risk caches in {report.name}:")
            for it in report.low_risk_items:
                if it.size > 0:
                    print(f"  {format_size(it.size):>10}  {it.relative_path}")
            print(
                f"\nTotal reclaimable: {theme.safe(format_size(plan.total_bytes_to_clean))}"
            )

            confirmed = prompt_confirmation('Type "clean" to confirm: ')
            if not confirmed:
                print("\nCleanup cancelled.")
                continue

            result = execute_cleanup_plan(plan, dry_run=False)
            print(f"\n✓ Cleaned {theme.safe(format_size(result.deleted_bytes))}")
            if result.errors:
                print(f"Warnings/errors ({len(result.errors)}):")
                for err in result.errors[:5]:
                    print(f"  {err}")

            try:
                input("\nPress Enter to continue...")
            except (EOFError, KeyboardInterrupt):
                pass
            return True

        if choice == "4":
            print(f"\n{theme.bold('Review items for')} {report.name}:")
            if not report.review_items:
                print("  No review items present.")
            for it in report.review_items:
                print(f"\n  {it.relative_path} — {format_size(it.size)}")
                print(f"    {it.rationale or it.description}")
            try:
                input("\nPress Enter to continue...")
            except (EOFError, KeyboardInterrupt):
                pass

        elif choice == "5":
            all_items: list = []
            for level in SafetyLevel:
                all_items.extend(report.items_by_safety.get(level, []))

            if not all_items:
                print("\nNo items to explain.")
                continue

            print("\nSelect an item to explain:")
            for i, it in enumerate(all_items, 1):
                print(f"  {i:>2}. {it.relative_path:<35} [{it.safety.value}]")
            try:
                item_choice = input("\nItem number: ").strip()
                if item_choice.isdigit() and 1 <= int(item_choice) <= len(all_items):
                    selected = all_items[int(item_choice) - 1]
                    print(render_why_explanation(selected))
                else:
                    print("Invalid item number.")
                input("\nPress Enter to continue...")
            except (EOFError, KeyboardInterrupt):
                pass


def handle_batch_safe_cleanup(
    aggregate: AggregateReport,
    scanner: ProfileScanner,
    auto_confirm: bool = False,
    interactive: bool = True,
) -> bool:
    """Execute batch cleanup of all safe caches across inactive profiles."""
    plan = create_cleanup_plan_for_all(aggregate)

    if plan.is_empty:
        print("\nNo safe caches available to clean across inactive browsers.")
        if interactive:
            try:
                input("\nPress Enter to continue...")
            except (EOFError, KeyboardInterrupt):
                pass
        return False

    print("\n" + theme.bold("Clean Safe Caches Summary"))
    print("═" * 45)
    print(f"Inactive browsers to clean: {theme.bold(str(len(plan.targeted_browsers)))}")
    print(
        f"Safe storage to reclaim:    {theme.safe(format_size(plan.total_bytes_to_clean))}"
    )
    print()

    # Show largest profiles in cleanup plan
    sorted_targets = sorted(
        plan.browser_plans, key=lambda p: p.total_bytes, reverse=True
    )
    print("Largest opportunities:")
    for bp in sorted_targets[:5]:
        print(f"  {bp.report.name:<25} {format_size(bp.total_bytes):>10}")

    if plan.skipped_active:
        print(
            f"\n{theme.active('Active browsers skipped')} ({len(plan.skipped_active)}):"
        )
        for r in plan.skipped_active:
            print(f"  {r.name} (PID {r.active_pid})")

    if plan.skipped_unknown:
        print(
            f"\n{theme.review('Unknown status browsers skipped')} ({len(plan.skipped_unknown)}):"
        )
        for r in plan.skipped_unknown:
            print(f"  {r.name}")

    print()
    if not auto_confirm:
        confirmed = prompt_confirmation('Type "clean" to confirm batch cleanup: ')
        if not confirmed:
            print("\nCleanup cancelled.")
            if interactive:
                try:
                    input("\nPress Enter to continue...")
                except (EOFError, KeyboardInterrupt):
                    pass
            return False
    else:
        print("Confirmation bypassed (--yes).")

    print("\nCleaning safe caches...")
    result = execute_cleanup_plan(plan, dry_run=False)

    print("\n" + theme.bold("Cleanup Complete"))
    print("─" * 30)
    print(f"Deleted:  {theme.safe(format_size(result.deleted_bytes))}")
    print(f"Profiles: {result.cleaned_profiles_count}")
    print(
        f"Skipped:  {result.skipped_active_count} active, {result.skipped_unknown_count} unknown"
    )
    print(f"Errors:   {len(result.errors)}")

    if result.errors:
        print("\nErrors encountered:")
        for err in result.errors[:10]:
            print(f"  {err}")

    if interactive:
        try:
            input("\nPress Enter to return to main menu...")
        except (EOFError, KeyboardInterrupt):
            pass

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
        print("\nNo low-risk caches available to clean across inactive browsers.")
        if interactive:
            try:
                input("\nPress Enter to continue...")
            except (EOFError, KeyboardInterrupt):
                pass
        return False

    print("\n" + theme.bold("Clean Low-Risk Caches Summary"))
    print("═" * 45)
    print(
        f"⚠️  {theme.review('Notice')}: Low-risk items include component downloads, ML models, and"
    )
    print(
        "   safe experiment seeds. Chrome will automatically redownload them when needed."
    )
    print()
    print(f"Inactive browsers to clean: {theme.bold(str(len(plan.targeted_browsers)))}")
    print(
        f"Low-risk storage to reclaim: {theme.safe(format_size(plan.total_bytes_to_clean))}"
    )
    print()

    # Show largest profiles in cleanup plan
    sorted_targets = sorted(
        plan.browser_plans, key=lambda p: p.total_bytes, reverse=True
    )
    print("Largest opportunities:")
    for bp in sorted_targets[:5]:
        print(f"  {bp.report.name:<25} {format_size(bp.total_bytes):>10}")

    if plan.skipped_active:
        print(
            f"\n{theme.active('Active browsers skipped')} ({len(plan.skipped_active)}):"
        )
        for r in plan.skipped_active:
            print(f"  {r.name} (PID {r.active_pid})")

    if plan.skipped_unknown:
        print(
            f"\n{theme.review('Unknown status browsers skipped')} ({len(plan.skipped_unknown)}):"
        )
        for r in plan.skipped_unknown:
            print(f"  {r.name}")

    print()
    if not auto_confirm:
        confirmed = prompt_confirmation(
            'Type "clean" to confirm batch low-risk cleanup: '
        )
        if not confirmed:
            print("\nCleanup cancelled.")
            if interactive:
                try:
                    input("\nPress Enter to continue...")
                except (EOFError, KeyboardInterrupt):
                    pass
            return False
    else:
        print("Confirmation bypassed (--yes).")

    print("\nCleaning low-risk caches...")
    result = execute_cleanup_plan(plan, dry_run=False)

    print("\n" + theme.bold("Cleanup Complete"))
    print("─" * 30)
    print(f"Deleted:  {theme.safe(format_size(result.deleted_bytes))}")
    print(f"Profiles: {result.cleaned_profiles_count}")
    print(
        f"Skipped:  {result.skipped_active_count} active, {result.skipped_unknown_count} unknown"
    )
    print(f"Errors:   {len(result.errors)}")

    if result.errors:
        print("\nErrors encountered:")
        for err in result.errors[:10]:
            print(f"  {err}")

    if interactive:
        try:
            input("\nPress Enter to return to main menu...")
        except (EOFError, KeyboardInterrupt):
            pass

    return True


def main_menu(root: Path | None = None) -> None:
    """Main interactive terminal loop."""
    scanner = ProfileScanner()
    chrome_root = get_chrome_root(root)

    print(f"\nScanning ChromePower browsers in {chrome_root}...")
    aggregate = scanner.scan_all(chrome_root)

    while True:
        print(render_overview(aggregate))
        print()
        print("What would you like to do?")
        print()
        print("  1. Overview (o)")
        print("  2. Browsers (b)")
        print("  3. Inspect browser")
        print("  4. Clean safe caches")
        print("  5. Clean low-risk caches")
        print("  6. Largest cleanup opportunities")
        print("  7. Largest unknown data")
        print("  8. Largest review data")
        print("  9. Refresh scan (r)")
        print("  10. Quit (q)")
        print()

        try:
            choice = input("❯ ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            print("\n\nBye.")
            sys.exit(0)

        if choice in ("1", "o", "overview"):
            continue

        elif choice in ("2", "b", "browsers"):
            selected = choose_browser_interactive(aggregate.reports)
            if selected:
                changed = handle_browser_inspection(selected, scanner)
                if changed:
                    print(f"\nRescanning {chrome_root}...")
                    aggregate = scanner.scan_all(chrome_root, force=True)

        elif choice in ("3", "inspect"):
            selected = choose_browser_interactive(aggregate.reports)
            if selected:
                changed = handle_browser_inspection(selected, scanner)
                if changed:
                    print(f"\nRescanning {chrome_root}...")
                    aggregate = scanner.scan_all(chrome_root, force=True)

        elif choice in ("4", "clean", "clean-safe"):
            changed = handle_batch_safe_cleanup(aggregate, scanner)
            if changed:
                print(f"\nRescanning {chrome_root}...")
                aggregate = scanner.scan_all(chrome_root, force=True)

        elif choice in ("5", "clean-low-risk", "low-risk"):
            changed = handle_batch_low_risk_cleanup(aggregate, scanner)
            if changed:
                print(f"\nRescanning {chrome_root}...")
                aggregate = scanner.scan_all(chrome_root, force=True)

        elif choice == "6":
            print(render_largest_cleanup_opportunities(aggregate.reports))
            try:
                input("\nPress Enter to continue...")
            except (EOFError, KeyboardInterrupt):
                pass

        elif choice == "7":
            print(render_largest_unknown_data(aggregate.reports))
            try:
                input("\nPress Enter to continue...")
            except (EOFError, KeyboardInterrupt):
                pass

        elif choice == "8":
            print(render_largest_review_data(aggregate.reports))
            try:
                input("\nPress Enter to continue...")
            except (EOFError, KeyboardInterrupt):
                pass

        elif choice in ("9", "r", "refresh"):
            print(f"\nRefreshing scan of {chrome_root}...")
            aggregate = scanner.scan_all(chrome_root, force=True)

        elif choice in ("10", "q", "quit", "exit"):
            print("Bye.")
            break

        else:
            print("Unknown command.")


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
        print(f"Performing dry run on {chrome_root}...")
        aggregate = scanner.scan_all(chrome_root)

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
        print("\n" + theme.bold(dry_title))
        print("═" * 45)
        print(f"Targeted inactive profiles: {len(plan.targeted_browsers)}")
        print(
            f"Total cache reclaimable: {theme.safe(format_size(plan.total_bytes_to_clean))}"
        )
        print(f"Skipped active profiles: {len(plan.skipped_active)}")
        print(f"Skipped unknown profiles: {len(plan.skipped_unknown)}")
        result = execute_cleanup_plan(plan, dry_run=True)
        print(
            f"\nDry run complete: would delete {format_size(result.deleted_bytes)} across {result.cleaned_profiles_count} profiles."
        )
        return

    # Direct batch clean flags
    if args.clean_safe or args.clean_low_risk:
        aggregate = scanner.scan_all(chrome_root)
        if args.clean_safe:
            handle_batch_safe_cleanup(
                aggregate, scanner, auto_confirm=args.yes, interactive=False
            )
            if args.clean_low_risk:
                aggregate = scanner.scan_all(chrome_root, force=True)
        if args.clean_low_risk:
            handle_batch_low_risk_cleanup(
                aggregate, scanner, auto_confirm=args.yes, interactive=False
            )
        return

    # Interactive menu by default
    try:
        main_menu(args.root)
    except KeyboardInterrupt:
        print("\n\nBye.")
        sys.exit(0)


if __name__ == "__main__":
    main()
