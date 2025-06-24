#!/usr/bin/env python3
"""
sitrad_data_fetcher.py — SQLite-based DataFetcher for TC-900 logs.
Ensures the schema is migrated, then fetches all rows each run,
builds a payload containing exactly the fields:
Temp1, Temp2, defr, fans, refr, dig1, dig2, ts.
Rows are expected to be deleted by the caller after processing.
"""

import os
import math
import logging
import sqlite3
from .data_fetcher import DataFetcher
from utils.db.db_connect import get_sqlite_connection
from utils.db.schema_manager import ensure_schema

log = logging.getLogger("sitrad_data_fetcher")


class SitradDataFetcher(DataFetcher):
    SQL_QUERY_TEMPLATE = """
        SELECT rowid,
               ROUND(Temp1/10.0, 2) AS t1,
               ROUND(Temp2/10.0, 2) AS t2,
               defr, fans, refr,
               dig1, dig2,
               {time_column} AS ts
          FROM {table}
         ORDER BY rowid
    """

    def __init__(
        self,
        db_path: str,
        timeout: float,
        schema_version: int,
        time_column: str,
        tables: dict
    ):
        super().__init__()
        self.db_path = db_path
        self.timeout = timeout
        self.schema_version = schema_version
        self.time_column = time_column

        # pull your telemetry table name
        self.telemetry_table = tables.get("telemetry", "tc900log")

        # build the final SQL
        self._fetch_sql = self.SQL_QUERY_TEMPLATE.format(
            table=self.telemetry_table,
            time_column=self.time_column
        )

        # ensure schema/migrations only needs the table name once
        ensure_schema(
            db_path=self.db_path,
            table=self.telemetry_table,
            time_column=self.time_column,
            target_version=self.schema_version,
            timeout=self.timeout
        )

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
                cursor.execute(self._fetch_sql)
                return cursor.fetchall()
        except sqlite3.Error as e:
            log.error("SQLite error: %s", e)
            return []

    def build_payload(self, row: sqlite3.Row) -> dict:
        ts = row["ts"]
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
        if value is None:
            return None
        if isinstance(value, float) and (math.isnan(value) or math.isinf(value)):
            log.debug("Filtered out invalid float: %r", value)
            return None
        return value
