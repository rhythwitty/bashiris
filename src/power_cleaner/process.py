"""Active Chrome process detection and profile locking checks."""

from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

from power_cleaner.models import BrowserStatus


def get_system_processes() -> list[tuple[int, str]] | None:
    """Return a list of (pid, command_line) for running processes on macOS/Linux.

    Uses ``ps -axwwo`` so that long ``--user-data-dir`` paths are never
    truncated by the terminal width, which would cause a false INACTIVE
    determination for an active browser.

    Returns None if process inspection fails or is inconclusive.
    """
    try:
        result = subprocess.run(
            ["ps", "-axwwo", "pid,command="],
            capture_output=True,
            text=True,
            check=True,
            timeout=10,
        )
    except (subprocess.SubprocessError, OSError):
        return None

    processes: list[tuple[int, str]] = []
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(maxsplit=1)
        if len(parts) == 2 and parts[0].isdigit():
            processes.append((int(parts[0]), parts[1]))
    return processes


# Backward-compatible private alias
_get_system_processes = get_system_processes


def _extract_user_data_dir(command: str) -> str | None:
    """Extract the value of --user-data-dir from a command line string."""
    match = re.search(r'--user-data-dir=(?:"([^"]+)"|\'([^\']+)\'|(\S+))', command)
    if match:
        val = match.group(1) or match.group(2) or match.group(3)
        return val.strip("\"'") if val else None
    return None


def _is_pid_alive(pid: int) -> bool:
    """Check whether a PID is currently running."""
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        # Process exists, owned by another user or elevated
        return True


def _get_command_for_pid(pid: int) -> str | None:
    """Fetch the command line of a specific PID."""
    try:
        res = subprocess.run(
            ["ps", "-p", str(pid), "-o", "command="],
            capture_output=True,
            text=True,
            check=True,
            timeout=5,
        )
        return res.stdout.strip()
    except (subprocess.SubprocessError, OSError):
        return None


def inspect_browser_activity(
    browser_path: Path,
    processes: list[tuple[int, str]] | None = None,
) -> tuple[BrowserStatus, str, int | None]:
    """Determine whether Chrome is currently using the given user-data directory.

    Returns (status, reason, active_pid).

    Safety principles:
    1. Process detection is the strongest signal.
    2. Singleton files are supporting evidence, but stale locks after crashes
       must not be mistaken for active Chrome.
    3. If process inspection is inconclusive, return UNKNOWN (which blocks cleanup).
    """
    resolved_path = browser_path.resolve()
    resolved_path_str = str(resolved_path)

    # 1. Fetch process list if not provided
    if processes is None:
        processes = _get_system_processes()

    if processes is None:
        return (
            BrowserStatus.UNKNOWN,
            "Could not inspect system processes safely (process inspection failed)",
            None,
        )

    current_pid = os.getpid()

    # 2. Check process command lines for --user-data-dir
    for pid, command in processes:
        if pid == current_pid:
            continue

        # Skip cleaner tool itself
        if "power_cleaner" in command or "power-cleaner" in command:
            continue

        # Check for user-data-dir
        if "--user-data-dir=" in command:
            udd = _extract_user_data_dir(command)
            if udd:
                try:
                    udd_resolved = Path(udd).resolve()
                    if udd_resolved == resolved_path:
                        return (
                            BrowserStatus.ACTIVE,
                            f"Chrome is running with this profile (PID {pid})",
                            pid,
                        )
                except OSError:
                    pass

            if resolved_path_str in command:
                return (
                    BrowserStatus.ACTIVE,
                    f"Chrome process is referencing profile directory (PID {pid})",
                    pid,
                )

    # 3. Check Singleton files as supporting evidence
    singleton_lock = browser_path / "SingletonLock"
    if singleton_lock.is_symlink():
        try:
            target = singleton_lock.readlink()
            # Chrome on macOS/Linux formats target as <hostname>-<pid>
            match = re.search(r"-(\d+)$", str(target))
            if match:
                lock_pid = int(match.group(1))
                if _is_pid_alive(lock_pid):
                    lock_cmd = _get_command_for_pid(lock_pid)
                    if lock_cmd and (
                        "Chrome" in lock_cmd or "chrome" in lock_cmd.lower()
                    ):
                        return (
                            BrowserStatus.ACTIVE,
                            f"Active Chrome instance holds SingletonLock (PID {lock_pid})",
                            lock_pid,
                        )
                    # If lock PID is alive but command could not be checked:
                    if lock_cmd is None:
                        return (
                            BrowserStatus.UNKNOWN,
                            f"SingletonLock PID {lock_pid} is alive but could not be inspected",
                            lock_pid,
                        )
        except (OSError, ValueError):
            pass

    return (
        BrowserStatus.INACTIVE,
        "No running Chrome processes found for this profile",
        None,
    )
