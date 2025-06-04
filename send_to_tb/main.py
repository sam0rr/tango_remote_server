#!/usr/bin/env python3
"""
main.py — Entrypoint: loads .env, instantiates the correct DataFetcher & HttpClient,
then calls SendToLauncher.start().
"""

import os
import sys
import logging
from pathlib import Path

pkg_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, pkg_dir)

from clients.thingsboard_client import ThingsBoardClient
from fetchers.sitrad_data_fetcher import SitradDataFetcher
from launcher.send_launcher import SendToLauncher


def load_dotenv(dotenv_path: str):
    """Load environment variables from .env file if present."""
    path = Path(dotenv_path)
    if not path.is_file():
        print(f"⚠️  No .env file found at {dotenv_path}. Skipping load.")
        return

    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, val = line.split("=", 1)
        val = val.split("#", 1)[0].strip()
        os.environ.setdefault(key, val)


def setup_logging() -> logging.Logger:
    """Configure logging to console and a log file in the logs/ folder."""
    log_level = getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper(), logging.INFO)
    log_file_name = os.getenv("LOG_FILE", "sitrad_push.log")

    logs_dir = Path(pkg_dir) / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    log_file_path = logs_dir / log_file_name

    handlers = [
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(log_file_path, mode="a")
    ]

    logging.basicConfig(
        level=log_level,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=handlers
    )

    return logging.getLogger("send_to_thingsboard")


def get_env_config() -> tuple[str, str, int]:
    """Extract required config values from the environment."""
    raw_db = os.getenv("DB_PATH")
    if not raw_db:
        raise ValueError("✖️  DB_PATH is missing in environment. Exiting.")

    db_path = os.path.expanduser(raw_db)
    state_file = os.getenv("STATE_FILE", ".last_rowid")
    max_per_sec = int(os.getenv("MAX_MSGS_PER_SEC", "10"))

    return db_path, state_file, max_per_sec


def build_launcher(db_path: str, state_file: str, max_per_sec: int) -> SendToLauncher:
    """Create and return a configured SendToLauncher."""
    fetcher = SitradDataFetcher(db_path=db_path, state_file=state_file)
    client = ThingsBoardClient()
    return SendToLauncher(fetcher, client, max_per_sec=max_per_sec)


def main():
    """Entrypoint for launching the data pipeline."""
    dotenv_file = os.path.join(pkg_dir, ".env")
    load_dotenv(dotenv_file)
    log = setup_logging()

    try:
        db_path, state_file, max_per_sec = get_env_config()
        launcher = build_launcher(db_path, state_file, max_per_sec)

        log.info("▶︎ Starting send_to_thingsboard...")
        launcher.start()
    except Exception as e:
        log.exception("🔥 An error occurred during execution:")
        sys.exit(1)


if __name__ == "__main__":
    main()
