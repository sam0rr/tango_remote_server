# utils/log/log_setup.py

import sys
import logging
from pathlib import Path

def setup_logging(pkg_dir: Path, level: str, log_filename: str) -> logging.Logger:
    """
    Configure logging with given level and output path.
    Logs are written to logs/<LOG_FILE> and also streamed to console.
    """
    log_level = getattr(logging, level.upper(), logging.INFO)

    logs_dir = pkg_dir / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    log_path = logs_dir / log_filename

    logging.basicConfig(
        level=log_level,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler(log_path, mode="a")
        ]
    )
    return logging.getLogger("send_to_thingsboard")
