"""Safe cleanup execution engine with multiple safety guards."""

from __future__ import annotations

import os
import shutil
from dataclasses import dataclass, field
from pathlib import Path

from power_cleaner.models import CleanupAction, SafetyLevel
from power_cleaner.planner import CleanupPlan


def _calculate_path_size(path: Path) -> int:
    """Calculate the total size of a file or directory tree in bytes without following symlinks."""
    if path.is_symlink():
        return 0
    if path.is_file():
        try:
            return path.stat().st_size
        except OSError:
            return 0
    if path.is_dir():
        total = 0
        try:
            for root, dirs, files in os.walk(path, followlinks=False):
                root_path = Path(root)
                dirs[:] = [d for d in dirs if not (root_path / d).is_symlink()]
                for filename in files:
                    file_path = root_path / filename
                    if not file_path.is_symlink():
                        try:
                            total += file_path.stat().st_size
                        except OSError:
                            pass
        except OSError:
            pass
        return total
    return 0


@dataclass
class CleanupResult:
    """Summary of cleanup execution results."""

    dry_run: bool = False
    deleted_bytes: int = 0
    cleaned_profiles_count: int = 0
    skipped_active_count: int = 0
    skipped_unknown_count: int = 0
    errors: list[str] = field(default_factory=list)


def prompt_confirmation(
    prompt_text: str = 'Type "clean" to confirm: ',
    expected: str = "clean",
) -> bool:
    """Prompt the user for explicit confirmation. Returns True ONLY on exact expected input."""
    try:
        user_input = input(f"\n{prompt_text}").strip()
        return user_input.lower() == expected.lower()
    except (EOFError, KeyboardInterrupt):
        return False


def execute_cleanup_plan(
    plan: CleanupPlan,
    dry_run: bool = False,
) -> CleanupResult:
    """Execute a validated cleanup plan with strict filesystem guards.

    Safety principles enforced:
    1. Active or Unknown status profiles are completely skipped.
    2. Only SAFE or explicitly planned LOW_RISK items are processed.
    3. Target paths must resolve strictly within the specific browser profile.
    4. Target paths can never be the profile itself or the tool directory.
    5. 'clear_contents' empties directory contents while preserving the directory.
    6. In dry-run mode, no filesystem changes occur.
    """
    result = CleanupResult(
        dry_run=dry_run,
        skipped_active_count=len(plan.skipped_active),
        skipped_unknown_count=len(plan.skipped_unknown),
    )

    for b_plan in plan.browser_plans:
        report = b_plan.report
        browser_resolved = report.path.resolve()

        profile_bytes_deleted = 0

        allowed_levels = getattr(b_plan, "allowed_safety_levels", (SafetyLevel.SAFE,))

        for item in b_plan.items_to_clean:
            if item.safety not in allowed_levels or item.safety not in (
                SafetyLevel.SAFE,
                SafetyLevel.LOW_RISK,
            ):
                result.errors.append(
                    f"Safety guard: item {item.relative_path} is not permitted for cleanup ({item.safety}), skipped."
                )
                continue

            target_path = (report.path / item.relative_path).resolve()

            # Path containment guard: must be strictly inside the profile directory
            try:
                if not target_path.is_relative_to(browser_resolved):
                    result.errors.append(
                        f"Safety guard: path {target_path} escapes profile {browser_resolved}"
                    )
                    continue
            except (ValueError, AttributeError):
                result.errors.append(f"Invalid path traversal: {target_path}")
                continue

            # Cannot delete the profile directory itself
            if target_path == browser_resolved:
                result.errors.append(
                    f"Safety guard: cannot delete profile root {target_path}"
                )
                continue

            if dry_run:
                profile_bytes_deleted += item.size
                continue

            if not target_path.exists() and not target_path.is_symlink():
                continue

            try:
                if item.cleanup_action == CleanupAction.CLEAR_CONTENTS:
                    # Empties children inside the cache folder
                    if target_path.is_dir() and not target_path.is_symlink():
                        for child in list(target_path.iterdir()):
                            try:
                                child_size = _calculate_path_size(child)
                                if child.is_symlink() or child.is_file():
                                    child.unlink()
                                elif child.is_dir():
                                    shutil.rmtree(child)
                                profile_bytes_deleted += child_size
                            except (PermissionError, FileNotFoundError, OSError) as exc:
                                result.errors.append(
                                    f"Failed to remove {child.name} in {item.relative_path}: {exc}"
                                )
                    elif target_path.is_file() or target_path.is_symlink():
                        # Fallback for file-based caches
                        size = _calculate_path_size(target_path)
                        target_path.unlink()
                        profile_bytes_deleted += size

                elif item.cleanup_action == CleanupAction.DELETE_PATH:
                    size = _calculate_path_size(target_path)
                    if target_path.is_symlink() or target_path.is_file():
                        target_path.unlink()
                    elif target_path.is_dir():
                        shutil.rmtree(target_path)
                    profile_bytes_deleted += size

            except (PermissionError, OSError) as exc:
                result.errors.append(f"Error cleaning {item.relative_path}: {exc}")

        if profile_bytes_deleted > 0 or dry_run:
            result.cleaned_profiles_count += 1
            result.deleted_bytes += (
                b_plan.total_bytes if dry_run else profile_bytes_deleted
            )

    return result
