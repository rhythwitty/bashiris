"""Configuration and path constants for ChromePower Cleaner."""

from __future__ import annotations

import os
from pathlib import Path

# Standard default ChromePower cache root
STANDARD_ROOT = Path.home() / "Documents" / "ChromePowerCache" / "chrome"

# Chrome user-data directories must have these markers directly inside them
CHROME_MARKERS = (
    "Local State",
    "Default",
)

# Directory / file names to always exclude from profile discovery
EXCLUDED_NAMES = {
    "power-cleaner",
    "power_cleaner",
    ".DS_Store",
    ".git",
    ".venv",
}


def get_chrome_root(explicit_root: Path | str | None = None) -> Path:
    """Return the ChromePower cache root directory.

    Resolution order:
    1. Explicit path parameter if provided.
    2. CHROME_POWER_ROOT environment variable if set.
    3. Standard root: ~/Documents/ChromePowerCache/chrome (if it exists).
    4. Current working directory as a last resort.
    """
    if explicit_root is not None:
        return Path(explicit_root).resolve()

    env_root = os.environ.get("CHROME_POWER_ROOT")
    if env_root:
        return Path(env_root).resolve()

    if STANDARD_ROOT.is_dir():
        return STANDARD_ROOT.resolve()

    return Path.cwd().resolve()
