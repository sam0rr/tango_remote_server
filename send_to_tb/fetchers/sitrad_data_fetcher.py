#!/usr/bin/env python3
"""
sitrad_data_fetcher.py — SQLite-based DataFetcher for TC-900 logs.
Fetch all rows each run, then build a payload containing exactly the fields:
Temp1, Temp2, defr, fans, refr, dig1, dig2.
"""

import os
import sqlite3
import math
import logging
from .data_fetcher import DataFetcher

log = logging.getLogger("sitrad_data_fetcher")


class SitradDataFetcher(DataFetcher):
    """
    Concrete DataFetcher for the tc900log table in a SQLite database.
    On each fetch, retrieve ALL rows (ORDER BY rowid), filter out invalid timestamps,
    and return a list of payload dicts.
    """

    SQL_QUERY = """
        SELECT rowid,
               ROUND(Temp1/10.0, 1) AS t1,
               ROUND(Temp2/10.0, 1) AS t2,
               defr, fans, refr,
               dig1, dig2,
               CAST(((data - 25569)*86400 - 14400)*1000 AS INTEGER) AS ts_ms
          FROM tc900log
         ORDER BY rowid
    """

    def __init__(self, db_path: str):
        """
        :param db_path: Path to the SQLite database file (tc900log.sqlite).
        """
        super().__init__()
        self.db_path = db_path

    def fetch_rows(self) -> list[sqlite3.Row]:
        """
        Open the database in WAL mode, fetch all rows, then close the connection.
        """
        if not os.path.isfile(self.db_path):
            log.error("Database not found: %s", self.db_path)
            return []

        rows: list[sqlite3.Row] = []
        try:
            conn = sqlite3.connect(self.db_path, timeout=30)
            conn.row_factory = sqlite3.Row
            # Enable WAL mode to reduce write conflicts with Sitrad
            conn.execute("PRAGMA journal_mode=WAL;")
            conn.execute("PRAGMA synchronous=NORMAL;")
            cursor = conn.cursor()
            cursor.execute(self.SQL_QUERY)
            rows = cursor.fetchall()
        except sqlite3.Error as e:
            log.error("SQLite error: %s", e)
            rows = []
        finally:
            conn.close()

        return rows

    def _is_valid_timestamp(self, ts: int) -> bool:
        """
        Return False if ts < MIN_VALID_TS_MS (default: Jan 1, 2000 in ms).
        """
        min_ts = int(os.getenv("MIN_VALID_TS_MS", "946684800000"))
        return ts >= min_ts

    def _clean_value(self, value) -> float | int | None:
        """
        If value is None, NaN, or Infinity → return None. Otherwise, return value.
        """
        if value is None:
            return None
        if isinstance(value, float) and (math.isnan(value) or math.isinf(value)):
            return None
        return value

    def build_payload(self, row: sqlite3.Row) -> dict | None:
        """
        Transform one sqlite3.Row into a dict:
            {
              "rowid": <rowid>,
              "ts":     <timestamp_ms>,
              "values": {
                  "Temp1": …,
                  "Temp2": …,
                  "defr":  …,
                  "fans":  …,
                  "refr":  …,
                  "dig1":  …,
                  "dig2":  …
              }
            }
        If the timestamp is invalid (too old), return None.
        """
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
