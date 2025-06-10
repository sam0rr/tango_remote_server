# utils/log/config.py

import os
from dataclasses import dataclass
from pathlib import Path

get = os.getenv  # Global alias for conciseness (used throughout the config loader)

@dataclass(frozen=True)
class Config:
    """
    Configuration object populated from environment variables.
    Only critical variables are strictly required.
    """

    # ▶︎ Credentials
    device_token: str

    # ▶︎ Paths
    db_path: str
    log_file: str

    # ▶︎ Telemetry sending behavior
    max_msgs_per_sec: int
    max_retry: int
    initial_delay_sec: float
    post_timeout_sec: int
    batch_window_sec: float
    min_batch_size_to_split: int

    # ▶︎ Filtering / Data cleaning
    min_valid_ts_ms: int
    excel_ts_offset: float
    sqlite_timeout_sec: int

    # ▶︎ Table names
    telemetry_table: str
    alarm_table: str

    # ▶︎ Logging
    log_level: str
    purge_log_days: int

    @classmethod
    def from_env(cls) -> "Config":
        """
        Load all configuration values from environment variables,
        validate critical ones, and apply sensible defaults elsewhere.
        """
        return cls(
            **cls._load_credentials(),
            **cls._load_paths(),
            **cls._load_telemetry(),
            **cls._load_filtering(),
            **cls._load_tables(),
            **cls._load_logging()
        )

    @staticmethod
    def _load_credentials() -> dict:
        """
        Load and validate required credentials.
        """
        token = get("DEVICE_TOKEN")
        if not token:
            raise ValueError("Missing required DEVICE_TOKEN in environment")
        return {"device_token": token.strip()}

    @staticmethod
    def _load_paths() -> dict:
        """
        Load database and log file paths, validate DB_PATH.
        """
        raw_db_path = get("DB_PATH")
        if not raw_db_path:
            raise ValueError("Missing required DB_PATH in environment")
        db_path = os.path.expanduser(raw_db_path)
        log_file = get("LOG_FILE", "sitrad_push.log")
        return {"db_path": db_path, "log_file": log_file}

    @staticmethod
    def _load_telemetry() -> dict:
        """
        Load telemetry transmission configuration.
        """
        return {
            "max_msgs_per_sec": int(get("MAX_MSGS_PER_SEC", "10")),
            "max_retry": int(get("MAX_RETRY", "5")),
            "initial_delay_sec": int(get("INITIAL_DELAY_MS", "200")) / 1000.0,
            "post_timeout_sec": int(get("POST_TIMEOUT", "10")),
            "batch_window_sec": float(get("BATCH_WINDOW_SEC", "1.0")),
            "min_batch_size_to_split": int(get("MIN_BATCH_SIZE_TO_SPLIT", "2")),
        }

    @staticmethod
    def _load_filtering() -> dict:
        """
        Load filtering rules and data cleaning thresholds.
        """
        return {
            "min_valid_ts_ms": int(get("MIN_VALID_TS_MS", "946684800000")),
            "excel_ts_offset": float(get("EXCEL_TS_OFFSET", "25569")),
            "sqlite_timeout_sec": int(get("SQLITE_TIMEOUT_SEC", "30")),
        }

    @staticmethod
    def _load_tables() -> dict:
        """
        Load custom table name overrides if provided.
        """
        return {
            "telemetry_table": get("TELEMETRY_TABLE", "tc900log"),
            "alarm_table": get("ALARM_TABLE", "rel_alarmes"),
        }

    @staticmethod
    def _load_logging() -> dict:
        """
        Load logging configuration: log level and retention policy.
        """
        return {
            "log_level": get("LOG_LEVEL", "INFO").upper(),
            "purge_log_days": int(get("PURGE_LOG_DAYS", "1")),
        }
