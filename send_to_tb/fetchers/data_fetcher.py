#!/usr/bin/env python3
"""
data_fetcher.py — Abstract base for fetching all rows and building telemetry payloads.
No more “last_id” file.
"""

import os
from abc import ABC, abstractmethod


class DataFetcher(ABC):
    """
    Every DataFetcher must:
      1. implement fetch_rows() → return raw rows list,
      2. implement build_payload(row) → convert a row into a JSON-friendly dict,
      3. fetch_and_prepare() combines fetch_rows() + build_payload(row).
    """

    def __init__(self):
        pass

    @abstractmethod
    def fetch_rows(self) -> list:
        """
        Retrieve all raw rows from the source (e.g., SQLite).
        Return a list of row-like objects.
        """
        ...

    @abstractmethod
    def build_payload(self, row) -> dict | None:
        """
        Given a single raw row, return a dict {"rowid":…, "ts":…, "values":{…}}
        or None if this row should be skipped.
        """
        ...

    def fetch_and_prepare(self) -> list[dict]:
        """
        1. Call fetch_rows() to get all rows.
        2. For each row, call build_payload(row) and keep non-None results.
        3. Return the list of payloads (each payload contains "rowid", "ts", and "values").
        """
        rows = self.fetch_rows()
        payloads: list[dict] = []

        for row in rows:
            pl = self.build_payload(row)
            if pl is None:
                continue
            payloads.append(pl)
        return payloads
