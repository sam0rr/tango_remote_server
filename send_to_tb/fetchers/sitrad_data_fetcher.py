#!/usr/bin/env python3
"""
sitrad_data_fetcher.py — SQLite-based DataFetcher for TC-900 logs.
"""
import os
import sqlite3
import math
import logging
from .data_fetcher import DataFetcher

log = logging.getLogger("sitrad_data_fetcher")


class SitradDataFetcher(DataFetcher):
    """
    Concrete DataFetcher for the tc900log table in an SQLite database.
    Implements fetch_rows() + build_payload().
    """

    SQL_QUERY = """
        SELECT rowid, id,
               ROUND(Temp1/10.0, 1) AS t1,
               ROUND(Temp2/10.0, 1) AS t2,
               ROUND(Temp3/10.0, 1) AS t3,
               defr, fans, refr, buzz, econ, fast,
               dig1, dig2, door, estagio,
               CAST(((data - 25569)*86400 - 14400)*1000 AS INTEGER) AS ts_ms
          FROM tc900log
         WHERE rowid > ?
         ORDER BY rowid
    """

    def __init__(self, db_path: str, state_file: str):
        """
        :param db_path:     Path to the SQLite database file.
        :param state_file:  Path to the file storing the last processed rowid.
        """
        super().__init__(state_file)
        self.db_path = db_path

    def fetch_rows(self, since_id: int) -> list[sqlite3.Row]:
        """
        Connect to SQLite, run SQL_QUERY with since_id, and return a list of sqlite3.Row.
        """
        if not os.path.isfile(self.db_path):
            log.error("Database not found: %s", self.db_path)
            return []

        try:
            conn = sqlite3.connect(self.db_path)
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute(self.SQL_QUERY, (since_id,))
            rows = cursor.fetchall()
        except sqlite3.Error as e:
            log.error("SQLite error: %s", e)
            rows = []
        finally:
            conn.close()

        return rows

    def _is_valid_timestamp(self, ts: int) -> bool:
        """
        Return False if ts < MIN_VALID_TS_MS. Read MIN_VALID_TS_MS from environment.
        """
        min_ts = int(os.getenv("MIN_VALID_TS_MS", "946684800000"))
        return ts >= min_ts

    def _clean_value(self, value) -> float | int | None:
        """
        If value is None, NaN, or Infinity → return None. Else return value.
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
              "ts": <timestamp_ms>,
              "values": { … }       
            }
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
