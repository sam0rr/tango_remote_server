# utils/log_cleaner.py
import os
import time
from pathlib import Path


def purge_old_logs(log_dir: str | Path, max_age_days: int = 7):
    """
    Delete .log files in log_dir older than `max_age_days`.
    """
    log_dir = Path(log_dir)
    if not log_dir.is_dir():
        return

    now = time.time()
    cutoff = now - (max_age_days * 86400)

    for log_file in log_dir.glob("*.log"):
        if log_file.stat().st_mtime < cutoff:
            try:
                log_file.unlink()
                print(f"🧹 Deleted old log: {log_file.name}")
            except Exception as e:
                print(f"⚠️ Could not delete {log_file.name}: {e}")
