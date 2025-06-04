#!/usr/bin/env python3
"""
data_fetcher.py — Abstract base for reading a “last_id” state file,
fetching raw rows, and building telemetry payloads.
"""
import os
from abc import ABC, abstractmethod


class DataFetcher(ABC):
    """
    Every DataFetcher must:
      1. read/write a “last_id” from a file to track progress,
      2. fetch raw rows newer than that ID,
      3. build a list of telemetry dicts from those rows.
    """

    def __init__(self, state_file: str):
        """
        :param state_file: Path to a file storing the last‐processed ID.
        """
        self.state_file = state_file

    def read_last_id(self) -> int:
        """
        Return the last processed ID from state_file, or 0 if missing/invalid.
        """
        try:
            with open(self.state_file, "r") as f:
                return int(f.read().strip())
        except Exception:
            return 0

    def write_last_id(self, last_id: int):
        """
        Overwrite state_file with last_id.
        """
        directory = os.path.dirname(self.state_file) or "."
        os.makedirs(directory, exist_ok=True)
        with open(self.state_file, "w") as f:
            f.write(str(last_id))

    @abstractmethod
    def fetch_rows(self, since_id: int) -> list:
        """
        Fetch raw rows from the underlying source, all row IDs > since_id.
        Return a list of row‐like objects.
        """
        ...

    @abstractmethod
    def build_payload(self, row) -> dict | None:
        """
        Given a single raw `row`, return a dict {"ts":…, "values":{…}}
        or None to skip this row.
        """
        ...

    def fetch_and_prepare(self) -> tuple[list[dict], int]:
        """
        1. Read last_id from state_file.
        2. Call fetch_rows(last_id).
        3. For each row, call build_payload(row). Keep non‐None payloads.
        4. Track the max rowid seen; return (payloads, last_seen_id).
        """
        last_id = self.read_last_id()
        rows = self.fetch_rows(last_id)

        payloads: list[dict] = []
        last_seen = last_id

        for row in rows:
            pl = self.build_payload(row)
            if pl is None:
                continue
            payloads.append(pl)
            rowid = getattr(row, "rowid", None)
            if isinstance(rowid, int) and rowid > last_seen:
                last_seen = rowid

        return payloads, last_seen
