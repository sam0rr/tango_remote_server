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
               ROUND(Temp1/10.0, 1) AS t1,
               ROUND(Temp2/10.0, 1) AS t2,
               defr, fans, refr,
               dig1, dig2,
               CAST(((data - :excel_offset)*86400)*1000 AS INTEGER) AS ts_ms
          FROM {table}
         ORDER BY rowid
    """

    def __init__(self, db_path: str, min_ts: int, excel_offset: float, timeout: float, tables: dict):
        """
        :param db_path: Path to the SQLite database file (tc900log.sqlite).
        :param min_ts: Minimal valid timestamp in ms.
        :param excel_offset: Excel origin date offset (default: 25569).
        :param timeout: Timeout to use with sqlite3.connect.
        :param tables: Dict of table names, e.g., {"telemetry": "tc900log", "alarm": "rel_alarmes"}
        """
        super().__init__()
        self.db_path = db_path
        self.min_ts = min_ts
        self.excel_offset = excel_offset
        self.timeout = timeout
        self.tables = tables

    def fetch_rows(self) -> list[sqlite3.Row]:
        """
        Open the database in WAL mode, fetch all rows from the telemetry table,
        then close the connection.
        """
        if not os.path.isfile(self.db_path):
            log.error("Database not found: %s", self.db_path)
            return []

        rows: list[sqlite3.Row] = []
        try:
            with get_sqlite_connection(self.db_path, self.timeout) as conn:
                conn.row_factory = sqlite3.Row
                conn.execute("PRAGMA journal_mode=WAL;")
                conn.execute("PRAGMA synchronous=NORMAL;")
                cursor = conn.cursor()

                telemetry_table = self.tables.get("telemetry", "tc900log")
                query = self.SQL_QUERY_TEMPLATE.format(table=telemetry_table)
                cursor.execute(query, {"excel_offset": self.excel_offset})

                rows = cursor.fetchall()
        except sqlite3.Error as e:
            log.error("SQLite error: %s", e)
            rows = []

        return rows

    def _is_valid_timestamp(self, ts: int) -> bool:
        return ts >= self.min_ts

    def _clean_value(self, value) -> float | int | None:
        if value is None:
            return None
        if isinstance(value, float) and (math.isnan(value) or math.isinf(value)):
            return None
        return value

    def build_payload(self, row: sqlite3.Row) -> dict | None:
        ts = row["ts_ms"]
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

        return {
            "rowid": row["rowid"],
            "ts": ts,
            "values": filtered
        }
