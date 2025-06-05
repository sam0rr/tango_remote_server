#!/usr/bin/env python3
"""
main.py — Entrypoint: load .env (with python-dotenv), configure logging, then purge old logs.
"""

import os
import sys
import logging
from pathlib import Path

pkg_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(pkg_dir))

from dotenv import load_dotenv
from clients.thingsboard_client import ThingsBoardClient
from fetchers.sitrad_data_fetcher import SitradDataFetcher
from launcher.send_launcher import SendToLauncher
from utils.log_cleaner import purge_old_logs

dotenv_path = pkg_dir / ".env"
logs_path = pkg_dir / "logs"

def setup_logging() -> logging.Logger:
    """
    Configure logging to both console and logs/<LOG_FILE>.
    LOG_LEVEL is read from environment variables.
    """
    level_name = os.getenv("LOG_LEVEL", "INFO").upper()
    level = getattr(logging, level_name, logging.INFO)
    log_filename = os.getenv("LOG_FILE", "sitrad_push.log")

    logs_dir = pkg_dir / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    log_path = logs_dir / log_filename

    logging.basicConfig(
        level=level,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler(log_path, mode="a")
        ]
    )
    return logging.getLogger("send_to_thingsboard")

def get_env_config() -> tuple[str, int]:
    """
    Read essential configuration from environment:
      - DB_PATH         : path to the SQLite database
      - MAX_MSGS_PER_SEC: allowed messages per second
    """
    raw_db = os.getenv("DB_PATH")
    if not raw_db:
        raise ValueError("DB_PATH is missing from environment. Exiting.")
    db_path = os.path.expanduser(raw_db)
    max_per_sec = int(os.getenv("MAX_MSGS_PER_SEC", "10"))
    return db_path, max_per_sec

def build_launcher(db_path: str, max_per_sec: int) -> SendToLauncher:
    """
    Instantiate SendToLauncher with configured fetcher and client.
    """
    fetcher = SitradDataFetcher(db_path=db_path)
    client = ThingsBoardClient()
    return SendToLauncher(fetcher, client, max_per_sec=max_per_sec)

def main():
    """
    Entrypoint: load .env, print debug info, configure logger, purge old logs,
    then start the data-push loop to ThingsBoard.
    """
    load_dotenv(dotenv_path)
    log = setup_logging()

    purge_raw = os.getenv("PURGE_LOG_DAYS", "2")
    purge_days = int(purge_raw)
    purge_old_logs(logs_path, max_age_days=purge_days)

    try:
        db_path, max_per_sec = get_env_config()
        launcher = build_launcher(db_path, max_per_sec)

        log.info("Starting send_to_thingsboard...")
        launcher.start()
    except Exception:
        log.exception("An error occurred during execution:")
        sys.exit(1)

if __name__ == "__main__":
    main()
