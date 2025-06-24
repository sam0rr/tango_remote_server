#!/usr/bin/env python3
"""
sitrad_data_fetcher.py — SQLite-based DataFetcher for TC-900 logs.
Fetch all rows each run, then build a payload containing exactly the fields:
Temp1, Temp2, defr, fans, refr, dig1, dig2.
"""

import os
import math
import logging
import sqlite3
from datetime import datetime, timedelta, timezone
from .data_fetcher import DataFetcher
from utils.db.db_connect import get_sqlite_connection

log = logging.getLogger("sitrad_data_fetcher")


class SitradDataFetcher(DataFetcher):
    """
    Concrete DataFetcher for the tc900log table in a SQLite database.
    On each fetch, retrieve ALL rows (ORDER BY rowid), filter out invalid timestamps,
    and return a list of payload dicts.
    """

    SQL_QUERY_TEMPLATE = """
        SELECT rowid,
               ROUND(Temp1/10.0, 2) AS t1,
               ROUND(Temp2/10.0, 2) AS t2,
               defr, fans, refr,
               dig1, dig2,
               data AS excel_serial
          FROM {table}
         ORDER BY rowid
    """

    def __init__(
        self,
        db_path: str,
        timeout: float,
        schema_version: str,
        tables: dict
    ):
        """
        Initialize with database path and cleaning parameters.

        :param db_path: Path to the SQLite database file.
        :param min_ts: Minimal valid timestamp in ms.
        :param timeout: SQLite connection timeout in seconds.
        :param tables: Dictionary of table names (e.g., {'telemetry': 'tc900log'}).
        """
        super().__init__()
        self.db_path = db_path
        self.timeout = timeout
        self.schema_version = schema_version
        self.tables = tables

    def fetch_rows(self) -> list[sqlite3.Row]:
        """
        Open the SQLite database and fetch all rows from the telemetry table.
        Returns a list of sqlite3.Row objects or an empty list on error.
        """
        if not os.path.isfile(self.db_path):
            log.error("Database not found: %s", self.db_path)
            return []

        try:
            with get_sqlite_connection(self.db_path, self.timeout) as conn:
                conn.row_factory = sqlite3.Row
                cursor = conn.cursor()
                table = self.tables.get("telemetry", "tc900log")
                query = self.SQL_QUERY_TEMPLATE.format(table=table)
                cursor.execute(query)
                return cursor.fetchall()
        except sqlite3.Error as e:
            log.error("SQLite error: %s", e)
            return []

    def _is_valid_timestamp(self, ts: int) -> bool:
        """
        Check if the timestamp meets the minimum valid threshold.

        :param ts: Timestamp in milliseconds.
        :return: True if ts >= self.min_ts, False otherwise.
        """
        return ts >= self.min_ts

    def build_payload(self, row: sqlite3.Row) -> dict | None:
        """
        Convert a database row into a telemetry payload dict.
        Skips rows with invalid timestamps.

        :param row: sqlite3.Row from the telemetry query.
        :return: A dict {'rowid', 'ts', 'values'} or None to skip.
        """
        ts = self._excel_serial_to_utc_ms(row["excel_serial"])
        if not self._is_valid_timestamp(ts):
            return None

        values = {
            "Temp1": self._clean_value(row["t1"]),
            "Temp2": self._clean_value(row["t2"]),
            "defr":  row["defr"],
            "fans":  row["fans"],
            "refr":  row["refr"],
            "dig1":  row["dig1"],
            "dig2":  row["dig2"],
        }
        filtered = {k: v for k, v in values.items() if v is not None}

        return {"rowid": row["rowid"], "ts": ts, "values": filtered}

    @staticmethod
    def _clean_value(value) -> float | int | None:
        """
        Clean numeric values, converting NaN or infinite floats to None.

        :param value: Numeric or None.
        :return: Cleaned number or None.
        """
        if value is None:
            return None
        if isinstance(value, float) and (math.isnan(value) or math.isinf(value)):
            return None
        return value

    @staticmethod
    def _excel_serial_to_utc_ms(serial: float) -> int:
        """
        Convert an Excel serial date (days since 1899-12-30) to a UTC timestamp in ms.
        """

        base_naive = datetime(1899, 12, 30)
        dt_local_naive = base_naive + timedelta(days=serial)
        local_tz = datetime.now().astimezone().tzinfo
        dt_local = dt_local_naive.replace(tzinfo=local_tz)
        dt_utc = dt_local.astimezone(timezone.utc)
        return int(dt_utc.timestamp() * 1000)
