# utils/config.py

import os
from dataclasses import dataclass
from pathlib import Path

@dataclass
class Config:
    """
    Configuration object populated from environment variables.
    """
    db_path: str
    max_per_sec: int
    batch_window_sec: float
    min_valid_ts: int
    excel_offset: float
    device_token: str
    max_retry: int
    initial_delay: float
    timeout: int
    min_batch_size_to_split: int
    sqlite_timeout: int
    telemetry_table: str
    alarm_table: str

    @classmethod
    def from_env(cls) -> "Config":
        """
        Load and validate configuration from environment variables.
        """
        raw_db = os.getenv("DB_PATH")
        if not raw_db:
            raise ValueError("DB_PATH is missing from environment. Exiting.")

        return cls(
            db_path=os.path.expanduser(raw_db),
            max_per_sec=int(os.getenv("MAX_MSGS_PER_SEC", "10")),
            batch_window_sec=float(os.getenv("BATCH_WINDOW_SEC", "1.0")),
            min_valid_ts=int(os.getenv("MIN_VALID_TS_MS", "946684800000")),
            excel_offset=float(os.getenv("EXCEL_TS_OFFSET", "25569")),
            device_token=os.getenv("DEVICE_TOKEN", "").strip(),
            max_retry=int(os.getenv("MAX_RETRY", "5")),
            initial_delay=int(os.getenv("INITIAL_DELAY_MS", "200")) / 1000.0,
            timeout=int(os.getenv("POST_TIMEOUT", "10")),
            min_batch_size_to_split=int(os.getenv("MIN_BATCH_SIZE_TO_SPLIT", "2")),
            sqlite_timeout=int(os.getenv("SQLITE_TIMEOUT_SEC", "30")),
            telemetry_table=os.getenv("TELEMETRY_TABLE", "tc900log"),
            alarm_table=os.getenv("ALARM_TABLE", "rel_alarmes")
        )
