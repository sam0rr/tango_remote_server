# utils/log_cleaner.py

import os
import time
import logging
from pathlib import Path

def purge_old_logs(log_dir: str | Path, max_age_days: int = 7):
    """
    Delete .log files in log_dir older than `max_age_days`.
    """
    logger = logging.getLogger(__name__)
    log_dir = Path(log_dir)
    if not log_dir.is_dir():
        return

    now = time.time()
    cutoff = now - (max_age_days * 86400)

    for log_file in log_dir.glob("*.log"):
        try:
            if log_file.stat().st_mtime < cutoff:
                log_file.unlink()
                logger.info("Deleted old log: %s", log_file.name)
        except Exception as e:
            logger.warning("Could not delete %s: %s", log_file.name, e)
