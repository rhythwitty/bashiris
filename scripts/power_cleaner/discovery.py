"""Discovery of valid ChromePower browser user-data directories."""

from __future__ import annotations

from pathlib import Path

from power_cleaner.config import EXCLUDED_NAMES, get_chrome_root


def is_chrome_user_data_dir(path: Path) -> bool:
    """Detect whether a directory is a valid ChromePower browser profile.

    Requires both:
    1. 'Local State' (file)
    2. 'Default' (directory)
    """
    try:
        if not path.is_dir() or path.is_symlink():
            return False

        local_state = path / "Local State"
        default_dir = path / "Default"

        return (
            local_state.is_file()
            and not local_state.is_symlink()
            and default_dir.is_dir()
            and not default_dir.is_symlink()
        )
    except (PermissionError, OSError):
        return False


def discover_browsers(root: Path | None = None) -> list[Path]:
    """Find and return all valid ChromePower browser directories directly below root.

    Deterministic and sorted by name.
    Never inspects power-cleaner or hidden/system files.
    """
    search_root = get_chrome_root(root)
    if not search_root.is_dir():
        return []

    browsers: list[Path] = []

    try:
        entries = sorted(search_root.iterdir(), key=lambda p: p.name.lower())
    except (PermissionError, OSError):
        return []

    for entry in entries:
        if entry.name in EXCLUDED_NAMES:
            continue

        if entry.name.startswith("."):
            continue

        if entry.is_symlink():
            continue

        if is_chrome_user_data_dir(entry):
            browsers.append(entry)

    return browsers
