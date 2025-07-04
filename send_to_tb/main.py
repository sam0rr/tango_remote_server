#!/usr/bin/env python3
"""
main.py — Entrypoint: load .env, configure logging, purge logs, and start loop.
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
from utils.log.log_cleaner import purge_old_logs
from utils.log.log_setup import setup_logging
from utils.config import Config

dotenv_path = pkg_dir / ".env"
logs_path = pkg_dir / "logs"

def build_launcher(cfg: Config) -> SendToLauncher:
    """
    Instantiate SendToLauncher with configured fetcher and client.
    """
    tables = {
        "telemetry": cfg.telemetry_table,
        "alarm": cfg.alarm_table
    }

    fetcher = SitradDataFetcher(
        db_path=cfg.db_path,
        timeout=cfg.sqlite_timeout_sec,
        schema_version=cfg.schema_version,
        time_column=cfg.time_column_name,
        tables=tables
    )

    client = ThingsBoardClient(
        device_token=cfg.device_token,
        max_retry=cfg.max_retry,
        initial_delay=cfg.initial_delay_sec,
        max_delay=cfg.max_delay_sec,
        timeout=cfg.post_timeout_sec,
        min_batch_size_to_split=cfg.min_batch_size_to_split
    )

    return SendToLauncher(
        fetcher,
        client,
        max_batch_size=cfg.max_batch_size,
        batch_window_sec=cfg.batch_window_sec
    )

def main():
    """
    Entrypoint: load .env, configure logger, purge old logs,
    then start the data-push loop to ThingsBoard Cloud.
    """
    load_dotenv(dotenv_path)

    try:
        cfg = Config.from_env()
        log = setup_logging(pkg_dir, level=cfg.log_level, log_file=cfg.log_file)
        purge_old_logs(logs_path, max_age_days=cfg.purge_log_days)

        launcher = build_launcher(cfg)
        log.info("[TELEMETRY_START] Starting telemetry cycle")
        launcher.start()

    except Exception:
        logging.exception("An error occurred during execution:")
        sys.exit(1)

if __name__ == "__main__":
    main()
